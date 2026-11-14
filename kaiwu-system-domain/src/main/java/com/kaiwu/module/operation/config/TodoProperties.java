package com.kaiwu.module.operation.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 统一待办的容量与清理配置（ADR 0034）。
 *
 * <p>旧投递保留站内信的 {@code kaiwu.notification.delivery-token}；受管协议只接受C5的todo:managed凭据。
 */
@ConfigurationProperties(prefix = "kaiwu.todo")
public class TodoProperties {

    /** 单个项目、单个收件人同时处于 OPEN 的待办上限，超出时拒绝打开新的待办，防止业务服务灌入。 */
    private int maxOpenPerRecipient = 500;

    /** 新旧写入共享锁协议；迁移和全副本升级核对之前必须保持关闭。 */
    private boolean managedProtocolEnabled = false;

    /** 读取共享待办协议开关。 */
    public boolean isManagedProtocolEnabled() {
        return managedProtocolEnabled;
    }

    /** 仅在受控停写、回填和全副本升级完成后启用。 */
    public void setManagedProtocolEnabled(boolean enabled) {
        this.managedProtocolEnabled = enabled;
    }

    /** 是否启用每日清理。 */
    private boolean cleanupEnabled = true;

    /** OPEN 待办超期多少天后被兜底取消：旧记录按dueAt/更新时间，受管记录仅按UTC lastSeenAt判断。 */
    private int staleDays = 90;

    /** 已关闭（DONE / CANCELLED）的待办保留多少天后物理删除。 */
    private int closedRetainDays = 180;

    /** 单批处理行数；相关条件不是索引最左前缀，必须分批以免长事务。 */
    private int batchSize = 500;

    /** 单次任务每类操作最多处理的总行数，防止历史积压时一次跑太久。 */
    private int maxRowsPerRun = 50_000;

    /** 清理的执行时间，默认每天凌晨 4 点。 */
    private String cleanupCron = "0 0 4 * * *";

    /**
     * 读取单个收件人的 OPEN 待办上限。
     *
     * @return 上限
     */
    public int getMaxOpenPerRecipient() {
        return maxOpenPerRecipient;
    }

    /**
     * 设置单个收件人的 OPEN 待办上限。
     *
     * @param maxOpenPerRecipient 上限
     */
    public void setMaxOpenPerRecipient(int maxOpenPerRecipient) {
        this.maxOpenPerRecipient = maxOpenPerRecipient;
    }

    /**
     * 读取是否启用每日清理。
     *
     * @return 是否启用
     */
    public boolean isCleanupEnabled() {
        return cleanupEnabled;
    }

    /**
     * 设置是否启用每日清理。
     *
     * @param cleanupEnabled 是否启用
     */
    public void setCleanupEnabled(boolean cleanupEnabled) {
        this.cleanupEnabled = cleanupEnabled;
    }

    /**
     * 读取 OPEN 待办的兜底取消天数。
     *
     * @return 天数
     */
    public int getStaleDays() {
        return staleDays;
    }

    /**
     * 设置 OPEN 待办的兜底取消天数。
     *
     * @param staleDays 天数
     */
    public void setStaleDays(int staleDays) {
        this.staleDays = staleDays;
    }

    /**
     * 读取已关闭待办的保留天数。
     *
     * @return 天数
     */
    public int getClosedRetainDays() {
        return closedRetainDays;
    }

    /**
     * 设置已关闭待办的保留天数。
     *
     * @param closedRetainDays 天数
     */
    public void setClosedRetainDays(int closedRetainDays) {
        this.closedRetainDays = closedRetainDays;
    }

    /**
     * 读取单批处理行数。
     *
     * @return 行数
     */
    public int getBatchSize() {
        return batchSize;
    }

    /**
     * 设置单批处理行数。
     *
     * @param batchSize 行数
     */
    public void setBatchSize(int batchSize) {
        this.batchSize = batchSize;
    }

    /**
     * 读取单次任务每类操作的总行数上限。
     *
     * @return 行数
     */
    public int getMaxRowsPerRun() {
        return maxRowsPerRun;
    }

    /**
     * 设置单次任务每类操作的总行数上限。
     *
     * @param maxRowsPerRun 行数
     */
    public void setMaxRowsPerRun(int maxRowsPerRun) {
        this.maxRowsPerRun = maxRowsPerRun;
    }

    /**
     * 读取清理的 cron 表达式。
     *
     * @return cron 表达式
     */
    public String getCleanupCron() {
        return cleanupCron;
    }

    /**
     * 设置清理的 cron 表达式。
     *
     * @param cleanupCron cron 表达式
     */
    public void setCleanupCron(String cleanupCron) {
        this.cleanupCron = cleanupCron;
    }
}
