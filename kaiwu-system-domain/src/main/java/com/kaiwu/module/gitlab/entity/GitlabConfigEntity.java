package com.kaiwu.module.gitlab.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * GitLab 交付配置实体，全库仅一行（{@code id = 1}）。
 *
 * <p>主键用 {@link IdType#INPUT}：平台 ID 一律由 {@code LongIdGenerator} 在应用内生成，
 * 不使用数据库自增，也不使用 MyBatis-Plus 的雪花算法——生成策略是平台既有事实，
 * 换 ORM 不改它。</p>
 */
@TableName("sys_gitlab_config")
public class GitlabConfigEntity {

    /** 主键 */
    @TableId(type = IdType.INPUT)
    private Long id;

    /** GitLab 基础地址 */
    private String baseUrl;

    /** 访问令牌密文 */
    private String tokenCiphertext;

    /** 默认群组 ID */
    private String defaultGroupId;

    /** 是否启用 */
    private Boolean enabled;

    /** 最近一次连通性测试结果 */
    private String lastTestStatus;

    /** 最近一次连通性测试信息 */
    private String lastTestMessage;

    /** 最近一次连通性测试时间 */
    private LocalDateTime lastTestAt;

    /** 创建时间 */
    private LocalDateTime createdAt;

    /** 更新时间 */
    private LocalDateTime updatedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public String getTokenCiphertext() {
        return tokenCiphertext;
    }

    public void setTokenCiphertext(String tokenCiphertext) {
        this.tokenCiphertext = tokenCiphertext;
    }

    public String getDefaultGroupId() {
        return defaultGroupId;
    }

    public void setDefaultGroupId(String defaultGroupId) {
        this.defaultGroupId = defaultGroupId;
    }

    public Boolean getEnabled() {
        return enabled;
    }

    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }

    public String getLastTestStatus() {
        return lastTestStatus;
    }

    public void setLastTestStatus(String lastTestStatus) {
        this.lastTestStatus = lastTestStatus;
    }

    public String getLastTestMessage() {
        return lastTestMessage;
    }

    public void setLastTestMessage(String lastTestMessage) {
        this.lastTestMessage = lastTestMessage;
    }

    public LocalDateTime getLastTestAt() {
        return lastTestAt;
    }

    public void setLastTestAt(LocalDateTime lastTestAt) {
        this.lastTestAt = lastTestAt;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
