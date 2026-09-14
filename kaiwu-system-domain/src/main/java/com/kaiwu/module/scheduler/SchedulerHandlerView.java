package com.kaiwu.module.scheduler;

import java.time.LocalDateTime;

public record SchedulerHandlerView(String projectId, String taskType, String taskName, LocalDateTime lastSeenAt) {}
