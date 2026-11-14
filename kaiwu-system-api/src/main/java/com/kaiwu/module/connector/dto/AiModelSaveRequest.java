package com.kaiwu.module.connector.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

/** 新建或编辑模型；未填密钥沿用原密钥。 */
public record AiModelSaveRequest(
        String id,
        @NotBlank @Size(max = 100) String providerName,
        @NotBlank @Size(max = 512) String baseUrl,
        @Size(max = 4096) String apiKey,
        Boolean clearApiKey,
        @NotBlank @Size(max = 128) String model,
        @DecimalMin("0.0") @DecimalMax("2.0") BigDecimal temperature,
        @Min(5) @Max(300) Integer timeoutSeconds) {}
