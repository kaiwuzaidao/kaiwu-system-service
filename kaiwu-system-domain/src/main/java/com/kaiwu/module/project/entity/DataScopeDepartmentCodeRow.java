package com.kaiwu.module.project.entity;

/**
 * 部门 ID 与部门编码的对应。移交包用编码而不是 ID 表示部门，因为 ID 在各环境不同。
 *
 * @param id       部门 ID
 * @param deptCode 部门编码，全局唯一
 */
public record DataScopeDepartmentCodeRow(String id, String deptCode) {}
