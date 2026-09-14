package com.kaiwu.module.audit.vo;

import java.time.LocalDateTime;

/** 可由安全运营中心查询和强制下线的登录会话。 */
public record OnlineSessionView(
        String sessionId,
        String userId,
        String username,
        String status,
        LocalDateTime createdAt,
        LocalDateTime lastSeenAt,
        LocalDateTime expiresAt,
        LocalDateTime revokedAt) {}
