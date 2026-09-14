package com.kaiwu.module.scheduler;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.LongIdGenerator;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectCredentialAuthenticationPort;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.security.SecureRandom;
import java.time.ZoneId;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.support.CronExpression;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;

@Service
public class ProjectSchedulerService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final ProjectSchedulerRepository repository;
    private final ProjectMembershipPort projectMembership;
    private final AuditPort auditService;
    private final PasswordEncoder passwordEncoder;
    private final ObjectMapper objectMapper;
    private final ProjectCredentialAuthenticationPort credentials;

    public ProjectSchedulerService(
            ProjectSchedulerRepository repository,
            ProjectMembershipPort projectMembership,
            AuditPort auditService,
            PasswordEncoder passwordEncoder,
            ObjectMapper objectMapper,
            ProjectCredentialAuthenticationPort credentials) {
        this.repository = repository;
        this.projectMembership = projectMembership;
        this.auditService = auditService;
        this.passwordEncoder = passwordEncoder;
        this.objectMapper = objectMapper;
        this.credentials = credentials;
    }

    /** 当前用户可见的调度任务分页；只返回其为 ACTIVE 成员的项目下的任务。 */
    public PageResult<SchedulerJobView> jobs(String projectId, long current, long size, KaiwuContext actor) {
        validatePage(current, size);
        if (projectId != null) {
            requireMember(projectId, actor.userId());
        }
        return repository.jobsForUser(actor.userId(), projectId, current, size);
    }

    /**
     * 新建或编辑调度任务；{@code id} 为空表示新建。
     *
     * <p>编辑会递增 {@code config_version}，让正在执行的旧配置失效——否则一次改动要等
     * 当前执行跑完才生效，期间新旧配置并存。</p>
     */
    @Transactional
    public SchedulerJobView saveJob(
            String id, SchedulerJobSaveRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireMember(request.projectId(), actor.userId());
        validateSchedule(request);
        SchedulerJobView existing = null;
        if (id != null) {
            existing = requireJob(id);
            if (!existing.projectId().equals(request.projectId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "不能跨项目修改定时任务", "api.common.badRequest");
            }
        }
        String taskType = request.taskType().trim();
        boolean handlerRequired =
                existing == null || !existing.taskType().equals(taskType) || (!existing.enabled() && request.enabled());
        if (handlerRequired && !repository.handlerActive(request.projectId(), taskType)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目未注册该定时任务 Handler，或所有实例已离线", "api.common.badRequest");
        }
        SchedulerJobView saved = repository.saveJob(
                id,
                request.projectId(),
                request.jobName().trim(),
                taskType,
                request.cronExpression().trim(),
                request.zoneId().trim(),
                normalizePayload(request.payload()),
                request.enabled());
        auditService.recordOperationInCallerTransaction(
                actor,
                "scheduler",
                id == null ? "CREATE_JOB" : "UPDATE_JOB",
                id == null ? "/api/scheduler/jobs" : "/api/scheduler/jobs/" + id,
                "projectId=" + saved.projectId() + ",jobId=" + saved.id(),
                metadata);
        return saved;
    }

    /** 逻辑删除调度任务：同时置 deleted 与 enabled=0，避免删除后仍被调度器捞起。 */
    @Transactional
    public void deleteJob(String id, KaiwuContext actor, RequestMetadata metadata) {
        SchedulerJobView job = requireJob(id);
        requireMember(job.projectId(), actor.userId());
        repository.deleteJob(id, job.projectId());
        auditService.recordOperationInCallerTransaction(
                actor,
                "scheduler",
                "DELETE_JOB",
                "/api/scheduler/jobs/" + id,
                "projectId=" + job.projectId() + ",jobId=" + id,
                metadata);
    }

    public List<SchedulerHandlerView> handlers(String projectId, KaiwuContext actor) {
        requireMember(projectId, actor.userId());
        return repository.handlers(projectId);
    }

    /** 执行记录分页；同样按项目成员身份过滤，可再按项目或任务收窄。 */
    public PageResult<SchedulerExecutionView> executions(
            String projectId, String jobId, long current, long size, KaiwuContext actor) {
        validatePage(current, size);
        if (projectId != null) {
            requireMember(projectId, actor.userId());
        }
        if (jobId != null) {
            SchedulerJobView job = requireJob(jobId);
            requireMember(job.projectId(), actor.userId());
            if (projectId != null && !projectId.equals(job.projectId())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "执行记录任务与筛选项目不一致", "api.common.badRequest");
            }
        }
        return repository.executionsForUser(actor.userId(), projectId, jobId, current, size);
    }

    /**
     * 轮换项目调度凭据：撤销该项目现有 ACTIVE 凭据，再签发一枚新的。
     *
     * <p>明文只在本次响应里返回一次，库里只存哈希——调用方没记下来就只能再轮换一次。</p>
     */
    @Transactional
    public SchedulerCredentialView rotateCredential(String projectId, KaiwuContext actor, RequestMetadata metadata) {
        requireMember(projectId, actor.userId());
        String credentialId = LongIdGenerator.nextId();
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String secret = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        String token = "zsch_" + credentialId + "_" + secret;
        repository.replaceCredential(credentialId, projectId, passwordEncoder.encode(token));
        auditService.recordOperationInCallerTransaction(
                actor,
                "scheduler",
                "ROTATE_CREDENTIAL",
                "/api/scheduler/projects/" + projectId + "/credential/rotate",
                "projectId=" + projectId + ",credentialId=" + credentialId,
                metadata);
        return new SchedulerCredentialView(credentialId, projectId, token);
    }

    /**
     * 业务服务启动时上报自己能处理的任务类型，并取回该项目当前启用的任务列表。
     *
     * <p>上报同时刷新心跳；五分钟内没有心跳的处理器视为离线，其任务不再被派发。</p>
     */
    @Transactional
    public List<SchedulerJobView> synchronize(String token, SchedulerSyncRequest request) {
        ProjectCredentialAuthenticationPort.AuthenticatedProject credential = authenticate(token);
        repository.synchronizeHandlers(credential.projectId(), request.instanceId(), request.handlers());
        return repository.enabledJobs(credential.projectId());
    }

    /**
     * 抢占一次调度执行。
     *
     * <p>同一个 {@code (jobId, scheduledAt)} 只会有一个实例抢到；没抢到不是错误，
     * 返回体里以未获授权表示，调用方跳过本次即可。</p>
     */
    @Transactional
    public SchedulerClaimView claim(String token, SchedulerClaimRequest request) {
        ProjectCredentialAuthenticationPort.AuthenticatedProject credential = authenticate(token);
        SchedulerJobView job = requireJob(request.jobId());
        if (!credential.projectId().equals(job.projectId())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "凭据项目与定时任务项目不一致", "api.common.forbidden");
        }
        if (!job.enabled()) {
            throw new ApiException(HttpStatus.CONFLICT, "定时任务已停用", "api.common.conflict");
        }
        if (job.configVersion() != request.configVersion()) {
            throw new ApiException(HttpStatus.CONFLICT, "定时任务配置版本已变化", "api.common.conflict");
        }
        return repository
                .claimExecution(
                        job.id(), job.projectId(), request.instanceId(), request.configVersion(), request.scheduledAt())
                .map(SchedulerClaimView::acquired)
                .orElseGet(SchedulerClaimView::rejected);
    }

    /**
     * 回报执行结果。
     *
     * <p>只有持有该执行租约的实例能回报（校验 instanceId），防止晚到的旧实例把
     * 别人的成功覆盖成失败。</p>
     */
    @Transactional
    public void complete(String token, String executionId, SchedulerCompletionRequest request) {
        ProjectCredentialAuthenticationPort.AuthenticatedProject credential = authenticate(token);
        String status = request.status().trim().toUpperCase(Locale.ROOT);
        if (!List.of("SUCCESS", "FAILED").contains(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "执行状态只允许 SUCCESS 或 FAILED", "api.common.badRequest");
        }
        boolean updated = repository.completeExecution(
                executionId, credential.projectId(), request.instanceId(), status, safeMessage(request.message()));
        if (!updated) {
            throw new ApiException(HttpStatus.CONFLICT, "执行记录不存在、已完成或不属于当前实例", "api.common.conflict");
        }
    }

    @Transactional
    public boolean renew(String token, String executionId, SchedulerLeaseRequest request) {
        ProjectCredentialAuthenticationPort.AuthenticatedProject credential = authenticate(token);
        return repository.renewExecution(executionId, credential.projectId(), request.instanceId());
    }

    /**
     * 凭据校验统一委托给项目凭据 Port：凭据是项目级的，调度与配置
     * 拉取共用同一套，安全校验只保留一份实现。
     */
    private ProjectCredentialAuthenticationPort.AuthenticatedProject authenticate(String token) {
        return credentials.authenticate(token);
    }

    private SchedulerJobView requireJob(String id) {
        return repository
                .findJob(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "定时任务不存在", "api.common.notFound"));
    }

    private void requireMember(String projectId, String userId) {
        if (!projectMembership.activeMemberExists(projectId, userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "不是该项目的有效成员", "api.common.forbidden");
        }
    }

    private void validateSchedule(SchedulerJobSaveRequest request) {
        try {
            CronExpression.parse(request.cronExpression().trim());
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Cron 表达式不合法", "api.common.badRequest");
        }
        try {
            ZoneId.of(request.zoneId().trim());
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "时区不合法", "api.common.badRequest");
        }
        if (request.payload() != null && request.payload().length() > 10_000) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "任务参数不能超过 10000 字符", "api.common.badRequest");
        }
        String payload = normalizePayload(request.payload());
        try {
            if (!objectMapper.readTree(payload).isObject()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "任务参数必须是 JSON 对象", "api.common.badRequest");
            }
        } catch (ApiException exception) {
            throw exception;
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "任务参数必须是合法 JSON 对象", "api.common.badRequest");
        }
    }

    private static String normalizePayload(String payload) {
        return payload == null || payload.isBlank() ? "{}" : payload.trim();
    }

    private static String safeMessage(String message) {
        if (message == null || message.isBlank()) {
            return null;
        }
        return message.length() <= 1000 ? message : message.substring(0, 1000);
    }

    private static void validatePage(long current, long size) {
        PageBounds.require(current, size);
    }
}
