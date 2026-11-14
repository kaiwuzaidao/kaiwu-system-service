package com.kaiwu.module.identity.entity;

/**
 * 登录校验所需的账号行。
 *
 * <p>**这是全平台唯一会取出密码哈希的查询路径。** {@code UserEntity} 上的
 * {@code @TableField(select = false)} 让默认查询取不到密码，登录必须显式走这里——
 * 需要密码的地方应该少且显眼。</p>
 */
public class UserAccountRow {

    private String id;
    private String username;
    private String passwordHash;
    private String displayName;
    private String status;
    private String locale;
    private Boolean mustChangePassword;
    private Boolean agentAutoOpen;

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getLocale() {
        return locale;
    }

    public void setLocale(String locale) {
        this.locale = locale;
    }

    public Boolean getMustChangePassword() {
        return mustChangePassword;
    }

    public void setMustChangePassword(Boolean mustChangePassword) {
        this.mustChangePassword = mustChangePassword;
    }

    public Boolean getAgentAutoOpen() {
        return agentAutoOpen;
    }

    public void setAgentAutoOpen(Boolean agentAutoOpen) {
        this.agentAutoOpen = agentAutoOpen;
    }
}
