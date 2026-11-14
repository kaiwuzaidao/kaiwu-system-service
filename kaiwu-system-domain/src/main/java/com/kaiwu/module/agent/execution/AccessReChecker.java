package com.kaiwu.module.agent.execution;

import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

/**
 * 执行前的统一兜底鉴权。
 *
 * <p>为什么编排层要自己再查一遍：控制面各模块的项目收窄方式并不统一
 * （{@code requireMember} 目前只在调度模块使用，生成任务走仓储层按 userId 过滤），
 * 而 Agent 的调用不经过 Controller，「每个实现都做对了」不是可依赖的假设
 * （ADR 0030 第 4 条）。</p>
 *
 * <p>另一层意义是时间差：规划与执行之间成员关系可能刚被撤销，
 * 因此这里重新取一次，而不是沿用组装提示词时的那份快照。</p>
 */
@Component
public class AccessReChecker {

    private final ProjectMembershipPort membership;
    private final AuthRepository auth;
    private final Clock clock;
    private RemoteCapabilitySource remote;

    @org.springframework.beans.factory.annotation.Autowired
    public void remoteSource(RemoteCapabilitySource value) {
        remote = value;
    }

    public AccessReChecker(ProjectMembershipPort membership, AuthRepository auth, Clock clock) {
        this.membership = membership;
        this.auth = auth;
        this.clock = clock;
    }

    /** 规划前用在线会话与当前权限过滤本地能力，不把已撤权能力送给模型。 */
    public List<Capability> visibleTo(List<Capability> candidates, KaiwuContext actor) {
        Set<String> permissions = currentPermissions(actor);
        return candidates.stream()
                .filter(capability -> !Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())
                        || permissions.contains(capability.permission()))
                .toList();
    }

    /**
     * 对一次调用做执行前复核。
     *
     * @throws PlanRejectedException 能力已不可用，或参数中的项目此刻已无成员关系
     */
    public void check(Capability capability, Map<String, Object> params, KaiwuContext actor) {
        if (!Capability.SYSTEM_PROJECT_CODE.equals(capability.projectCode())) {
            if (remote == null
                    || (capability.readOnly()
                                    ? remote.findVisible(capability.code(), actor)
                                    : remote.findVisibleWrite(capability.code(), actor))
                            .filter(capability::equals)
                            .isEmpty()) throw denied();
            return;
        }
        if (!actor.hasPermission(capability.permission())
                || !currentPermissions(actor).contains(capability.permission())) {
            throw denied();
        }
        Object projectId = params.get("projectId");
        if (projectId != null && !membership.activeMemberExists(String.valueOf(projectId), actor.userId())) {
            // 话术与规则 9 一致：不区分「不存在」与「无权限」。
            throw new PlanRejectedException(9, "没有找到你有权限的项目");
        }
    }

    private Set<String> currentPermissions(KaiwuContext actor) {
        if (actor == null || actor.sessionId() == null || actor.userId() == null) throw denied();
        var session = auth.findSession(actor.sessionId()).orElseThrow(AccessReChecker::denied);
        var user = auth.findUserById(actor.userId()).orElseThrow(AccessReChecker::denied);
        if (!actor.userId().equals(session.userId())
                || !"ONLINE".equals(session.status())
                || !session.expiresAt().isAfter(Instant.now(clock))
                || !"ENABLED".equals(user.status())
                || user.mustChangePassword()) throw denied();
        Set<String> permissions = auth.findPermissions(actor.userId());
        if (permissions == null || !permissions.contains("system:agent:ask")) throw denied();
        return permissions;
    }

    private static PlanRejectedException denied() {
        return new PlanRejectedException(3, "无权限操作");
    }
}
