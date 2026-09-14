package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.util.Set;

public record ProjectMemberRequest(
        @NotNull(message = "项目角色不能为空") Set<String> roleIds,
        @NotNull(message = "成员状态不能为空") @Pattern(regexp = "ACTIVE|DISABLED", message = "成员状态非法") String status) {}
