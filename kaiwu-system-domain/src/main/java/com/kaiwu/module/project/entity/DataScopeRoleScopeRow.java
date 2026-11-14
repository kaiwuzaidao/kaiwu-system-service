package com.kaiwu.module.project.entity;

/**
 * 成员的有效角色与其数据范围配置的左连接投影；没有任何配置的角色也会出现一行，此时 {@code scopeId} 为空。
 * 列顺序必须与 {@code ProjectDataScopeMapper#findMemberRoleScopes} 一致。
 *
 * @param roleId       角色 ID
 * @param roleCode     角色编码
 * @param builtIn      是否内置角色
 * @param scopeId      范围配置行 ID，没有配置时为空
 * @param resourceCode 配置所属资源码，没有配置时为空
 * @param scopeType    范围类型，没有配置时为空
 * @param includeChild 是否含下级，没有配置时为空
 */
public record DataScopeRoleScopeRow(
        String roleId,
        String roleCode,
        boolean builtIn,
        String scopeId,
        String resourceCode,
        String scopeType,
        Boolean includeChild) {}
