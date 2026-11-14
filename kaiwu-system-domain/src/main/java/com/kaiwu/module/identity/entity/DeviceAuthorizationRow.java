package com.kaiwu.module.identity.entity;

import java.time.LocalDateTime;

/**
 * 设备授权请求行（ADR 0035）。
 *
 * <p>只映射查询需要的列；设备码摘要只用于定位，不读回内存。MyBatis 按字段反射赋值，
 * 因此不提供 setter，避免业务代码误改。</p>
 */
public class DeviceAuthorizationRow {

    private String id;
    private String userCode;
    private String clientName;
    private String requestIp;
    private String authStatus;
    private String userId;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;

    /** 请求主键。 */
    public String getId() {
        return id;
    }

    /** 供用户人工核对的短码。 */
    public String getUserCode() {
        return userCode;
    }

    /** CLI 声明的客户端名称，仅供展示。 */
    public String getClientName() {
        return clientName;
    }

    /** 发起请求的客户端地址，仅供用户核对。 */
    public String getRequestIp() {
        return requestIp;
    }

    /** 授权状态：PENDING / APPROVED / DENIED / CONSUMED。 */
    public String getAuthStatus() {
        return authStatus;
    }

    /** 允许或拒绝该请求的用户；PENDING 时为空。 */
    public String getUserId() {
        return userId;
    }

    /** 请求过期时间（按系统默认时区落库的 DATETIME）。 */
    public LocalDateTime getExpiresAt() {
        return expiresAt;
    }

    /** 请求发起时间。 */
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
}
