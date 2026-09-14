package com.kaiwu.module.scheduler;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SchedulerCompletionRequest(
        @NotBlank @Size(max = 128) String instanceId,
        @NotBlank @Size(max = 20) String status,
        @Size(max = 1000) String message) {}
