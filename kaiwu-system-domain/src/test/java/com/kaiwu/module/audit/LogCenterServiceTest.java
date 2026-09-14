package com.kaiwu.module.audit;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class LogCenterServiceTest {

    private LogCenterRepository repository;
    private SessionSnapshotPort sessionSnapshots;
    private AuditService auditService;
    private LogCenterService service;
    private KaiwuContext actor;

    @BeforeEach
    void setUp() {
        repository = mock(LogCenterRepository.class);
        sessionSnapshots = mock(SessionSnapshotPort.class);
        auditService = mock(AuditService.class);
        service = new LogCenterService(repository, sessionSnapshots, auditService);
        actor = new KaiwuContext(
                "1",
                "current-session",
                null,
                null,
                Set.of("system:session:force-offline"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void forceOfflineRevokesDatabaseSessionAndRedisSnapshot() {
        LocalDateTime expiresAt = LocalDateTime.now().plusDays(1);
        when(repository.findSession("session-2"))
                .thenReturn(Optional.of(new LogCenterRepository.SessionRow(
                        "session-2",
                        "2",
                        "tester",
                        "ONLINE",
                        LocalDateTime.now(),
                        LocalDateTime.now(),
                        expiresAt,
                        null)));
        when(repository.forceOffline("session-2")).thenReturn(true);

        service.forceOffline("session-2", "风险处置", actor, new RequestMetadata("127.0.0.1", "trace-1"));

        verify(repository).forceOffline("session-2");
        verify(sessionSnapshots).delete("session-2");
        verify(auditService)
                .recordOperation(
                        actor,
                        "security",
                        "FORCE_OFFLINE",
                        "/api/logs/sessions/session-2/force-offline",
                        "sessionId=session-2, reason=风险处置",
                        new RequestMetadata("127.0.0.1", "trace-1"));
    }

    @Test
    void forceOfflineRejectsCurrentSession() {
        assertThatThrownBy(() -> service.forceOffline(
                        "current-session", null, actor, new RequestMetadata("127.0.0.1", "trace-1")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("当前会话");

        verify(repository, never()).forceOffline("current-session");
    }

    @Test
    void pageRejectsUnboundedSize() {
        assertThatThrownBy(() -> service.sessions(null, null, 1, 101))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("分页参数");
    }
}
