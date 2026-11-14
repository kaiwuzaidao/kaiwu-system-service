package com.kaiwu.module.agent.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/** 审核针对操作者看到的确切版本；PENDING 用于明确重新开放已撤销能力的注册。 */
public record AgentCapabilityReviewRequest(
        @NotNull @Valid AgentCapabilityRevision revision,
        @NotBlank @Pattern(regexp = "PENDING|APPROVED|REVOKED") String status) {}
