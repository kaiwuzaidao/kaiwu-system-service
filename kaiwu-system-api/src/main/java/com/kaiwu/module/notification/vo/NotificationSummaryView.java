package com.kaiwu.module.notification.vo;

/**
 * 收件箱概览：未读数与最近若干条未读，供顶栏铃铛使用。
 */
public record NotificationSummaryView(long unreadCount, java.util.List<NotificationView> recent) {}
