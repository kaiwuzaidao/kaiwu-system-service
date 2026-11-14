package com.kaiwu.module.agent.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/** 远程写任务的持久化行；密文与确认摘要只在服务端使用，不作为 HTTP 响应。 */
@TableName("sys_agent_remote_action")
public class AgentRemoteActionEntity {
    @TableId(type = IdType.INPUT)
    private String actionId;

    private String projectId;
    private String userId;
    private String sessionId;
    private String capabilityCode;
    private String capabilityVersion;
    private String manifestHash;
    private String paramsHash;
    private String preconditionsHash;
    private String previewHash;
    private String frozenCiphertext;
    private String tokenHash;
    private String confirmationMode;
    private String status;
    private LocalDateTime expiresAt;
    private LocalDateTime startedAt;
    private LocalDateTime finishedAt;
    private String resultCiphertext;
    private String reasonCode;
    private Integer revision;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public String getActionId() {
        return actionId;
    }

    public void setActionId(String value) {
        this.actionId = value;
    }

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String value) {
        this.projectId = value;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String value) {
        this.userId = value;
    }

    public String getSessionId() {
        return sessionId;
    }

    public void setSessionId(String value) {
        this.sessionId = value;
    }

    public String getCapabilityCode() {
        return capabilityCode;
    }

    public void setCapabilityCode(String value) {
        this.capabilityCode = value;
    }

    public String getCapabilityVersion() {
        return capabilityVersion;
    }

    public void setCapabilityVersion(String value) {
        this.capabilityVersion = value;
    }

    public String getManifestHash() {
        return manifestHash;
    }

    public void setManifestHash(String value) {
        this.manifestHash = value;
    }

    public String getParamsHash() {
        return paramsHash;
    }

    public void setParamsHash(String value) {
        this.paramsHash = value;
    }

    public String getPreconditionsHash() {
        return preconditionsHash;
    }

    public void setPreconditionsHash(String value) {
        this.preconditionsHash = value;
    }

    public String getPreviewHash() {
        return previewHash;
    }

    public void setPreviewHash(String value) {
        this.previewHash = value;
    }

    public String getFrozenCiphertext() {
        return frozenCiphertext;
    }

    public void setFrozenCiphertext(String value) {
        this.frozenCiphertext = value;
    }

    public String getTokenHash() {
        return tokenHash;
    }

    public void setTokenHash(String value) {
        this.tokenHash = value;
    }

    public String getConfirmationMode() {
        return confirmationMode;
    }

    public void setConfirmationMode(String value) {
        this.confirmationMode = value;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String value) {
        this.status = value;
    }

    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    public void setExpiresAt(LocalDateTime value) {
        this.expiresAt = value;
    }

    public LocalDateTime getStartedAt() {
        return startedAt;
    }

    public void setStartedAt(LocalDateTime value) {
        this.startedAt = value;
    }

    public LocalDateTime getFinishedAt() {
        return finishedAt;
    }

    public void setFinishedAt(LocalDateTime value) {
        this.finishedAt = value;
    }

    public String getResultCiphertext() {
        return resultCiphertext;
    }

    public void setResultCiphertext(String value) {
        this.resultCiphertext = value;
    }

    public String getReasonCode() {
        return reasonCode;
    }

    public void setReasonCode(String value) {
        this.reasonCode = value;
    }

    public Integer getRevision() {
        return revision;
    }

    public void setRevision(Integer value) {
        this.revision = value;
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
