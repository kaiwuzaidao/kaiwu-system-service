package com.kaiwu.module.project.model;

/**
 * 业务项目内「成员与角色授权」的权限码。
 *
 * <p>每个业务项目创建时都会种入这组菜单与按钮，并授予项目管理员角色；项目管理员再按需授予别人。
 * 权限只在本项目内生效，与平台级的 {@code system:project:*} 无关，所以普通项目管理员无需平台权限
 * 就能管理自己项目的成员与角色。</p>
 */
public final class ProjectAccessPermissions {

    /** 查看成员列表。 */
    public static final String MEMBER_LIST = "access:member:list";

    /** 添加或编辑成员（含角色分配与启停）。 */
    public static final String MEMBER_SAVE = "access:member:save";

    /** 移除成员。 */
    public static final String MEMBER_DELETE = "access:member:delete";

    /** 查看角色与菜单。 */
    public static final String ROLE_LIST = "access:role:list";

    /** 新增、编辑或启停角色。 */
    public static final String ROLE_SAVE = "access:role:save";

    /** 给角色授权菜单与按钮。 */
    public static final String ROLE_GRANT = "access:role:grant";

    /** 删除角色。 */
    public static final String ROLE_DELETE = "access:role:delete";

    /** 工具类，不允许实例化。 */
    private ProjectAccessPermissions() {}
}
