package com.kaiwu.module.connector.repository;

import com.kaiwu.module.connector.entity.AiProviderConfigEntity;
import com.kaiwu.module.connector.mapper.AiProviderConfigMapper;
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

    /** 单次读取模型和对应配置修订号，供连接测试使用。 */
    public Optional<TestRow> findForTest(long id) {
        return Optional.ofNullable(mapper.selectById(id))
                .map(entity -> new TestRow(toRow(entity), entity.getConfigRevision()));
    }

    /** 仅更新对应配置修订的测试状态。 */
    public boolean recordTestIfRevision(
            long id, long revision, boolean successful, String message, LocalDateTime testedAt) {
        return mapper.recordTestIfRevision(
                        id,
                        revision,
                        successful ? "SUCCESS" : "FAILED",
                        truncate(message, MAX_TEST_MESSAGE_LENGTH),
                        testedAt)
                == 1;
    }

    /** 测试所用配置及数据库修订号。 */
    public record TestRow(ProviderRow row, long revision) {}

    /** 读取指定模型配置，编号由服务端分配。 */
    public Optional<ProviderRow> find(long id) {
        return Optional.ofNullable(mapper.selectById(id)).map(AiProviderRepository::toRow);
    }

    /** 列出模型，密文仅在服务内部使用。 */
    public java.util.List<AiProviderConfigEntity> list() {
        return mapper.selectList(null);
    }

    /** 保存指定模型，保留既有测试记录。 */
    public void save(long id, ProviderRow row) {
        mapper.upsert(
                id,
                row.providerName(),
                row.baseUrl(),
                row.apiKeyCiphertext(),
                row.model(),
                row.temperature(),
                row.timeoutSeconds(),
                row.enabled());
    }

    /** 记录指定模型测试结果。 */
    public void recordTest(long id, boolean successful, String message, LocalDateTime testedAt) {
        mapper.recordTest(id, successful ? "SUCCESS" : "FAILED", truncate(message, MAX_TEST_MESSAGE_LENGTH), testedAt);
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
