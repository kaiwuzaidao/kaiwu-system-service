package com.kaiwu.module.connector.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 新建或修改存储账号（ADR 0039）。
 *
 * @param accountCode 账号编码，创建后不可修改，用于审计与排查
 * @param accountName 展示名称
 * @param providerType 存储类型，取字典 {@code storage.provider.type}
 * @param endpoint 数据面 S3 兼容地址，业务项目用它读写对象
 * @param region 签名区域
 * @param bucket 桶名
 * @param pathStyle 是否使用 path-style 访问；阿里云 OSS 必须为 {@code false}
 * @param stsEndpoint STS 服务地址
 * @param roleArn 扮演的角色 ARN；阿里云必填，MinIO 可空
 * @param accessKeyId 签发用 AccessKey ID；修改时留空表示沿用原值
 * @param accessKeySecret 签发用 AccessKey Secret；修改时留空表示沿用原值
 * @param credentialTtlSeconds 临时凭证有效期（秒）
 * @param enabled 是否启用
 */
public record StorageAccountSaveRequest(
        @NotBlank(message = "账号编码不能为空") @Pattern(regexp = "[a-z0-9][a-z0-9-]{1,63}", message = "账号编码只允许小写字母、数字和连字符")
                String accountCode,
        @NotBlank(message = "名称不能为空") @Size(max = 100, message = "名称不能超过 100 个字符") String accountName,
        @NotBlank(message = "存储类型不能为空") String providerType,
        @NotBlank(message = "存储地址不能为空") @Size(max = 255, message = "存储地址不能超过 255 个字符") String endpoint,
        @NotBlank(message = "区域不能为空") @Size(max = 64, message = "区域不能超过 64 个字符") String region,
        @NotBlank(message = "桶名不能为空") @Pattern(regexp = "[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", message = "桶名格式不正确")
                String bucket,
        Boolean pathStyle,
        @NotBlank(message = "STS 地址不能为空") @Size(max = 255, message = "STS 地址不能超过 255 个字符") String stsEndpoint,
        @Size(max = 255, message = "角色 ARN 不能超过 255 个字符") String roleArn,
        @Size(max = 128, message = "AccessKey ID 不能超过 128 个字符") String accessKeyId,
        @Size(max = 256, message = "AccessKey Secret 不能超过 256 个字符") String accessKeySecret,
        @Min(value = 900, message = "凭证有效期不能少于 900 秒") @Max(value = 3600, message = "凭证有效期不能超过 3600 秒")
                Integer credentialTtlSeconds,
        Boolean enabled) {}
