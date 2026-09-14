package com.kaiwu.module.scheduler;

import java.time.Instant;
import java.time.LocalDateTime;

public record SchedulerExecutionView(
        String id,
        String jobId,
        String jobName,
        String projectId,
        String projectName,
        Instant scheduledAt,
        String instanceId,
        String status,
        String message,
        LocalDateTime startedAt,
        LocalDateTime completedAt) {}
