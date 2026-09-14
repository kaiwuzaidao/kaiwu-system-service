package com.kaiwu.module.audit.entity;

import java.time.LocalDateTime;

/**
 * 在线会话与用户名的连接结果。
 *
 * <p>不是实体：{@code username} 来自 {@code sys_user}，本类没有对应的单表。
 * 用带 setter 的 POJO 而不是 record，是为了让 MyBatis 的下划线转驼峰自动映射生效——
 * record 的构造器映射依赖编译参数名，条件更苛刻。</p>
 */
public class OnlineSessionJoinRow {

    private String id;
    private String userId;
    private String username;
    private String sessionStatus;
    private LocalDateTime createdAt;
    private LocalDateTime lastSeenAt;
    private LocalDateTime expiresAt;
    private LocalDateTime revokedAt;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getSessionStatus() {
        return sessionStatus;
    }

    public void setSessionStatus(String sessionStatus) {
        this.sessionStatus = sessionStatus;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getLastSeenAt() {
        return lastSeenAt;
    }

    public void setLastSeenAt(LocalDateTime lastSeenAt) {
        this.lastSeenAt = lastSeenAt;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public LocalDateTime getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(LocalDateTime revokedAt) {
        this.revokedAt = revokedAt;
    }
}
