package com.kaiwu.module.project.entity;

/**
 * 单个角色的一条数据范围配置投影。列顺序必须与 {@code ProjectDataScopeMapper#findRoleConfigs} 一致。
 *
 * @param id           配置行 ID
 * @param resourceCode 资源码
 * @param scopeType    范围类型
 * @param includeChild 是否含下级
 */
public record DataScopeConfigRow(String id, String resourceCode, String scopeType, boolean includeChild) {}
