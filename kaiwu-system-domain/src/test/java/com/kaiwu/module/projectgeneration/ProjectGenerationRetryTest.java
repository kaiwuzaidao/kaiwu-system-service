package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.projectgeneration.ProjectGenerationRepository.GenerationRow;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationRetryRequest;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.Executor;
import org.junit.jupiter.api.Test;

class ProjectGenerationRetryTest {

    @Test
    void exposesFailedInputAndUpdatesItBeforeRetrying() {
        ProjectGenerationRepository repository = mock(ProjectGenerationRepository.class);
        ProjectFactoryAccessService accessService = mock(ProjectFactoryAccessService.class);
        Executor executor = mock(Executor.class);
        ProjectGenerationService service =
                new ProjectGenerationService(repository, accessService, null, null, null, null, null, null, executor);
        GenerationRow failed = failedRow();
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(failed));
        when(repository.repositories("project-1")).thenReturn(List.of());
        when(repository.updateAndRetry("PG-1", "user-1", "修改后的描述", "CREATE TABLE fixed_table (id BIGINT PRIMARY KEY);"))
                .thenReturn(true);

        var input = service.editableInput("PG-1", "user-1");
        assertThat(input.businessDescription()).isEqualTo("原描述");
        assertThat(input.ddl()).contains("original_table");

        service.retry(
                "PG-1",
                new ProjectGenerationRetryRequest("修改后的描述", "CREATE TABLE fixed_table (id BIGINT PRIMARY KEY);"),
                "user-1");

        verify(repository)
                .updateAndRetry("PG-1", "user-1", "修改后的描述", "CREATE TABLE fixed_table (id BIGINT PRIMARY KEY);");
        verify(executor).execute(any(Runnable.class));
    }

    private GenerationRow failedRow() {
        LocalDateTime now = LocalDateTime.now();
        return new GenerationRow(
                "PG-1",
                "project-1",
                "demo",
                "演示项目",
                "user-1",
                "AI_PROJECT",
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
