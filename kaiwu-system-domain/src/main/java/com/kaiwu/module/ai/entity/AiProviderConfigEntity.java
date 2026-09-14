package com.kaiwu.module.ai.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/** AI 供应商配置实体，全库仅一行（{@code id = 1}）。 */
@TableName("sys_ai_provider_config")
public class AiProviderConfigEntity {

    @TableId(type = IdType.INPUT)
    private Long id;

    /** 供应商名称 */
    private String providerName;

    /** 接口基础地址 */
    private String baseUrl;

    /** API Key 密文 */
    private String apiKeyCiphertext;

    /** 模型标识 */
    private String model;

    /** 采样温度 */
    private BigDecimal temperature;

    /** 超时秒数 */
    private Integer timeoutSeconds;

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

    public String getProviderName() {
        return providerName;
    }

    public void setProviderName(String providerName) {
        this.providerName = providerName;
    }

    public String getBaseUrl() {
        return baseUrl;
    }

    public void setBaseUrl(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public String getApiKeyCiphertext() {
        return apiKeyCiphertext;
    }

    public void setApiKeyCiphertext(String apiKeyCiphertext) {
        this.apiKeyCiphertext = apiKeyCiphertext;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public BigDecimal getTemperature() {
        return temperature;
    }

    public void setTemperature(BigDecimal temperature) {
        this.temperature = temperature;
    }

    public Integer getTimeoutSeconds() {
        return timeoutSeconds;
    }

    public void setTimeoutSeconds(Integer timeoutSeconds) {
        this.timeoutSeconds = timeoutSeconds;
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
