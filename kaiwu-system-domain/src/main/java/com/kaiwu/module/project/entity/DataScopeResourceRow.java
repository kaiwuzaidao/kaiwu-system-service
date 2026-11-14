package com.kaiwu.module.project.entity;

/**
 * {@code sys_project_data_resource} 的查询投影。列顺序必须与 {@code ProjectDataScopeMapper} 的 SELECT 一致。
 *
 * @param id             行 ID
 * @param resourceCode   资源码
 * @param resourceName   展示名
 * @param allowedScopes  逗号分隔的允许范围类型
 * @param status         {@code ENABLED} 或 {@code DISABLED}
 */
public record DataScopeResourceRow(
        String id, String resourceCode, String resourceName, String allowedScopes, String status) {}
