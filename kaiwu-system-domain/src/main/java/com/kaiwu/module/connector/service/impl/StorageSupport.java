package com.kaiwu.module.connector.service.impl;

import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.connector.client.StorageAccountAccess;
import com.kaiwu.module.connector.client.StorageCredentialIssuer;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * 账号管理与凭证签发共用的协作者：按类型查找签发器、解密账号参数、生成会话名。
 */
@Component
class StorageSupport {

    private static final int MAX_SESSION_NAME = 64;

    private final Map<String, StorageCredentialIssuer> issuers;
    private final ConfigEncryptionService encryptionService;

    /**
     * 收集全部签发器。
     *
     * @param issuers Spring 中注册的签发器
     * @param encryptionService 平台配置加密服务
     */
    StorageSupport(List<StorageCredentialIssuer> issuers, ConfigEncryptionService encryptionService) {
        this.issuers = issuers.stream()
                .collect(Collectors.toUnmodifiableMap(StorageCredentialIssuer::providerType, Function.identity()));
        this.encryptionService = encryptionService;
    }

    /**
     * 判断存储类型是否有对应签发器。
     *
     * @param providerType 存储类型
     * @return 支持时返回 {@code true}
     */
    boolean supports(String providerType) {
        return issuers.containsKey(providerType);
    }

    /**
     * 取存储类型对应的签发器。
     *
     * @param providerType 存储类型
     * @return 签发器
     * @throws IllegalStateException 类型没有签发器时抛出
     */
    StorageCredentialIssuer issuer(String providerType) {
        StorageCredentialIssuer issuer = issuers.get(providerType);
        if (issuer == null) {
            throw new IllegalStateException("不支持的存储类型：" + providerType);
        }
        return issuer;
    }

    /**
     * 加密 Secret。
     *
     * @param plain Secret 明文
     * @return 密文
     */
    String encrypt(String plain) {
        return encryptionService.encrypt(plain);
    }

    /**
     * 解密账号参数，仅在签发调用栈内使用。
     *
     * @param row 账号行
     * @return 已解密的账号参数
     */
    StorageAccountAccess access(StorageAccountRow row) {
        return new StorageAccountAccess(
                row.providerType(),
                row.endpoint(),
                row.region(),
                row.bucket(),
                row.pathStyle(),
                row.stsEndpoint(),
                row.roleArn(),
                row.accessKeyId(),
                encryptionService.decrypt(row.accessKeySecretCiphertext()));
    }

    /**
     * 生成云端审计可追溯的会话名，只保留 STS 允许的字符。
     *
     * @param suffix 项目编码或用途
     * @return 会话名
     */
    static String sessionName(String suffix) {
        String name = ("kaiwu-" + suffix).replaceAll("[^A-Za-z0-9_.@-]", "-");
        return name.length() > MAX_SESSION_NAME ? name.substring(0, MAX_SESSION_NAME) : name;
    }
}
