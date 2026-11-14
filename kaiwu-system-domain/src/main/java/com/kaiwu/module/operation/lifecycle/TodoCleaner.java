package com.kaiwu.module.operation.lifecycle;

import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.repository.TodoRepository;
import com.kaiwu.module.operation.service.LegacyTodoCleanupRunner;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.function.IntUnaryOperator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 待办每日清理（ADR 0034）：作为业务服务漏发「关闭」时的兜底，并限制表的增长。
 *
 * <p>先把长期未处理的 OPEN 待办置为 CANCELLED，再物理删除关闭已久的记录。顺序不能反：
 * 刚被取消的待办关闭时间是现在，不会被同一轮删除掉。与审计日志清理一样用 Redis 锁保证多副本只有一个执行，
 * 分批处理并受总量上限约束；失败不外抛，下次调度会重试。
 */
@Component
@EnableConfigurationProperties(TodoProperties.class)
public class TodoCleaner {

    private static final Logger LOGGER = LoggerFactory.getLogger(TodoCleaner.class);
    private static final String LOCK_KEY = "kaiwu:todo:cleanup:lock";

    private final TodoRepository repository;
    private final StringRedisTemplate redisTemplate;
    private final TodoProperties properties;
    private final Clock clock;
    private final LegacyTodoCleanupRunner guardedCleanup;

    /**
     * 创建清理任务。
     *
     * @param repository 待办仓储
     * @param redisTemplate 多副本互斥用的 Redis 模板
     * @param properties 保留策略
     * @param clock 时钟
     */
    public TodoCleaner(
            TodoRepository repository,
            StringRedisTemplate redisTemplate,
            TodoProperties properties,
            Clock clock,
            LegacyTodoCleanupRunner guardedCleanup) {
        this.repository = repository;
        this.redisTemplate = redisTemplate;
        this.properties = properties;
        this.clock = clock;
        this.guardedCleanup = guardedCleanup;
    }

    /**
     * 执行一轮清理：兜底取消长期未处理的待办，再删除关闭已久的记录。
     */
    @Scheduled(cron = "${kaiwu.todo.cleanup-cron:0 0 4 * * *}")
    public void cleanup() {
        if (!properties.isCleanupEnabled()) {
            return;
        }
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(LOCK_KEY, "1", Duration.ofMinutes(30));
        if (!Boolean.TRUE.equals(acquired)) {
            return;
        }
        try {
            LocalDateTime now = LocalDateTime.now(clock);
            LocalDateTime staleBefore = now.minusDays(properties.getStaleDays());
            LocalDateTime closedBefore = now.minusDays(properties.getClosedRetainDays());
            int cancelled = properties.isManagedProtocolEnabled()
                    ? inBatches(batch -> guardedCleanup.cancelBatch(staleBefore, now, batch))
                    : inBatches(batch -> repository.cancelStaleBefore(staleBefore, now, batch));
            int deleted = properties.isManagedProtocolEnabled()
                    ? inBatches(batch -> guardedCleanup.deleteBatch(closedBefore, batch))
                    : inBatches(batch -> repository.deleteClosedBefore(closedBefore, batch));
            if (cancelled > 0 || deleted > 0) {
                LOGGER.info(
                        "待办清理完成：兜底取消 {} 条（超过 {} 天未处理），删除已关闭 {} 条（超过 {} 天）",
                        cancelled,
                        properties.getStaleDays(),
                        deleted,
                        properties.getClosedRetainDays());
            }
        } catch (Exception exception) {
            // 清理失败不能影响平台运行，下次调度会重试。
            LOGGER.warn("待办清理失败：{}", exception.getMessage());
        } finally {
            redisTemplate.delete(LOCK_KEY);
        }
    }

    /** 反复执行一批操作直到做完或达到单次总量上限；单批返回少于批量，说明已处理完。 */
    private int inBatches(IntUnaryOperator operation) {
        int total = 0;
        while (total < properties.getMaxRowsPerRun()) {
            int done = operation.applyAsInt(properties.getBatchSize());
            total += done;
            if (done < properties.getBatchSize()) {
                break;
            }
        }
        return total;
    }
}
