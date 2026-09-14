package com.kaiwu.module.projectgeneration;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.kaiwu.module.projectgeneration.mapper.ProjectGenerationMapper;
import org.junit.jupiter.api.Test;

class ProjectGenerationRepositoryTest {

    @Test
    void dispatchCompensationTargetsPendingStateTransition() {
        ProjectGenerationMapper mapper = mock(ProjectGenerationMapper.class);
        ProjectGenerationRepository repository = new ProjectGenerationRepository(mapper);

        repository.markDispatchFailed("PG-1", "queue full");

        verify(mapper).markDispatchFailed("PG-1", "queue full");
    }
}
