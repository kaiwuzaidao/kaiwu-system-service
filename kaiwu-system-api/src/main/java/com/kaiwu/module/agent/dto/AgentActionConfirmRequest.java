package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** 接受一次性凭证和强确认短语；冻结参数与能力版本不得由确认请求修改。 */
public record AgentActionConfirmRequest(
        @NotBlank @Pattern(regexp = "[A-Za-z0-9_-]{43}") String confirmationToken,
        @Size(max = 128) String confirmationPhrase) {
    @Override
    public String toString() {
        return "AgentActionConfirmRequest[redacted]";
    }
}
