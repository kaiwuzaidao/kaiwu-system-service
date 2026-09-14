package com.kaiwu.module.audit;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 审计日志保留策略。
 *
 * <p>登录日志与操作日志每次登录、每次写操作都会落一行，没有清理机制时只增不减，
 * 最终拖慢查询并占满磁盘。
 */
@ConfigurationProperties(prefix = "kaiwu.audit.retention")
public class AuditRetentionProperties {

    /** 是否启用定时清理。 */
    private boolean enabled = true;
    /** 保留天数，超过该天数的记录会被删除。 */
    private int retainDays = 90;
    /**
     * 单批删除行数。
     *
     * <p>两张表的 created_at 都不是索引最左前缀，删除会走全表扫描，因此必须分批，
     * 避免一次长事务把表锁住影响登录与写操作。
     */
    private int batchSize = 1000;
    /** 单次任务最多删除的总行数，防止历史积压时一次跑太久。 */
    private int maxRowsPerRun = 200_000;
    /** 执行时间，默认每天凌晨 3 点半。 */
    private String cron = "0 30 3 * * *";

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public int getRetainDays() {
        return retainDays;
    }

    public void setRetainDays(int retainDays) {
        this.retainDays = retainDays;
    }

    public int getBatchSize() {
        return batchSize;
    }

    public void setBatchSize(int batchSize) {
        this.batchSize = batchSize;
    }

    public int getMaxRowsPerRun() {
        return maxRowsPerRun;
    }

    public void setMaxRowsPerRun(int maxRowsPerRun) {
        this.maxRowsPerRun = maxRowsPerRun;
    }

    public String getCron() {
        return cron;
    }

    public void setCron(String cron) {
        this.cron = cron;
    }
}
