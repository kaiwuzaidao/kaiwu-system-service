package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;

/** Private persistence entity. */
@TableName("sys_agent_conversation")
public class AgentConversationEntity {
    @TableId(type = IdType.INPUT)
    private String id;

    private String userId;
    private String title;
    private Boolean useMemory;
    private String runId;
    private java.time.LocalDateTime busyUntil;
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

    public String getTitle() {
        return title;
    }

    public void setTitle(String value) {
        title = value;
    }

    public Boolean getUseMemory() {
        return useMemory;
    }

    public void setUseMemory(Boolean value) {
        useMemory = value;
    }

    public String getRunId() {
        return runId;
    }

    public void setRunId(String value) {
        runId = value;
    }

    public java.time.LocalDateTime getBusyUntil() {
        return busyUntil;
    }

    public void setBusyUntil(java.time.LocalDateTime value) {
        busyUntil = value;
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
