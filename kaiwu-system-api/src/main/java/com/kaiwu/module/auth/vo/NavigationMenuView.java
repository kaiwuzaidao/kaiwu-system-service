package com.kaiwu.module.auth.vo;

import java.util.List;

/**
 * 当前用户的导航菜单节点。
 *
 * <p>只包含 DIRECTORY 与 MENU；BUTTON 是权限码载体，不进导航。
 */
public record NavigationMenuView(
        String id,
        String name,
        /** DIRECTORY 为分组节点，路由为空；MENU 对应一个前端路由。 */
        String type,
        String path,
        String icon,
        List<NavigationMenuView> children) {}
