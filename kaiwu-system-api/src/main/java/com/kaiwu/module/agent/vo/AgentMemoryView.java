package com.kaiwu.module.agent.vo;
/** Personal Agent data, without executable action tokens or raw capability payloads. */
public record AgentMemoryView(String id, String content, boolean enabled, java.time.LocalDateTime updatedAt) {}
