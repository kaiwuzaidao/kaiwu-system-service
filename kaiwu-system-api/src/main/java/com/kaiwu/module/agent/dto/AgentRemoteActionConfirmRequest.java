package com.kaiwu.module.agent.dto;

/** 确认请求不接受参数、预览、项目或摘要覆盖。 */
public record AgentRemoteActionConfirmRequest(String confirmationToken, String typedPhrase) {
    @Override
    public String toString() {
        return "AgentRemoteActionConfirmRequest[redacted]";
    }
}
