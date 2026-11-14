package com.kaiwu.module.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 最近一轮对话的最小上下文；持久会话从服务端历史构造，旧入口兼容浏览器传入。 */
public record AgentConversationTurn(@NotBlank @Size(max = 500) String question, @Size(max = 2000) String answer) {}
