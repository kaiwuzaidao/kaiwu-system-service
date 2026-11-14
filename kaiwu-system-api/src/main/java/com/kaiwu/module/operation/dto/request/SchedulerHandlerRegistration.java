package com.kaiwu.module.operation.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SchedulerHandlerRegistration(
        @NotBlank @Size(max = 128) String taskType, @NotBlank @Size(max = 128) String taskName) {}
