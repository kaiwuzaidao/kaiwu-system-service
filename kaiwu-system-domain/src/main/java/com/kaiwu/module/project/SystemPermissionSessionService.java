package com.kaiwu.module.project;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.kaiwu.module.auth.entity.OnlineSessionEntity;
import com.kaiwu.module.auth.mapper.OnlineSessionMapper;
import com.kaiwu.module.project.mapper.SystemRuntimeMapper;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.port.UserNotificationPort;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;

/**
 * system 项目权限变化后撤销受影响的平台会话，禁止旧权限快照继续生效。
 */
@Service
public class SystemPermissionSessionService {

    private final SystemRuntimeMapper runtimeMapper;
    private final OnlineSessionMapper sessionMapper;
    private final SessionSnapshotPort sessionSnapshots;
    private final UserNotificationPort notificationService;
    private final Clock clock;

    public SystemPermissionSessionService(
            SystemRuntimeMapper runtimeMapper,
            OnlineSessionMapper sessionMapper,
            SessionSnapshotPort sessionSnapshots,
            UserNotificationPort notificationService,
            Clock clock) {
        this.runtimeMapper = runtimeMapper;
        this.sessionMapper = sessionMapper;
        this.sessionSnapshots = sessionSnapshots;
        this.notificationService = notificationService;
        this.clock = clock;
    }

    public void revokeUser(String userId) {
        revoke(Set.of(userId));
    }

    public void revokeRoleMembers(String projectId, String roleId) {
        revoke(new LinkedHashSet<>(runtimeMapper.findRoleMemberUserIds(projectId, roleId)));
    }

    public void revokeProjectMembers(String projectId) {
        revoke(new LinkedHashSet<>(runtimeMapper.findProjectMemberUserIds(projectId)));
    }

    private void revoke(Set<String> userIds) {
        if (userIds.isEmpty()) return;
        List<Long> ids = userIds.stream().map(Long::parseLong).toList();
        // 先取会话 ID 再撤销：撤销之后就查不到它们了，而 Redis 快照必须按 ID 逐个删。
        List<String> sessionIds = sessionMapper
                .selectList(new LambdaQueryWrapper<OnlineSessionEntity>()
                        .select(OnlineSessionEntity::getId)
                        .eq(OnlineSessionEntity::getSessionStatus, "ONLINE")
                        .in(OnlineSessionEntity::getUserId, ids))
                .stream()
                .map(OnlineSessionEntity::getId)
                .toList();
        sessionMapper.update(
                null,
                new LambdaUpdateWrapper<OnlineSessionEntity>()
                        .eq(OnlineSessionEntity::getSessionStatus, "ONLINE")
                        .in(OnlineSessionEntity::getUserId, ids)
                        .set(OnlineSessionEntity::getSessionStatus, "REVOKED")
                        .set(OnlineSessionEntity::getRevokedAt, LocalDateTime.now(clock)));
        sessionIds.forEach(sessionSnapshots::delete);
        // 被强制下线的用户需要知情，否则只会看到一次莫名其妙的跳登录页。
        userIds.forEach(userId ->
                notificationService.notifyUser(userId, "SYSTEM", "你的权限已变更", "平台权限发生调整，现有登录会话已失效，请重新登录以获取最新权限。", null));
    }
}
