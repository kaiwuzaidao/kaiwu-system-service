package com.kaiwu.module.credential;

import com.kaiwu.common.ApiException;
import com.kaiwu.port.ProjectCredentialStorePort;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 项目服务凭据的统一校验入口。
 *
 * <p>业务服务的后台线程（调度执行、配置拉取）没有用户 Gateway Context，只能用项目级凭据
 * 访问 `/api/internal/**`。凭据本身与具体能力无关——表里只有项目归属和状态，因此这里做
 * 统一校验，各能力自行判断拿到的 projectId 能做什么。</p>
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
        if (token == null || !token.startsWith(TOKEN_PREFIX)) {
            throw unauthorized();
        }
        String[] parts = token.split("_", 3);
        if (parts.length != 3 || parts[1].isBlank() || parts[2].isBlank()) {
            throw unauthorized();
        }
        ProjectServiceCredential credential = credentialStore
                .findActive(parts[1])
                .map(row -> new ProjectServiceCredential(row.id(), row.projectId(), row.tokenHash(), "ACTIVE"))
                .orElseThrow(ProjectServiceCredentials::unauthorized);
        if (!passwordEncoder.matches(token, credential.tokenHash())) {
            throw unauthorized();
        }
        return credential;
    }

    /** 从 `Authorization: Bearer xxx` 中取出凭据，缺失或格式错误一律 401。 */
    public ProjectServiceCredential authenticateBearer(String authorization) {
        if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, "Bearer ".length())) {
            throw unauthorized();
        }
        return authenticate(authorization.substring("Bearer ".length()).trim());
    }

    private static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "项目服务凭据无效", "api.common.unauthorized");
    }
}
