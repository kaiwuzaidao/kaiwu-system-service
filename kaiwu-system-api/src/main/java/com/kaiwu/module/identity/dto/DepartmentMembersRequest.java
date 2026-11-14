package com.kaiwu.module.identity.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

/** 一次向部门添加最多 100 位平台用户。 */
public record DepartmentMembersRequest(@NotEmpty @Size(max = 100) List<@NotBlank String> userIds) {}
