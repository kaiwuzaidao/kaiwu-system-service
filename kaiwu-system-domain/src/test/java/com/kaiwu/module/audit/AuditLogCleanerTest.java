package com.kaiwu.module.audit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.audit.mapper.AuditWriteMapper;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/**
 * 审计日志清理：分批、总量上限、多副本互斥与失败不外抛。
 */
class AuditLogCleanerTest {

    private AuditWriteMapper auditMapper;
    private StringRedisTemplate redisTemplate;
    private ValueOperations<String, String> valueOps;
    private AuditRetentionProperties properties;
    private AuditLogCleaner cleaner;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        auditMapper = mock(AuditWriteMapper.class);
        redisTemplate = mock(StringRedisTemplate.class);
        valueOps = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        properties = new AuditRetentionProperties();
        cleaner = new AuditLogCleaner(auditMapper, redisTemplate, properties, Clock.systemDefaultZone());
    }

    private void lockAcquired(boolean acquired) {
        when(valueOps.setIfAbsent(anyString(), anyString(), any(Duration.class)))
                .thenReturn(acquired);
    }

    @Test
    void deletesBothTablesAndReleasesLock() {
        lockAcquired(true);
        // 单批返回小于 batchSize，表示已删完。
        when(auditMapper.deleteLoginLogsBefore(any(), anyInt())).thenReturn(1);
        when(auditMapper.deleteOperationLogsBefore(any(), anyInt())).thenReturn(1);

        cleaner.cleanup();

        verify(auditMapper).deleteLoginLogsBefore(any(), anyInt());
        verify(auditMapper).deleteOperationLogsBefore(any(), anyInt());
        verify(redisTemplate).delete("kaiwu:audit:cleanup:lock");
    }

    @Test
    void skipsWhenAnotherInstanceHoldsLock() {
        lockAcquired(false);

        cleaner.cleanup();

        verify(auditMapper, never()).deleteLoginLogsBefore(any(), anyInt());
        verify(auditMapper, never()).deleteOperationLogsBefore(any(), anyInt());
        // 没拿到锁就不能删别人的锁。
        verify(redisTemplate, never()).delete(anyString());
    }

    @Test
    void skipsWhenDisabled() {
        properties.setEnabled(false);

        cleaner.cleanup();

        verify(valueOps, never()).setIfAbsent(anyString(), anyString(), any(Duration.class));
        verify(auditMapper, never()).deleteLoginLogsBefore(any(), anyInt());
        verify(auditMapper, never()).deleteOperationLogsBefore(any(), anyInt());
    }

    @Test
    void stopsAtMaxRowsPerRunWhenBacklogIsHuge() {
        lockAcquired(true);
        properties.setBatchSize(100);
        properties.setMaxRowsPerRun(300);
        // 每批都删满，模拟历史积压；必须靠总量上限停下来而不是无限循环。
        when(auditMapper.deleteLoginLogsBefore(any(), anyInt())).thenReturn(100);
        when(auditMapper.deleteOperationLogsBefore(any(), anyInt())).thenReturn(100);

        cleaner.cleanup();

        // 两张表各 3 批（300/100），共 6 次。
        verify(auditMapper, times(3)).deleteLoginLogsBefore(any(), anyInt());
        verify(auditMapper, times(3)).deleteOperationLogsBefore(any(), anyInt());
    }

    @Test
    void releasesLockWhenDeleteFails() {
        lockAcquired(true);
        when(auditMapper.deleteLoginLogsBefore(any(), anyInt())).thenThrow(new RuntimeException("表被锁"));

        // 不外抛，否则会污染调度线程。
        cleaner.cleanup();

        verify(redisTemplate, atLeastOnce()).delete("kaiwu:audit:cleanup:lock");
    }

    @Test
    void deletesUsingRetainDaysBoundary() {
        lockAcquired(true);
        properties.setRetainDays(30);
        when(auditMapper.deleteLoginLogsBefore(any(), anyInt())).thenReturn(0);

        cleaner.cleanup();

        // 两张审计表各删一次；边界时间由保留期推导。
        ArgumentCaptor<LocalDateTime> before = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(auditMapper).deleteLoginLogsBefore(before.capture(), anyInt());
        verify(auditMapper).deleteOperationLogsBefore(any(), anyInt());
        assertThat(before.getValue())
                .isBefore(LocalDateTime.now().minusDays(29))
                .isAfter(LocalDateTime.now().minusDays(31));
    }
}
