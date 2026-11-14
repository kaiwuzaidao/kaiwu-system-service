package com.kaiwu.module.project.model;

/**
 * 业务项目内「文件」管理页的权限码与开关（ADR 0041）。
 *
 * <p>与「成员与角色授权」同一套机制：页面由项目模板自带，菜单与按钮在创建项目时由平台种入并授予项目管理员。
 * 接口在业务项目的 Starter 里（{@code /api/files}），平台不保存文件数据。</p>
 */
public final class ProjectFilePermissions {

    /**
     * 新项目是否默认带「文件」页：菜单种入与项目模板生成共用这一个开关。
     *
     * <p>生成项目依赖的 Starter 必须已包含 {@code StoredFileController}，否则菜单会指向不存在的接口。
     * 发布包含该能力的 Starter、把 {@code ProjectScaffoldGenerator.STARTER_VERSION} 升到
     * {@link #MIN_STARTER_VERSION} 及以上之后，再把本开关改为 {@code true}；
     * {@code ProjectFilePermissionsTest} 会校验两者一致。</p>
     */
    public static final boolean REGISTRY_ENABLED = false;

    /** 包含统一文件记录能力的最低 Starter 版本。 */
    public static final String MIN_STARTER_VERSION = "0.2.0";

    /** 查看文件列表。 */
    public static final String FILE_LIST = "file:record:list";

    /** 下载文件。 */
    public static final String FILE_DOWNLOAD = "file:record:download";

    /** 删除文件（软删除）。 */
    public static final String FILE_DELETE = "file:record:delete";

    /** 工具类，不允许实例化。 */
    private ProjectFilePermissions() {}
}
