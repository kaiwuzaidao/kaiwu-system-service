package com.kaiwu.module.projectgeneration.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 发起一次性项目生成。
 */
public record ProjectGenerationCreateRequest(
        @NotBlank(message = "项目不能为空") String projectId,
        @NotBlank(message = "生成模式不能为空")
                @Pattern(regexp = "^(AI_PROJECT|BASIC_SCAFFOLD)$", message = "生成模式只支持 AI_PROJECT 或 BASIC_SCAFFOLD")
                String generationMode,
        @Size(max = 10000, message = "业务描述不能超过 10000 个字符") String businessDescription,
        @Size(max = 500000, message = "DDL 不能超过 500000 个字符") String ddl) {}
