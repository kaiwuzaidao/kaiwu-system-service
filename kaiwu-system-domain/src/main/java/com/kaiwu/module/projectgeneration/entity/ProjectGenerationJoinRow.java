package com.kaiwu.module.projectgeneration.entity;

import java.time.LocalDateTime;

/**
 * 生成任务与其所属项目的连接结果。
 *
 * <p>{@code projectCode} / {@code projectName} 来自 {@code sys_project}，因此这是连接结果
 * 而不是实体。用带 setter 的 POJO 让 MyBatis 的下划线转驼峰自动映射生效。</p>
 */
public class ProjectGenerationJoinRow {

    private String taskNo;
    private String projectId;
    private String projectCode;
    private String projectName;
    private String ownerUserId;
    private String generationMode;
    private String businessDescription;
    private String ddlContent;
    private String generationStatus;
    private String templateVersion;
    private String blueprintJson;
    private String aiModel;
    private String designSummary;
    private String backendArtifactName;
    private String frontendArtifactName;
    private String backendFileManifest;
    private String frontendFileManifest;
    private String lastError;
    private LocalDateTime startedAt;
    private LocalDateTime completedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public String getTaskNo() {
        return taskNo;
    }

    public void setTaskNo(String taskNo) {
        this.taskNo = taskNo;
    }

    public String getProjectId() {
        return projectId;
    }

    public void setProjectId(String projectId) {
        this.projectId = projectId;
    }

    public String getProjectCode() {
        return projectCode;
    }

    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    public String getProjectName() {
        return projectName;
    }

    public void setProjectName(String projectName) {
        this.projectName = projectName;
    }

    public String getOwnerUserId() {
        return ownerUserId;
    }

    public void setOwnerUserId(String ownerUserId) {
        this.ownerUserId = ownerUserId;
    }

    public String getGenerationMode() {
        return generationMode;
    }

    public void setGenerationMode(String generationMode) {
        this.generationMode = generationMode;
    }

    public String getBusinessDescription() {
        return businessDescription;
    }

    public void setBusinessDescription(String businessDescription) {
        this.businessDescription = businessDescription;
    }

    public String getDdlContent() {
        return ddlContent;
    }

    public void setDdlContent(String ddlContent) {
        this.ddlContent = ddlContent;
    }

    public String getGenerationStatus() {
        return generationStatus;
    }

    public void setGenerationStatus(String generationStatus) {
        this.generationStatus = generationStatus;
    }

    public String getTemplateVersion() {
        return templateVersion;
    }

    public void setTemplateVersion(String templateVersion) {
        this.templateVersion = templateVersion;
    }

    public String getBlueprintJson() {
        return blueprintJson;
    }

    public void setBlueprintJson(String blueprintJson) {
        this.blueprintJson = blueprintJson;
    }

    public String getAiModel() {
        return aiModel;
    }

    public void setAiModel(String aiModel) {
        this.aiModel = aiModel;
    }

    public String getDesignSummary() {
        return designSummary;
    }

    public void setDesignSummary(String designSummary) {
        this.designSummary = designSummary;
    }

    public String getBackendArtifactName() {
        return backendArtifactName;
    }

    public void setBackendArtifactName(String backendArtifactName) {
        this.backendArtifactName = backendArtifactName;
    }

    public String getFrontendArtifactName() {
        return frontendArtifactName;
    }

    public void setFrontendArtifactName(String frontendArtifactName) {
        this.frontendArtifactName = frontendArtifactName;
    }

    public String getBackendFileManifest() {
        return backendFileManifest;
    }

    public void setBackendFileManifest(String backendFileManifest) {
        this.backendFileManifest = backendFileManifest;
    }

    public String getFrontendFileManifest() {
        return frontendFileManifest;
    }

    public void setFrontendFileManifest(String frontendFileManifest) {
        this.frontendFileManifest = frontendFileManifest;
    }

    public String getLastError() {
        return lastError;
    }

    public void setLastError(String lastError) {
        this.lastError = lastError;
    }

    public LocalDateTime getStartedAt() {
        return startedAt;
    }

    public void setStartedAt(LocalDateTime startedAt) {
        this.startedAt = startedAt;
    }

    public LocalDateTime getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(LocalDateTime completedAt) {
        this.completedAt = completedAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
