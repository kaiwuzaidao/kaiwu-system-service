package com.kaiwu.module.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.module.scheduler.mapper.ProjectSchedulerMapper;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DuplicateKeyException;

class ProjectSchedulerRepositoryTest {

    @Test
    void concurrentExpiredLeaseDeadlockIsReportedAsRejectedClaim() {
        ProjectSchedulerMapper mapper = mock(ProjectSchedulerMapper.class);
        // 唯一键冲突：本次调度已被别的实例抢到。
        when(mapper.insertExecution(anyString(), anyString(), anyString(), anyLong(), any(), anyString()))
                .thenThrow(new DuplicateKeyException("same scheduled fire"));
        // 接管过期租约时与另一个恢复者互为死锁牺牲者。
        when(mapper.takeOverExpiredExecution(anyString(), any(), anyString(), anyLong()))
                .thenThrow(new CannotAcquireLockException("deadlock victim"));
        ProjectSchedulerRepository repository = new ProjectSchedulerRepository(mapper);

        var claimed =
                repository.claimExecution("job-1", "project-1", "instance-b", 2, Instant.parse("2026-07-29T01:00:00Z"));

        assertThat(claimed).isEmpty();
    }
}
