package com.kaiwu.module.identity.vo;

import java.time.LocalDateTime;

/**
 * 确认页展示的待确认设备授权（ADR 0035）。
 *
 * <p>只包含用户核对所需的信息，不含设备码或其摘要。</p>
 */
public record DeviceAuthorizationPendingView(
        String userCode, String clientName, String requestIp, LocalDateTime createdAt, LocalDateTime expiresAt) {}
