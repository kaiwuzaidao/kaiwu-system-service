package com.kaiwu.module.project.entity;

/**
 * 部门树的一条边，用来展开下级。
 *
 * @param id       部门 ID
 * @param parentId 上级部门 ID，根部门为空
 */
public record DataScopeDepartmentRow(String id, String parentId) {}
