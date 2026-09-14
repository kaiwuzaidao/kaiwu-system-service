package com.kaiwu.port;

import java.math.BigDecimal;
import java.util.Optional;

/** 项目蓝图生成所需的最小模型调用边界。 */
public interface ProjectGenerationAiPort {

    Optional<RuntimeConfig> effectiveConfig();

    String chat(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens);

    record RuntimeConfig(
            String providerName,
            String baseUrl,
            String apiKey,
            String model,
            BigDecimal temperature,
            int timeoutSeconds) {}
}
