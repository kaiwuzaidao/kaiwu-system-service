package com.kaiwu.module.ai;

import com.kaiwu.module.ai.entity.AiProviderConfigEntity;
import com.kaiwu.module.ai.mapper.AiProviderConfigMapper;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/**
 * Persistence adapter for the single AI-provider configuration row.
 */
@Repository
public class AiProviderRepository {

    private static final long SINGLETON_ID = 1L;
    private static final int MAX_TEST_MESSAGE_LENGTH = 500;
    private static final int DEFAULT_TIMEOUT_SECONDS = 60;

    private final AiProviderConfigMapper mapper;

    public AiProviderRepository(AiProviderConfigMapper mapper) {
        this.mapper = mapper;
    }

    public Optional<ProviderRow> current() {
        return Optional.ofNullable(mapper.selectById(SINGLETON_ID)).map(AiProviderRepository::toRow);
    }

    /** 写入唯一一行配置；连通性测试结果不在覆盖范围内，由 {@link #recordTest} 单独维护。 */
    public void save(ProviderRow row) {
        mapper.upsert(
                SINGLETON_ID,
                row.providerName(),
                row.baseUrl(),
                row.apiKeyCiphertext(),
                row.model(),
                row.temperature(),
                row.timeoutSeconds(),
                row.enabled());
    }

    /** 记录一次连通性测试结果；信息超长时截断到列宽，避免一条长错误让写入直接失败。 */
    public void recordTest(boolean successful, String message, LocalDateTime testedAt) {
        mapper.recordTest(
                SINGLETON_ID, successful ? "SUCCESS" : "FAILED", truncate(message, MAX_TEST_MESSAGE_LENGTH), testedAt);
    }

    private static ProviderRow toRow(AiProviderConfigEntity entity) {
        return new ProviderRow(
                entity.getProviderName(),
                entity.getBaseUrl(),
                entity.getApiKeyCiphertext(),
                entity.getModel(),
                entity.getTemperature(),
                // 迁移前用 wasNull() 兜底，列可空时回落到默认超时；这里保持同一语义。
                entity.getTimeoutSeconds() == null ? DEFAULT_TIMEOUT_SECONDS : entity.getTimeoutSeconds(),
                Boolean.TRUE.equals(entity.getEnabled()),
                entity.getLastTestStatus(),
                entity.getLastTestMessage(),
                entity.getLastTestAt());
    }

    private static String truncate(String value, int maximumLength) {
        if (value == null || value.length() <= maximumLength) {
            return value;
        }
        return value.substring(0, maximumLength);
    }

    public record ProviderRow(
            String providerName,
            String baseUrl,
            String apiKeyCiphertext,
            String model,
            BigDecimal temperature,
            int timeoutSeconds,
            boolean enabled,
            String lastTestStatus,
            String lastTestMessage,
            LocalDateTime lastTestAt) {}
}
