package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;
import java.time.LocalDateTime;

/** Agent 注册持久化行；不作为 HTTP 响应。 */
@TableName("sys_agent_credential")
public class AgentCredentialEntity {
    @TableId(type = IdType.INPUT)
    private String projectId;

    private String credentialId;
    private String tokenHash;
    private String status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String value) {
        this.projectId = value;
    }

    public String getCredentialId() {
        return credentialId;
    }

    public void setCredentialId(String value) {
        this.credentialId = value;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public void setTokenHash(String value) {
        this.tokenHash = value;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String value) {
        this.status = value;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime value) {
        this.createdAt = value;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime value) {
        this.updatedAt = value;
    }
}
