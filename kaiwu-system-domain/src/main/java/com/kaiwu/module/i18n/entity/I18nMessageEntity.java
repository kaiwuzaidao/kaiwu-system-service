package com.kaiwu.module.i18n.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/**
 * 国际化资源实体。
 *
 * <p>{@code version} 用于乐观锁，但**有意不加 MyBatis-Plus 的 {@code @Version} 注解**：
 * 那需要额外装 {@code OptimisticLockerInnerInterceptor}，且版本冲突时的行为由拦截器决定。
 * 现有代码靠「带 version 条件的 UPDATE 是否影响 1 行」判断冲突，语义直白且已被上层依赖，
 * 迁移不改它。</p>
 */
@TableName("sys_i18n_message")
public class I18nMessageEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    private String messageKey;
    private String defaultText;
    /** 逐语言译文 JSON */
    private String translationsJson;

    private String moduleCode;
    /** 是否允许匿名下发（登录页需要） */
    private Boolean publicVisible;
    /** 是否必需资源：缺译文会让整门语言不可选 */
    private Boolean requiredResource;

    private String status;
    private String description;
    private Long version;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getMessageKey() {
        return messageKey;
    }

    public void setMessageKey(String messageKey) {
        this.messageKey = messageKey;
    }

    public String getDefaultText() {
        return defaultText;
    }

    public void setDefaultText(String defaultText) {
        this.defaultText = defaultText;
    }

    public String getTranslationsJson() {
        return translationsJson;
    }

    public void setTranslationsJson(String translationsJson) {
        this.translationsJson = translationsJson;
    }

    public String getModuleCode() {
        return moduleCode;
    }

    public void setModuleCode(String moduleCode) {
        this.moduleCode = moduleCode;
    }

    public Boolean getPublicVisible() {
        return publicVisible;
    }

    public void setPublicVisible(Boolean publicVisible) {
        this.publicVisible = publicVisible;
    }

    public Boolean getRequiredResource() {
        return requiredResource;
    }

    public void setRequiredResource(Boolean requiredResource) {
        this.requiredResource = requiredResource;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
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
