package com.kaiwu.module.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 管理员重置用户密码。
 */
public record ResetPasswordRequest(
        @NotBlank(message = "新密码不能为空") @Size(min = 8, max = 72, message = "密码长度必须为8到72个字符") String newPassword) {}
