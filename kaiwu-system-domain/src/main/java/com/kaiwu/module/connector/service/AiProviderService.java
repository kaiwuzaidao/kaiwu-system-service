package com.kaiwu.module.connector.service;

import com.kaiwu.module.ai.dto.AiProviderSaveRequest;
import com.kaiwu.module.ai.vo.AiProviderView;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface AiProviderService {

    AiProviderView current();

    void save(AiProviderSaveRequest request);

    Optional<RuntimeConfig> effective();

    /** 列出不包含密钥的模型配置。 */
    java.util.List<com.kaiwu.module.connector.vo.AiModelView> models();

    /** 保存指定模型并加密密钥。 */
    com.kaiwu.module.connector.vo.AiModelView saveModel(com.kaiwu.module.connector.dto.AiModelSaveRequest request);

    /** 查看识别与回答用途绑定。 */
    com.kaiwu.module.connector.dto.AiModelRoutes routes();

    /** 校验并原子保存两项用途绑定。 */
    void saveRoutes(com.kaiwu.module.connector.dto.AiModelRoutes routes);

    /** 读取指定模型的内部调用配置。 */
    Optional<RuntimeConfig> effectiveModel(String id);

    /** 保存指定模型的最近一次连接测试结果。 */
    void recordModelTest(String id, boolean successful, String message, LocalDateTime testedAt);

    /** 按用途读取配置及稳定标识；无明确绑定时使用原默认模型。 */
    Optional<RoutedConfig> effectiveFor(String purpose);

    /** 读取连通性测试快照及其修订号。 */
    Optional<TestConfig> prepareModelTest(String id);

    /** 若配置版本未变化则记录测试结果，否则拒绝旧结果。 */
    boolean recordModelTestIfRevision(
            String id, long revision, boolean successful, String message, LocalDateTime testedAt);

    /** 测试运行配置仅在内部传递，不输出凭据。 */
    record TestConfig(RuntimeConfig config, long revision) {}

    /** 指定模型及运行配置；密钥仅供内部调用。 */
    record RoutedConfig(String modelId, RuntimeConfig config) {}

    void recordTest(boolean successful, String message, LocalDateTime testedAt);

    public record RuntimeConfig(
            String providerName,
            String baseUrl,
            String apiKey,
            String model,
            BigDecimal temperature,
            int timeoutSeconds) {}
}
