package com.kaiwu.module.auth;

import java.time.Duration;
import java.util.Locale;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 登录失败次数限制：连续失败达到阈值后按用户名锁定一段时间。
 *
 * <p>登录接口是 PUBLIC 路由，没有次数限制时可被无限次撞库；登录日志只能让攻击"可见"，
 * 拦不住。计数放 Redis 而不是数据库：失败尝试是高频写且允许丢失，不值得占数据库事务。
 *
 * <p>锁定按用户名而非 IP，理由见 {@link AuthProperties#getMaxFailedAttempts()}。
 * 用户名统一转小写并去空白后作为 key，避免 {@code Admin} 与 {@code admin} 分别计数绕过。
 */
@Component
public class LoginAttemptGuard {

    private static final String FAIL_KEY_PREFIX = "kaiwu:login:fail:";
    private static final String LOCK_KEY_PREFIX = "kaiwu:login:lock:";

    private final StringRedisTemplate redisTemplate;
    private final AuthProperties properties;

    public LoginAttemptGuard(StringRedisTemplate redisTemplate, AuthProperties properties) {
        this.redisTemplate = redisTemplate;
        this.properties = properties;
    }

    /**
     * 登录前检查是否处于锁定期。
     *
     * @return 剩余锁定秒数；未锁定返回 0
     */
    public long lockedSeconds(String username) {
        if (!enabled() || username == null || username.isBlank()) {
            return 0;
        }
        Long ttl = redisTemplate.getExpire(LOCK_KEY_PREFIX + normalize(username));
        return ttl != null && ttl > 0 ? ttl : 0;
    }

    /**
     * 记录一次失败，达到阈值则锁定。
     *
     * @return 本次是否触发了锁定
     */
    public boolean recordFailure(String username) {
        if (!enabled() || username == null || username.isBlank()) {
            return false;
        }
        String key = FAIL_KEY_PREFIX + normalize(username);
        Long attempts = redisTemplate.opsForValue().increment(key);
        if (attempts == null) {
            return false;
        }
        if (attempts == 1L) {
            // 只在首次失败时设置窗口，后续失败不续期，避免攻击者靠持续尝试无限延长窗口。
            redisTemplate.expire(key, Duration.ofSeconds(properties.getFailedAttemptWindowSeconds()));
        }
        if (attempts < properties.getMaxFailedAttempts()) {
            return false;
        }
        redisTemplate
                .opsForValue()
                .set(
                        LOCK_KEY_PREFIX + normalize(username),
                        "1",
                        Duration.ofSeconds(properties.getLockDurationSeconds()));
        redisTemplate.delete(key);
        return true;
    }

    /** 登录成功后清除计数与锁定。 */
    public void reset(String username) {
        if (username == null || username.isBlank()) {
            return;
        }
        String normalized = normalize(username);
        redisTemplate.delete(FAIL_KEY_PREFIX + normalized);
        redisTemplate.delete(LOCK_KEY_PREFIX + normalized);
    }

    private boolean enabled() {
        return properties.getMaxFailedAttempts() > 0;
    }

    private static String normalize(String username) {
        return username.trim().toLowerCase(Locale.ROOT);
    }
}
