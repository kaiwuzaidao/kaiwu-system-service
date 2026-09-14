package com.kaiwu.module.scheduler;

import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.scheduler.entity.SchedulerExecutionJoinRow;
import com.kaiwu.module.scheduler.entity.SchedulerJobJoinRow;
import com.kaiwu.module.scheduler.mapper.ProjectSchedulerMapper;
import com.kaiwu.port.ProjectCredentialStorePort;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Repository;

@Repository
public class ProjectSchedulerRepository implements ProjectCredentialStorePort {

    private final ProjectSchedulerMapper mapper;

    public ProjectSchedulerRepository(ProjectSchedulerMapper mapper) {
        this.mapper = mapper;
    }

    public boolean handlerActive(String projectId, String taskType) {
        Long count = mapper.countActiveHandler(projectId, taskType);
        return count != null && count > 0;
    }

    /**
     * 新建或编辑调度任务；{@code id} 为 null 表示新建，此时由本方法生成 ID。
     *
     * @return 写入后重新查出的任务视图，保证返回值与库中一致
     */
    public SchedulerJobView saveJob(
            String id,
            String projectId,
            String jobName,
            String taskType,
            String cronExpression,
            String zoneId,
            String payload,
            boolean enabled) {
        if (id == null) {
            id = LongIdGenerator.nextId();
            mapper.insertJob(id, projectId, jobName, taskType, cronExpression, zoneId, payload, enabled);
        } else {
            mapper.updateJob(id, projectId, jobName, taskType, cronExpression, zoneId, payload, enabled);
        }
        return findJob(id).orElseThrow();
    }

    public Optional<SchedulerJobView> findJob(String id) {
        return Optional.ofNullable(mapper.findJob(id)).map(ProjectSchedulerRepository::toJob);
    }

    public List<SchedulerJobView> enabledJobs(String projectId) {
        return mapper.enabledJobs(projectId).stream()
                .map(ProjectSchedulerRepository::toJob)
                .toList();
    }

    /** 按用户可见范围分页查任务：只包含其为 ACTIVE 成员的项目，已逻辑删除的不计。 */
    public PageResult<SchedulerJobView> jobsForUser(String userId, String projectId, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        Long total = mapper.countJobsForUser(userId, projectId);
        List<SchedulerJobView> rows = mapper.jobsForUser(userId, projectId, size, (current - 1) * size).stream()
                .map(ProjectSchedulerRepository::toJob)
                .toList();
        return new PageResult<>(current, size, total == null ? 0 : total, rows);
    }

    public void deleteJob(String id, String projectId) {
        mapper.deleteJob(id, projectId);
    }

    public void synchronizeHandlers(String projectId, String instanceId, List<SchedulerHandlerRegistration> handlers) {
        for (SchedulerHandlerRegistration handler : handlers) {
            mapper.upsertHandler(projectId, handler.taskType(), handler.taskName(), instanceId);
        }
    }

    /** 该项目当前在线的任务处理器；五分钟内有心跳才算在线。 */
    public List<SchedulerHandlerView> handlers(String projectId) {
        return mapper.handlers(projectId).stream()
                .map(row -> new SchedulerHandlerView(
                        row.getProjectId(), row.getTaskType(), row.getTaskName(), row.getLastSeenAt()))
                .toList();
    }

    @Override
    public Optional<StoredCredential> findActive(String credentialId) {
        return Optional.ofNullable(mapper.findCredential(credentialId))
                .filter(row -> "ACTIVE".equals(row.getStatus()))
                .map(row -> new StoredCredential(row.getId(), row.getProjectId(), row.getTokenHash()));
    }

    public void replaceCredential(String credentialId, String projectId, String tokenHash) {
        mapper.revokeCredentials(projectId);
        mapper.insertCredential(credentialId, projectId, tokenHash);
    }

