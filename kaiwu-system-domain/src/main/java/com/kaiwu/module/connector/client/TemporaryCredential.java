package com.kaiwu.module.connector.client;

import java.time.Instant;

/**
 * STS 签发的临时凭证。
 *
 * @param accessKeyId 临时 AccessKey ID
 * @param accessKeySecret 临时 AccessKey Secret
 * @param securityToken 会话令牌
 * @param expiresAt 失效时间
 */
public record TemporaryCredential(String accessKeyId, String accessKeySecret, String securityToken, Instant expiresAt) {

    /**
     * 不输出临时密钥。
     *
     * @return 只含失效时间的描述
     */
    @Override
    public String toString() {
        return "TemporaryCredential[expiresAt=" + expiresAt + "]";
    }
}
