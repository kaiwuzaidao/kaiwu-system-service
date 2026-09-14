package com.kaiwu.module.auth;

import io.jsonwebtoken.Jwts;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;
import org.springframework.util.StringUtils;

/**
 * System 签发仅供 Gateway 验证的短期外部 Access JWT。
 */
public final class AccessTokenService {

    public static final String ACCESS_TOKEN_TYPE = "kaiwu-access+jwt";

    private final AuthProperties properties;
    private final PrivateKey privateKey;

    public AccessTokenService(AuthProperties properties) {
        if (!StringUtils.hasText(properties.getAccessPrivateKey())) {
            throw new IllegalStateException("缺少必需配置：kaiwu.auth.access-private-key");
        }
        this.properties = properties;
        this.privateKey = parsePrivateKey(properties.getAccessPrivateKey());
    }

    /** 签发短期 access token；只带身份标识，权限事实由 Gateway 与 System 各自查库。 */
    public String issue(String userId, String sessionId, String username) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plusSeconds(properties.getAccessTtlSeconds());
        return Jwts.builder()
                .header()
                .type(ACCESS_TOKEN_TYPE)
                .and()
                .issuer(properties.getAccessIssuer())
                .audience()
                .add(properties.getAccessAudience())
                .and()
                .subject(userId)
                .id(UUID.randomUUID().toString())
                .issuedAt(Date.from(issuedAt))
                .expiration(Date.from(expiresAt))
                .claim("sid", sessionId)
                .claim("username", username)
                .signWith(privateKey, Jwts.SIG.RS256)
                .compact();
    }

    private static PrivateKey parsePrivateKey(String pem) {
        try {
            String normalized = pem.replace("\\n", "\n")
                    .replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");
            return KeyFactory.getInstance("RSA")
                    .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(normalized)));
        } catch (Exception exception) {
            throw new IllegalStateException("kaiwu.auth.access-private-key 不是有效的 PKCS8 RSA 私钥", exception);
        }
    }
}
