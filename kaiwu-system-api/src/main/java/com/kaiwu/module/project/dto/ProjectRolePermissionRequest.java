package com.kaiwu.module.project.dto;

import jakarta.validation.constraints.NotNull;
import java.util.Set;

/**
 * 按权限码给角色授权（整体替换）。
 *
 * <p>服务端把权限码解析成菜单节点并自动补齐其上级菜单，空集合表示清空该角色的全部授权。</p>
 */
public record ProjectRolePermissionRequest(@NotNull(message = "权限码集合不能为空") Set<String> permissionCodes) {}
