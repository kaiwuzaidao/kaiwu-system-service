package com.kaiwu.module.project.vo;

import java.time.LocalDateTime;

public record ProjectView(
        String id,
        String projectCode,
        String projectName,
        String description,
        String status,
        boolean builtIn,
        String createdBy,
        String packageName,
        String repositoryUrl,
        String gitlabProjectId,
        String defaultBranch,
        String backendUrl,
        String backendLabel,
        String serviceUrl,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
