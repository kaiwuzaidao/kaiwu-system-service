package com.kaiwu.module.operation.lifecycle;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.repository.TodoRepository;
import java.time.Clock;
import java.time.Duration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/**
 * 待办清理的调度行为：多副本互斥、分批与总量上限、失败不外抛。清理规则本身见 {@code TodoMySqlTest}。
 */
class TodoCleanerTest {

    private TodoRepository repository;
    private StringRedisTemplate redis;
    private ValueOperations<String, String> values;
    private TodoProperties properties;
    private TodoCleaner cleaner;
    private com.kaiwu.module.operation.service.LegacyTodoCleanupRunner guardedCleanup;

    /** 构造带 Mockito 替身的清理任务。 */
    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        repository = mock(TodoRepository.class);
        redis = mock(StringRedisTemplate.class);
        values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        properties = new TodoProperties();
        guardedCleanup = mock(com.kaiwu.module.operation.service.LegacyTodoCleanupRunner.class);
        cleaner = new TodoCleaner(repository, redis, properties, Clock.systemDefaultZone(), guardedCleanup);
    }

    /** 让 Redis 锁的抢占结果固定为给定值。 */
    private void lock(boolean acquired) {
        when(values.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(acquired);
    }

    /** 抢到锁后依次取消与删除，并在结束时释放锁。 */
    @Test
    void cancelsThenDeletesAndReleasesLock() {
        lock(true);

        cleaner.cleanup();

        verify(repository).cancelStaleBefore(any(), any(), anyInt());
        verify(repository).deleteClosedBefore(any(), anyInt());
        verify(redis).delete("kaiwu:todo:cleanup:lock");
    }

    /** 新协议开启时只能走逐键持锁清理，不能调用旧的批量 SQL。 */
    @Test
    void managedProtocolUsesGuardedCleanup() {
        lock(true);
        properties.setManagedProtocolEnabled(true);
        cleaner.cleanup();
        verify(guardedCleanup).cancelBatch(any(), any(), anyInt());
        verify(guardedCleanup).deleteBatch(any(), anyInt());
        verify(repository, never()).cancelStaleBefore(any(), any(), anyInt());
        verify(repository, never()).deleteClosedBefore(any(), anyInt());
    }

    /** 另一个副本持有锁时什么都不做，也不会误删别人的锁。 */
    @Test
    void skipsWhenAnotherInstanceHoldsTheLock() {
        lock(false);

        cleaner.cleanup();

        verify(repository, never()).cancelStaleBefore(any(), any(), anyInt());
        verify(repository, never()).deleteClosedBefore(any(), anyInt());
        verify(redis, never()).delete(anyString());
    }

    /** 关闭开关后完全不执行，连锁都不抢。 */
    @Test
    void doesNothingWhenDisabled() {
        properties.setCleanupEnabled(false);

        cleaner.cleanup();

        verify(values, never()).setIfAbsent(anyString(), anyString(), any(Duration.class));
    }

    /** 单批做满时继续下一批，直到做不满或达到单次总量上限。 */
    @Test
    void keepsGoingWhileBatchesAreFullAndStopsAtTheCap() {
        lock(true);
        properties.setBatchSize(10);
        properties.setMaxRowsPerRun(30);
        // 取消阶段永远返回满批，应在总量达到 30 时停下（共 3 批）；删除阶段一批就做完。
        when(repository.cancelStaleBefore(any(), any(), anyInt())).thenReturn(10);

        cleaner.cleanup();

        verify(repository, times(3)).cancelStaleBefore(any(), any(), anyInt());
        verify(repository, times(1)).deleteClosedBefore(any(), anyInt());
    }

    /** 清理抛异常不外抛（不能影响平台运行），并且仍然释放锁。 */
    @Test
    void swallowsFailuresAndStillReleasesTheLock() {
        lock(true);
        when(repository.cancelStaleBefore(any(), any(), anyInt())).thenThrow(new IllegalStateException("db down"));

        cleaner.cleanup();

        verify(redis).delete("kaiwu:todo:cleanup:lock");
    }
}
