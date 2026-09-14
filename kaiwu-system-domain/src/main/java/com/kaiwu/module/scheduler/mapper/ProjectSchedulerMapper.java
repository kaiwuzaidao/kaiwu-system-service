package com.kaiwu.module.scheduler.mapper;

import com.kaiwu.module.scheduler.entity.SchedulerCredentialRow;
import com.kaiwu.module.scheduler.entity.SchedulerExecutionJoinRow;
import com.kaiwu.module.scheduler.entity.SchedulerHandlerRow;
import com.kaiwu.module.scheduler.entity.SchedulerJobJoinRow;
import java.time.LocalDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 项目调度 Mapper。
 *
 * <p>**全部为注解 SQL，这是本次迁移里最不该动的一个仓储。** 它实现的是基于租约的分布式
 * 抢占：唯一键冲突表示别人已抢到，{@code lease_until &lt; CURRENT_TIMESTAMP} 表示租约过期
 * 可以接管，更新影响行数即抢占结果。任何一处改写都可能让同一个任务被两个实例同时执行。</p>
 *
 * <p>异常语义同样依赖底层：{@code DuplicateKeyException} 与 {@code CannotAcquireLockException}
 * 由 Spring 的 SQL 异常翻译产生，MyBatis 走的是同一套翻译器，因此调用方的 catch 分支
 * 迁移后继续成立。</p>
 */
@Mapper
public interface ProjectSchedulerMapper {

    /** 处理器五分钟内有心跳才算在线。 */
    @Select(
            """
            SELECT COUNT(*) FROM sys_scheduler_handler
            WHERE project_id = #{projectId} AND task_type = #{taskType}
              AND last_seen_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE)
            """)
    Long countActiveHandler(@Param("projectId") String projectId, @Param("taskType") String taskType);

