package com.kaiwu.module.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * CLI 轮询设备授权结果的请求（ADR 0035）。
 *
 * @param deviceCode 发起授权时返回的高熵设备码，只有发起方持有
 */
public record DeviceTokenRequest(
        @NotBlank(message = "设备码不能为空") @Size(max = 128, message = "设备码不能超过128个字符") String deviceCode) {}
