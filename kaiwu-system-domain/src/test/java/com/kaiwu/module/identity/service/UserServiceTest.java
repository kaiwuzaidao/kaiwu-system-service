package com.kaiwu.module.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.impl.UserServiceImpl;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.operation.service.NotificationService;
import com.kaiwu.module.user.dto.ResetPasswordRequest;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.dto.UserUpdateRequest;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class UserServiceTest {

    private UserRepository repository;
    private PasswordEncoder passwordEncoder;
    private SessionSnapshotPort sessionSnapshots;
    private AuditService auditService;
    private NotificationService notificationService;
    private UserService service;
    private KaiwuContext actor;

    @BeforeEach
    void setUp() {
        repository = mock(UserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        sessionSnapshots = mock(SessionSnapshotPort.class);
        auditService = mock(AuditService.class);
        notificationService = mock(NotificationService.class);
        service = new UserServiceImpl(
                repository,
                passwordEncoder,
                sessionSnapshots,
                auditService,
                notificationService,
                Clock.systemDefaultZone());
        actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:user:list"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void createsUserWithoutReturningPasswordMaterial() {
        UserCreateRequest request = new UserCreateRequest("tester", "测试用户", "tester@example.com", "password-123");
        when(repository.existsByUsername("tester")).thenReturn(false);
        when(passwordEncoder.encode("password-123")).thenReturn("encoded");
        when(repository.findView(anyString()))
                .thenAnswer(invocation -> Optional.of(new UserView(
                        invocation.getArgument(0),
                        "tester",
                        "测试用户",
                        "tester@example.com",
                        "ENABLED",
                        LocalDateTime.now(),
                        LocalDateTime.now())));

        UserView result = service.create(request, actor, new RequestMetadata("127.0.0.1", "trace-1"));

        assertThat(result.id()).hasSize(19);
        verify(repository).create(result.id(), "tester", "测试用户", "tester@example.com", "encoded");
    }

    @Test
    void chatProfileEditRejectsStalePreviewWithoutChangingUser() {
        when(repository.findViewForUpdate("35"))
                .thenReturn(
                        Optional.of(new UserView("35", "alice", "页面新名称", "new@example.com", "ENABLED", null, null)));

        assertThatThrownBy(() -> service.updateProfileForAgent(
                        "35",
                        new UserUpdateRequest("聊天新名称", ""),
                        new UserService.UserProfileExpectation("alice", "旧名称", "old@example.com", "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class);
        verifyNoInteractions(auditService);
    }

    @Test
    void displayNameOnlyChatEditPreservesLatestEmailInsideUserLock() {
        when(repository.findViewForUpdate("35"))
                .thenReturn(Optional.of(new UserView("35", "alice", "旧名称", "new@example.com", "ENABLED", null, null)));
        when(repository.findView("35"))
                .thenReturn(Optional.of(new UserView("35", "alice", "新名称", "new@example.com", "ENABLED", null, null)));

        service.updateDisplayNameForAgent("35", "新名称", "旧名称", actor, new RequestMetadata("127.0.0.1", "trace-1"));

        verify(repository).update("35", "新名称", "new@example.com");
    }

    @Test
    void preventsDisablingCurrentUser() {
        when(repository.findView("1")).thenReturn(Optional.of(view("1", "admin", "ENABLED")));

        assertThatThrownBy(
                        () -> service.updateStatus("1", "DISABLED", actor, new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("当前登录用户");

        verifyNoInteractions(sessionSnapshots, auditService);
    }

    @Test
    void resetPasswordRevokesAllTargetSessions() {
        when(repository.findView("2")).thenReturn(Optional.of(view("2", "tester", "ENABLED")));
        when(passwordEncoder.encode("new-password")).thenReturn("new-hash");
        when(repository.findOnlineSessionIds("2")).thenReturn(List.of("session-a", "session-b"));

        service.resetPassword(
                "2", new ResetPasswordRequest("new-password"), actor, new RequestMetadata("127.0.0.1", "trace-1"));

        verify(repository).updatePassword("2", "new-hash");
        verify(repository).revokeOnlineSessions("2");
        verify(sessionSnapshots).delete("session-a");
        verify(sessionSnapshots).delete("session-b");
    }

    @Test
    void chatPasswordResetRejectsChangedTargetBeforeCreatingCredential() {
        when(repository.findViewForUpdate("2")).thenReturn(Optional.of(view("2", "页面改过的名称", "ENABLED")));

        assertThatThrownBy(() -> service.resetPasswordForAgent(
                        "2",
                        new ResetPasswordRequest("temporary-password"),
                        new UserService.UserResetExpectation("tester", "旧名称", "ENABLED"),
                        actor,
                        new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class);
        verifyNoInteractions(passwordEncoder, sessionSnapshots, auditService, notificationService);
    }

    private static UserView view(String id, String username, String status) {
        LocalDateTime now = LocalDateTime.now();
        return new UserView(id, username, username, null, status, now, now);
    }
}
