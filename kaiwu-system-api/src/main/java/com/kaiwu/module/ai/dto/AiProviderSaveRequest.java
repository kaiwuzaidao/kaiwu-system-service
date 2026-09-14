package com.kaiwu.module.ai.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record AiProviderSaveRequest(
        @NotBlank(message = "配置名称不能为空") @Size(max = 100, message = "配置名称不能超过 100 个字符") String providerName,
        @NotBlank(message = "API 地址不能为空") @Size(max = 512, message = "API 地址不能超过 512 个字符") String baseUrl,
        @Size(max = 4096, message = "API Key 不能超过 4096 个字符") String apiKey,
        Boolean clearApiKey,
        @NotBlank(message = "模型不能为空") @Size(max = 128, message = "模型不能超过 128 个字符") String model,
        @DecimalMin(value = "0.0", message = "Temperature 不能小于 0")
                @DecimalMax(value = "2.0", message = "Temperature 不能大于 2")
                BigDecimal temperature,
        @Min(value = 5, message = "超时时间不能小于 5 秒") @Max(value = 300, message = "超时时间不能大于 300 秒") Integer timeoutSeconds,
        Boolean enabled) {}
