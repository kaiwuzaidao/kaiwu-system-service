package com.kaiwu.module.projectgeneration.vo;

/**
 * 仅供任务所有者编辑失败任务；不包含凭据、蓝图或制品内容。
 */
public record ProjectGenerationInputView(
        String taskNo,
        String projectId,
        String projectName,
        String generationMode,
        String businessDescription,
        String ddl) {}
