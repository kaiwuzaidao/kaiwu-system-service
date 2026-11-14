package com.kaiwu.module.project.vo;

import java.util.List;

/**
 * 某个角色的数据范围配置，覆盖项目内全部已启用的受控资源。
 *
 * <p>没有配置的资源也会列出，{@code scope} 为 {@code SELF} 且 {@code configured=false}，
 * 前端据此显示「仅本人（默认）」。内置 {@code project-admin} 角色整体只读，所有资源固定 {@code ALL}。</p>
 *
 * @param roleId   角色 ID
 * @param roleCode 角色编码
 * @param readOnly 是否只读（内置角色）
 * @param items    每个已启用资源一项，按资源码排序
 */
public record ProjectRoleDataScopeView(String roleId, String roleCode, boolean readOnly, List<Item> items) {

    /**
     * 单个资源上的有效配置。
     *
     * @param resourceCode  资源码
     * @param resourceName  展示名
     * @param allowedScopes 该资源允许选择的范围类型
     * @param scope         当前有效的范围类型
     * @param configured    是否有显式配置；{@code false} 表示默认
     * @param includeChild  仅 {@code CUSTOM_DEPT} 有意义
     * @param deptIds       仅 {@code CUSTOM_DEPT} 有意义的部门 ID，升序
     */
    public record Item(
            String resourceCode,
            String resourceName,
            List<String> allowedScopes,
            String scope,
            boolean configured,
            boolean includeChild,
            List<String> deptIds) {}
}
