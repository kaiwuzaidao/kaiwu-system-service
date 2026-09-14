package com.kaiwu.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 创建平台用户。
 */
public record UserCreateRequest(
        @NotBlank(message = "用户名不能为空") @Pattern(regexp = "[A-Za-z0-9._-]{3,64}", message = "用户名只能包含字母、数字、点、下划线和短横线")
                String username,
        @NotBlank(message = "显示名称不能为空") @Size(max = 100, message = "显示名称不能超过100个字符") String displayName,
        @Email(message = "邮箱格式不正确") @Size(max = 200, message = "邮箱不能超过200个字符") String email,
        @NotBlank(message = "初始密码不能为空") @Size(min = 8, max = 72, message = "密码长度必须为8到72个字符") String password) {}
