package com.kaiwu.module.metadata;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * 敏感配置静态加密。密钥只允许从环境变量注入，绝不写入数据库或仓库。
 */
@Component
public class ConfigEncryptionService {

    private static final int IV_LENGTH = 12;
    private static final int TAG_BITS = 128;
    private final SecretKeySpec key;
    private final SecureRandom secureRandom = new SecureRandom();

    public ConfigEncryptionService(@Value("${kaiwu.metadata.encryption-key:}") String encodedKey) {
        if (!StringUtils.hasText(encodedKey)) {
            throw new IllegalStateException("缺少必需环境变量：KAIWU_CONFIG_ENCRYPTION_KEY");
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(encodedKey);
            if (decoded.length != 32) {
                throw new IllegalArgumentException("key length");
            }
            this.key = new SecretKeySpec(decoded, "AES");
        } catch (Exception exception) {
            throw new IllegalStateException("KAIWU_CONFIG_ENCRYPTION_KEY 必须是 Base64 编码的 32 字节密钥", exception);
        }
    }

    /** AES-GCM 加密敏感配置值；每次生成新 IV 并与密文一同存储。 */
    public String encrypt(String value) {
        try {
            byte[] iv = new byte[IV_LENGTH];
            secureRandom.nextBytes(iv);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
            byte[] payload = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, payload, 0, iv.length);
            System.arraycopy(encrypted, 0, payload, iv.length, encrypted.length);
            return "v1:" + Base64.getEncoder().encodeToString(payload);
        } catch (Exception exception) {
            throw new IllegalStateException("敏感配置加密失败", exception);
        }
    }

    /** 解密敏感配置值；空值原样返回，密钥不匹配时抛出而不是返回乱码。 */
    public String decrypt(String value) {
        if (!StringUtils.hasText(value)) {
            return null;
        }
        if (!value.startsWith("v1:")) {
            throw new IllegalStateException("敏感配置密文版本不受支持");
        }
        try {
            byte[] payload = Base64.getDecoder().decode(value.substring(3));
            if (payload.length <= IV_LENGTH) {
                throw new IllegalArgumentException("payload length");
            }
            byte[] iv = new byte[IV_LENGTH];
            byte[] encrypted = new byte[payload.length - IV_LENGTH];
            System.arraycopy(payload, 0, iv, 0, iv.length);
            System.arraycopy(payload, iv.length, encrypted, 0, encrypted.length);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception exception) {
            throw new IllegalStateException("敏感配置解密失败", exception);
        }
    }
}
