package com.kaiwu.module.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 平台外部 Access JWT 与在线会话配置。
 */
@ConfigurationProperties(prefix = "kaiwu.auth")
public class AuthProperties {

    private String accessPrivateKey;
    private String bootstrapAdminPassword;
    private long accessTtlSeconds = 900;
    private long refreshTtlSeconds = 604800;
    /** 部署环境必须为 true；仅 local HTTP profile 可显式关闭。 */
    private boolean refreshCookieSecure = true;

    private String accessIssuer = "kaiwu-system-service";
    private String accessAudience = "kaiwu-gateway-service";
    /**
     * 连续登录失败多少次后锁定账号。设为 0 表示不启用锁定。
     *
     * <p>按用户名维度计数而不是 IP：撞库的主要特征是同一账号被反复尝试，换 IP 很容易，
     * 换账号则失去目标。代价是攻击者可以用错误密码把已知账号锁住，所以锁定时长取分钟级，
     * 且锁定事件会进登录日志，便于从审计发现。
     */
    private int maxFailedAttempts = 5;
    /** 触发锁定后的锁定时长（秒）。 */
    private long lockDurationSeconds = 900;
    /** 失败计数的滑动窗口（秒）：窗口内累计到阈值才锁定。 */
    private long failedAttemptWindowSeconds = 900;

    public String getAccessPrivateKey() {
        return accessPrivateKey;
    }

    public void setAccessPrivateKey(String accessPrivateKey) {
        this.accessPrivateKey = accessPrivateKey;
    }

    public String getBootstrapAdminPassword() {
        return bootstrapAdminPassword;
    }

    public void setBootstrapAdminPassword(String bootstrapAdminPassword) {
        this.bootstrapAdminPassword = bootstrapAdminPassword;
    }

    public long getAccessTtlSeconds() {
        return accessTtlSeconds;
    }

    public void setAccessTtlSeconds(long accessTtlSeconds) {
        this.accessTtlSeconds = accessTtlSeconds;
    }

    public long getRefreshTtlSeconds() {
        return refreshTtlSeconds;
    }

    public void setRefreshTtlSeconds(long refreshTtlSeconds) {
        this.refreshTtlSeconds = refreshTtlSeconds;
    }

    public boolean isRefreshCookieSecure() {
        return refreshCookieSecure;
    }

    public void setRefreshCookieSecure(boolean refreshCookieSecure) {
        this.refreshCookieSecure = refreshCookieSecure;
    }

    public String getAccessIssuer() {
        return accessIssuer;
    }

    public void setAccessIssuer(String accessIssuer) {
        this.accessIssuer = accessIssuer;
    }

    public String getAccessAudience() {
        return accessAudience;
    }

    public void setAccessAudience(String accessAudience) {
        this.accessAudience = accessAudience;
    }

    public int getMaxFailedAttempts() {
        return maxFailedAttempts;
    }

    public void setMaxFailedAttempts(int maxFailedAttempts) {
        this.maxFailedAttempts = maxFailedAttempts;
    }

    public long getLockDurationSeconds() {
        return lockDurationSeconds;
    }

    public void setLockDurationSeconds(long lockDurationSeconds) {
        this.lockDurationSeconds = lockDurationSeconds;
    }

    public long getFailedAttemptWindowSeconds() {
        return failedAttemptWindowSeconds;
    }

    public void setFailedAttemptWindowSeconds(long failedAttemptWindowSeconds) {
        this.failedAttemptWindowSeconds = failedAttemptWindowSeconds;
    }
}
