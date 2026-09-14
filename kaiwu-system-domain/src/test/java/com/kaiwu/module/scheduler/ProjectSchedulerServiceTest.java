package com.kaiwu.module.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectCredentialAuthenticationPort;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;
import tools.jackson.databind.ObjectMapper;

class ProjectSchedulerServiceTest {

    private ProjectSchedulerRepository repository;
    private ProjectMembershipPort projectMembership;
    private AuditPort auditService;
    private PasswordEncoder passwordEncoder;
    private ProjectCredentialAuthenticationPort credentials;
    private ProjectSchedulerService service;
    private KaiwuContext actor;

    @BeforeEach
    void setUp() {
        repository = mock(ProjectSchedulerRepository.class);
        projectMembership = mock(ProjectMembershipPort.class);
        auditService = mock(AuditPort.class);
        passwordEncoder = mock(PasswordEncoder.class);
        credentials = mock(ProjectCredentialAuthenticationPort.class);
        service = new ProjectSchedulerService(
                repository, projectMembership, auditService, passwordEncoder, new ObjectMapper(), credentials);
        actor = new KaiwuContext(
                "user-1",
                "session-1",
                null,
                null,
                Set.of("system:scheduler:save"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void projectMemberCanOnlySaveRegisteredHandlerForOwnProject() {
        when(projectMembership.activeMemberExists("project-1", "user-1")).thenReturn(true);
        when(repository.handlerActive("project-1", "order.timeout-close")).thenReturn(true);
        when(repository.saveJob(
                        eq(null),
                        eq("project-1"),
                        any(),
                        eq("order.timeout-close"),
                        eq("0 */5 * * * *"),
                        eq("Asia/Shanghai"),
                        eq("{}"),
                        eq(true)))
                .thenReturn(job("job-1", "project-1", 1L, true));

        SchedulerJobView saved = service.saveJob(
                null,
                new SchedulerJobSaveRequest(
                        "project-1", "超时订单关闭", "order.timeout-close", "0 */5 * * * *", "Asia/Shanghai", "{}", true),
                actor,
                metadata());

        assertThat(saved.id()).isEqualTo("job-1");
        assertThat(saved.projectId()).isEqualTo("project-1");
        verify(auditService)
                .recordOperationInCallerTransaction(
                        eq(actor),
                        eq("scheduler"),
                        eq("CREATE_JOB"),
                        eq("/api/scheduler/jobs"),
                        eq("projectId=project-1,jobId=job-1"),
                        any());
    }

    @Test
    void rejectsHandlerThatWasNotRegisteredByProjectStarter() {
        when(projectMembership.activeMemberExists("project-1", "user-1")).thenReturn(true);
        when(repository.handlerActive("project-1", "arbitrary.class.Name")).thenReturn(false);

        assertThatThrownBy(() -> service.saveJob(
                        null,
                        new SchedulerJobSaveRequest(
                                "project-1", "危险任务", "arbitrary.class.Name", "0 0 1 * * *", "UTC", "{}", true),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("未注册");
        verify(repository, never()).saveJob(any(), any(), any(), any(), any(), any(), any(), anyBoolean());
    }

    @Test
    void existingJobCanBeDisabledWhenAllHandlerInstancesAreOffline() {
        when(projectMembership.activeMemberExists("project-1", "user-1")).thenReturn(true);
        when(repository.findJob("job-1")).thenReturn(Optional.of(job("job-1", "project-1", 2L, true)));
        when(repository.handlerActive("project-1", "order.timeout-close")).thenReturn(false);
        when(repository.saveJob(
                        eq("job-1"),
                        eq("project-1"),
                        any(),
                        eq("order.timeout-close"),
                        eq("0 */5 * * * *"),
                        eq("Asia/Shanghai"),
                        eq("{}"),
                        eq(false)))
                .thenReturn(job("job-1", "project-1", 3L, false));

        SchedulerJobView disabled = service.saveJob(
                "job-1",
                new SchedulerJobSaveRequest(
                        "project-1", "超时订单关闭", "order.timeout-close", "0 */5 * * * *", "Asia/Shanghai", "{}", false),
                actor,
                metadata());

        assertThat(disabled.enabled()).isFalse();
    }

    @Test
    void onlyOneInstanceCanClaimSameJobAndScheduledTime() {
        when(credentials.authenticate("zsch_credential-1_secret"))
                .thenReturn(new ProjectCredentialAuthenticationPort.AuthenticatedProject("credential-1", "project-1"));
        when(repository.findJob("job-1")).thenReturn(Optional.of(job("job-1", "project-1", 3L, true)));
        Instant scheduledAt = Instant.parse("2026-07-29T01:00:00Z");
        when(repository.claimExecution("job-1", "project-1", "instance-a", 3L, scheduledAt))
                .thenReturn(Optional.of("execution-1"));
        when(repository.claimExecution("job-1", "project-1", "instance-b", 3L, scheduledAt))
                .thenReturn(Optional.empty());

        SchedulerClaimView first = service.claim(
                "zsch_credential-1_secret", new SchedulerClaimRequest("job-1", 3L, scheduledAt, "instance-a"));
        SchedulerClaimView second = service.claim(
                "zsch_credential-1_secret", new SchedulerClaimRequest("job-1", 3L, scheduledAt, "instance-b"));

        assertThat(first.acquired()).isTrue();
        assertThat(first.executionId()).isEqualTo("execution-1");
        assertThat(second.acquired()).isFalse();
    }

    @Test
    void credentialCannotClaimJobFromAnotherProject() {
        when(credentials.authenticate("zsch_credential-1_secret"))
                .thenReturn(new ProjectCredentialAuthenticationPort.AuthenticatedProject("credential-1", "project-1"));
        when(repository.findJob("job-2")).thenReturn(Optional.of(job("job-2", "project-2", 1L, true)));

        assertThatThrownBy(() -> service.claim(
                        "zsch_credential-1_secret",
                        new SchedulerClaimRequest("job-2", 1L, Instant.parse("2026-07-29T01:00:00Z"), "instance-a")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("项目");
        verify(repository, never()).claimExecution(any(), any(), any(), anyLong(), any());
    }

    @Test
    void rejectsMalformedJsonPayload() {
        when(projectMembership.activeMemberExists("project-1", "user-1")).thenReturn(true);

        assertThatThrownBy(() -> service.saveJob(
                        null,
                        new SchedulerJobSaveRequest(
                                "project-1", "坏参数任务", "report.daily", "0 0 1 * * *", "UTC", "{broken", true),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("JSON");
        verify(repository, never()).saveJob(any(), any(), any(), any(), any(), any(), any(), anyBoolean());
    }

    @Test
    void credentialCanRenewOnlyItsOwnRunningExecution() {
        when(credentials.authenticate("zsch_credential-1_secret"))
                .thenReturn(new ProjectCredentialAuthenticationPort.AuthenticatedProject("credential-1", "project-1"));
        when(repository.renewExecution("execution-1", "project-1", "instance-a"))
                .thenReturn(true);

        assertThat(service.renew("zsch_credential-1_secret", "execution-1", new SchedulerLeaseRequest("instance-a")))
                .isTrue();
        verify(repository).renewExecution("execution-1", "project-1", "instance-a");
    }

    @Test
    void rejectsOutOfRangePaginationBeforeQueryingDatabase() {
        assertThatThrownBy(() -> service.jobs(null, 0, 101, actor))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("分页");
        verify(repository, never()).jobsForUser(any(), any(), anyLong(), anyLong());
    }

    private static SchedulerJobView job(String id, String projectId, long version, boolean enabled) {
        return new SchedulerJobView(
                id,
                projectId,
                "项目",
                "任务",
                "order.timeout-close",
                "0 */5 * * * *",
                "Asia/Shanghai",
                "{}",
                enabled,
                version,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    private static RequestMetadata metadata() {
        return new RequestMetadata("127.0.0.1", "trace-test");
    }
}
