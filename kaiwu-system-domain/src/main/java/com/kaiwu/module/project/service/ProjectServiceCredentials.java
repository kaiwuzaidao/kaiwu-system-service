package com.kaiwu.module.project.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.port.ProjectCredentialStorePort;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 项目服务凭据的统一校验入口。
 *
 * <p>业务服务的后台线程（调度执行、配置拉取）没有用户 Gateway Context，只能用项目级凭据
 * 访问 `/api/internal/**`。旧凭据只允许访问旧能力；新凭据按项目与明确的 scope 校验。</p>
 *
 * <p>校验逻辑只保留这一份：它是安全代码，复制成多份会出现"改了一处忘了另一处"的漏洞。
 * 历史表名与 token 前缀沿用调度时期的命名，改动会使已发放凭据全部失效，不值得。</p>
 */
@Component
public class ProjectServiceCredentials {

    /** 历史前缀，保持不变以免已发放的凭据失效。 */
    private static final String TOKEN_PREFIX = "zsch_";

    /**
     * 凭据表目前由调度模块持久化，但认证逻辑只依赖存储 Port，不反向依赖其 Mapper。
     */
    private final ProjectCredentialStorePort credentialStore;

    private final PasswordEncoder passwordEncoder;

    public ProjectServiceCredentials(ProjectCredentialStorePort credentialStore, PasswordEncoder passwordEncoder) {
        this.credentialStore = credentialStore;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * 校验凭据并返回其归属项目。
     *
     * <p>所有失败路径返回同一句提示，避免通过错误差异区分"凭据不存在"与"凭据错误"。</p>
     *
     * @param token 形如 {@code zsch_{credentialId}_{secret}} 的完整凭据
     * @return 该凭据绑定的项目
     * @throws ApiException 401，凭据缺失、格式错误、已停用或项目已归档
     */
    public ProjectServiceCredential authenticate(String token) {
        var row = authenticateStored(token);
        // 旧调度、配置和存储入口只接受 default，不让新 scope 凭据继承旧权限。
        if (!"default".equals(row.serviceCode())) {
            throw unauthorized();
        }
        return toCredential(row);
    }

    /**
     * 校验内部能力凭据，项目和 scope 均从已认证的持久化事实确认。
     *
     * @param token 完整服务凭据
     * @param projectId 端点所要求的权威项目 ID
     * @param scope 端点固定要求的能力范围
     * @return 已验证的项目凭据
     */
    public ProjectServiceCredential authenticateScoped(String token, String projectId, String scope) {
        var row = authenticateStored(token);
        if ("default".equals(row.serviceCode())
                || projectId == null
                || !projectId.equals(row.projectId())
                || scope == null
                || !row.scopes().contains(scope)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "项目服务凭据无权访问", "api.common.forbidden");
        }
        return toCredential(row);
    }

    /** 先认证凭据本身和固定范围，再由调用方校验路径项目归属。 */
    public ProjectServiceCredential authenticateScopeBearer(String authorization, String scope) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, "Bearer ".length())) {
            throw unauthorized();
        }
        var row = authenticateStored(authorization.substring("Bearer ".length()).trim());
        if ("default".equals(row.serviceCode())
                || scope == null
                || !row.scopes().contains(scope)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "项目服务凭据无权访问", "api.common.forbidden");
        }
        return toCredential(row);
    }

    /** 先核对持久状态、有效期及BCrypt，再尽力记录使用时间；统计失败不污染认证事务。 */
    private ProjectCredentialStorePort.StoredCredential authenticateStored(String token) {
        if (token == null || !token.startsWith(TOKEN_PREFIX)) {
            throw unauthorized();
        }
        String[] parts = token.split("_", 3);
        if (parts.length != 3 || parts[1].isBlank() || parts[2].isBlank()) {
            throw unauthorized();
        }
        var row = credentialStore.findActive(parts[1]).orElseThrow(ProjectServiceCredentials::unauthorized);
        if (!passwordEncoder.matches(token, row.tokenHash())) {
            throw unauthorized();
        }
        try {
            credentialStore.touchLastUsed(row.id());
        } catch (RuntimeException ignored) {
            // 限频统计是非关键路径；不得将凭据、哈希或异常参数写入日志。
        }
        return row;
    }

    /** 认证结果仅携带项目和服务身份，不将哈希或scope集合泄漏到业务返回对象。 */
    private static ProjectServiceCredential toCredential(ProjectCredentialStorePort.StoredCredential row) {
        return new ProjectServiceCredential(row.id(), row.projectId(), row.serviceCode());
    }

    /** 从 `Authorization: Bearer xxx` 中取出凭据，缺失或格式错误一律 401。 */
    public ProjectServiceCredential authenticateBearer(String authorization) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, "Bearer ".length())) {
            throw unauthorized();
        }
        return authenticate(authorization.substring("Bearer ".length()).trim());
    }

    /**
     * 从 Bearer 头认证受限服务身份，并核验目标项目和能力范围。
     *
     * @param authorization 调用方凭据头
     * @param projectId 权威项目 ID
     * @param scope 端点所需能力范围
     * @return 不含凭据密钥或哈希的服务身份
     */
    public ProjectServiceCredential authenticateScopedBearer(String authorization, String projectId, String scope) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, "Bearer ".length())) {
            throw unauthorized();
        }
        return authenticateScoped(authorization.substring("Bearer ".length()).trim(), projectId, scope);
    }

    private static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "项目服务凭据无效", "api.common.unauthorized");
    }
}
