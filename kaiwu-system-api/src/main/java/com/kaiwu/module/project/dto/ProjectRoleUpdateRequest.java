package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ProjectRoleUpdateRequest(
        @NotBlank(message = "角色名称不能为空") @Size(max = 100, message = "角色名称不能超过 100 个字符") String roleName,
        @Size(max = 255, message = "角色描述不能超过 255 个字符") String description) {}
