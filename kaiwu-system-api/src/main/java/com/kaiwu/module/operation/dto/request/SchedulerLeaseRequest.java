package com.kaiwu.module.operation.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SchedulerLeaseRequest(@NotBlank @Size(max = 128) String instanceId) {}
