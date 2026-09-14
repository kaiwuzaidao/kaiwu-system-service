package com.kaiwu.module.ai.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.ai.entity.AiProviderConfigEntity;
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
     * <p>{@code last_test_*} 三列有意不在更新列表里：保存配置不该清空上一次连通性测试结果，
     * 那是 {@link #recordTest} 的职责。</p>
     */
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
