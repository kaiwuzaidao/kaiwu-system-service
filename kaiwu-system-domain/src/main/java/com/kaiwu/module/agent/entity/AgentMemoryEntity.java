package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;

/** Private persistence entity. */
@TableName("sys_agent_memory")
public class AgentMemoryEntity {
    @TableId(type = IdType.INPUT)
    private String id;

    private String userId;
    private String content;
    private Boolean enabled;
    private java.time.LocalDateTime createdAt;
    private java.time.LocalDateTime updatedAt;

    public String getId() {
        return id;
    }

    public void setId(String value) {
        id = value;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String value) {
        userId = value;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String value) {
        content = value;
    }

    public Boolean getEnabled() {
        return enabled;
    }

    public void setEnabled(Boolean value) {
        enabled = value;
    }

    public java.time.LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(java.time.LocalDateTime value) {
        createdAt = value;
    }

    public java.time.LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(java.time.LocalDateTime value) {
        updatedAt = value;
    }
}
