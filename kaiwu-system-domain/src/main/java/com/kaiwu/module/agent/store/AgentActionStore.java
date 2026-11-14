package com.kaiwu.module.agent.store;

import com.kaiwu.common.ApiException;
import java.time.Duration;
import java.util.List;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

/** 单键 CAS 为确认与取消提供互斥；没有状态就拒绝，绝不从客户端重建或自动重放。 */
@Component
public class AgentActionStore {
    private static final String PREFIX = "agent:action:";
    private static final Duration RETENTION = Duration.ofHours(1);
    private static final DefaultRedisScript<Long> CAS = new DefaultRedisScript<>(
            """
            if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
            local ttl = redis.call('PTTL', KEYS[1])
            if ttl <= 0 then return 0 end
            redis.call('SET', KEYS[1], ARGV[2], 'PX', ttl)
            return 1
            """,
            Long.class);
    private final StringRedisTemplate redis;
    private final ObjectMapper json;

    public AgentActionStore(StringRedisTemplate redis, ObjectMapper json) {
        this.redis = redis;
        this.json = json;
    }

    public void create(AgentActionRecord value) {
        try {
            if (!Boolean.TRUE.equals(
                    redis.opsForValue().setIfAbsent(key(value.actionId()), json.writeValueAsString(value), RETENTION)))
                throw unavailable();
        } catch (RuntimeException failure) {
            throw unavailable();
        }
    }

    public AgentActionRecord get(String id) {
        try {
            String value = redis.opsForValue().get(key(id));
            return value == null ? null : json.readValue(value, AgentActionRecord.class);
        } catch (RuntimeException failure) {
            throw unavailable();
        }
    }

    public boolean replace(AgentActionRecord before, AgentActionRecord after) {
        try {
            Long replaced = redis.execute(
                    CAS,
                    List.of(key(before.actionId())),
                    json.writeValueAsString(before),
                    json.writeValueAsString(after));
            if (replaced == null) throw unavailable();
            return replaced == 1;
        } catch (RuntimeException failure) {
            throw unavailable();
        }
    }

    private static String key(String id) {
        return PREFIX + id;
    }

    public static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "操作状态暂不可用，请查询状态，勿重复创建", "api.agent.actionUnavailable");
    }
}
