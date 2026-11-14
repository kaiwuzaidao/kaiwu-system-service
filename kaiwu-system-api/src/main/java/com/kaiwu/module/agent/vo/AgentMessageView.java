package com.kaiwu.module.agent.vo;
/** Personal Agent data, without executable action tokens or raw capability payloads. */
public record AgentMessageView(
        String id, String question, String answer, boolean completed, java.time.LocalDateTime createdAt) {}
