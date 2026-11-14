package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Personal conversation settings. Ownership is always derived from the authenticated actor. */
public record AgentConversationRequest(@NotBlank @Size(max = 100) String title, boolean useMemory) {}
