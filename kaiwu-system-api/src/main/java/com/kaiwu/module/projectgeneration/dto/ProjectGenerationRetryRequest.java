package com.kaiwu.module.projectgeneration.dto;

import jakarta.validation.constraints.Size;

/**
 * 修改失败任务的原始输入并重新生成。
 */
public record ProjectGenerationRetryRequest(
        @Size(max = 10000, message = "业务描述不能超过 10000 个字符") String businessDescription,
        @Size(max = 500000, message = "DDL 不能超过 500000 个字符") String ddl) {}
