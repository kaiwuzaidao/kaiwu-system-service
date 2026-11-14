package com.kaiwu.module.connector.client;

/**
 * 签发器使用的已解密账号参数。只在签发调用栈内短暂存在，不缓存、不落日志。
 *
 * @param providerType 存储类型
 * @param endpoint 数据面地址
 * @param region 签名区域
 * @param bucket 桶名
 * @param pathStyle 是否 path-style
 * @param stsEndpoint STS 地址
 * @param roleArn 角色 ARN，可空
 * @param accessKeyId 签发用 AccessKey ID
 * @param accessKeySecret 签发用 AccessKey Secret 明文
 */
public record StorageAccountAccess(
        String providerType,
        String endpoint,
        String region,
        String bucket,
        boolean pathStyle,
        String stsEndpoint,
        String roleArn,
        String accessKeyId,
        String accessKeySecret) {

    /**
     * 不输出 AccessKey，避免被日志或异常带出。
     *
     * @return 不含凭据的描述
     */
    @Override
    public String toString() {
        return "StorageAccountAccess[providerType=" + providerType + ", bucket=" + bucket + "]";
    }
}
