package com.kaiwu.module.metadata.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.LocalDateTime;

/** 参数配置实体。 */
@TableName("sys_app_config")
public class AppConfigEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 作用域：0 为平台全局，其余为项目 ID */
    private Long scopeId;

    /** 配置键 */
    private String configKey;

    /** 配置值 */
    private String configValue;

    /** 展示型配置引用的国际化资源 key；非空即启用（ADR 0013） */
    private String valueI18nKey;

    /** 值类型 */
    private String valueType;

    /** 是否敏感值 */
    private Boolean secret;

    /** 状态 */
    private String status;

    /** 描述 */
    private String description;

    /** 排序 */
    private Integer sortNo;

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

    public Long getScopeId() {
        return scopeId;
    }

    public void setScopeId(Long scopeId) {
        this.scopeId = scopeId;
    }

    public String getConfigKey() {
        return configKey;
    }

    public void setConfigKey(String configKey) {
        this.configKey = configKey;
    }

    public String getConfigValue() {
        return configValue;
    }

    public void setConfigValue(String configValue) {
        this.configValue = configValue;
    }

    public String getValueI18nKey() {
        return valueI18nKey;
    }

    public void setValueI18nKey(String valueI18nKey) {
        this.valueI18nKey = valueI18nKey;
    }

    public String getValueType() {
        return valueType;
    }

    public void setValueType(String valueType) {
        this.valueType = valueType;
    }

    public Boolean getSecret() {
        return secret;
    }

    public void setSecret(Boolean secret) {
        this.secret = secret;
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

    public Integer getSortNo() {
        return sortNo;
    }

    public void setSortNo(Integer sortNo) {
        this.sortNo = sortNo;
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
