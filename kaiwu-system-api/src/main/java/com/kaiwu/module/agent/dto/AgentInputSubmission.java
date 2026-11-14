package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;

/** Structured user input, never an authorization or execution confirmation. */
public record AgentInputSubmission(
        @NotBlank @Size(max = 160) String capabilityCode,
        @jakarta.validation.constraints.NotNull @Size(max = 32) Map<@Size(max = 64) String, Object> values) {
    public AgentInputSubmission {
        if (values != null) {
            for (Object value : values.values()) {
                if (value != null
                        && !(value instanceof String)
                        && !(value instanceof Number)
                        && !(value instanceof Boolean))
                    throw new IllegalArgumentException("Only scalar form values are supported");
                if (value instanceof String text && text.length() > 4000)
                    throw new IllegalArgumentException("Form value is too long");
            }
        }
    }
}
