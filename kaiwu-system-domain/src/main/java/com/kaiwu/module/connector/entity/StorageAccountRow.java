package com.kaiwu.module.connector.entity;

import java.time.LocalDateTime;

/**
 * {@code sys_storage_account} 的查询投影。列顺序必须与 {@code StorageAccountMapper} 的 SELECT 一致：
 * MyBatis 按列顺序调用 record 的规范构造器。
 *
 * @param id 账号 ID
 * @param accountCode 账号编码
 * @param accountName 展示名称
 * @param providerType 存储类型
 * @param endpoint 数据面地址
 * @param region 签名区域
 * @param bucket 桶名
 * @param pathStyle 是否 path-style
 * @param stsEndpoint STS 地址
 * @param roleArn 角色 ARN，可空
 * @param accessKeyId 签发用 AccessKey ID
 * @param accessKeySecretCiphertext 签发用 Secret 的密文
 * @param credentialTtlSeconds 临时凭证有效期（秒）
 * @param status 账号状态
 * @param lastTestStatus 最近一次测试结果
 * @param lastTestMessage 最近一次测试信息
 * @param lastTestAt 最近一次测试时间
 * @param bindingCount 引用该账号的绑定数
 */
public record StorageAccountRow(
        String id,
        String accountCode,
        String accountName,
        String providerType,
        String endpoint,
        String region,
        String bucket,
        boolean pathStyle,
        String stsEndpoint,
        String roleArn,
        String accessKeyId,
        String accessKeySecretCiphertext,
        int credentialTtlSeconds,
        String status,
        String lastTestStatus,
        String lastTestMessage,
        LocalDateTime lastTestAt,
        long bindingCount) {

    /**
     * 判断账号是否启用。
     *
     * @return 状态为 {@code ENABLED} 时返回 {@code true}
     */
    public boolean enabled() {
        return "ENABLED".equals(status);
    }

    /**
     * 不输出 AccessKey 与密文，避免投影被日志或异常消息带出。
     *
     * @return 不含凭据的描述
     */
    @Override
    public String toString() {
        return "StorageAccountRow[id=" + id + ", accountCode=" + accountCode + ", providerType=" + providerType + "]";
    }
}
