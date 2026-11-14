package com.kaiwu.module.identity.vo;

import com.kaiwu.module.auth.vo.TokenView;

/**
 * 设备授权轮询结果（ADR 0035）。
 *
 * <p>授权结果用状态字段表达而不是错误码：等待中、被拒绝和已过期都是轮询的正常分支，
 * CLI 只需按状态决定继续等待还是退出。</p>
 *
 * @param status PENDING / APPROVED / DENIED / EXPIRED；APPROVED 只会返回一次
 * @param token  仅在 APPROVED 时非空，Refresh Token 按 ADR 0019 写入 Cookie
 */
public record DeviceTokenView(String status, TokenView token) {}
