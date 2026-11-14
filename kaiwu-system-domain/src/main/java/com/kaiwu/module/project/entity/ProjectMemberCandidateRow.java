package com.kaiwu.module.project.entity;

/** 可选成员的查询结果行。 */
public class ProjectMemberCandidateRow {

    private String userId;
    private String username;
    private String displayName;

    /** 用户 ID。 */
    public String getUserId() {
        return userId;
    }

    /** 设置用户 ID。 */
    public void setUserId(String userId) {
        this.userId = userId;
    }

    /** 登录名。 */
    public String getUsername() {
        return username;
    }

    /** 设置登录名。 */
    public void setUsername(String username) {
        this.username = username;
    }

    /** 显示名。 */
    public String getDisplayName() {
        return displayName;
    }

    /** 设置显示名。 */
    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }
}
