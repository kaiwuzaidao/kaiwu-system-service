package com.kaiwu.module.audit.vo;

import java.time.LocalDateTime;

/** 用户登录成功、失败与会话退出记录。 */
public record LoginLogView(
        String id,
        String userId,
        String username,
        String status,
        String message,
        String clientIp,
        String traceId,
        LocalDateTime createdAt) {}
