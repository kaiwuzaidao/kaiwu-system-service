package com.kaiwu.port;

import java.math.BigDecimal;
import java.util.Optional;

/**
 * Agent 调用大模型的出口。
 *
 * <p>平台已不再用模型生成项目（ADR 0038），这是唯一的模型调用端口。
 * Agent 除了正文，还需要 token 数落入评估事件，否则三个月复核时算不出成本，
 * 也发现不了异常变长的对话（ADR 0030 第 12 条）。</p>
 */
public interface AgentAiPort {

    Optional<RuntimeConfig> effectiveConfig();

    /** 按用途读取当前绑定；旧实现沿用默认模型。 */
    default Optional<RoutedConfig> effectiveFor(String purpose) {
        return effectiveConfig().map(config -> new RoutedConfig("1", config));
    }

    /** 包含稳定配置身份的运行配置，仅在读取或调用期间使用。 */
    record RoutedConfig(String modelId, RuntimeConfig config) {}

    ChatOutcome chat(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens);

    record RuntimeConfig(
            String providerName,
            String baseUrl,
            String apiKey,
            String model,
            BigDecimal temperature,
            int timeoutSeconds) {}

    record ChatOutcome(String content, Long promptTokens, Long completionTokens) {}
}
