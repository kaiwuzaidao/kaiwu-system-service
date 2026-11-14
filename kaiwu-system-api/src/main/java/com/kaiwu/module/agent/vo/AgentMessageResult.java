package com.kaiwu.module.agent.vo;
/** Personal Agent data, without executable action tokens or raw capability payloads. */
public record AgentMessageResult(String messageId, AgentAnswerView answer) {}
