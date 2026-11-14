package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.util.Set;

/**
 * 按登录名与角色编码保存项目成员（命令行与 AI 工具使用）。
 *
 * <p>与按用户 ID、角色 ID 保存的接口等价，只是由服务端把登录名和角色编码解析成 ID。</p>
 */
public record ProjectMemberByNameRequest(
        @NotEmpty(message = "角色编码不能为空") Set<String> roleCodes,
        @NotNull(message = "成员状态不能为空") @Pattern(regexp = "ACTIVE|DISABLED", message = "成员状态非法") String status) {}
