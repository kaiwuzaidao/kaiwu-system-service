package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.dto.ManagedTodoRequest;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import com.kaiwu.module.operation.mapper.ManagedTodoMapper;
import com.kaiwu.module.operation.service.impl.ManagedTodoServiceImpl;
import com.kaiwu.module.project.model.ProjectServiceCredential;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** 受管服务的鉴权范围、版本重试与限额错误；SQL 语义另需真实数据库验证。 */
class ManagedTodoServiceTest {
    private static final Instant NOW = Instant.parse("2026-11-01T00:00:00Z");
    private ProjectServiceCredentials credentials;
    private ManagedTodoLockMapper locks;
    private ManagedTodoMapper records;
    private ManagedTodoServiceImpl service;
    private TodoProperties properties;

    /** 固定项目、生产者和时钟，避免测试依赖真实凭据。 */
    @BeforeEach
    void setUp() {
        credentials = mock(ProjectServiceCredentials.class);
        locks = mock(ManagedTodoLockMapper.class);
        records = mock(ManagedTodoMapper.class);
        properties = new TodoProperties();
        properties.setManagedProtocolEnabled(true);
        service = new ManagedTodoServiceImpl(
                credentials, locks, records, properties, Clock.fixed(NOW, ZoneOffset.UTC), 30);
        when(credentials.authenticateScopeBearer(anyString(), org.mockito.ArgumentMatchers.eq("todo:managed")))
                .thenReturn(new ProjectServiceCredential("1", "601", "workflow"));
        when(records.activeProjectCode(601)).thenReturn("flow");
        when(locks.lockBusinessKey("flow", "wf:1")).thenReturn("wf:1");
    }

    /** 相同版本的重试不重查成员，也不产生写入和配额变化。 */
    @Test
    void duplicateDoesNotReopen() {
        var request = request("flow", 1, "OPEN", false, "待审批");
        var op = new ManagedTodoDigest.Operation(
                "flow", "workflow", "wf:1", 501, 1, "OPEN", false, NOW, "待审批", null, null, null);
        when(locks.lockQuota("flow", 501)).thenReturn(1L);
        when(locks.lockGuard("flow", "wf:1", 501)).thenReturn("MANAGED");
        when(records.lockProjection("flow", "workflow", "wf:1", 501))
                .thenReturn(Map.of(
                        "id",
                        1L,
                        "operationSequence",
                        1L,
                        "state",
                        "OPEN",
                        "terminal",
                        false,
                        "payloadDigest",
                        ManagedTodoDigest.sha256(op)));
        assertThat(service.put("Bearer fixture", request).disposition()).isEqualTo("DUPLICATE");
        verify(credentials).authenticateScopeBearer("Bearer fixture", "todo:managed");
        verify(records, never()).lockUserStatus(anyLong());
        verify(records, never()).update(any());
        verify(locks, never()).replaceQuota(anyString(), anyLong(), anyLong(), anyLong());
    }

    /** 终态投递后的迟到 OPEN 必须冲突，即使版本更旧。 */
    @Test
    void terminalNeverReopens() {
        when(locks.lockQuota("flow", 501)).thenReturn(0L);
        when(locks.lockGuard("flow", "wf:1", 501)).thenReturn("MANAGED");
        when(records.lockProjection("flow", "workflow", "wf:1", 501))
                .thenReturn(Map.of(
                        "id",
                        1L,
                        "operationSequence",
                        2L,
                        "state",
                        "DONE",
                        "terminal",
                        true,
                        "payloadDigest",
                        new byte[32]));
        assertThatThrownBy(() -> service.put("Bearer fixture", request("flow", 1, "OPEN", false, "待审批")))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(409));
    }

    /** 请求不能指定其它项目，非默认服务也必须使用固定 scope。 */
    @Test
    void projectMismatchIsForbidden() {
        assertThatThrownBy(() -> service.put("Bearer fixture", request("other", 1, "OPEN", false, "待审批")))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(403));
        verify(credentials).authenticateScopeBearer("Bearer fixture", "todo:managed");
        verify(locks, never()).ensureBusinessKey(anyString(), anyString());
    }

    /** 达到共享上限返回 429，且不写入投影。 */
    @Test
    void sharedCapacityIsRetryable() {
        properties.setMaxOpenPerRecipient(1);
        when(locks.lockQuota("flow", 501)).thenReturn(1L);
        when(locks.lockGuard("flow", "wf:1", 501)).thenReturn("MANAGED");
        when(locks.countLegacyOpenForUpdate("flow", 501)).thenReturn(1L);
        when(records.lockUserStatus(501)).thenReturn("ENABLED");
        when(records.lockMemberStatus(601, 501)).thenReturn("ACTIVE");
        assertThatThrownBy(() -> service.put("Bearer fixture", request("flow", 1, "OPEN", false, "待审批")))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        ex -> assertThat(ex.getStatus().value()).isEqualTo(429));
        verify(records, never()).insert(any());
    }

    /** 固定模拟用户和正文，只改变与每项断言有关的字段。 */
    private static ManagedTodoRequest request(String project, long seq, String state, boolean terminal, String title) {
        return new ManagedTodoRequest(project, "wf:1", "501", seq, state, terminal, NOW, title, null, null, null);
    }
}
