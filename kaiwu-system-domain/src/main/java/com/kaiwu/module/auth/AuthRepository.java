package com.kaiwu.module.auth;

import com.kaiwu.module.auth.entity.NavigationMenuRow;
import com.kaiwu.module.auth.entity.OnlineSessionRow;
import com.kaiwu.module.auth.entity.UserAccountRow;
import com.kaiwu.module.auth.mapper.AuthMapper;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.stereotype.Repository;

/**
 * 最小身份与在线会话数据访问。
 */
@Repository
public class AuthRepository {

    private final AuthMapper mapper;

    public AuthRepository(AuthMapper mapper) {
        this.mapper = mapper;
    }

    public Optional<UserAccount> findUserByUsername(String username) {
        return Optional.ofNullable(mapper.findUserByUsername(username)).map(AuthRepository::toAccount);
    }

    public Optional<UserAccount> findUserById(String userId) {
        return Optional.ofNullable(mapper.findUserById(userId)).map(AuthRepository::toAccount);
    }

    public Set<String> findPermissions(String userId) {
        return new LinkedHashSet<>(mapper.findPermissions(userId));
    }

    /**
     * 查询用户在内置 system 项目下已授权的导航节点。
     *
     * <p>授权链路与 {@link #findPermissions} 完全一致，区别只在筛选：这里取
     * DIRECTORY/MENU 且可见启用的节点，权限码所在的 BUTTON 不进导航。
     * 结果按层级与 sort_no 排序，由上层组装成树。
     *
     * <p>菜单名不在这里解析：ADR 0013 起内置菜单的译文来自国际化资源目录，SQL 够不到
     * 目录缓存，继续在库里解析就得再 JOIN 一张表，让这条本就有五个 JOIN、每次登录都走的
     * 查询更重。这里只出原始数据，由 {@code AuthService} 用统一入口解析。</p>
     */
    public List<NavigationRow> findNavigationMenus(String userId) {
        return mapper.findNavigationMenus(userId).stream()
                .map(AuthRepository::toRow)
                .toList();
    }

    /** 建立在线会话；过期时间按系统默认时区落成 DATETIME，与迁移前语义一致。 */
    public void createSession(String sessionId, String userId, String refreshTokenHash, Instant expiresAt) {
        // 会话过期时间在库里是 DATETIME（无时区），按系统默认时区落库，与迁移前
        // Timestamp.from(instant) 的行为一致。
        mapper.createSession(
                sessionId, userId, refreshTokenHash, LocalDateTime.ofInstant(expiresAt, ZoneId.systemDefault()));
    }

    public Optional<OnlineSession> findSession(String sessionId) {
        return Optional.ofNullable(mapper.findSession(sessionId)).map(AuthRepository::toSession);
    }

    public void touchSession(String sessionId) {
        mapper.touchSession(sessionId);
    }

    /** 条件轮换 Refresh Token 摘要；并发使用同一旧令牌时最多一方成功。 */
    public boolean rotateRefreshToken(String sessionId, String expectedHash, String newHash) {
        return mapper.rotateRefreshToken(sessionId, expectedHash, newHash) == 1;
    }

    public void revokeSession(String sessionId) {
        mapper.revokeSession(sessionId);
    }

    /** 用户自助改密：同时清除强制改密标记。 */
    public void updatePassword(String userId, String passwordHash) {
        mapper.updatePassword(userId, passwordHash);
    }

    /** 更新当前用户的界面语言偏好，不改变任何会话或权限事实。 */
    public void updateLocale(String userId, String locale) {
        mapper.updateLocale(userId, locale);
    }

    /**
     * 查询该用户除当前会话外的其它在线会话，用于改密码后定点下线。
     *
     * @param userId         用户 ID
     * @param keepSessionId  保留的会话（发起改密码的当前会话）
     * @return 需要撤销的会话 ID 列表
     */
    public List<String> findOtherOnlineSessionIds(String userId, String keepSessionId) {
        return mapper.findOtherOnlineSessionIds(userId, keepSessionId);
    }

    public void revokeOtherSessions(String userId, String keepSessionId) {
        mapper.revokeOtherSessions(userId, keepSessionId);
    }

    public boolean userExists(String username) {
        return mapper.countByUsername(username) > 0;
    }

    private static UserAccount toAccount(UserAccountRow row) {
        return new UserAccount(
                row.getId(),
                row.getUsername(),
                row.getPasswordHash(),
                row.getDisplayName(),
                row.getStatus(),
                row.getLocale(),
                Boolean.TRUE.equals(row.getMustChangePassword()));
    }

    private static NavigationRow toRow(NavigationMenuRow row) {
        return new NavigationRow(
                row.getId(),
                row.getParentId(),
                row.getMenuName(),
                row.getMenuNameKey(),
                row.getMenuType(),
                row.getRoutePath(),
                row.getIcon(),
                row.getSortNo() == null ? 0 : row.getSortNo());
    }

    private static OnlineSession toSession(OnlineSessionRow row) {
        return new OnlineSession(
                row.getId(),
                row.getUserId(),
                row.getRefreshTokenHash(),
                row.getSessionStatus(),
                row.getExpiresAt().atZone(ZoneId.systemDefault()).toInstant());
    }

    public record UserAccount(
            String id,
            String username,
            String passwordHash,
            String displayName,
            String status,
            String locale,
            boolean mustChangePassword) {}

    /**
     * 导航节点原始行，由 Service 组装成树。
     *
     * @param name    录入原文，最终回退值
     * @param nameKey 引用的国际化资源 key；多语言只走这条路（ADR 0015）
     */
    public record NavigationRow(
            String id,
            String parentId,
            String name,
            String nameKey,
            String type,
            String path,
            String icon,
            int sortNo) {}

    public record OnlineSession(String id, String userId, String refreshTokenHash, String status, Instant expiresAt) {}
}
