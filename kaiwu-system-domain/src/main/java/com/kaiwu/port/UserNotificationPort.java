package com.kaiwu.port;

/** 平台内部事件投递站内信的边界。 */
public interface UserNotificationPort {

    void notifyUser(String recipientUserId, String type, String title, String content, String linkUrl);
}
