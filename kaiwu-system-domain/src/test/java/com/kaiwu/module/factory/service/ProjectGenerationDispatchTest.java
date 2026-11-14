package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.factory.adapter.ProjectFactoryAccessService;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository;
import com.kaiwu.module.factory.repository.ProjectGenerationRepository.GenerationRow;
import com.kaiwu.module.factory.service.impl.ProjectGenerationServiceImpl;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class ProjectGenerationDispatchTest {

    private final ProjectGenerationRepository repository = mock(ProjectGenerationRepository.class);
    private final ProjectFactoryAccessService accessService = mock(ProjectFactoryAccessService.class);
    private final Executor rejectingExecutor = task -> {
        throw new RejectedExecutionException("queue full");
    };
    private final ProjectGenerationService service = new ProjectGenerationServiceImpl(
            repository, accessService, null, null, null, null, null, rejectingExecutor);

    @Test
    void marksNewGenerationFailedWhenExecutorRejects() {
        when(accessService.requireProjectAdmin("project-1", "user-1")).thenReturn(project());

        assertUnavailable(() -> service.create(
                new ProjectGenerationCreateRequest("project-1", "BASIC_SCAFFOLD", null, null), "user-1"));

        verify(repository).markDispatchFailed(anyString(), contains("执行队列已满"));
    }

    @Test
    void returnsRetriedGenerationToFailedWhenExecutorRejects() {
        GenerationRow failed = generation("FAILED");
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(failed));
        when(repository.updateAndRetry("PG-1", "user-1", failed.businessDescription(), failed.ddlContent()))
                .thenReturn(true);

        assertUnavailable(() -> service.retry("PG-1", null, "user-1"));

        verify(repository).markDispatchFailed("PG-1", "项目生成执行队列已满，请稍后重试");
    }

    private void assertUnavailable(Runnable operation) {
        assertThatThrownBy(operation::run).isInstanceOfSatisfying(ApiException.class, exception -> {
            assertThat(exception.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
            assertThat(exception.getMessageKey()).isEqualTo("api.common.serviceUnavailable");
        });
    }

    private ProjectView project() {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectView(
                "project-1",
                "demo",
                "演示项目",
                null,
                "ACTIVE",
                false,
                "user-1",
                "com.example.demo",
                null,
                null,
                "main",
                null,
                null,
                null,
                now,
                now);
    }

    private GenerationRow generation(String status) {
        LocalDateTime now = LocalDateTime.now();
        return new GenerationRow(
                "PG-1",
                "project-1",
                "demo",
                "演示项目",
                "user-1",
                "BASIC_SCAFFOLD",
                null,
                null,
                status,
                "kaiwu-project-v5",
                null,
                null,
                null,
                "backend.zip",
                "frontend.zip",
                null,
                null,
                null,
                now,
                now,
                now,
                now);
    }
}