    /**
     * 抢占一次调度执行。
     *
     * <p>协议是：先按唯一键 {@code (job_id, scheduled_at)} 插入，插进去就是抢到；
     * 唯一键冲突说明别人已经抢过，此时只有在对方租约过期的情况下才允许接管。
     * 三条分支的返回值语义必须一致——都表示"本实例是否应当执行这一次"。</p>
     */
    public Optional<String> claimExecution(
            String jobId, String projectId, String instanceId, long configVersion, Instant scheduledAt) {
        String executionId = LongIdGenerator.nextId();
        LocalDateTime scheduledAtLocal = toLocal(scheduledAt);
        try {
            mapper.insertExecution(executionId, jobId, projectId, configVersion, scheduledAtLocal, instanceId);
            return Optional.of(executionId);
        } catch (DuplicateKeyException duplicate) {
            int recovered;
            try {
                recovered = mapper.takeOverExpiredExecution(jobId, scheduledAtLocal, instanceId, configVersion);
            } catch (CannotAcquireLockException concurrentTakeover) {
                // 两个恢复者会先在唯一键插入上竞争，再同时尝试接管同一过期行。
                // MySQL 可能选择其中一个事务作为 deadlock victim；对调度协议而言，
                // victim 与普通“未抢到”完全等价，不能向 Starter 暴露为 500。
                return Optional.empty();
            }
            if (recovered == 0) {
                return Optional.empty();
            }
            return Optional.ofNullable(mapper.findExecutionId(jobId, scheduledAtLocal));
        }
    }

    public boolean renewExecution(String executionId, String projectId, String instanceId) {
        return mapper.renewExecution(executionId, projectId, instanceId) == 1;
    }

    /**
     * 回报执行结果并回写任务的最近运行时间。
     *
     * @return 是否回报成功；false 表示租约已不属于该实例（超时被别人接管）
     */
    public boolean completeExecution(
            String executionId, String projectId, String instanceId, String status, String message) {
        int updated = mapper.completeExecution(executionId, projectId, instanceId, status, message);
        if (updated == 1) {
            mapper.touchJobLastRun(executionId);
        }
        return updated == 1;
    }

    /** 按用户可见范围分页查执行记录；可再按项目或任务收窄。 */
    public PageResult<SchedulerExecutionView> executionsForUser(
            String userId, String projectId, String jobId, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        Long total = mapper.countExecutionsForUser(userId, projectId, jobId);
        List<SchedulerExecutionView> rows =
                mapper.executionsForUser(userId, projectId, jobId, size, (current - 1) * size).stream()
                        .map(ProjectSchedulerRepository::toExecution)
                        .toList();
        return new PageResult<>(current, size, total == null ? 0 : total, rows);
    }

    private static SchedulerJobView toJob(SchedulerJobJoinRow row) {
        return new SchedulerJobView(
                row.getId(),
                row.getProjectId(),
                row.getProjectName(),
                row.getJobName(),
                row.getTaskType(),
                row.getCronExpression(),
                row.getZoneId(),
                row.getRequestPayload(),
                Boolean.TRUE.equals(row.getEnabled()),
                row.getConfigVersion() == null ? 0 : row.getConfigVersion(),
                row.getLastRunTime(),
                row.getNextRunTime(),
                row.getCreatedAt(),
                row.getUpdatedAt());
    }

    private static SchedulerExecutionView toExecution(SchedulerExecutionJoinRow row) {
        return new SchedulerExecutionView(
                row.getId(),
                row.getJobId(),
                row.getJobName(),
                row.getProjectId(),
                row.getProjectName(),
                toInstant(row.getScheduledAt()),
                row.getInstanceId(),
                row.getStatus(),
                row.getMessage(),
                row.getStartedAt(),
                row.getCompletedAt());
    }

    /**
     * {@code scheduled_at} 在库里是无时区的 DATETIME。
     *
     * <p>迁移前由 {@code Timestamp.from(instant)} / {@code Timestamp.toInstant()} 按系统
     * 默认时区转换，这里显式保持同一语义——调度时刻是唯一键的一部分，转换若有偏移，
     * 同一次调度会被认成两次。</p>
     */
    private static LocalDateTime toLocal(Instant instant) {
        return LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
    }

    private static Instant toInstant(LocalDateTime value) {
        return value == null ? null : value.atZone(ZoneId.systemDefault()).toInstant();
    }
}
