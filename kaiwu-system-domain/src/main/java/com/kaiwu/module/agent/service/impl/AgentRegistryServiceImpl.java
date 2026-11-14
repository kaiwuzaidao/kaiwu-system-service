package com.kaiwu.module.agent.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.dto.AgentCapabilityBatchReviewRequest;
import com.kaiwu.module.agent.dto.AgentCapabilityReviewRequest;
import com.kaiwu.module.agent.dto.AgentCapabilityRevision;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.CapabilityManifest;
import com.kaiwu.module.agent.protocol.CapabilityManifestValidator;
import com.kaiwu.module.agent.repository.AgentRegistryRepository;
import com.kaiwu.module.agent.service.AgentRegistryService;
import com.kaiwu.module.agent.vo.AgentCredentialView;
import com.kaiwu.module.agent.vo.AgentRegistrationView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Agent 能力注册生命周期。每个事务先锁项目行，再读取凭据/清单；轮换和撤销不能被旧请求覆盖。
 * APPROVED 仅表示该版清单通过审核；写能力还须启用独立执行开关、保持在线并满足当前项目权限。
 */
@Service("agentRegistryService")
public class AgentRegistryServiceImpl implements AgentRegistryService {
    private static final String PREFIX = "kagent_";
    private static final SecureRandom RANDOM = new SecureRandom();
    private final AgentRegistryRepository repository;
    private final CapabilityManifestValidator validator;
    private final AgentManifestCodec codec;
    private final Clock clock;
    private final AuditPort audit;

    public AgentRegistryServiceImpl(
            AgentRegistryRepository repository,
            CapabilityManifestValidator validator,
            AgentManifestCodec codec,
            Clock clock,
            AuditPort audit) {
        this.repository = repository;
        this.validator = validator;
        this.codec = codec;
        this.clock = clock;
        this.audit = audit;
    }

    /** 平台项目编辑权限加目标项目有效 project-admin；令牌只在本次响应返回。 */
    @Transactional
    public AgentCredentialView rotateCredential(String projectId, KaiwuContext actor, RequestMetadata metadata) {
        requireAdmin(projectId, actor, true);
        if (!repository.active(projectId)) throw conflict();
        AgentCredentialEntity credential = repository.credential(projectId);
        boolean fresh = credential == null;
        if (fresh) {
            credential = new AgentCredentialEntity();
            credential.setProjectId(projectId);
            credential.setCreatedAt(now());
        }
        byte[] secret = new byte[32];
        RANDOM.nextBytes(secret);
        String token = PREFIX + projectId + "_"
                + Base64.getUrlEncoder().withoutPadding().encodeToString(secret);
        credential.setCredentialId(UUID.randomUUID().toString());
        credential.setTokenHash(AgentManifestCodec.digest(token));
        credential.setStatus("ACTIVE");
        credential.setUpdatedAt(now());
        if (fresh) repository.insertCredential(credential);
        else repository.updateCredential(credential);
        repository.invalidate(projectId, "PENDING", now());
        event(projectId, null, "CREDENTIAL_ROTATED", actor.userId(), credential.getCredentialId());
        adminAudit(actor, projectId, "CREDENTIAL_ROTATED", metadata);
        return new AgentCredentialView(projectId, credential.getCredentialId(), token);
    }

    @Transactional
    public void revokeCredential(String projectId, KaiwuContext actor, RequestMetadata metadata) {
        requireAdmin(projectId, actor, true);
        AgentCredentialEntity credential = repository.credential(projectId);
        if (credential == null) return;
        credential.setStatus("REVOKED");
        credential.setUpdatedAt(now());
        repository.updateCredential(credential);
        repository.invalidate(projectId, "REVOKED", now());
        event(projectId, null, "CREDENTIAL_REVOKED", actor.userId(), credential.getCredentialId());
        adminAudit(actor, projectId, "CREDENTIAL_REVOKED", metadata);
    }

    /** 单条注册；同版同内容幂等，改内容必须递增版本，已撤销记录只能由管理员重新开放。 */
    @Transactional
    public AgentRegistrationView register(String authorization, byte[] body) {
        Authenticated credential = authenticate(authorization);
        CapabilityManifest manifest = codec.decode(body);
        validate(manifest, credential.projectId(), credential.projectCode());
        String canonical = codec.canonical(manifest);
        if (canonical.getBytes(StandardCharsets.UTF_8).length > AgentManifestCodec.MAX_BYTES) throw invalid();
        String hash = AgentManifestCodec.digest(canonical);
        AgentCapabilityEntity row = repository.capability(credential.projectId(), manifest.code());
        String operation = null;
        if (row == null) {
            if (repository.count(credential.projectId()) >= 100) throw conflict();
            row = new AgentCapabilityEntity();
            row.setId(LongIdGenerator.nextId());
            row.setProjectId(credential.projectId());
            row.setCapabilityCode(manifest.code());
            row.setCreatedAt(now());
            operation = "REGISTERED";
        } else {
            if ("REVOKED".equals(row.getStatus())) throw conflict();
            if (row.getVersion().equals(manifest.version())) {
                if (!row.getManifestHash().equals(hash)) throw conflict();
            } else {
                if (compareVersion(manifest.version(), row.getVersion()) <= 0) throw conflict();
                operation = "VERSION_CHANGED";
            }
        }
        if (operation != null) {
            row.setVersion(manifest.version());
            row.setManifestJson(canonical);
            row.setManifestHash(hash);
            row.setStatus("PENDING");
        }
        row.setLastSeenAt(now());
        row.setUpdatedAt(now());
        if ("REGISTERED".equals(operation)) repository.insertCapability(row);
        else repository.updateCapability(row);
        if (operation != null) event(credential.projectId(), row, operation, null, credential.id());
        return view(row, true);
    }

