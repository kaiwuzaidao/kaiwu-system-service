package com.kaiwu.module.project.entity;

/**
 * 用户所属部门投影。
 *
 * @param departmentId 部门 ID
 * @param primary      是否主部门
 */
public record DataScopeUserDepartmentRow(String departmentId, boolean primary) {}
