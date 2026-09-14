package com.kaiwu.module.scheduler;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public record SchedulerSyncRequest(
        @NotBlank @Size(max = 128) String instanceId,
        @Size(max = 200) List<@Valid SchedulerHandlerRegistration> handlers) {
    public SchedulerSyncRequest {
        handlers = handlers == null ? List.of() : List.copyOf(handlers);
    }
}
