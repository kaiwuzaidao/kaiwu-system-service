package com.kaiwu.module.agent.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * 一次提问。
 *
 * <p>P1a 不接受前端传入语言：答复语言的权威来源是服务端的 {@code sys_user.locale}。
 * 前端传入是一个能改变模型行为的自由文本入口，且与账号偏好可能冲突。</p>
 */
public record AgentAskRequest(
        @NotBlank @Size(max = 500) String question,
        @Valid @Size(max = 4) List<AgentConversationTurn> history,
        @Valid AgentInputSubmission input) {
    public AgentAskRequest(String question, List<AgentConversationTurn> history) {
        this(question, history, null);
    }

    public AgentAskRequest {
        history = history == null ? List.of() : List.copyOf(history);
    }
}
