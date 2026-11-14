package com.kaiwu.module.operation.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SchedulerJobSaveRequest(
        @NotBlank String projectId,
        @NotBlank @Size(max = 128) String jobName,
        @NotBlank @Size(max = 128) String taskType,
        @NotBlank @Size(max = 128) String cronExpression,
        @NotBlank @Size(max = 64) String zoneId,
        String payload,
        boolean enabled) {}
