package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.ai.AiProviderService;
import com.kaiwu.module.ai.OpenAiCompatibleClient;
import com.kaiwu.port.ProjectGenerationAiPort;
import java.util.Optional;
import org.springframework.stereotype.Component;

/** 项目工厂到模型配置与模型客户端的适配器。 */
@Component
public class ProjectGenerationAiAdapter implements ProjectGenerationAiPort {

    private final AiProviderService providers;
    private final OpenAiCompatibleClient client;

    public ProjectGenerationAiAdapter(AiProviderService providers, OpenAiCompatibleClient client) {
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

    @Override
    public String chat(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens) {
        AiProviderService.RuntimeConfig providerConfig = new AiProviderService.RuntimeConfig(
                config.providerName(),
                config.baseUrl(),
                config.apiKey(),
                config.model(),
                config.temperature(),
                config.timeoutSeconds());
        return client.chat(providerConfig, systemPrompt, userPrompt, maxTokens).content();
    }
}
