package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.http.HttpStatus;

class ProjectGenerationRecoveryRunnerTest {

    @Test
    void oneRejectedRecoveryDoesNotAbortStartupOrSkipRemainingTasks() {
        ProjectGenerationRepository repository = mock(ProjectGenerationRepository.class);
        ProjectGenerationService service = mock(ProjectGenerationService.class);
        when(repository.recoverableTaskNos()).thenReturn(List.of("PG-1", "PG-2"));
        doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "项目生成执行队列已满，请稍后重试", "api.common.serviceUnavailable"))
                .when(service)
                .enqueue("PG-1");
        ProjectGenerationRecoveryRunner runner = new ProjectGenerationRecoveryRunner(repository, service);

        assertThatCode(() -> runner.run(new DefaultApplicationArguments())).doesNotThrowAnyException();

        verify(service).enqueue("PG-1");
        verify(service).enqueue("PG-2");
    }
}
