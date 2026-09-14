package com.kaiwu.module.auth;

import com.kaiwu.port.SessionSnapshotPort;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/** Redis 会话快照适配器；缓存键格式只在认证模块内维护。 */
@Component
public class RedisSessionSnapshotAdapter implements SessionSnapshotPort {

    static final String KEY_PREFIX = "kaiwu:session:";

    private final StringRedisTemplate redisTemplate;

    public RedisSessionSnapshotAdapter(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void write(String sessionId, String userId, String username, Set<String> permissions, Instant expiresAt) {
        String key = KEY_PREFIX + sessionId;
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("userId", userId);
        fields.put("username", username);
        fields.put("permissions", String.join(",", permissions));
        fields.put("authzVersion", permissionVersion(permissions));
        redisTemplate.opsForHash().putAll(key, fields);
        Duration ttl = Duration.between(Instant.now(), expiresAt);
        if (ttl.isPositive()) {
            redisTemplate.expire(key, ttl);
        }
    }

    @Override
    public void delete(String sessionId) {
        redisTemplate.delete(KEY_PREFIX + sessionId);
    }

    @Override
    public void deleteAll() {
        Set<String> keys = redisTemplate.keys(KEY_PREFIX + "*");
        if (keys != null && !keys.isEmpty()) {
            redisTemplate.delete(keys);
        }
    }

    private static String permissionVersion(Set<String> permissions) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(String.join(",", permissions).getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder()
                    .withoutPadding()
                    .encodeToString(digest)
                    .substring(0, 16);
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }
}
