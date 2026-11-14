package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.*;
import java.time.LocalDateTime;

/** Agent 注册持久化行；不作为 HTTP 响应。 */
@TableName("sys_agent_registry_event")
public class AgentRegistryEventEntity {
    @TableId(type = IdType.INPUT)
    private String id;

    private String projectId;
    private String capabilityCode;
    private String manifestHash;
    private String operation;
    private String actorUserId;
    private String credentialId;
    private LocalDateTime occurredAt;

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

    public String getManifestHash() {
        return manifestHash;
    }

    public void setManifestHash(String value) {
        this.manifestHash = value;
    }

    public String getOperation() {
        return operation;
    }

    public void setOperation(String value) {
        this.operation = value;
    }

    public String getActorUserId() {
        return actorUserId;
    }

    public void setActorUserId(String value) {
        this.actorUserId = value;
    }

    public String getCredentialId() {
        return credentialId;
    }

    public void setCredentialId(String value) {
        this.credentialId = value;
    }

    public LocalDateTime getOccurredAt() {
        return occurredAt;
    }

    public void setOccurredAt(LocalDateTime value) {
        this.occurredAt = value;
    }
}
