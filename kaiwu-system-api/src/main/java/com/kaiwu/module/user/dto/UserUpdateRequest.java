package com.kaiwu.module.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 编辑平台用户基础资料，用户名不可修改。
 */
public record UserUpdateRequest(
        @NotBlank(message = "显示名称不能为空") @Size(max = 100, message = "显示名称不能超过100个字符") String displayName,
        @Email(message = "邮箱格式不正确") @Size(max = 200, message = "邮箱不能超过200个字符") String email) {}