    @Insert(
            """
            INSERT INTO sys_scheduler_job
                (id, project_id, job_name, task_type, cron_expression, zone_id,
                 request_payload, enabled, config_version, created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{jobName}, #{taskType}, #{cronExpression}, #{zoneId},
                    #{payload}, #{enabled}, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertJob(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("jobName") String jobName,
            @Param("taskType") String taskType,
            @Param("cronExpression") String cronExpression,
            @Param("zoneId") String zoneId,
            @Param("payload") String payload,
            @Param("enabled") boolean enabled);

    /** 编辑任务；{@code config_version + 1} 让正在执行的旧配置失效。 */
    @Update(
            """
            UPDATE sys_scheduler_job
            SET job_name = #{jobName}, task_type = #{taskType},
                cron_expression = #{cronExpression}, zone_id = #{zoneId},
                request_payload = #{payload}, enabled = #{enabled},
                config_version = config_version + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id} AND project_id = #{projectId}
            """)
    int updateJob(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("jobName") String jobName,
            @Param("taskType") String taskType,
            @Param("cronExpression") String cronExpression,
            @Param("zoneId") String zoneId,
            @Param("payload") String payload,
            @Param("enabled") boolean enabled);

    @Select(
            """
            SELECT j.id, j.project_id, p.project_name, j.job_name, j.task_type,
                   j.cron_expression, j.zone_id, j.request_payload, j.enabled,
                   j.config_version, j.last_run_time, j.next_run_time,
                   j.created_at, j.updated_at
            FROM sys_scheduler_job j
            JOIN sys_project p ON p.id = j.project_id
            WHERE j.id = #{id} AND j.deleted = 0
            """)
    SchedulerJobJoinRow findJob(@Param("id") String id);

    @Select(
            """
            SELECT j.id, j.project_id, p.project_name, j.job_name, j.task_type,
                   j.cron_expression, j.zone_id, j.request_payload, j.enabled,
                   j.config_version, j.last_run_time, j.next_run_time,
                   j.created_at, j.updated_at
            FROM sys_scheduler_job j
            JOIN sys_project p ON p.id = j.project_id
            WHERE j.project_id = #{projectId} AND j.enabled = 1 AND j.deleted = 0
            ORDER BY j.created_at, j.id
            """)
    List<SchedulerJobJoinRow> enabledJobs(@Param("projectId") String projectId);

    @Select(
            """
            SELECT COUNT(*)
            FROM sys_scheduler_job j
            JOIN sys_project_member m ON m.project_id = j.project_id
            WHERE m.user_id = #{userId} AND m.status = 'ACTIVE' AND j.deleted = 0
              AND (#{projectId} IS NULL OR j.project_id = #{projectId})
            """)
    Long countJobsForUser(@Param("userId") String userId, @Param("projectId") String projectId);

    @Select(
            """
            SELECT j.id, j.project_id, p.project_name, j.job_name, j.task_type,
                   j.cron_expression, j.zone_id, j.request_payload, j.enabled,
                   j.config_version, j.last_run_time, j.next_run_time,
                   j.created_at, j.updated_at
            FROM sys_scheduler_job j
            JOIN sys_project p ON p.id = j.project_id
            JOIN sys_project_member m ON m.project_id = j.project_id
            WHERE m.user_id = #{userId} AND m.status = 'ACTIVE' AND j.deleted = 0
              AND (#{projectId} IS NULL OR j.project_id = #{projectId})
            ORDER BY j.updated_at DESC
            LIMIT #{size} OFFSET #{offset}
            """)
    List<SchedulerJobJoinRow> jobsForUser(
            @Param("userId") String userId,
            @Param("projectId") String projectId,
            @Param("size") long size,
            @Param("offset") long offset);

    /** 逻辑删除：同时停用，避免删除后仍被调度。 */
    @Update(
            """
            UPDATE sys_scheduler_job
            SET enabled = 0, deleted = 1,
                config_version = config_version + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id} AND project_id = #{projectId}
            """)
    int deleteJob(@Param("id") String id, @Param("projectId") String projectId);

    @Insert(
            """
            INSERT INTO sys_scheduler_handler
                (project_id, task_type, task_name, instance_id, last_seen_at,
                 created_at, updated_at)
            VALUES (#{projectId}, #{taskType}, #{taskName}, #{instanceId},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                task_name = VALUES(task_name), instance_id = VALUES(instance_id),
                last_seen_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            """)
    int upsertHandler(
            @Param("projectId") String projectId,
            @Param("taskType") String taskType,
            @Param("taskName") String taskName,
            @Param("instanceId") String instanceId);

    @Select(
            """
            SELECT project_id, task_type, task_name, last_seen_at
            FROM sys_scheduler_handler
            WHERE project_id = #{projectId}
              AND last_seen_at >= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE)
            ORDER BY task_type
            """)
    List<SchedulerHandlerRow> handlers(@Param("projectId") String projectId);

    @Select(
            """
            SELECT credential.id, credential.project_id,
                   credential.token_hash, credential.status
            FROM sys_scheduler_credential credential
            JOIN sys_project project ON project.id = credential.project_id
            WHERE credential.id = #{credentialId} AND project.status = 'ACTIVE'
            """)
    SchedulerCredentialRow findCredential(@Param("credentialId") String credentialId);

    @Update(
            """
            UPDATE sys_scheduler_credential
            SET status = 'REVOKED', updated_at = CURRENT_TIMESTAMP
            WHERE project_id = #{projectId} AND status = 'ACTIVE'
            """)
    int revokeCredentials(@Param("projectId") String projectId);

    @Insert(
            """
            INSERT INTO sys_scheduler_credential
                (id, project_id, token_hash, status, created_at, updated_at)
            VALUES (#{credentialId}, #{projectId}, #{tokenHash}, 'ACTIVE',
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertCredential(
            @Param("credentialId") String credentialId,
            @Param("projectId") String projectId,
            @Param("tokenHash") String tokenHash);

    /**
     * 抢占一次执行；唯一键 {@code (job_id, scheduled_at)} 冲突即表示别人已抢到，
     * 由调用方 catch {@code DuplicateKeyException} 后走接管分支。
     */
    @Insert(
            """
            INSERT INTO sys_scheduler_execution
                (id, job_id, project_id, config_version, scheduled_at,
                 instance_id, status, lease_until, started_at, created_at, updated_at)
            VALUES (#{executionId}, #{jobId}, #{projectId}, #{configVersion}, #{scheduledAt},
                    #{instanceId}, 'RUNNING',
                    DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE),
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertExecution(
            @Param("executionId") String executionId,
            @Param("jobId") String jobId,
            @Param("projectId") String projectId,
            @Param("configVersion") long configVersion,
            @Param("scheduledAt") LocalDateTime scheduledAt,
            @Param("instanceId") String instanceId);

    /** 接管租约已过期的执行；影响 0 行表示租约仍有效，本次没抢到。 */
    @Update(
            """
            UPDATE sys_scheduler_execution
            SET instance_id = #{instanceId}, config_version = #{configVersion},
                status = 'RUNNING',
                lease_until = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE),
                started_at = CURRENT_TIMESTAMP, completed_at = NULL,
                message = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE job_id = #{jobId} AND scheduled_at = #{scheduledAt}
              AND status = 'RUNNING' AND lease_until < CURRENT_TIMESTAMP
            """)
    int takeOverExpiredExecution(
            @Param("jobId") String jobId,
            @Param("scheduledAt") LocalDateTime scheduledAt,
            @Param("instanceId") String instanceId,
            @Param("configVersion") long configVersion);

    @Select(
            """
            SELECT id FROM sys_scheduler_execution
            WHERE job_id = #{jobId} AND scheduled_at = #{scheduledAt}
            """)
    String findExecutionId(@Param("jobId") String jobId, @Param("scheduledAt") LocalDateTime scheduledAt);

    @Update(
            """
            UPDATE sys_scheduler_execution
            SET lease_until = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{executionId} AND project_id = #{projectId}
              AND instance_id = #{instanceId} AND status = 'RUNNING'
            """)
    int renewExecution(
            @Param("executionId") String executionId,
            @Param("projectId") String projectId,
            @Param("instanceId") String instanceId);

    @Update(
            """
            UPDATE sys_scheduler_execution
            SET status = #{status}, message = #{message}, completed_at = CURRENT_TIMESTAMP,
                lease_until = NULL, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{executionId} AND project_id = #{projectId}
              AND instance_id = #{instanceId} AND status = 'RUNNING'
            """)
    int completeExecution(
            @Param("executionId") String executionId,
            @Param("projectId") String projectId,
            @Param("instanceId") String instanceId,
            @Param("status") String status,
            @Param("message") String message);

    /**
     * 回写任务的最近执行时间。
     *
     * <p>{@code j.updated_at = j.updated_at} 是有意为之：回写运行时间不该改变配置更新时间，
     * 否则列表页会因为一次例行调度就把任务排到最前。</p>
     */
    @Update(
            """
            UPDATE sys_scheduler_job j
            JOIN sys_scheduler_execution e ON e.job_id = j.id
            SET j.last_run_time = e.completed_at,
                j.updated_at = j.updated_at
            WHERE e.id = #{executionId}
            """)
    int touchJobLastRun(@Param("executionId") String executionId);

    @Select(
            """
            SELECT COUNT(*)
            FROM sys_scheduler_execution e
            JOIN sys_project_member m ON m.project_id = e.project_id
            WHERE m.user_id = #{userId} AND m.status = 'ACTIVE'
              AND (#{projectId} IS NULL OR e.project_id = #{projectId})
              AND (#{jobId} IS NULL OR e.job_id = #{jobId})
            """)
    Long countExecutionsForUser(
            @Param("userId") String userId, @Param("projectId") String projectId, @Param("jobId") String jobId);

    @Select(
            """
            SELECT e.id, e.job_id, j.job_name, e.project_id, p.project_name,
                   e.scheduled_at, e.instance_id, e.status, e.message,
                   e.started_at, e.completed_at
            FROM sys_scheduler_execution e
            JOIN sys_scheduler_job j ON j.id = e.job_id
            JOIN sys_project p ON p.id = e.project_id
            JOIN sys_project_member m ON m.project_id = e.project_id
            WHERE m.user_id = #{userId} AND m.status = 'ACTIVE'
              AND (#{projectId} IS NULL OR e.project_id = #{projectId})
              AND (#{jobId} IS NULL OR e.job_id = #{jobId})
            ORDER BY e.created_at DESC
            LIMIT #{size} OFFSET #{offset}
            """)
    List<SchedulerExecutionJoinRow> executionsForUser(
            @Param("userId") String userId,
            @Param("projectId") String projectId,
            @Param("jobId") String jobId,
            @Param("size") long size,
            @Param("offset") long offset);
}
