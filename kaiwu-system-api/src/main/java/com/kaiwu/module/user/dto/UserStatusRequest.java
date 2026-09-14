package com.kaiwu.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * 用户启停请求。
 */
public record UserStatusRequest(
        @NotBlank(message = "用户状态不能为空") @Pattern(regexp = "ENABLED|DISABLED", message = "用户状态只能是 ENABLED 或 DISABLED")
                String status) {}
