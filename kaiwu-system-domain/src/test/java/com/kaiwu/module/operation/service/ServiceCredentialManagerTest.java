package com.kaiwu.module.operation.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.security.crypto.password.PasswordEncoder;

/** 验证服务凭据签发的范围和兼容性守卫。 */
class ServiceCredentialManagerTest {
    /** 有效范围首次签发，轮换范围不可变，明文不进入审计。 */
    @Test
    void issuesOnlyWhenEnabledAndScopeIsUnchanged() {
        var repo = mock(ProjectSchedulerRepository.class);
        var membership = mock(ProjectMembershipPort.class);
        var audit = mock(AuditPort.class);
        var encoder = mock(PasswordEncoder.class);
        var actor = mock(KaiwuContext.class);
        var metadata = mock(RequestMetadata.class);
        when(actor.userId()).thenReturn("u1");
        when(membership.activeMemberExists("p1", "u1")).thenReturn(true);
        when(repo.lockCredentialProject("p1")).thenReturn(true);
        when(encoder.encode(anyString())).thenReturn("hash");
        var manager = new ServiceCredentialManager(repo, membership, audit, encoder, true, 86400);
        Instant expiry = Instant.now().plusSeconds(172800);
        var issued = manager.issue("p1", "workflow", Set.of("member:read"), expiry, actor, metadata);
        assertThat(issued.token()).startsWith("zsch_");
        assertThat(issued.toString()).doesNotContain(issued.token());
        verify(repo)
                .insertScopedCredential(
                        anyString(), eq("p1"), eq("hash"), eq("workflow"), any(), eq(Set.of("member:read")));
        verify(audit)
                .recordOperationInCallerTransaction(
                        eq(actor),
                        eq("project"),
                        eq("ISSUE_SERVICE_CREDENTIAL"),
                        anyString(),
                        argThat(detail -> !detail.contains(issued.token())),
                        eq(metadata));
        when(repo.activeServiceCredentials("p1", "workflow"))
                .thenReturn(List.of(new ProjectSchedulerRepository.ScopedCredential("a", Set.of("todo:managed"))));
        assertThatThrownBy(() -> manager.issue("p1", "workflow", Set.of("member:read"), expiry, actor, metadata))
                .isInstanceOf(ApiException.class);
        var disabled = new ServiceCredentialManager(repo, membership, audit, encoder, false, 86400);
        assertThatThrownBy(() -> disabled.issue("p1", "workflow", Set.of("member:read"), expiry, actor, metadata))
                .isInstanceOf(ApiException.class);
    }
    /** 不显式配置开关的真实Spring装配必须拒绝签发，不能因默认值或版本混部静默开启。 */
    @Test
    void springDefaultKeepsMultiCredentialsDisabled() {
        new ApplicationContextRunner()
                .withBean(ProjectSchedulerRepository.class, () -> mock(ProjectSchedulerRepository.class))
                .withBean(ProjectMembershipPort.class, () -> mock(ProjectMembershipPort.class))
                .withBean(AuditPort.class, () -> mock(AuditPort.class))
                .withBean(PasswordEncoder.class, () -> mock(PasswordEncoder.class))
                .withUserConfiguration(ServiceCredentialManager.class)
                .run(context -> {
                    assertThat(context).hasNotFailed();
                    assertThatThrownBy(() -> context.getBean(ServiceCredentialManager.class)
                                    .issue(
                                            "1",
                                            "workflow",
                                            Set.of("member:read"),
                                            Instant.now().plusSeconds(60),
                                            null,
                                            null))
                            .isInstanceOfSatisfying(
                                    ApiException.class,
                                    ex -> assertThat(ex.getStatus().value()).isEqualTo(503));
                    verifyNoInteractions(
                            context.getBean(ProjectSchedulerRepository.class), context.getBean(AuditPort.class));
                });
    }

    /** 两份有效凭据已并存时不能继续发行第三份，项目或范围错误不能进入凭据写入。 */
    @Test
    void refusesThirdCredentialAndWrongProjectBeforeWriting() {
        var repo = mock(ProjectSchedulerRepository.class);
        var membership = mock(ProjectMembershipPort.class);
        var audit = mock(AuditPort.class);
        var actor = mock(KaiwuContext.class);
        when(actor.userId()).thenReturn("123");
        when(membership.activeMemberExists("1", "123")).thenReturn(true);
        when(repo.lockCredentialProject("1")).thenReturn(true);
        when(repo.activeServiceCredentials("1", "workflow"))
                .thenReturn(List.of(
                        new ProjectSchedulerRepository.ScopedCredential("10", Set.of("member:read")),
                        new ProjectSchedulerRepository.ScopedCredential("11", Set.of("member:read"))));
        var manager = new ServiceCredentialManager(repo, membership, audit, mock(PasswordEncoder.class), true, 60);
        assertThatThrownBy(() -> manager.issue(
                        "1", "workflow", Set.of("member:read"), Instant.now().plusSeconds(3600), actor, null))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(409));
        assertThatThrownBy(() -> manager.issue(
                        "2", "workflow", Set.of("member:read"), Instant.now().plusSeconds(3600), actor, null))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(403));
        verify(repo, never())
                .insertScopedCredential(anyString(), anyString(), anyString(), anyString(), any(), anySet());
        verifyNoInteractions(audit);
    }
}
