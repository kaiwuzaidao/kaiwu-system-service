package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ProjectRoleStatusRequest(
        @NotBlank(message = "角色状态不能为空") @Pattern(regexp = "ACTIVE|DISABLED", message = "角色状态非法") String status) {}
