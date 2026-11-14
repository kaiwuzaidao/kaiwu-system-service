package com.kaiwu.module.agent.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.execution.AgentActionAccess;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.service.AgentActionService;
import com.kaiwu.module.agent.store.AgentActionRecord;
import com.kaiwu.module.agent.store.AgentActionStore;
import com.kaiwu.module.agent.vo.AgentActionView;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.agent.LocalAgentWriteHandler;
import com.kaiwu.port.agent.LocalAgentWriteResult;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validator;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

/** System 本地写动作统一预览、确认、实时授权和结果查询；不经过只读 invoker 或模型总结。 */
@Service("agentActionService")
public class AgentActionServiceImpl implements AgentActionService {
    private static final Logger LOG = LoggerFactory.getLogger(AgentActionService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private final AgentActionStore store;
    private final AgentActionAccess access;
    private final CapabilityCatalog catalog;
    private final ProjectService projects;
    private final Validator validator;
    private final ObjectMapper json;
    private final AuditPort audit;
    private Map<String, LocalAgentWriteHandler> localHandlers = Map.of();

    public AgentActionServiceImpl(
            AgentActionStore store,
            AgentActionAccess access,
            CapabilityCatalog catalog,
            ProjectService projects,
            Validator validator,
            ObjectMapper json,
            AuditPort audit) {
        this.store = store;
        this.access = access;
        this.catalog = catalog;
        this.projects = projects;
        this.validator = validator;
        this.json = json;
        this.audit = audit;
    }

    @org.springframework.beans.factory.annotation.Autowired
    public void localWriteHandlers(List<LocalAgentWriteHandler> handlers) {
        this.localHandlers = handlers.stream()
                .collect(Collectors.toUnmodifiableMap(LocalAgentWriteHandler::capabilityCode, Function.identity()));
    }

    public AgentActionView preview(AgentPlan.Call call, KaiwuContext actor, RequestMetadata metadata) {
        Capability capability = catalog.findVisible(call.code(), actor).orElseThrow(AgentActionServiceImpl::notFound);
        access.require(actor, capability.permission());
        if (capability.readOnly() || !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) throw notFound();
        ProjectCreateRequest request = null;
        Map<String, Object> parameters = null;
        Map<String, String> previewFields = null;
        ConfirmationMode confirmationMode = ConfirmationMode.REQUIRED;
        String confirmationPhrase = null;
        if (CapabilityCatalog.PROJECT_CREATE.equals(capability.code())) {
            request = projectRequest(call.params());
        } else {
            var handler = localHandlers.get(capability.code());
            if (handler == null) throw notFound();
            try {
                parameters = handler.normalize(call.params());
            } catch (IllegalArgumentException invalid) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "操作参数不完整或格式错误", "api.agent.actionParameters");
            }
            previewFields = handler.preview(parameters, actor);
            confirmationMode = handler.confirmationMode(parameters);
            if (confirmationMode == null || confirmationMode == ConfirmationMode.NONE) throw notFound();
            if (confirmationMode == ConfirmationMode.STRONG) {
                confirmationPhrase = handler.confirmationPhrase(parameters, previewFields);
                if (confirmationPhrase == null || confirmationPhrase.isBlank()) throw notFound();
            }
        }
        byte[] secret = new byte[32];
        RANDOM.nextBytes(secret);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(secret);
        var action = new AgentActionRecord(
                UUID.randomUUID().toString(),
                actor.userId(),
                actor.sessionId(),
                capability.code(),
                capability.version(),
                request != null ? planHash(capability, request) : planHash(capability, parameters),
                AgentManifestCodec.digest(token),
                request,
                System.currentTimeMillis() + 300000,
                0,
                "PENDING",
                null,
                null,
                capability.permission(),
                parameters,
                previewFields,
                confirmationMode.name(),
                confirmationPhrase);
        audit(action, actor, "ACTION_PREVIEW", metadata);
        store.create(action);
        return view(action, token);
    }

    public AgentActionView confirm(String id, String token, KaiwuContext actor, RequestMetadata metadata) {
        return confirm(id, token, null, actor, metadata);
    }

    public AgentActionView confirm(
            String id, String token, String phrase, KaiwuContext actor, RequestMetadata metadata) {
        AgentActionRecord action = owned(id, actor);
        access.require(actor, action.permission());
        if (token == null
                || !MessageDigest.isEqual(
                        action.tokenHash().getBytes(StandardCharsets.US_ASCII),
                        AgentManifestCodec.digest(token).getBytes(StandardCharsets.US_ASCII))) {
            audit(action, actor, "ACTION_REJECTED", metadata);
            throw notFound();
        }
        if (!"PENDING".equals(action.status())) {
            audit(action, actor, "ACTION_REPLAY_REJECTED", metadata);
            return view(action, null);
        }
        if (action.expiresAt() <= System.currentTimeMillis()) return terminal(action, "EXPIRED", null, actor, metadata);
        if ("STRONG".equals(action.confirmationMode())
                && !java.util.Objects.equals(action.confirmationPhrase(), phrase)) {
            audit(action, actor, "ACTION_REJECTED", metadata);
            throw new ApiException(HttpStatus.BAD_REQUEST, "确认短语不匹配", "api.agent.actionParameters");
        }
        Capability capability =
                catalog.findVisible(action.capabilityCode(), actor).orElse(null);
        if (capability == null
                || capability.readOnly()
                || !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())
                || !capability.permission().equals(action.permission())
                || !capability.version().equals(action.version())
                || !(action.project() != null
                        ? CapabilityCatalog.PROJECT_CREATE.equals(capability.code())
                                && planHash(capability, action.project()).equals(action.planHash())
                        : localHandlers.containsKey(capability.code())
                                && action.parameters() != null
                                && localHandlers
                                        .get(capability.code())
                                        .confirmationMode(action.parameters())
                                        .name()
                                        .equals(action.confirmationMode())
                                && planHash(capability, action.parameters()).equals(action.planHash())))
            return terminal(action, "REJECTED", "VERSION_CHANGED", actor, metadata);
        // 重新验证冻结参数，而不是接受确认请求提交的新参数。
        if (action.project() != null && !validator.validate(action.project()).isEmpty())
            return terminal(action, "REJECTED", "INVALID_PARAMETERS", actor, metadata);
        if (action.project() == null) {
            try {
                if (!localHandlers
                        .get(capability.code())
                        .normalize(action.parameters())
                        .equals(action.parameters()))
                    return terminal(action, "REJECTED", "INVALID_PARAMETERS", actor, metadata);
            } catch (IllegalArgumentException invalid) {
                return terminal(action, "REJECTED", "INVALID_PARAMETERS", actor, metadata);
            }
        }
        AgentActionRecord executing = action.state("EXECUTING", System.currentTimeMillis(), null, null);
        if (!store.replace(action, executing)) return view(owned(id, actor), null);
        AgentActionRecord outcome;
        String oneTimeSecret = null;
        try {
            // 原子占用后再复核，规划/预览时的旧权限不能让创建调用通过。
            access.require(actor, action.permission());
            audit(executing, actor, "ACTION_CONFIRM", metadata);
            if (executing.expiresAt() <= System.currentTimeMillis()) {
                outcome = executing.state("EXPIRED", executing.startedAt(), null, null);
            } else {
                LocalAgentWriteResult result = executing.project() != null
                        ? new LocalAgentWriteResult(
                                projects.create(executing.project(), actor, metadata)
                                        .id(),
                                null)
                        : localHandlers
                                .get(executing.capabilityCode())
                                .executeForAction(executing.parameters(), executing.previewFields(), actor, metadata);
                oneTimeSecret = result.oneTimeSecret();
                outcome = executing.state("SUCCEEDED", executing.startedAt(), result.id(), null);
            }
        } catch (ApiException rejected) {
            String reason = rejected.getStatus() == HttpStatus.CONFLICT ? "PROJECT_CONFLICT" : "EXECUTION_REJECTED";
            outcome = rejected.getStatus().is4xxClientError()
                    ? executing.state("FAILED", executing.startedAt(), null, reason)
                    : executing.state("UNKNOWN", executing.startedAt(), null, "UNKNOWN_OUTCOME");
        } catch (RuntimeException uncertain) {
            // 事务提交或网络结果不可判定时不能重放；项目编码唯一约束是额外的领域守卫。
            outcome = executing.state("UNKNOWN", executing.startedAt(), null, "UNKNOWN_OUTCOME");
        }
        try {
            if (!store.replace(executing, outcome)) return view(owned(id, actor), null);
        } catch (RuntimeException unavailable) {
            outcome = executing.state("UNKNOWN", executing.startedAt(), null, "UNKNOWN_OUTCOME");
        }
        try {
            audit(outcome, actor, "ACTION_" + outcome.status(), metadata);
        } catch (RuntimeException unavailable) {
            LOG.warn("Agent action outcome audit unavailable: actionId={}", id);
        }
        return view(outcome, null, "SUCCEEDED".equals(outcome.status()) ? oneTimeSecret : null);
    }

    public AgentActionView cancel(String id, KaiwuContext actor, RequestMetadata metadata) {
        var action = owned(id, actor);
        access.require(actor, action.permission());
        if (!"PENDING".equals(action.status())) return view(action, null);
        return terminal(
                action,
                action.expiresAt() <= System.currentTimeMillis() ? "EXPIRED" : "CANCELLED",
                null,
                actor,
                metadata);
    }

    public AgentActionView status(String id, KaiwuContext actor) {
        var action = owned(id, actor);
        access.require(actor, action.permission());
        return view(action, null);
    }

    private AgentActionView terminal(
            AgentActionRecord before, String state, String reason, KaiwuContext actor, RequestMetadata metadata) {
        var next = before.state(state, 0, null, reason);
        if (!store.replace(before, next)) return view(owned(before.actionId(), actor), null);
        audit(next, actor, "ACTION_" + state, metadata);
        return view(next, null);
    }

    private AgentActionRecord owned(String id, KaiwuContext actor) {
        if (id == null || !id.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")) throw notFound();
        var action = store.get(id);
        if (action == null
                || !actor.userId().equals(action.userId())
                || !actor.sessionId().equals(action.sessionId())) throw notFound();
        return action;
    }

    private ProjectCreateRequest projectRequest(Map<String, Object> params) {
        for (var entry : params.entrySet()) {
            if (!java.util.Set.of("projectCode", "projectName", "description", "packageName")
                            .contains(entry.getKey())
                    || !(entry.getValue() instanceof String)) throw invalidParameters();
        }
        String code = text(params, "projectCode");
        String packageName = text(params, "packageName");
        if (packageName == null && code != null) packageName = "com.kaiwu.business." + code.replace("-", "");
        var request =
                new ProjectCreateRequest(code, text(params, "projectName"), text(params, "description"), packageName);
        if (!validator.validate(request).isEmpty() || "system".equals(code)) throw invalidParameters();
        return request;
    }

    private static String text(Map<String, Object> params, String name) {
        String value = (String) params.get(name);
        return value == null || value.isBlank() ? null : value.trim();
    }

    private String planHash(Capability capability, ProjectCreateRequest request) {
        return AgentManifestCodec.digest(
                capability.code() + "\n" + capability.version() + "\n" + json.writeValueAsString(request));
    }

    private String planHash(Capability capability, Map<String, Object> parameters) {
        return AgentManifestCodec.digest(
                capability.code() + "\n" + capability.version() + "\n" + json.writeValueAsString(parameters));
    }

    private static AgentActionView view(AgentActionRecord action, String token) {
        return view(action, token, null);
    }

    private static AgentActionView view(AgentActionRecord action, String token, String oneTimeSecret) {
        String status = action.status();
        if ("PENDING".equals(status) && action.expiresAt() <= System.currentTimeMillis()) status = "EXPIRED";
        if ("EXECUTING".equals(status) && action.startedAt() + 60000 <= System.currentTimeMillis()) status = "UNKNOWN";
        return new AgentActionView(
                action.actionId(),
                action.capabilityCode(),
                action.version(),
                status,
                action.project(),
                Instant.ofEpochMilli(action.expiresAt()),
                token,
                action.projectId(),
                action.reason(),
                action.permission(),
                action.previewFields() == null
                        ? null
                        : action.previewFields().entrySet().stream()
                                .filter(entry -> !entry.getKey().startsWith("_"))
                                .collect(Collectors.toUnmodifiableMap(Map.Entry::getKey, Map.Entry::getValue)),
                oneTimeSecret,
                action.confirmationMode(),
                token == null ? null : action.confirmationPhrase());
    }

    private void audit(AgentActionRecord action, KaiwuContext actor, String operation, RequestMetadata metadata) {
        audit.recordOperation(
                actor,
                "agent",
                operation,
                "/api/agent/actions",
                "actionId=" + action.actionId() + " capability=" + action.capabilityCode(),
                metadata);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "操作不存在或不可用，请重新发起", "api.agent.actionNotFound");
    }

    private static ApiException invalidParameters() {
        return new ApiException(HttpStatus.BAD_REQUEST, "项目参数不完整或格式错误，请补充项目编码与名称", "api.agent.actionParameters");
    }
}
