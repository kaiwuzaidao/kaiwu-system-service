package com.kaiwu.module.agent.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** A request identifier prevents network retries from executing the same turn again. */
public record AgentMessageRequest(
        @NotBlank @Size(max = 500) String question,
        @NotBlank @Pattern(regexp = "[a-zA-Z0-9-]{16,64}") String requestId,
        @Valid AgentInputSubmission input) {}
