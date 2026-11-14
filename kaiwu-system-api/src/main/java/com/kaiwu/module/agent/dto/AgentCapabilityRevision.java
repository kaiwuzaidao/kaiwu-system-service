package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** 心跳绑定明确的版本和规范化清单摘要，旧实例不能续活新版本。 */
public record AgentCapabilityRevision(
        @NotBlank @Size(max = 160) String capabilityCode,
        @NotBlank @Size(max = 16) String version,
        @NotBlank @Pattern(regexp = "[a-f0-9]{64}") String manifestHash) {}
