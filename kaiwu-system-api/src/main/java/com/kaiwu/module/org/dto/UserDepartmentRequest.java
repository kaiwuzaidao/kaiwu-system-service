package com.kaiwu.module.org.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

/** 用户部门归属；首项为主部门。 */
public record UserDepartmentRequest(@Size(max = 20, message = "用户最多归属 20 个部门") List<@NotBlank String> departmentIds) {}
