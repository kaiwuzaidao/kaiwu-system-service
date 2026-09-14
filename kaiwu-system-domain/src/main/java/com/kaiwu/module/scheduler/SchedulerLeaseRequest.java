package com.kaiwu.module.scheduler;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SchedulerLeaseRequest(@NotBlank @Size(max = 128) String instanceId) {}
