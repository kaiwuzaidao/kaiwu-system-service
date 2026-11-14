package com.kaiwu.module.identity.vo;

/**
 * 设备授权发起结果（ADR 0035）。
 *
 * @param deviceCode       只返回给发起方一次的高熵设备码，用于轮询
 * @param userCode         供用户在确认页人工核对的短码
 * @param verificationUri  确认页相对路径
 * @param expiresInSeconds 请求有效期
 * @param intervalSeconds  建议的轮询间隔
 */
public record DeviceAuthorizationStartView(
        String deviceCode, String userCode, String verificationUri, long expiresInSeconds, long intervalSeconds) {}
