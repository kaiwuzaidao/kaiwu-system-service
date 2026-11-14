package com.kaiwu.module.identity.entity;

import java.time.LocalDateTime;

/** 在线会话行。 */
public class OnlineSessionRow {

    private String id;
    private String userId;
    private String refreshTokenHash;
    private String sessionStatus;
    private String sessionSource;
    private LocalDateTime expiresAt;

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

    public String getRefreshTokenHash() {
        return refreshTokenHash;
    }

    public void setRefreshTokenHash(String refreshTokenHash) {
        this.refreshTokenHash = refreshTokenHash;
    }

    /** 会话来源（WEB 或 CLI）。 */
    public String getSessionSource() {
        return sessionSource;
    }

    /** 设置会话来源。 */
    public void setSessionSource(String sessionSource) {
        this.sessionSource = sessionSource;
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
}
