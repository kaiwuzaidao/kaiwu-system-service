package com.kaiwu.module.auth.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 在线会话实体（{@code sys_online_session}）。
 *
 * <p>会话表归 auth 模块所有，但 role / project 模块在权限变更后也要按用户批量撤销会话。
 * 与其在各自的 Mapper 里各写一份 {@code IN (...)} 的 SQL（迁移后一度有两份逐字相同的
 * 副本），不如共用这一个实体 + {@code BaseMapper}，条件构造器的 {@code in()} 天然表达
 * 批量，连 SQL 字符串都不需要。</p>
 */
@TableName("sys_online_session")
public class OnlineSessionEntity {

    /** 会话 ID，UUID 字符串，由应用生成 */
    @TableId(type = IdType.INPUT)
    private String id;

    private Long userId;
    private String refreshTokenHash;
    private String sessionStatus;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;
    private LocalDateTime lastSeenAt;
    private LocalDateTime revokedAt;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getRefreshTokenHash() {
        return refreshTokenHash;
    }

    public void setRefreshTokenHash(String refreshTokenHash) {
        this.refreshTokenHash = refreshTokenHash;
    }

    public String getSessionStatus() {
        return sessionStatus;
    }

    public void setSessionStatus(String sessionStatus) {
        this.sessionStatus = sessionStatus;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
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

    public LocalDateTime getRevokedAt() {
        return revokedAt;
    }

    public void setRevokedAt(LocalDateTime revokedAt) {
        this.revokedAt = revokedAt;
    }
}
