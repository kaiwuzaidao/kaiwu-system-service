package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record ProjectStatusRequest(
        @NotBlank(message = "项目状态不能为空") @Pattern(regexp = "ACTIVE|DISABLED|ARCHIVED", message = "项目状态非法")
                String status) {}
