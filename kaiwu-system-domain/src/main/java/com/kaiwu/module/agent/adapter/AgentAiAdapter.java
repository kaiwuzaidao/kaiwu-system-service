package com.kaiwu.module.agent.adapter;

import com.kaiwu.module.connector.client.OpenAiCompatibleClient;
import com.kaiwu.module.connector.service.AiProviderService;
import com.kaiwu.port.AgentAiPort;
import java.util.Optional;
import org.springframework.stereotype.Component;

/** 把受管 Provider 配置与 OpenAI 兼容客户端接到 {@link AgentAiPort}。 */
@Component
public class AgentAiAdapter implements AgentAiPort {

    private final AiProviderService providers;
    private final OpenAiCompatibleClient client;

    public AgentAiAdapter(AiProviderService providers, OpenAiCompatibleClient client) {
        this.providers = providers;
        this.client = client;
    }

    @Override
    public Optional<RuntimeConfig> effectiveConfig() {
        return providers
                .effective()
                .map(config -> new RuntimeConfig(
                        config.providerName(),
                        config.baseUrl(),
                        config.apiKey(),
                        config.model(),
                        config.temperature(),
                        config.timeoutSeconds()));
    }

    /** 按用途读取当前受管绑定，不暴露密钥给接口调用方以外的组件。 */
    @Override
    public Optional<RoutedConfig> effectiveFor(String purpose) {
        return providers.effectiveFor(purpose).map(route -> {
            var config = route.config();
            return new RoutedConfig(
                    route.modelId(),
                    new RuntimeConfig(
                            config.providerName(),
                            config.baseUrl(),
                            config.apiKey(),
                            config.model(),
                            config.temperature(),
                            config.timeoutSeconds()));
        });
    }

    @Override
    public ChatOutcome chat(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens) {
        AiProviderService.RuntimeConfig providerConfig = new AiProviderService.RuntimeConfig(
                config.providerName(),
                config.baseUrl(),
                config.apiKey(),
                config.model(),
                config.temperature(),
                config.timeoutSeconds());
        OpenAiCompatibleClient.ChatResult result = client.chat(providerConfig, systemPrompt, userPrompt, maxTokens);
        return new ChatOutcome(result.content(), result.promptTokens(), result.completionTokens());
    }
}
