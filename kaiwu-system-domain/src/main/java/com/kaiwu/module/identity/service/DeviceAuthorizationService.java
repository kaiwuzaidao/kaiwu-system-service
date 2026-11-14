package com.kaiwu.module.identity.service;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.auth.vo.TokenView;
import com.kaiwu.module.identity.vo.DeviceAuthorizationPendingView;
import com.kaiwu.module.identity.vo.DeviceAuthorizationStartView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;

/**
 * CLI 设备授权用例（ADR 0035）。
 *
 * <p>流程：CLI 发起 → 已登录用户在确认页核对短码与客户端名称后允许或拒绝 → CLI 轮询兑换。
 * 兑换得到的是普通在线会话，权限与用户本人相同，生命周期沿用 ADR 0019。</p>
 */
public interface DeviceAuthorizationService {

    /** 发起授权；按客户端地址限流。 */
    DeviceAuthorizationStartView start(String clientName, RequestMetadata metadata);

    /** 当前用户查看待确认请求；不存在或已过期时返回 404。 */
    DeviceAuthorizationPendingView pending(String userCode);

    /** 当前用户允许请求。 */
    void approve(KaiwuContext context, String userCode, RequestMetadata metadata);

    /** 当前用户拒绝请求。 */
    void deny(KaiwuContext context, String userCode, RequestMetadata metadata);

    /** CLI 轮询；允许后一次性签发会话，其余情况只返回状态。 */
    PollResult poll(String deviceCode, RequestMetadata metadata);

    /**
     * 轮询结果。
     *
     * @param status             PENDING / APPROVED / DENIED / EXPIRED
     * @param token              仅 APPROVED 时非空
     * @param refreshToken       仅 APPROVED 时非空，只供 Controller 写入 HttpOnly Cookie
     * @param absoluteExpiresAt  仅 APPROVED 时非空，会话绝对过期时间
     */
    record PollResult(String status, TokenView token, String refreshToken, Instant absoluteExpiresAt) {}
}
