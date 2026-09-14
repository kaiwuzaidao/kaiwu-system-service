package com.kaiwu.module.scheduler;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record SchedulerClaimRequest(
        @NotBlank String jobId,
        @Positive long configVersion,
        @NotNull Instant scheduledAt,
        @NotBlank @Size(max = 128) String instanceId) {}
