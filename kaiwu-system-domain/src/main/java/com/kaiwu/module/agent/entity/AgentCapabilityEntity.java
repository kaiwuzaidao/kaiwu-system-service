package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;
import java.time.LocalDateTime;

/** Agent 注册持久化行；不作为 HTTP 响应。 */
@TableName("sys_agent_capability")
public class AgentCapabilityEntity {
    @TableId(type = IdType.INPUT)
    private String id;

    private String projectId;
    private String capabilityCode;
    private String version;
    private String manifestJson;
    private String manifestHash;
    private String status;
    private LocalDateTime lastSeenAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public String getId() {
        return id;
    }

    public void setId(String value) {
        this.id = value;
    }

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String value) {
        this.projectId = value;
    }

    public String getCapabilityCode() {
        return capabilityCode;
    }

    public void setCapabilityCode(String value) {
        this.capabilityCode = value;
    }

    public String getVersion() {
        return version;
    }

    public void setVersion(String value) {
        this.version = value;
    }

    public String getManifestJson() {
        return manifestJson;
    }

    public void setManifestJson(String value) {
        this.manifestJson = value;
    }

    public String getManifestHash() {
        return manifestHash;
    }

    public void setManifestHash(String value) {
        this.manifestHash = value;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String value) {
        this.status = value;
    }

    public LocalDateTime getLastSeenAt() {
        return lastSeenAt;
    }

    public void setLastSeenAt(LocalDateTime value) {
        this.lastSeenAt = value;
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
