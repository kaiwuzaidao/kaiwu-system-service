package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ProjectMenuStatusRequest(
        @NotBlank(message = "菜单状态不能为空") @Pattern(regexp = "ACTIVE|DISABLED", message = "菜单状态非法") String status) {}
