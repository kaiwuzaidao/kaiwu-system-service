package com.kaiwu.module.agent.execution;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/** PLATFORM 写操作使用 System 当前会话和权限事实，不沿用规划时的 Context 快照。 */
@Component
public class AgentActionAccess {
    private final AuthRepository auth;

    public AgentActionAccess(AuthRepository auth) {
        this.auth = auth;
    }

    public void require(KaiwuContext actor) {
        require(actor, "system:project:create");
    }

    public void require(KaiwuContext actor, String permission) {
        if (permission == null || permission.isBlank())
            throw new ApiException(HttpStatus.FORBIDDEN, "无权限操作", "api.agent.actionForbidden");
        var session = auth.findSession(actor.sessionId()).orElseThrow(AgentActionAccess::unauthorized);
        var user = auth.findUserById(actor.userId()).orElseThrow(AgentActionAccess::unauthorized);
        if (!actor.userId().equals(session.userId())
                || !"ONLINE".equals(session.status())
                || !session.expiresAt().isAfter(Instant.now())
                || !"ENABLED".equals(user.status())
                || user.mustChangePassword()) throw unauthorized();
        var permissions = auth.findPermissions(actor.userId());
        if (!permissions.contains("system:agent:ask") || !permissions.contains(permission))
            throw new ApiException(HttpStatus.FORBIDDEN, "当前无权执行此操作，请重新发起", "api.agent.actionForbidden");
    }

    private static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "登录会话已失效，请重新登录", "api.common.unauthorized");
    }
}
