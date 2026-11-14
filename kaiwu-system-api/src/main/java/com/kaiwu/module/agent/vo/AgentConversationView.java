package com.kaiwu.module.agent.vo;
/** Personal Agent data, without executable action tokens or raw capability payloads. */
public record AgentConversationView(String id, String title, boolean useMemory, java.time.LocalDateTime updatedAt) {}
