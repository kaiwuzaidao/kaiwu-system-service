package com.kaiwu.module.agent.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentRemoteWriteAuthorizationRequest;
import com.kaiwu.module.agent.entity.AgentRemoteActionEntity;
import com.kaiwu.module.agent.planning.AgentPlanValidator;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.repository.AgentRemoteActionRepository;
import com.kaiwu.module.agent.service.AgentRemoteActionService;
import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.port.ProjectAgentAccessPort;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.core.StreamReadConstraints;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.core.json.JsonFactory;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.json.JsonMapper;

/** 远程写任务的冻结、一次性确认和取消；调用者必须先取得真实业务预览。 */
@Service("agentRemoteActionService")
public class AgentRemoteActionServiceImpl implements AgentRemoteActionService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final JsonMapper JSON = JsonMapper.builder(JsonFactory.builder()
                    .streamReadConstraints(StreamReadConstraints.builder()
                            .maxNestingDepth(12)
                            .maxStringLength(32_768)
                            .maxNumberLength(20)
                            .build())
                    .build())
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
            .build();

    /** 只供内部 Gateway 授权入口使用；不含冻结参数和确认凭据。 */

    /** 只交给内部 Gateway 调用方，不能作为 HTTP 响应或模型上下文。 */
    private record Frozen(
            String actionId,
            String userId,
            String sessionId,
            String projectId,
            String projectCode,
            String capabilityCode,
            String capabilityName,
            String version,
            String manifestHash,
            String permission,
            String paramsJson,
            String preconditionsJson,
            String previewJson,
            String previewHash,
            String confirmationMode,
            Set<String> outboundFields,
            long expiresAtMillis,
            String correlationId) {
        @Override
        public String toString() {
            return "Frozen[redacted]";
        }
    }

    private record Preview(
            Map<String, String> displayFields,
            Map<String, String> displayLabels,
            int affectedCount,
            String preconditionsJson) {
        @Override
        public String toString() {
            return "Preview[redacted]";
        }
    }

    private final AgentRemoteActionRepository repository;
    private final RemoteCapabilitySource source;
    private final ProjectAgentAccessPort projects;
    private final ConfigEncryptionService encryption;
    private final Clock clock;

    public AgentRemoteActionServiceImpl(
            AgentRemoteActionRepository repository,
            RemoteCapabilitySource source,
            ProjectAgentAccessPort projects,
            ConfigEncryptionService encryption,
            Clock clock) {
        this.repository = repository;
        this.source = source;
        this.projects = projects;
        this.encryption = encryption;
        this.clock = clock;
    }

    /** 仅供内部业务预览调用链使用；不能将浏览器或模型提交的预览直接传入。 */
    public Pending prepare(
            String code,
            String version,
            String manifestHash,
            String paramsJson,
            String preconditionsJson,
            String previewJson,
            String correlationId,
            KaiwuContext actor) {
        requireSession(actor);
        if (correlationId == null || !correlationId.matches("[A-Za-z0-9-]{1,64}")) throw unavailable();
        var approved = source.authorizeWrite(code, version, manifestHash, actor.sessionId());
        if (!approved.capability().idempotent() || approved.capability().readOnly()) throw unavailable();
        parameters(paramsJson, approved.capability());
        preconditions(preconditionsJson);
        Preview preview = preview(previewJson);
        if (!preconditionsJson.equals(preview.preconditionsJson())) throw unavailable();
        String actionId = UUID.randomUUID().toString();
        Instant expiry = clock.instant().plusSeconds(300).truncatedTo(ChronoUnit.MILLIS);
        String previewHash =
                AgentManifestCodec.digest(JSON.writeValueAsString(List.of(previewJson, preconditionsJson)));
        var frozen = new Frozen(
                actionId,
                actor.userId(),
                actor.sessionId(),
                approved.access().projectId(),
                approved.access().projectCode(),
                code,
                approved.capability().description(),
                version,
                manifestHash,
                approved.capability().permission(),
                paramsJson,
                preconditionsJson,
                previewJson,
                previewHash,
                approved.confirmation().name(),
                approved.capability().outboundFields(),
                expiry.toEpochMilli(),
                correlationId);
        byte[] secret = new byte[32];
        RANDOM.nextBytes(secret);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(secret);
        LocalDateTime now = now();
        var action = new AgentRemoteActionEntity();
        action.setActionId(actionId);
        action.setProjectId(frozen.projectId());
        action.setUserId(frozen.userId());
        action.setSessionId(frozen.sessionId());
        action.setCapabilityCode(code);
        action.setCapabilityVersion(version);
        action.setManifestHash(manifestHash);
        action.setParamsHash(AgentManifestCodec.digest(paramsJson));
        action.setPreconditionsHash(AgentManifestCodec.digest(preconditionsJson));
        action.setPreviewHash(previewHash);
        action.setFrozenCiphertext(encryption.encrypt(JSON.writeValueAsString(frozen)));
        action.setTokenHash(AgentManifestCodec.digest(token));
        action.setConfirmationMode(frozen.confirmationMode());
        action.setStatus("PENDING");
        action.setExpiresAt(LocalDateTime.ofInstant(expiry, clock.getZone()));
        action.setRevision(0);
        action.setCreatedAt(now);
        action.setUpdatedAt(now);
        repository.create(action);
        return new Pending(actionId, token, phrase(frozen), view(preview), expiry);
    }

    /** SQL CAS 成功后仍复核实时权限；返回后只能发送一次，不得因网络错误重发。 */
    public Claimed confirm(String actionId, String token, String typedPhrase, KaiwuContext actor) {
        var action = owned(actionId, actor);
        Frozen frozen = frozen(action);
        if (!matchesToken(token, action.getTokenHash())
                || ("STRONG".equals(action.getConfirmationMode())
                        && !phrase(frozen).equals(typedPhrase))) throw unavailable();
        if (!"PENDING".equals(action.getStatus())) throw unavailable();
        LocalDateTime now = now();
        if (!action.getExpiresAt().isAfter(now)) {
            repository.closePending(action, "EXPIRED", "ACTION_EXPIRED", now);
            throw unavailable();
        }
        if (!stillApproved(frozen, actor)) {
            repository.closePending(action, "REJECTED", "ACCESS_CHANGED", now);
            throw unavailable();
        }
        if (!repository.claim(action, now)) throw unavailable();
        // 认领后发生撤权也不能发出执行；确定未发出时记为 FAILED。
        if (!stillApproved(frozen, actor)) {
            AgentRemoteActionEntity claimed = repository
                    .owned(actionId, actor.userId(), actor.sessionId())
                    .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
            repository.complete(claimed, "FAILED", null, "ACCESS_CHANGED_BEFORE_DISPATCH", now());
            throw unavailable();
        }
        return new Claimed(
                actionId,
                frozen.projectId(),
                frozen.projectCode(),
                frozen.capabilityCode(),
                frozen.version(),
                frozen.manifestHash(),
                frozen.paramsJson(),
                frozen.preconditionsJson(),
                frozen.previewHash(),
                frozen.expiresAtMillis(),
                frozen.correlationId());
    }

    public State cancel(String actionId, KaiwuContext actor) {
        var action = owned(actionId, actor);
        if ("PENDING".equals(action.getStatus())) {
            LocalDateTime now = now();
            String target = action.getExpiresAt().isAfter(now) ? "CANCELLED" : "EXPIRED";
            repository.closePending(action, target, null, now);
        }
        return status(actionId, actor);
    }

    public State status(String actionId, KaiwuContext actor) {
        var action = owned(actionId, actor);
        Frozen frozen = frozen(action);
        if ("EXECUTING".equals(action.getStatus())
                && action.getStartedAt() != null
                && !action.getStartedAt().isAfter(now().minusSeconds(60))) {
            repository.markUnknown(action, now().minusSeconds(60), now());
            action = owned(actionId, actor);
        }
        return new State(
                actionId,
                frozen.projectId(),
                frozen.projectCode(),
                frozen.capabilityCode(),
                frozen.capabilityName(),
                frozen.version(),
                action.getStatus(),
                frozen.confirmationMode(),
                view(preview(frozen.previewJson())),
                Instant.ofEpochMilli(frozen.expiresAtMillis()),
                action.getReasonCode(),
                "SUCCEEDED".equals(action.getStatus()) ? storedResult(action, frozen) : null);
    }

    /** 结果核实时使用冻结原文；只允许原会话查询已认领或未知的动作。 */
    public Claimed queryBinding(String actionId, KaiwuContext actor) {
        var action = owned(actionId, actor);
        if (!("EXECUTING".equals(action.getStatus()) || "UNKNOWN".equals(action.getStatus()))) throw unavailable();
        return claimed(frozen(action));
    }

    /** 确定已提交的结果只能来自 Gateway 固定 Handler 响应；任意异常由调用方转 UNKNOWN。 */
    public State acceptResult(Claimed claimed, byte[] response, KaiwuContext actor) {
        var action = repository
                .owned(claimed.actionId(), actor.userId(), actor.sessionId())
                .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        Frozen value = frozen(action);
        if (!claimed(value).equals(claimed)) throw unavailable();
        Map<String, Object> result = successful(response, value.outboundFields());
        if (result != null) {
            String ciphertext = encryption.encrypt(
                    JSON.writeValueAsString(Map.of("actionId", claimed.actionId(), "result", result)));
            LocalDateTime now = now();
            if ("EXECUTING".equals(action.getStatus())) {
                repository.complete(action, "SUCCEEDED", ciphertext, null, now);
            } else if ("UNKNOWN".equals(action.getStatus())) {
                repository.reconcile(action, "SUCCEEDED", ciphertext, null, now);
            }
        } else if ("EXECUTING".equals(action.getStatus())) {
            repository.markUnknown(action, now(), now());
        }
        return status(claimed.actionId(), actor);
    }

    /** 发出执行后任何不确定响应均不能重发；SQL CAS 仅转为待核实。 */
    public State markUnknown(Claimed claimed, KaiwuContext actor) {
        var action = repository
                .owned(claimed.actionId(), actor.userId(), actor.sessionId())
                .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        if (!claimed(frozen(action)).equals(claimed)) throw unavailable();
        if ("EXECUTING".equals(action.getStatus())) repository.markUnknown(action, now(), now());
        return status(claimed.actionId(), actor);
    }

    private static Claimed claimed(Frozen value) {
        return new Claimed(
                value.actionId(),
                value.projectId(),
                value.projectCode(),
                value.capabilityCode(),
                value.version(),
                value.manifestHash(),
                value.paramsJson(),
                value.preconditionsJson(),
                value.previewHash(),
                value.expiresAtMillis(),
                value.correlationId());
    }

    private static Map<String, Object> successful(byte[] response, Set<String> allowed) {
        if (response == null || response.length > 65_536) throw unavailable();
        var tree = JSON.readTree(response);
        if (tree == null || !tree.isObject() || !tree.path("state").isString()) throw unavailable();
        if ("UNKNOWN".equals(tree.path("state").asString())) {
            if (tree.size() != 1) throw unavailable();
            return null;
        }
        if (tree.size() != 2
                || !"SUCCEEDED".equals(tree.path("state").asString())
                || !tree.path("result").isObject()) throw unavailable();
        Map<String, Object> safe = new java.util.LinkedHashMap<>();
        tree.path("result").properties().forEach(entry -> {
            String name = entry.getKey();
            var field = entry.getValue();
            if (!allowed.contains(name) || field.isContainer() || field.isNull()) throw unavailable();
            if (field.isString()) {
                String text = field.asString();
                String lower = text.toLowerCase(Locale.ROOT);
                if (text.length() > 8000
                        || text.contains("<")
                        || text.contains(">")
                        || lower.contains("http://")
                        || lower.contains("https://")
                        || lower.contains("javascript:")
                        || lower.contains("data:")) throw unavailable();
            } else if (!field.isNumber() && !field.isBoolean()) throw unavailable();
            safe.put(name, JSON.convertValue(field, Object.class));
        });
        if (JSON.writeValueAsBytes(safe).length > 16_384) throw unavailable();
        return Map.copyOf(safe);
    }

    private Map<String, Object> storedResult(AgentRemoteActionEntity action, Frozen frozen) {
        if (action.getResultCiphertext() == null) throw new IllegalStateException("Agent result missing");
        var envelope = JSON.readTree(encryption.decrypt(action.getResultCiphertext()));
        if (!envelope.isObject()
                || envelope.size() != 2
                || !frozen.actionId().equals(envelope.path("actionId").asString())
                || !envelope.path("result").isObject())
            throw new IllegalStateException("Agent result binding mismatch");
        envelope.path("result").properties().forEach(entry -> {
            if (!frozen.outboundFields().contains(entry.getKey())
                    || entry.getValue().isContainer()) throw new IllegalStateException("Agent result field mismatch");
        });
        return JSON.convertValue(envelope.path("result"), new TypeReference<Map<String, Object>>() {});
    }

    /** EXECUTE 必须已被原会话认领；RESULT 只允许同一用户和会话核实未决执行。 */
    public Delegation authorizeDelegation(AgentRemoteWriteAuthorizationRequest request, String userId) {
        var action = repository
                .owned(request.actionId(), userId, request.sessionId())
                .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        Frozen value = frozen(action);
        if (!Objects.equals(value.capabilityCode(), request.code())
                || !Objects.equals(value.version(), request.version())
                || !Objects.equals(value.manifestHash(), request.manifestHash())
                || !Objects.equals(action.getParamsHash(), request.paramsHash())
                || !Objects.equals(action.getPreconditionsHash(), request.preconditionsHash())
                || !Objects.equals(value.previewHash(), request.previewHash())
                || !Objects.equals(value.expiresAtMillis(), request.actionExpiresAt())
                || !Objects.equals(value.correlationId(), request.correlationId())) throw unavailable();
        var access =
                projects.resolve(value.projectCode(), userId).orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        if (!access.projectId().equals(value.projectId())
                || !access.projectCode().equals(value.projectCode())
                || !access.permissions().contains(value.permission())) throw unavailable();
        if ("EXECUTE".equals(request.operation())) {
            if (!"EXECUTING".equals(action.getStatus()) || clock.instant().toEpochMilli() >= value.expiresAtMillis())
                throw unavailable();
            var approved = source.authorizeWrite(
                    value.capabilityCode(), value.version(), value.manifestHash(), request.sessionId());
            if (!approved.access().projectId().equals(value.projectId())
                    || !approved.access().projectCode().equals(value.projectCode())
                    || !approved.capability().permission().equals(value.permission())
                    || !approved.confirmation().name().equals(value.confirmationMode())) throw unavailable();
            return new Delegation(userId, approved.access(), approved.timeoutMs());
        }
        if (!"RESULT".equals(request.operation())
                || !("EXECUTING".equals(action.getStatus()) || "UNKNOWN".equals(action.getStatus())))
            throw unavailable();
        // 关闭写开关或清单下线后，仍允许原用户核实已发出的未知结果。
        return new Delegation(userId, access, 3000);
    }

    private AgentRemoteActionEntity owned(String actionId, KaiwuContext actor) {
        requireSession(actor);
        if (actionId == null || !actionId.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"))
            throw unavailable();
        var action = repository
                .owned(actionId, actor.userId(), actor.sessionId())
                .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        Frozen frozen = frozen(action);
        var access = projects.resolve(frozen.projectCode(), actor.userId())
                .orElseThrow(AgentRemoteActionServiceImpl::unavailable);
        if (!access.projectId().equals(action.getProjectId())
                || !access.permissions().contains(frozen.permission())) throw unavailable();
        return action;
    }

    private Frozen frozen(AgentRemoteActionEntity action) {
        try {
            Frozen value = JSON.readValue(encryption.decrypt(action.getFrozenCiphertext()), Frozen.class);
            if (value == null
                    || !Objects.equals(value.actionId(), action.getActionId())
                    || !Objects.equals(value.userId(), action.getUserId())
                    || !Objects.equals(value.sessionId(), action.getSessionId())
                    || !Objects.equals(value.projectId(), action.getProjectId())
                    || !Objects.equals(value.capabilityCode(), action.getCapabilityCode())
                    || value.capabilityName() == null
                    || value.capabilityName().length() > 200
                    || !Objects.equals(value.version(), action.getCapabilityVersion())
                    || !Objects.equals(value.manifestHash(), action.getManifestHash())
                    || !Objects.equals(value.confirmationMode(), action.getConfirmationMode())
                    || value.outboundFields() == null
                    || !Objects.equals(value.previewHash(), action.getPreviewHash())
                    || !Objects.equals(
                            value.previewHash(),
                            AgentManifestCodec.digest(
                                    JSON.writeValueAsString(List.of(value.previewJson(), value.preconditionsJson()))))
                    || !Objects.equals(AgentManifestCodec.digest(value.paramsJson()), action.getParamsHash())
                    || !Objects.equals(
                            AgentManifestCodec.digest(value.preconditionsJson()), action.getPreconditionsHash())
                    || !LocalDateTime.ofInstant(Instant.ofEpochMilli(value.expiresAtMillis()), clock.getZone())
                            .equals(action.getExpiresAt()))
                throw new IllegalStateException("Remote Agent action binding mismatch");
            return value;
        } catch (RuntimeException failure) {
            throw new IllegalStateException("Remote Agent action binding unavailable", failure);
        }
    }

    private boolean stillApproved(Frozen frozen, KaiwuContext actor) {
        try {
            var approved = source.authorizeWrite(
                    frozen.capabilityCode(), frozen.version(), frozen.manifestHash(), actor.sessionId());
            return approved.access().projectId().equals(frozen.projectId())
                    && approved.access().projectCode().equals(frozen.projectCode())
                    && approved.capability().permission().equals(frozen.permission())
                    && approved.confirmation().name().equals(frozen.confirmationMode());
        } catch (PlanRejectedException denied) {
            return false;
        }
    }

    private void requireSession(KaiwuContext actor) {
        if (actor == null || !actor.userId().equals(source.user(actor.sessionId()))) throw unavailable();
    }

    private static boolean matchesToken(String token, String hash) {
        return token != null
                && token.matches("[A-Za-z0-9_-]{43}")
                && MessageDigest.isEqual(
                        AgentManifestCodec.digest(token).getBytes(StandardCharsets.US_ASCII),
                        hash.getBytes(StandardCharsets.US_ASCII));
    }

    private static String phrase(Frozen frozen) {
        return "确认 " + frozen.previewHash().substring(0, 8);
    }

    private static void object(String raw, int maxBytes) {
        if (raw == null
                || raw.getBytes(StandardCharsets.UTF_8).length > maxBytes
                || !JSON.readTree(raw).isObject()) throw unavailable();
    }

    private static void parameters(String raw, Capability capability) {
        object(raw, 16_384);
        Map<String, Object> values = JSON.readValue(raw, new TypeReference<Map<String, Object>>() {});
        if (values.size() > 32) throw unavailable();
        values.forEach((name, value) -> {
            ParamSpec spec = capability.paramsSchema().get(name);
            if (spec == null || value == null) throw unavailable();
            switch (spec.type()) {
                case STRING -> {
                    if (!(value instanceof String text)
                            || (spec.required() && text.isBlank())
                            || (spec.maxLength() != null && text.length() > spec.maxLength())) throw unavailable();
                }
                case STRING_LIST -> {
                    if (!AgentPlanValidator.validStringList(spec, value)) throw unavailable();
                }
                case ENUM -> {
                    if (!(value instanceof String)
                            || spec.values() == null
                            || !spec.values().contains(value)) throw unavailable();
                }
                case BOOL -> {
                    if (!(value instanceof Boolean)) throw unavailable();
                }
                case DATETIME -> {
                    if (!(value instanceof String text)) throw unavailable();
                    try {
                        LocalDateTime.parse(text);
                    } catch (DateTimeParseException invalid) {
                        throw unavailable();
                    }
                }
                case INT -> {
                    if (!(value instanceof Number)) throw unavailable();
                    try {
                        int number = new BigDecimal(value.toString()).intValueExact();
                        if ((spec.min() != null && number < spec.min()) || (spec.max() != null && number > spec.max()))
                            throw unavailable();
                    } catch (ArithmeticException invalid) {
                        throw unavailable();
                    }
                }
            }
        });
        capability.paramsSchema().forEach((name, spec) -> {
            if (spec.required() && !values.containsKey(name)) throw unavailable();
        });
    }

    private static void preconditions(String raw) {
        object(raw, 16_384);
        Map<String, Object> values = JSON.readValue(raw, new TypeReference<Map<String, Object>>() {});
        if (values.size() > 32) throw unavailable();
        values.forEach((name, value) -> {
            String normalized = name == null ? "" : name.replace("_", "").toLowerCase(Locale.ROOT);
            if (name == null
                    || forbiddenName(normalized)
                    || (value != null
                            && !(value instanceof String || value instanceof Number || value instanceof Boolean))
                    || (value instanceof String text && text.length() > 8000)) throw unavailable();
        });
    }

    private static Preview preview(String raw) {
        if (raw == null || raw.getBytes(StandardCharsets.UTF_8).length > 65_536) throw unavailable();
        Preview value = JSON.readValue(raw, Preview.class);
        if (value == null
                || value.displayFields() == null
                || value.displayFields().size() > 32
                || (value.displayLabels() != null
                        && value.displayLabels().size() > value.displayFields().size())
                || value.affectedCount() < 0
                || value.affectedCount() > 100
                || value.preconditionsJson() == null) throw unavailable();
        value.displayFields().forEach((name, text) -> {
            String normalized = name == null ? "" : name.replace("_", "").toLowerCase(Locale.ROOT);
            String lower = text == null ? "" : text.toLowerCase(Locale.ROOT);
            if (name == null
                    || !name.matches("[a-zA-Z][a-zA-Z0-9_]{0,63}")
                    || forbiddenName(normalized)
                    || text == null
                    || text.length() > 8000
                    || text.contains("<")
                    || text.contains(">")
                    || lower.contains("http://")
                    || lower.contains("https://")
                    || lower.contains("javascript:")
                    || lower.contains("data:")
                    || text.chars().anyMatch(c -> c < 0x20 && c != '\n' && c != '\t')) throw unavailable();
        });
        if (value.displayLabels() != null)
            value.displayLabels().forEach((name, label) -> {
                String lower = label == null ? "" : label.toLowerCase(Locale.ROOT);
                if (!value.displayFields().containsKey(name)
                        || label == null
                        || label.isBlank()
                        || label.length() > 120
                        || label.contains("<")
                        || label.contains(">")
                        || lower.contains("http://")
                        || lower.contains("https://")
                        || lower.contains("javascript:")
                        || lower.contains("data:")) throw unavailable();
            });
        return value;
    }

    private static PreviewView view(Preview preview) {
        return new PreviewView(
                Map.copyOf(preview.displayFields()),
                preview.displayLabels() == null ? Map.of() : Map.copyOf(preview.displayLabels()),
                preview.affectedCount());
    }

    private static boolean forbiddenName(String name) {
        return name.contains("url")
                || name.contains("password")
                || name.contains("secret")
                || name.contains("token")
                || name.contains("credential")
                || name.contains("privatekey")
                || name.contains("authorization")
                || name.contains("context");
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock).truncatedTo(ChronoUnit.MILLIS);
    }

    private static ApiException unavailable() {
        return new ApiException(HttpStatus.NOT_FOUND, "操作不存在或不可用", "api.agent.actionNotFound");
    }
}
