package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ProjectRoleCreateRequest(
        @NotBlank(message = "角色编码不能为空") @Pattern(regexp = "[a-z][a-z0-9-]{1,63}", message = "角色编码只能包含小写字母、数字和连字符")
                String roleCode,
        @NotBlank(message = "角色名称不能为空") @Size(max = 100, message = "角色名称不能超过 100 个字符") String roleName,
        @Size(max = 255, message = "角色描述不能超过 255 个字符") String description) {}
