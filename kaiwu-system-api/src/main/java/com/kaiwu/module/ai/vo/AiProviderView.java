package com.kaiwu.module.ai.vo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record AiProviderView(
        String providerName,
        String baseUrl,
        boolean apiKeyConfigured,
        String model,
        BigDecimal temperature,
        int timeoutSeconds,
        boolean enabled,
        String lastTestStatus,
        String lastTestMessage,
        LocalDateTime lastTestAt) {}
