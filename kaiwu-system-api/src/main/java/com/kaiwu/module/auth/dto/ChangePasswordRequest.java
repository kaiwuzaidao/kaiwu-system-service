package com.kaiwu.module.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 当前登录用户自助修改密码。
 *
 * <p>长度上限 72 与 {@code ResetPasswordRequest} 保持一致：BCrypt 只取前 72 字节，
 * 超出部分会被静默截断，因此在入口处直接拒绝。
 */
public record ChangePasswordRequest(
        @NotBlank(message = "当前密码不能为空") @Size(max = 72, message = "密码长度必须为8到72个字符") String oldPassword,
        @NotBlank(message = "新密码不能为空") @Size(min = 8, max = 72, message = "密码长度必须为8到72个字符") String newPassword,
        @NotBlank(message = "确认密码不能为空") @Size(max = 72, message = "密码长度必须为8到72个字符") String confirmPassword) {}
