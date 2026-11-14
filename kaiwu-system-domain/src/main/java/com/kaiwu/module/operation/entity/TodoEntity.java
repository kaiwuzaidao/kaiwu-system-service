package com.kaiwu.module.operation.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 统一待办实体（ADR 0034）。
 *
 * <p>待办是来源业务事实的投影，状态由来源服务经打开与关闭两个幂等操作维护，收件人不能自行关闭。
 * 唯一约束为 {@code (project_code, biz_key, recipient_user_id)}。
 */
@TableName("sys_todo")
public class TodoEntity {

    /** 联合只读查询的存储来源标记，不属于sys_todo列，不参与BaseMapper写入。 */
    @TableField(exist = false)
    private boolean managedProjection;

    /** 受管时间按UTC存储，需要在只读投影时换算到平台配置时区。 */
    public boolean isManagedProjection() {
        return managedProjection;
    }

    /** 接收SQL只读来源别名，浏览器请求不能指定此标记。 */
    public void setManagedProjection(boolean value) {
        managedProjection = value;
    }

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 来源项目 ID。 */
    private Long projectId;

    /** 来源项目编码。 */
    private String projectCode;

    /** 业务唯一键，由来源服务约定。 */
    private String bizKey;

    /** 处理人。 */
    private Long recipientUserId;

    /** 标题。 */
    private String title;

    /** 正文。 */
    private String content;

    /** 平台内跳转路径。 */
    private String linkUrl;

    /** 状态：OPEN、DONE、CANCELLED。 */
    private String status;

    /** 截止时间，可空。 */
    private LocalDateTime dueAt;

    /** 打开（或重新打开）时间。 */
    private LocalDateTime openedAt;

    /** 关闭时间，OPEN 时为空。 */
    private LocalDateTime closedAt;

    /** 创建时间。 */
    private LocalDateTime createdAt;

    /** 最后更新时间。 */
    private LocalDateTime updatedAt;

    /**
     * 读取待办 ID。
     *
     * @return 待办 ID
     */
    public Long getId() {
        return id;
    }

    /**
     * 设置待办 ID。
     *
     * @param id 待办 ID
     */
    public void setId(Long id) {
        this.id = id;
    }

    /**
     * 读取来源项目 ID。
     *
     * @return 来源项目 ID
     */
    public Long getProjectId() {
        return projectId;
    }

    /**
     * 设置来源项目 ID。
     *
     * @param projectId 来源项目 ID
     */
    public void setProjectId(Long projectId) {
        this.projectId = projectId;
    }

    /**
     * 读取来源项目编码。
     *
     * @return 来源项目编码
     */
    public String getProjectCode() {
        return projectCode;
    }

    /**
     * 设置来源项目编码。
     *
     * @param projectCode 来源项目编码
     */
    public void setProjectCode(String projectCode) {
        this.projectCode = projectCode;
    }

    /**
     * 读取业务唯一键。
     *
     * @return 业务唯一键
     */
    public String getBizKey() {
        return bizKey;
    }

    /**
     * 设置业务唯一键。
     *
     * @param bizKey 业务唯一键
     */
    public void setBizKey(String bizKey) {
        this.bizKey = bizKey;
    }

    /**
     * 读取处理人。
     *
     * @return 处理人的用户 ID
     */
    public Long getRecipientUserId() {
        return recipientUserId;
    }

    /**
     * 设置处理人。
     *
     * @param recipientUserId 处理人的用户 ID
     */
    public void setRecipientUserId(Long recipientUserId) {
        this.recipientUserId = recipientUserId;
    }

    /**
     * 读取标题。
     *
     * @return 标题
     */
    public String getTitle() {
        return title;
    }

    /**
     * 设置标题。
     *
     * @param title 标题
     */
    public void setTitle(String title) {
        this.title = title;
    }

    /**
     * 读取正文。
     *
     * @return 正文
     */
    public String getContent() {
        return content;
    }

    /**
     * 设置正文。
     *
     * @param content 正文
     */
    public void setContent(String content) {
        this.content = content;
    }

    /**
     * 读取跳转路径。
     *
     * @return 平台内跳转路径
     */
    public String getLinkUrl() {
        return linkUrl;
    }

    /**
     * 设置跳转路径。
     *
     * @param linkUrl 平台内跳转路径
     */
    public void setLinkUrl(String linkUrl) {
        this.linkUrl = linkUrl;
    }

    /**
     * 读取状态。
     *
     * @return OPEN、DONE 或 CANCELLED
     */
    public String getStatus() {
        return status;
    }

    /**
     * 设置状态。
     *
     * @param status OPEN、DONE 或 CANCELLED
     */
    public void setStatus(String status) {
        this.status = status;
    }

    /**
     * 读取截止时间。
     *
     * @return 截止时间，可空
     */
    public LocalDateTime getDueAt() {
        return dueAt;
    }

    /**
     * 设置截止时间。
     *
     * @param dueAt 截止时间，可空
     */
    public void setDueAt(LocalDateTime dueAt) {
        this.dueAt = dueAt;
    }

    /**
     * 读取打开时间。
     *
     * @return 打开（或重新打开）时间
     */
    public LocalDateTime getOpenedAt() {
        return openedAt;
    }

    /**
     * 设置打开时间。
     *
     * @param openedAt 打开（或重新打开）时间
     */
    public void setOpenedAt(LocalDateTime openedAt) {
        this.openedAt = openedAt;
    }

    /**
     * 读取关闭时间。
     *
     * @return 关闭时间，未关闭为空
     */
    public LocalDateTime getClosedAt() {
        return closedAt;
    }

    /**
     * 设置关闭时间。
     *
     * @param closedAt 关闭时间
     */
    public void setClosedAt(LocalDateTime closedAt) {
        this.closedAt = closedAt;
    }

    /**
     * 读取创建时间。
     *
     * @return 创建时间
     */
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    /**
     * 设置创建时间。
     *
     * @param createdAt 创建时间
     */
    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    /**
     * 读取最后更新时间。
     *
     * @return 最后更新时间
     */
    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    /**
     * 设置最后更新时间。
     *
     * @param updatedAt 最后更新时间
     */
    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
