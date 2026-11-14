package com.kaiwu.module.connector.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.connector.service.StorageService;
import com.kaiwu.module.connector.vo.ProjectStorageBindingView;
import com.kaiwu.module.identity.model.CliSessionScope;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class StorageControllerTest {

    private final StorageService service = mock(StorageService.class);
    private final StorageController controller = new StorageController(service, mock(AuditService.class));

    @Test
    void bindingsFilterByProjectCodeForCli() {
        when(service.listBindings(null)).thenReturn(List.of(binding("1", "demo"), binding("2", "other")));

        assertThat(controller.bindings(null, " demo ").data())
                .extracting(ProjectStorageBindingView::id)
                .containsExactly("1");
        assertThat(controller.bindings(null, null).data()).hasSize(2);
        assertThat(controller.bindings(null, " ").data()).hasSize(2);
        assertThat(controller.bindings(null, "missing").data()).isEmpty();
    }

    /** 命令行会话只能绑定项目，不能创建或修改存储账号（ADR 0040）；网页会话不受影响。 */
    @Test
    void cliSessionCannotWriteStorageAccounts() {
        assertThatThrownBy(() -> StorageController.rejectCliAccountWrite(
                        context(Set.of(CliSessionScope.MARKER, "system:storage:save"))))
                .isInstanceOf(ApiException.class);
        assertThatCode(() -> StorageController.rejectCliAccountWrite(context(Set.of("system:storage:save"))))
                .doesNotThrowAnyException();
    }

    private static KaiwuContext context(Set<String> permissions) {
        return new KaiwuContext(
                "7",
                "session-1",
                null,
                null,
                permissions,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    private static ProjectStorageBindingView binding(String id, String projectCode) {
        return new ProjectStorageBindingView(
                id, "p" + id, projectCode, projectCode, "default", "9", "oss", "bucket", "ACTIVE", 1L, List.of(), null);
    }
}
