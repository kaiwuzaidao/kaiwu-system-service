package com.kaiwu.module.connector.vo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** 可展示的模型信息，密钥只返回配置状态。 */
public record AiModelView(
        String id,
        String providerName,
        String baseUrl,
        boolean apiKeyConfigured,
        String model,
        BigDecimal temperature,
        int timeoutSeconds,
        String lastTestStatus,
        String lastTestMessage,
        LocalDateTime lastTestAt) {}
