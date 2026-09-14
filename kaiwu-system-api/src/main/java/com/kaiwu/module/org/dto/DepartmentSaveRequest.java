package com.kaiwu.module.org.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** 新增或编辑部门；id 为空时新增。 */
public record DepartmentSaveRequest(
        String id,
        String parentId,
        @NotBlank(message = "部门名称不能为空") @Size(max = 100, message = "部门名称过长") String name,
        @NotBlank(message = "部门编码不能为空") @Pattern(regexp = "[a-z][a-z0-9-]{1,63}", message = "部门编码格式错误") String code,
        Integer sortNo,
        @Pattern(regexp = "ENABLED|DISABLED", message = "部门状态错误") String status) {}
