package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.adapter.ProjectFactoryAccessService;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository.GenerationRow;
import com.kaiwu.module.factory.service.impl.ProjectGenerationServiceImpl;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.concurrent.Executor;
import org.junit.jupiter.api.Test;

class ProjectGenerationRetryTest {

    @Test
    void historicalDdlInputRemainsReadableButCannotBeRetriedOrCreated() {
        ProjectGenerationRepository repository = mock(ProjectGenerationRepository.class);
        ProjectFactoryAccessService accessService = mock(ProjectFactoryAccessService.class);
        Executor executor = mock(Executor.class);
        ProjectGenerationService service =
                new ProjectGenerationServiceImpl(repository, accessService, null, null, null, null, null, executor);
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(failedRow()));
        assertThat(service.editableInput("PG-1", "user-1").ddl()).contains("original_table");
        assertThatThrownBy(() -> service.retry("PG-1", null, "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已下线");
        assertThatThrownBy(() -> service.create(
                        new ProjectGenerationCreateRequest(
                                "project-1", "DDL_SCAFFOLD", null, "CREATE TABLE x (id INT)"),
                        "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已下线");
        verify(repository, never()).updateAndRetry(any(), any(), any(), any());
        verify(executor, never()).execute(any(Runnable.class));
    }

    /** 历史 AI_PROJECT 失败任务不能再重试（ADR 0038）：同步拒绝，不更新也不入队。 */
    @Test
    void retiredAiProjectTaskCannotBeRetriedOrCreated() {
        ProjectGenerationRepository repository = mock(ProjectGenerationRepository.class);
        ProjectFactoryAccessService accessService = mock(ProjectFactoryAccessService.class);
        Executor executor = mock(Executor.class);
        ProjectGenerationService service =
                new ProjectGenerationServiceImpl(repository, accessService, null, null, null, null, null, executor);
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(legacyAiRow()));

        assertThatThrownBy(() -> service.retry("PG-1", null, "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已下线");
        assertThatThrownBy(() -> service.create(
                        new ProjectGenerationCreateRequest("project-1", "AI_PROJECT", "订单中心", null), "user-1"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已下线");

        verify(repository, never()).updateAndRetry(any(), any(), any(), any());
        verify(executor, never()).execute(any(Runnable.class));
    }

    private GenerationRow legacyAiRow() {
        GenerationRow row = failedRow();
        return new GenerationRow(
                row.taskNo(),
                row.projectId(),
                row.projectCode(),
                row.projectName(),
                row.ownerUserId(),
                "AI_PROJECT",
                row.businessDescription(),
                row.ddlContent(),
                row.status(),
                row.templateVersion(),
                row.blueprintJson(),
                row.aiModel(),
                row.designSummary(),
                row.backendArtifactName(),
                row.frontendArtifactName(),
                row.backendFileManifest(),
                row.frontendFileManifest(),
                row.lastError(),
                row.startedAt(),
                row.completedAt(),
                row.createdAt(),
                row.updatedAt());
    }

    private GenerationRow failedRow() {
        LocalDateTime now = LocalDateTime.now();
        return new GenerationRow(
                "PG-1",
                "project-1",
                "demo",
                "演示项目",
                "user-1",
                "DDL_SCAFFOLD",
                "原描述",
                "CREATE TABLE original_table (id BIGINT PRIMARY KEY);",
                "FAILED",
                "kaiwu-project-v2",
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                "仅支持 CREATE TABLE 语句",
                now,
                now,
                now,
                now);
    }
}