    @Transactional
    public AgentRegistrationView heartbeat(String authorization, AgentCapabilityRevision revision) {
        Authenticated credential = authenticate(authorization);
        AgentCapabilityEntity row = requireRevision(credential.projectId(), revision);
        if ("REVOKED".equals(row.getStatus())) throw conflict();
        validate(
                codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8)),
                credential.projectId(),
                credential.projectCode());
        row.setLastSeenAt(now());
        row.setUpdatedAt(now());
        repository.updateCapability(row);
        return view(row, true);
    }

    @Transactional
    public List<AgentRegistrationView> list(String projectId, KaiwuContext actor) {
        requireAdmin(projectId, actor, false);
        AgentCredentialEntity credential = repository.credential(projectId);
        boolean active = repository.active(projectId) && credential != null && "ACTIVE".equals(credential.getStatus());
        return repository.list(projectId).stream().map(row -> view(row, active)).toList();
    }

    /** 审核前展示完整规范化清单；无跨项目取数或凭据摘要。 */
    @Transactional
    public com.kaiwu.module.agent.vo.AgentCapabilityDetailView detail(
            String projectId, String code, KaiwuContext actor) {
        requireAdmin(projectId, actor, false);
        if (code == null || code.length() > 160) throw invalid();
        AgentCapabilityEntity row = repository.capability(projectId, code);
        if (row == null) throw conflict();
        AgentCredentialEntity credential = repository.credential(projectId);
        boolean active = repository.active(projectId) && credential != null && "ACTIVE".equals(credential.getStatus());
        return new com.kaiwu.module.agent.vo.AgentCapabilityDetailView(view(row, active), row.getManifestJson());
    }

    /** 审核与撤销都绑定已展示的版本和摘要，避免审核期间另一实例换版。 */
    @Transactional
    public AgentRegistrationView review(
            String projectId, AgentCapabilityReviewRequest request, KaiwuContext actor, RequestMetadata metadata) {
        String projectCode = requireAdmin(projectId, actor, true);
        AgentCapabilityEntity row = requireRevision(projectId, request.revision());
        AgentCredentialEntity credential = repository.credential(projectId);
        boolean active = repository.active(projectId) && credential != null && "ACTIVE".equals(credential.getStatus());
        switch (request.status()) {
            case "APPROVED" -> {
                if (!active || !"PENDING".equals(row.getStatus()) || !online(row)) throw conflict();
                CapabilityManifest manifest = codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8));
                validate(manifest, projectId, projectCode);
            }
            case "PENDING", "REVOKED" -> row.setLastSeenAt(null);
            default -> throw invalid();
        }
        row.setStatus(request.status());
        row.setUpdatedAt(now());
        repository.updateCapability(row);
        event(projectId, row, "REVIEW_" + request.status(), actor.userId(), null);
        adminAudit(actor, projectId, "REVIEW_" + request.status(), metadata);
        return view(row, active);
    }

    /** 同一项目行锁与事务内先验证整批，只允许在线待审只读能力；任一失败不批准任何一项。 */
    @Transactional
    public List<AgentRegistrationView> reviewBatch(
            String projectId, AgentCapabilityBatchReviewRequest request, KaiwuContext actor, RequestMetadata metadata) {
        String projectCode = requireAdmin(projectId, actor, true);
        if (request == null
                || request.revisions() == null
                || request.revisions().isEmpty()
                || request.revisions().size() > 50) throw invalid();
        AgentCredentialEntity credential = repository.credential(projectId);
        boolean active = repository.active(projectId) && credential != null && "ACTIVE".equals(credential.getStatus());
        if (!active) throw conflict();
        var codes = new HashSet<String>();
        var approved = new ArrayList<AgentCapabilityEntity>();
        for (AgentCapabilityRevision revision : request.revisions()) {
            if (revision == null || revision.capabilityCode() == null || !codes.add(revision.capabilityCode()))
                throw invalid();
            AgentCapabilityEntity row = requireRevision(projectId, revision);
            if (!"PENDING".equals(row.getStatus()) || !online(row)) throw conflict();
            CapabilityManifest manifest = codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8));
            if (!manifest.readOnly()) throw invalid();
            validate(manifest, projectId, projectCode);
            approved.add(row);
        }
        var result = new ArrayList<AgentRegistrationView>(approved.size());
        for (AgentCapabilityEntity row : approved) {
            row.setStatus("APPROVED");
            row.setUpdatedAt(now());
            repository.updateCapability(row);
            event(projectId, row, "REVIEW_APPROVED", actor.userId(), null);
            adminAudit(actor, projectId, "REVIEW_APPROVED", metadata);
            result.add(view(row, active));
        }
        return result;
    }

    private String requireAdmin(String projectId, KaiwuContext actor, boolean write) {
        if (actor == null || !actor.hasPermission(write ? "system:project:update" : "system:project:list"))
            throw forbidden();
        if (projectId == null || !projectId.matches("[1-9][0-9]{0,18}")) throw forbidden();
        String code = repository.lockProject(projectId);
        if (code == null || !repository.isAdmin(projectId, actor.userId())) throw forbidden();
        return code;
    }

    private Authenticated authenticate(String authorization) {
        if (authorization == null || authorization.length() > 150 || !authorization.startsWith("Bearer " + PREFIX))
            throw unauthorized();
        String token = authorization.substring(7);
        String[] parts = token.split("_", 3);
        if (parts.length != 3 || !parts[1].matches("[1-9][0-9]{0,18}") || !parts[2].matches("[A-Za-z0-9_-]{43}"))
            throw unauthorized();
        String projectCode = repository.lockProject(parts[1]);
        if (projectCode == null || !repository.active(parts[1])) throw unauthorized();
        AgentCredentialEntity credential = repository.credential(parts[1]);
        if (credential == null
                || !"ACTIVE".equals(credential.getStatus())
                || !MessageDigest.isEqual(
                        AgentManifestCodec.digest(token).getBytes(StandardCharsets.US_ASCII),
                        credential.getTokenHash().getBytes(StandardCharsets.US_ASCII))) throw unauthorized();
        return new Authenticated(parts[1], projectCode, credential.getCredentialId());
    }

    private AgentCapabilityEntity requireRevision(String projectId, AgentCapabilityRevision revision) {
        if (revision == null) throw conflict();
        AgentCapabilityEntity row = repository.capability(projectId, revision.capabilityCode());
        if (row == null
                || !row.getVersion().equals(revision.version())
                || !row.getManifestHash().equals(revision.manifestHash())) throw conflict();
        return row;
    }

    private void validate(CapabilityManifest manifest, String projectId, String projectCode) {
        try {
            validator.validate(
                    manifest,
                    projectCode,
                    repository.permissions(projectId),
                    repository.controlledResources(projectId));
        } catch (IllegalArgumentException exception) {
            throw invalid();
        }
    }

    private AgentRegistrationView view(AgentCapabilityEntity row, boolean active) {
        CapabilityManifest manifest = codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8));
        return new AgentRegistrationView(
                row.getId(),
                row.getProjectId(),
                row.getCapabilityCode(),
                row.getVersion(),
                row.getManifestHash(),
                row.getStatus(),
                manifest.readOnly(),
                active && !"REVOKED".equals(row.getStatus()) && online(row),
                row.getLastSeenAt(),
                manifest.description());
    }

    private boolean online(AgentCapabilityEntity row) {
        LocalDateTime time = now();
        return row.getLastSeenAt() != null
                && row.getLastSeenAt().isAfter(time.minusMinutes(3))
                && !row.getLastSeenAt().isAfter(time);
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock).truncatedTo(java.time.temporal.ChronoUnit.MILLIS);
    }

    private static int compareVersion(String next, String current) {
        String[] a = next.split("\\.");
        String[] b = current.split("\\.");
        for (int i = 0; i < Math.max(a.length, b.length); i++) {
            int compared =
                    new BigInteger(i < a.length ? a[i] : "0").compareTo(new BigInteger(i < b.length ? b[i] : "0"));
            if (compared != 0) return compared;
        }
        return 0;
    }

    private void event(
            String projectId, AgentCapabilityEntity row, String operation, String actor, String credentialId) {
        AgentRegistryEventEntity event = new AgentRegistryEventEntity();
        event.setId(LongIdGenerator.nextId());
        event.setProjectId(projectId);
        event.setOperation(operation);
        event.setActorUserId(actor);
        event.setCredentialId(credentialId);
        if (row != null) {
            event.setCapabilityCode(row.getCapabilityCode());
            event.setManifestHash(row.getManifestHash());
        }
        event.setOccurredAt(now());
        repository.event(event);
    }

    private void adminAudit(KaiwuContext actor, String projectId, String operation, RequestMetadata metadata) {
        audit.recordOperationInCallerTransaction(
                actor, "agent", operation, "/api/projects/" + projectId + "/agent", "projectId=" + projectId, metadata);
    }

    private static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Agent 注册凭据无效", "api.common.unauthorized");
    }

    private static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "无权管理该项目的 Agent 能力", "api.common.forbidden");
    }

    private static ApiException conflict() {
        return new ApiException(HttpStatus.CONFLICT, "注册状态或版本已变化，请重新获取后操作", "api.validation.failed");
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "能力清单或操作参数不合法", "api.validation.failed");
    }

    private record Authenticated(String projectId, String projectCode, String id) {}
}
