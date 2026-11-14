package com.kaiwu.module.connector.vo;

import java.time.Instant;
import java.util.List;

/**
 * 签发给业务项目的单个存储绑定的临时凭证。只经内部接口返回给项目服务凭据的持有方，
 * 不得出现在日志、审计或浏览器可见的接口中。
 *
 * @param storageRef 绑定标识，业务记录据此在切换存储后定位旧文件
 * @param storageName 项目内存储名
 * @param mode 访问模式：{@code READ_WRITE} 或 {@code READ_ONLY}
 * @param providerType 存储类型，决定 starter 的访问风格
 * @param endpoint 数据面地址
 * @param region 签名区域
 * @param bucket 桶名
 * @param pathStyle 是否 path-style
 * @param prefix 对象 key 前缀，固定为 {@code {projectCode}/}
 * @param maxObjectBytes 单个对象字节上限
 * @param allowedContentTypes 允许的 MIME 类型，空表示不限制
 * @param accessKeyId 临时 AccessKey ID
 * @param accessKeySecret 临时 AccessKey Secret
 * @param securityToken 临时会话令牌
 * @param expiresAt 失效时间
 */
public record StorageCredentialView(
        String storageRef,
        String storageName,
        String mode,
        String providerType,
        String endpoint,
        String region,
        String bucket,
        boolean pathStyle,
        String prefix,
        long maxObjectBytes,
        List<String> allowedContentTypes,
        String accessKeyId,
        String accessKeySecret,
        String securityToken,
        Instant expiresAt) {

    /**
     * 不在 toString 中输出临时密钥，避免被异常或调试日志意外带出。
     *
     * @return 不含密钥的描述
     */
    @Override
    public String toString() {
        return "StorageCredentialView[storageRef=" + storageRef + ", storageName=" + storageName + ", mode=" + mode
                + ", expiresAt=" + expiresAt + "]";
    }
}
