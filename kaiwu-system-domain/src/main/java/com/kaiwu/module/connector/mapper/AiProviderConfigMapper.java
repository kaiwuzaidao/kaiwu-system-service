package com.kaiwu.module.connector.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.connector.entity.AiProviderConfigEntity;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/** AI 供应商配置 Mapper。 */
@Mapper
public interface AiProviderConfigMapper extends BaseMapper<AiProviderConfigEntity> {

    /**
     * 写入唯一一行配置。
     *
     * <p>保存配置时清除旧测试结果，避免变更模型后沿用过期的成功状态。</p>
     */
    @Update(
            databaseId = "dm",
            value =
                    """
            MERGE INTO sys_ai_provider_config t
            USING (
            SELECT incoming.id, incoming.provider_name, incoming.base_url, incoming.api_key_ciphertext, incoming.model, incoming.temperature, incoming.timeout_seconds, incoming.enabled, incoming.created_at, incoming.updated_at, (SELECT existing.id FROM sys_ai_provider_config existing WHERE (existing.id = incoming.id)) AS match_id
            FROM (
            SELECT #{id} AS id,
                   #{providerName} AS provider_name,
                   #{baseUrl} AS base_url,
                   #{apiKeyCiphertext} AS api_key_ciphertext,
                   #{model} AS model,
                   #{temperature} AS temperature,
                   #{timeoutSeconds} AS timeout_seconds,
                   #{enabled} AS enabled,
                   CURRENT_TIMESTAMP AS created_at,
                   CURRENT_TIMESTAMP AS updated_at
            FROM dual
            ) incoming
            ) s
            ON (t.id = s.match_id)
            WHEN MATCHED THEN UPDATE SET t.provider_name = s.provider_name,
                t.base_url = s.base_url,
                t.api_key_ciphertext = s.api_key_ciphertext,
                t.model = s.model,
                t.temperature = s.temperature,
                t.timeout_seconds = s.timeout_seconds,
                t.enabled = s.enabled,
                t.config_revision = t.config_revision + 1,
                t.last_test_status = NULL,
                t.last_test_message = NULL,
                t.last_test_at = NULL,
                t.updated_at = CURRENT_TIMESTAMP
            WHEN NOT MATCHED THEN INSERT (id, provider_name, base_url, api_key_ciphertext, model, temperature, timeout_seconds, enabled, created_at, updated_at)
            VALUES (s.id, s.provider_name, s.base_url, s.api_key_ciphertext, s.model, s.temperature, s.timeout_seconds, s.enabled, s.created_at, s.updated_at)
            """)
    @Update(
            """
            INSERT INTO sys_ai_provider_config
                (id, provider_name, base_url, api_key_ciphertext, model, temperature,
                 timeout_seconds, enabled, created_at, updated_at)
            VALUES (#{id}, #{providerName}, #{baseUrl}, #{apiKeyCiphertext}, #{model},
                    #{temperature}, #{timeoutSeconds}, #{enabled},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                provider_name = VALUES(provider_name),
                base_url = VALUES(base_url),
                api_key_ciphertext = VALUES(api_key_ciphertext),
                model = VALUES(model),
                temperature = VALUES(temperature),
                timeout_seconds = VALUES(timeout_seconds),
                enabled = VALUES(enabled),
                config_revision = config_revision + 1,
                last_test_status = NULL,
                last_test_message = NULL,
                last_test_at = NULL,
                updated_at = CURRENT_TIMESTAMP
            """)
    int upsert(
            @Param("id") long id,
            @Param("providerName") String providerName,
            @Param("baseUrl") String baseUrl,
            @Param("apiKeyCiphertext") String apiKeyCiphertext,
            @Param("model") String model,
            @Param("temperature") BigDecimal temperature,
            @Param("timeoutSeconds") int timeoutSeconds,
            @Param("enabled") boolean enabled);

    /** 仅当配置未被修改时写入测试结果，避免旧调用覆盖新配置状态。 */
    @Update(
            """
            UPDATE sys_ai_provider_config
            SET last_test_status = #{status}, last_test_message = #{message},
                last_test_at = #{testedAt}, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id} AND config_revision = #{revision}
            """)
    int recordTestIfRevision(
            @Param("id") long id,
            @Param("revision") long revision,
            @Param("status") String status,
            @Param("message") String message,
            @Param("testedAt") LocalDateTime testedAt);

    @Update(
            """
            UPDATE sys_ai_provider_config
            SET last_test_status = #{status}, last_test_message = #{message},
                last_test_at = #{testedAt}, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int recordTest(
            @Param("id") long id,
            @Param("status") String status,
            @Param("message") String message,
            @Param("testedAt") LocalDateTime testedAt);
}
