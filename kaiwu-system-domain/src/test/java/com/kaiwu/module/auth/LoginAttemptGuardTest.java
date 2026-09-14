package com.kaiwu.module.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/**
 * 登录失败锁定：阈值、窗口不被续期、大小写归一与成功后清除。
 */
class LoginAttemptGuardTest {

    private StringRedisTemplate redisTemplate;
    private ValueOperations<String, String> valueOps;
    private AuthProperties properties;
    private LoginAttemptGuard guard;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        redisTemplate = mock(StringRedisTemplate.class);
        valueOps = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        properties = new AuthProperties();
        guard = new LoginAttemptGuard(redisTemplate, properties);
    }

    @Test
    void locksAfterReachingThreshold() {
        when(valueOps.increment("kaiwu:login:fail:admin")).thenReturn((long) properties.getMaxFailedAttempts());

        assertThat(guard.recordFailure("admin")).isTrue();

        verify(valueOps).set(eq("kaiwu:login:lock:admin"), eq("1"), any(Duration.class));
        // 锁定后清掉计数，解锁后重新从 0 开始。
        verify(redisTemplate).delete("kaiwu:login:fail:admin");
    }

    @Test
    void doesNotLockBeforeThreshold() {
        when(valueOps.increment(anyString())).thenReturn(1L);

        assertThat(guard.recordFailure("admin")).isFalse();

        // 首次失败才设置窗口；后续失败不得续期，否则持续尝试可无限延长窗口。
        verify(redisTemplate).expire(eq("kaiwu:login:fail:admin"), any(Duration.class));
        verify(valueOps, never()).set(anyString(), anyString(), any(Duration.class));
    }

    @Test
    void doesNotExtendWindowOnSubsequentFailures() {
        when(valueOps.increment(anyString())).thenReturn(2L);

        guard.recordFailure("admin");

        verify(redisTemplate, never()).expire(anyString(), any(Duration.class));
    }

    @Test
    void normalizesUsernameSoCaseCannotBypassCounting() {
        when(valueOps.increment("kaiwu:login:fail:admin")).thenReturn(1L);

        guard.recordFailure("  Admin  ");

        verify(valueOps).increment("kaiwu:login:fail:admin");
    }

    @Test
    void reportsRemainingLockSeconds() {
        when(redisTemplate.getExpire("kaiwu:login:lock:admin")).thenReturn(120L);

        assertThat(guard.lockedSeconds("admin")).isEqualTo(120L);
    }

    @Test
    void resetClearsBothCounterAndLock() {
        guard.reset("Admin");

        verify(redisTemplate).delete("kaiwu:login:fail:admin");
        verify(redisTemplate).delete("kaiwu:login:lock:admin");
    }

    @Test
    void disabledWhenThresholdIsZero() {
        properties.setMaxFailedAttempts(0);

        assertThat(guard.lockedSeconds("admin")).isZero();
        assertThat(guard.recordFailure("admin")).isFalse();
        verify(valueOps, never()).increment(anyString());
    }
}
