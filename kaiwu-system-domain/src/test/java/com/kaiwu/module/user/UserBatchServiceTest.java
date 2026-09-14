package com.kaiwu.module.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.org.OrgRepository;
import com.kaiwu.module.org.OrgService;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * 导出行数上限与筛选透传：无上限的全表导出会在用户量增长后 OOM。
 * 导出还必须留痕：批量带走全量名单不经过任何单条写操作审计。
 */
class UserBatchServiceTest {

    private static final KaiwuContext ACTOR = new KaiwuContext(
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
    private static final RequestMetadata METADATA = new RequestMetadata("127.0.0.1", "trace-1");

    private UserRepository repository;
    private UserWorkbookCodec codec;
    private AuditService auditService;
    private UserBatchService service;

    @BeforeEach
    void setUp() {
        repository = mock(UserRepository.class);
        codec = mock(UserWorkbookCodec.class);
        auditService = mock(AuditService.class);
        service = new UserBatchService(
                mock(UserService.class),
                repository,
                mock(OrgRepository.class),
                mock(OrgService.class),
                codec,
                auditService);
    }

    @Test
    void exportPassesKeywordAndBoundedLimit() {
        when(repository.listForExport(eq("ali"), anyInt())).thenReturn(List.of(view()));
        when(codec.exportUsers(anyList(), anyString())).thenReturn(new byte[] {1, 2});

        assertThat(service.exportUsers("ali", ACTOR, METADATA)).hasSize(2);

        ArgumentCaptor<Integer> limit = ArgumentCaptor.forClass(Integer.class);
        verify(repository).listForExport(eq("ali"), limit.capture());
        // 查询必须带上限；多取一行用于判断是否超限。
        assertThat(limit.getValue()).isGreaterThan(1);
    }

    @Test
    void exportIsAudited() {
        when(repository.listForExport(eq("ali"), anyInt())).thenReturn(List.of(view()));
        when(codec.exportUsers(anyList(), anyString())).thenReturn(new byte[] {1, 2});

        service.exportUsers("ali", ACTOR, METADATA);

        ArgumentCaptor<String> detail = ArgumentCaptor.forClass(String.class);
        verify(auditService)
                .recordOperation(
                        eq(ACTOR),
                        eq("user"),
                        eq("EXPORT_USERS"),
                        eq("/api/users/export"),
                        detail.capture(),
                        eq(METADATA));
        // 行数与筛选条件都要留痕，否则无法判断这次导出带走了多少数据。
        assertThat(detail.getValue()).contains("rows=1").contains("keyword=ali");
    }

    @Test
    void exportRejectsInsteadOfSilentlyTruncating() {
        // 返回的行数等于请求上限（含多取的那一行），即真实数据已超过导出上限。
        when(repository.listForExport(any(), anyInt()))
                .thenAnswer(invocation -> Collections.nCopies(invocation.getArgument(1), view()));

        assertThatThrownBy(() -> service.exportUsers(null, ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("请先用用户名或显示名筛选");

        // 必须报错而不是截断后照常生成文件；失败的导出也不该留下“已导出”记录。
        verifyNoInteractions(codec);
        verifyNoInteractions(auditService);
    }

    private static UserView view() {
        LocalDateTime now = LocalDateTime.now();
        return new UserView("1", "alice", "Alice", "alice@example.com", "ENABLED", now, now);
    }
}
