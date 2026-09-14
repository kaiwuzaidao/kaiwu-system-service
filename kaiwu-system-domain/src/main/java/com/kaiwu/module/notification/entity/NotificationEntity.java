package com.kaiwu.module.notification.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 站内信实体。
 *
 * <p>消息是不可变事实：只允许新增，以及收件人翻转自己的 {@code read_at}（ADR 0007）。
 * 因此本实体**不提供整行更新路径**，已读操作由 Mapper 上带收件人条件的注解 SQL 完成。</p>
 */
@TableName("sys_notification")
public class NotificationEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 收件人 */
    private Long recipientUserId;

    /** 来源项目；平台自身产生的消息为 null */
    private Long projectId;

    /** 来源项目编码 */
    private String projectCode;

    /** 类型，对应字典 notification.type */
    private String notificationType;

    /** 标题 */
    private String title;

    /** 正文 */
    private String content;

    /** 站内相对路径 */
    private String linkUrl;

    /** 已读时间；null 表示未读 */
    private LocalDateTime readAt;

    /** 创建时间 */
    private LocalDateTime createdAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRecipientUserId() {
        return recipientUserId;
    }

    public void setRecipientUserId(Long recipientUserId) {
        this.recipientUserId = recipientUserId;
    }

    public Long getProjectId() {
        return projectId;
    }

    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }

    public String getProjectCode() {
        return projectCode;
    }

    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    public String getNotificationType() {
        return notificationType;
    }

    public void setNotificationType(String notificationType) {
        this.notificationType = notificationType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getLinkUrl() {
        return linkUrl;
    }

    public void setLinkUrl(String linkUrl) {
        this.linkUrl = linkUrl;
    }

    public LocalDateTime getReadAt() {
        return readAt;
    }

    public void setReadAt(LocalDateTime readAt) {
        this.readAt = readAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
