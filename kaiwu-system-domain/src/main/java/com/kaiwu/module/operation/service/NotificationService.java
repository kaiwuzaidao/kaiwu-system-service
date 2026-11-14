package com.kaiwu.module.operation.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.module.notification.dto.NotificationSendRequest;
import com.kaiwu.module.notification.vo.NotificationSummaryView;
import com.kaiwu.module.notification.vo.NotificationView;
import com.kaiwu.port.UserNotificationPort;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface NotificationService extends UserNotificationPort {

    PageResult<NotificationView> myNotifications(
            String userId, long current, long size, boolean unreadOnly, String type);

    NotificationSummaryView summary(String userId);

    void markRead(String id, String userId);

    long markAllRead(String userId);

    void notifyUser(String recipientUserId, String type, String title, String content, String linkUrl);

    void deliver(NotificationSendRequest request);
}
