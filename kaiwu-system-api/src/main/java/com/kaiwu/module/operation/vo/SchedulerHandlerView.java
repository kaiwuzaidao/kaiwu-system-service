package com.kaiwu.module.operation.vo;

import java.time.LocalDateTime;

public record SchedulerHandlerView(String projectId, String taskType, String taskName, LocalDateTime lastSeenAt) {}
