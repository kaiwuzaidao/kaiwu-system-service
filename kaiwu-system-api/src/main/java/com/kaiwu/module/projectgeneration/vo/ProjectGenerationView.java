package com.kaiwu.module.projectgeneration.vo;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 项目工厂任务视图。请求原文、数据库凭据和蓝图 JSON 均不对浏览器暴露。
 */
public record ProjectGenerationView(
        String taskNo,
        String projectId,
        String projectCode,
        String projectName,
        String generationMode,
        String status,
        String aiModel,
        String designSummary,
        String templateVersion,
        List<String> backendFiles,
        List<String> frontendFiles,
        String backendPushStatus,
        String frontendPushStatus,
        String backendRepositoryUrl,
        String frontendRepositoryUrl,
        String backendHttpCloneUrl,
        String backendSshCloneUrl,
        String frontendHttpCloneUrl,
        String frontendSshCloneUrl,
        String lastError,
        LocalDateTime startedAt,
        LocalDateTime completedAt,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
