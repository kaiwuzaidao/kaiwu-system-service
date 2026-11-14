package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Explicit user-authored preference; never an authorization rule. */
public record AgentMemoryRequest(@NotBlank @Size(max = 500) String content, boolean enabled) {}
