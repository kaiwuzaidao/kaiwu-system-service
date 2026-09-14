package com.kaiwu.module.audit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.mapper.AuditWriteMapper;
import com.kaiwu.starter.KaiwuContext;
import java.lang.reflect.Method;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.apache.ibatis.annotations.Select;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

class AuditServiceTest {

    private static KaiwuContext actor() {
        return new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of(),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    private static AuditWriteMapper mapperReturningAdmin() {
        AuditWriteMapper mapper = mock(AuditWriteMapper.class);
        when(mapper.findUsername(anyString())).thenReturn("admin");
        return mapper;
    }

    @Test
    void transactionCoupledOperationAuditRequiresCallerTransaction() throws NoSuchMethodException {
        Method method = AuditService.class.getMethod(
                "recordOperationInCallerTransaction",
                KaiwuContext.class,
                String.class,
                String.class,
                String.class,
                String.class,
                RequestMetadata.class);

        Transactional transactional = method.getAnnotation(Transactional.class);

        assertThat(transactional).isNotNull();
        assertThat(transactional.propagation()).isEqualTo(Propagation.MANDATORY);
    }

    @Test
    void resolvesUsernameBeforeInsertSoOperationAuditDoesNotLockTheUserRow() throws NoSuchMethodException {
        AuditWriteMapper mapper = mapperReturningAdmin();
        AuditService service = new AuditService(mapper, JsonMapper.builder().build());

        service.recordOperation(
                actor(),
                "CHANGE_PASSWORD",
                "/api/auth/password",
                "self=true",
                new RequestMetadata("127.0.0.1", "trace-1"));

        // 用户名必须先查出来再插入：把 SELECT 放进 INSERT 会在写审计时锁住用户行。
        InOrder order = inOrder(mapper);
        order.verify(mapper).findUsername("1");
        order.verify(mapper)
                .insertOperationLog(
                        "1",
                        "admin",
                        "user",
                        "CHANGE_PASSWORD",
                        "/api/auth/password",
                        "self=true",
                        "127.0.0.1",
                        "trace-1");

        String select = String.join(
                "\n",
                AuditWriteMapper.class
                        .getMethod("findUsername", String.class)
                        .getAnnotation(Select.class)
                        .value());
        assertThat(select).doesNotContainIgnoringCase("FOR UPDATE");
    }

    @Test
    void recordOperationWithDiffSerializesChangesAndBuildsSummary() {
        AuditWriteMapper mapper = mapperReturningAdmin();
        AuditService service = new AuditService(mapper, JsonMapper.builder().build());

        service.recordOperationWithDiff(
                actor(),
                "role",
                "CHANGE_ROLE_STATUS",
                "/api/roles/42/status",
                "role",
                "42",
                List.of(new FieldChange("status", "ENABLED", "DISABLED")),
                new RequestMetadata("127.0.0.1", "trace-1"));

        ArgumentCaptor<String> detail = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> changeJson = ArgumentCaptor.forClass(String.class);
        verify(mapper)
                .insertOperationLogWithDiff(
                        any(),
                        any(),
                        any(),
                        any(),
                        any(),
                        detail.capture(),
                        any(),
                        any(),
                        changeJson.capture(),
                        any(),
                        any());

        assertThat(detail.getValue()).isEqualTo("status: ENABLED -> DISABLED");
        assertThat(changeJson.getValue())
                .contains("\"field\":\"status\"")
                .contains("\"before\":\"ENABLED\"")
                .contains("\"after\":\"DISABLED\"");
    }

    @Test
    void recordOperationWithDiffStillExplainsItselfWhenNothingChanged() {
        AuditWriteMapper mapper = mapperReturningAdmin();
        AuditService service = new AuditService(mapper, JsonMapper.builder().build());

        service.recordOperationWithDiff(
                actor(),
                "role",
                "UPDATE_ROLE",
                "/api/roles/42",
                "role",
                "42",
                List.of(),
                new RequestMetadata("127.0.0.1", "trace-1"));

        // detail 不能为空，否则操作日志列表出现无法解释的空白行；
        // 没有 diff 数据时 change_json 保持为空，前端 diff 入口据此禁用；
        // 目标资源仍需可追溯。
        verify(mapper)
                .insertOperationLogWithDiff(
                        "1",
                        "admin",
                        "role",
                        "UPDATE_ROLE",
                        "/api/roles/42",
                        "无字段变更",
                        "role",
                        "42",
                        null,
                        "127.0.0.1",
                        "trace-1");
    }
}
