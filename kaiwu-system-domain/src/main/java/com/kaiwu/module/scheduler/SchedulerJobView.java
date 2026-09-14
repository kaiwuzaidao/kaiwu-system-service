package com.kaiwu.module.scheduler;

import java.time.LocalDateTime;

public record SchedulerJobView(
        String id,
        String projectId,
        String projectName,
        String jobName,
        String taskType,
        String cronExpression,
        String zoneId,
        String payload,
        boolean enabled,
        long configVersion,
        LocalDateTime lastRunTime,
        LocalDateTime nextRunTime,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
