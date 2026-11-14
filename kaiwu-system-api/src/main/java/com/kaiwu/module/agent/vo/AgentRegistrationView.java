package com.kaiwu.module.agent.vo;

import java.time.LocalDateTime;

/** 注册结果与管理视图；无凭据摘要、后端地址或原始业务数据。 */
public record AgentRegistrationView(
        String id,
        String projectId,
        String capabilityCode,
        String version,
        String manifestHash,
        String status,
        boolean readOnly,
        boolean online,
        LocalDateTime lastSeenAt,
        String description) {}
