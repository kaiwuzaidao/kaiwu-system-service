package com.kaiwu.module.connector.vo;

import java.time.LocalDateTime;

/**
 * 存储账号的管理视图。AccessKey Secret 只以 {@code secretConfigured} 表达是否已配置，
 * AccessKey ID 只回显首尾各 4 位。
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
 * @param roleArn 角色 ARN
 * @param accessKeyIdMasked 掩码后的 AccessKey ID
 * @param secretConfigured 是否已配置 Secret
 * @param credentialTtlSeconds 临时凭证有效期（秒）
 * @param enabled 是否启用
 * @param bindingCount 引用该账号的项目绑定数
 * @param lastTestStatus 最近一次测试结果
 * @param lastTestMessage 最近一次测试信息
 * @param lastTestAt 最近一次测试时间
 */
public record StorageAccountView(
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
        String accessKeyIdMasked,
        boolean secretConfigured,
        int credentialTtlSeconds,
        boolean enabled,
        long bindingCount,
        String lastTestStatus,
        String lastTestMessage,
        LocalDateTime lastTestAt) {}
