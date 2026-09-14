package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.ProjectGenerationRepository.GenerationRow;
import com.kaiwu.module.projectgeneration.ProjectGenerationRepository.RepositoryRow;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationPushRequest;
import java.time.LocalDateTime;
import java.util.List;
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
    private final ProjectGenerationService service = new ProjectGenerationService(
            repository, accessService, null, null, null, null, null, null, rejectingExecutor);

    @Test
    void marksNewGenerationFailedWhenExecutorRejects() {
        when(accessService.requireProjectAdmin("project-1", "user-1")).thenReturn(project());

        assertUnavailable(() ->
                service.create(new ProjectGenerationCreateRequest("project-1", "AI_PROJECT", "订单中心", null), "user-1"));

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

    @Test
    void releasesClaimedRepositoriesWhenPushExecutorRejects() {
        GenerationRow success = generation("SUCCESS");
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(success));
        when(accessService.requireProjectAdmin("project-1", "user-1")).thenReturn(project());
        when(repository.repositories("project-1"))
                .thenReturn(List.of(repositoryRow("BACKEND"), repositoryRow("FRONTEND")));
        when(repository.claimPush("project-1", "BACKEND")).thenReturn(true);
        when(repository.claimPush("project-1", "FRONTEND")).thenReturn(true);

        assertUnavailable(
                () -> service.startPush("PG-1", new ProjectGenerationPushRequest(null, null, null), "user-1"));

        verify(repository).markPushFailed("project-1", "BACKEND", "项目推送执行队列已满，请稍后重试");
        verify(repository).markPushFailed("project-1", "FRONTEND", "项目推送执行队列已满，请稍后重试");
    }

    @Test
    void exposesCloneUrlsForLocalAiCodingHandoff() {
        GenerationRow success = generation("SUCCESS");
        when(repository.findOwned("PG-1", "user-1")).thenReturn(Optional.of(success));
        when(repository.repositories("project-1"))
                .thenReturn(List.of(pushedRepositoryRow("BACKEND", "service"), pushedRepositoryRow("FRONTEND", "web")));

        var view = service.get("PG-1", "user-1");

        assertThat(view.backendHttpCloneUrl()).isEqualTo("https://gitlab.example/team/service.git");
        assertThat(view.backendSshCloneUrl()).isEqualTo("git@gitlab.example:team/service.git");
        assertThat(view.frontendHttpCloneUrl()).isEqualTo("https://gitlab.example/team/web.git");
        assertThat(view.frontendSshCloneUrl()).isEqualTo("git@gitlab.example:team/web.git");
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
                "AI_PROJECT",
                "原描述",
                "CREATE TABLE biz_demo (id BIGINT PRIMARY KEY);",
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

    private RepositoryRow repositoryRow(String type) {
        return new RepositoryRow("project-1", type, null, null, null, null, "main", "NOT_CREATED", null, null);
    }

    private RepositoryRow pushedRepositoryRow(String type, String repositoryName) {
        return new RepositoryRow(
                "project-1",
                type,
                repositoryName,
                "https://gitlab.example/team/" + repositoryName,
                "https://gitlab.example/team/" + repositoryName + ".git",
                "git@gitlab.example:team/" + repositoryName + ".git",
                "main",
                "PUSHED",
                "commit",
                null);
    }
}
