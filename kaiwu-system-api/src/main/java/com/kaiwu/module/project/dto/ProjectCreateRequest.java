package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record ProjectCreateRequest(
        @NotBlank(message = "项目编码不能为空") @Pattern(regexp = "[a-z][a-z0-9-]{1,63}", message = "项目编码只能包含小写字母、数字和连字符")
                String projectCode,
        @NotBlank(message = "项目名称不能为空") @Size(max = 100, message = "项目名称不能超过 100 个字符") String projectName,
        @Size(max = 500, message = "项目描述不能超过 500 个字符") String description,
        @Pattern(regexp = "^$|^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$", message = "基础包名格式不正确")
                @Size(max = 128, message = "基础包名不能超过 128 个字符")
                String packageName) {}
