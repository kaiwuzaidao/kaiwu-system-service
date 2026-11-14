package com.kaiwu.module.agent.service;

import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * 每用户每分钟的提问次数上限。
 *
 * <p>P1a 第一次把用户输入直连模型，没有这道闸，一个循环脚本就能烧掉额度。
 * 计数放 Redis 而不是数据库：高频写且允许丢失，不值得占数据库事务
 * （与 {@code LoginAttemptGuard} 同一判断）。</p>
 */
@Component
public class AgentRateLimiter {

    private static final String KEY_PREFIX = "agent:rate:";

    private final StringRedisTemplate redisTemplate;
    private final int maxPerMinute;

    public AgentRateLimiter(
            StringRedisTemplate redisTemplate, @Value("${kaiwu.agent.max-questions-per-minute:10}") int maxPerMinute) {
        this.redisTemplate = redisTemplate;
        this.maxPerMinute = maxPerMinute;
    }

    /**
     * 记一次提问并判断是否超限。
     *
     * @return 超限返回 false，调用方应在不调用模型的情况下拒绝
     */
    public boolean tryAcquire(String userId) {
        String key = KEY_PREFIX + userId;
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, Duration.ofMinutes(1));
        }
        return count == null || count <= maxPerMinute;
    }

    public int maxPerMinute() {
        return maxPerMinute;
    }
}
