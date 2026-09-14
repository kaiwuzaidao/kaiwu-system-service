package com.kaiwu.module.notification.vo;

import java.time.LocalDateTime;

/**
 * 站内信视图；19 位 ID 在 JSON 契约中保持字符串。
 */
public record NotificationView(
        String id,
        String projectId,
        String projectCode,
        String notificationType,
        String title,
        String content,
        String linkUrl,
        LocalDateTime readAt,
        LocalDateTime createdAt) {}
