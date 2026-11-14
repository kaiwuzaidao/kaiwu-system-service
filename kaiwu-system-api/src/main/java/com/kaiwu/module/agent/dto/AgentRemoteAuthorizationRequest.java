package com.kaiwu.module.agent.dto;

/** Gateway 内部复核契约；用户由 sessionId 解析，不能提交 userId。 */
public record AgentRemoteAuthorizationRequest(String sessionId, String code, String version, String manifestHash) {}
