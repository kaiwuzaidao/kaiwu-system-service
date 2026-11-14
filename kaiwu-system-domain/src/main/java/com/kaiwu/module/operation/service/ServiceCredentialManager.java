package com.kaiwu.module.operation.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.module.operation.vo.ServiceCredentialView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Objects;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 项目服务凭据签发；调用入口另须验证平台管理权限。 */
@Service
public class ServiceCredentialManager {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Set<String> ALLOWED = Set.of("todo:managed", "member:read");
    private final ProjectSchedulerRepository repository;
    private final ProjectMembershipPort membership;
    private final AuditPort audit;
    private final PasswordEncoder encoder;
    private final boolean multiEnabled;
    private final long overlapSeconds;

    /** 注入凭据存储与默认关闭的混合版本保护开关。 */
    public ServiceCredentialManager(
            ProjectSchedulerRepository repository,
            ProjectMembershipPort membership,
            AuditPort audit,
            PasswordEncoder encoder,
            @Value("${kaiwu.service-credentials.multi-enabled:false}") boolean multiEnabled,
            @Value("${kaiwu.service-credentials.overlap-seconds:86400}") long overlapSeconds) {
        if (overlapSeconds < 0 || overlapSeconds > 604800)
            throw new IllegalArgumentException("invalid credential overlap");
        this.repository = repository;
        this.membership = membership;
        this.audit = audit;
        this.encoder = encoder;
        this.multiEnabled = multiEnabled;
        this.overlapSeconds = overlapSeconds;
    }

    /**
     * 签发或轮换单个服务的凭据；项目锁、范围、审计和凭据写入共用事务。
     * 明文只由返回值携带，不得记入审计或日志。
     */
    @Transactional
    public Issued issue(
            String projectId,
            String serviceCode,
            Set<String> scopes,
            Instant expiresAt,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (!multiEnabled)
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "多服务凭据尚未启用", "serviceCredential.multiDisabled");
        requireMember(projectId, actor);
        Instant now = Instant.now();
        expiresAt = expiresAt == null ? null : expiresAt.truncatedTo(ChronoUnit.SECONDS);
        if (serviceCode == null
                || !serviceCode.matches("[a-z][a-z0-9]{1,15}")
                || serviceCode.equals("default")
                || scopes == null
                || scopes.isEmpty()
                || scopes.stream().anyMatch(Objects::isNull)
                || !ALLOWED.containsAll(scopes)
                || expiresAt == null
                || !expiresAt.isAfter(now)
                || expiresAt.isAfter(Instant.parse("9999-12-31T23:59:59Z"))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "凭据参数无效", "api.common.badRequest");
        }
        Set<String> issuedScopes = Set.copyOf(scopes);
        if (!repository.lockCredentialProject(projectId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "项目不存在或未启用", "api.common.notFound");
        }
        var active = repository.activeServiceCredentials(projectId, serviceCode);
        if (active.size() >= 2 || active.stream().anyMatch(c -> !c.scopes().equals(issuedScopes))) {
            throw new ApiException(HttpStatus.CONFLICT, "凭据轮换或范围冲突", "api.common.conflict");
        }
        LocalDateTime overlap = LocalDateTime.ofInstant(now.plusSeconds(overlapSeconds), ZoneOffset.UTC);
        active.forEach(c -> repository.shortenCredential(c.id(), overlap));
        String id = LongIdGenerator.nextId();
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String token =
                "zsch_" + id + "_" + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        repository.insertScopedCredential(
                id,
                projectId,
                encoder.encode(token),
                serviceCode,
                LocalDateTime.ofInstant(expiresAt, ZoneOffset.UTC),
                issuedScopes);
        audit.recordOperationInCallerTransaction(
                actor,
                "project",
                "ISSUE_SERVICE_CREDENTIAL",
                "/api/projects/" + projectId + "/service-credentials",
                "projectId=" + projectId + ",serviceCode=" + serviceCode + ",credentialId=" + id + ",scopes="
                        + String.join(",", issuedScopes.stream().sorted().toList()),
                metadata);
        return new Issued(id, projectId, serviceCode, issuedScopes, expiresAt, token);
    }

    /** 平台列表权限之外复核目标项目有效成员，仅返回不含哈希的凭据元数据。 */
    public PageResult<ServiceCredentialView> list(String projectId, long current, long size, KaiwuContext actor) {
        requireMember(projectId, actor);
        PageBounds.require(current, size);
        return repository.listScopedCredentials(projectId, current, size);
    }

    /** 撤销当前项目的非 default 凭据，并在同一事务记录审计。 */
    @Transactional
    public void revoke(String projectId, String credentialId, KaiwuContext actor, RequestMetadata metadata) {
        requireMember(projectId, actor);
        if (!repository.lockCredentialProject(projectId)
                || !repository.revokeScopedCredential(projectId, credentialId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "凭据不存在或不可撤销", "api.common.notFound");
        }
        audit.recordOperationInCallerTransaction(
                actor,
                "project",
                "REVOKE_SERVICE_CREDENTIAL",
                "/api/projects/" + projectId + "/service-credentials/" + credentialId + "/revoke",
                "projectId=" + projectId + ",credentialId=" + credentialId,
                metadata);
    }

    /** 管理权限之外再次校验目标项目有效成员，拒绝以他项目身份签发或撤销凭据。 */
    private void requireMember(String projectId, KaiwuContext actor) {
        if (actor == null || !membership.activeMemberExists(projectId, actor.userId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "不是项目有效成员", "api.common.forbidden");
        }
    }

    /** 明文只在签发响应中展示一次。 */
    public record Issued(
            String credentialId,
            String projectId,
            String serviceCode,
            Set<String> scopes,
            Instant expiresAt,
            String token) {
        /** 字符串表示不包含一次性凭据。 */
        @Override
        public String toString() {
            return "Issued[credentialId=" + credentialId + ", projectId=" + projectId + ", serviceCode=" + serviceCode
                    + ", token=<redacted>]";
        }
    }
}
