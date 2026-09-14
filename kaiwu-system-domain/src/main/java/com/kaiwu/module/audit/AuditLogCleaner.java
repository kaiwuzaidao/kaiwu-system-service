package com.kaiwu.module.audit;

import com.kaiwu.module.audit.mapper.AuditWriteMapper;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 按保留期清理登录日志与操作日志。
 *
 * <p>平台自身的运维任务用 Spring 调度即可，不走项目 scheduler：那个平面是给业务项目的，
 * 需要 projectId 与应用凭据，平台把自己塞进去只会绕。
 */
@Component
@EnableScheduling
@EnableConfigurationProperties(AuditRetentionProperties.class)
public class AuditLogCleaner {

    private static final Logger LOGGER = LoggerFactory.getLogger(AuditLogCleaner.class);
    /** 多副本部署时只让一个实例执行，避免并发删除互相锁等待。 */
    private static final String LOCK_KEY = "kaiwu:audit:cleanup:lock";

    private final AuditWriteMapper auditMapper;
    private final StringRedisTemplate redisTemplate;
    private final AuditRetentionProperties properties;
    private final Clock clock;

    public AuditLogCleaner(
            AuditWriteMapper auditMapper,
            StringRedisTemplate redisTemplate,
            AuditRetentionProperties properties,
            Clock clock) {
        this.auditMapper = auditMapper;
        this.redisTemplate = redisTemplate;
        this.properties = properties;
        this.clock = clock;
    }

    /**
     * 按保留期清理登录与操作日志。
     *
     * <p>用 Redis 锁保证多实例只有一个执行；分批删除并受单次总量上限约束，
     * 避免一次删除锁表太久。失败不外抛——清理挂掉不该影响平台运行，下次调度会重试。</p>
     */
    @Scheduled(cron = "${kaiwu.audit.retention.cron:0 30 3 * * *}")
    public void cleanup() {
        if (!properties.isEnabled()) {
            return;
        }
        Boolean acquired = redisTemplate.opsForValue().setIfAbsent(LOCK_KEY, "1", Duration.ofMinutes(30));
        if (!Boolean.TRUE.equals(acquired)) {
            return;
        }
        try {
            LocalDateTime before = LocalDateTime.now(clock).minusDays(properties.getRetainDays());
            int loginRows = deleteInBatches(auditMapper::deleteLoginLogsBefore, before);
            int operationRows = deleteInBatches(auditMapper::deleteOperationLogsBefore, before);
            if (loginRows > 0 || operationRows > 0) {
                LOGGER.info(
                        "审计日志清理完成：保留 {} 天，删除登录日志 {} 行、操作日志 {} 行", properties.getRetainDays(), loginRows, operationRows);
            }
        } catch (Exception exception) {
            // 清理失败不能影响平台运行，下次调度会重试。
            LOGGER.warn("审计日志清理失败：{}", exception.getMessage());
        } finally {
            redisTemplate.delete(LOCK_KEY);
        }
    }

    /**
     * 分批删除到期记录。
     *
     * <p>迁移后表名不再由调用方拼接：两张表各有一条常量 SQL，这里只按方法引用选择其一，
     * 字符串拼 SQL 的口子从此关闭。
     *
     * @return 实际删除行数
     */
    private int deleteInBatches(BatchDelete delete, LocalDateTime before) {
        int total = 0;
        while (total < properties.getMaxRowsPerRun()) {
            int deleted = delete.apply(before, properties.getBatchSize());
            total += deleted;
            if (deleted < properties.getBatchSize()) {
                break;
            }
        }
        return total;
    }

    /** 一次分批删除；两张审计表各对应一个实现。 */
    @FunctionalInterface
    private interface BatchDelete {
        int apply(LocalDateTime before, int batchSize);
    }
}
