package com.kaiwu.module.identity.model;

import java.util.LinkedHashSet;
import java.util.Set;

/**
 * 命令行（设备授权）会话的权限范围（ADR 0035 的补充）。
 *
 * <p>CLI 会话与用户本人使用同一个账号，但只用于生成并取回业务项目、同步平台资源清单，
 * 不需要用户管理、角色、系统配置等权限。签发和刷新会话时把权限收窄为用户权限与本范围的交集，
 * AI 工具即使拿到令牌也调不动范围外的接口；网页登录的会话不受影响。</p>
 */
public final class CliSessionScope {

    /** 设备授权会话的来源取值，与 {@code sys_online_session.session_source} 一致。 */
    public static final String SOURCE = "CLI";

    /**
     * CLI 会话的标记权限：只写进 CLI 会话的权限快照，用来让「项目内成员与角色授权」这类按项目权限码判定的接口
     * 认出调用来自命令行，从而额外要求平台级权限（见 {@code ProjectAccessGuard}）。网页会话没有它。
     */
    public static final String MARKER = "cli:session";

    /**
     * CLI 会话允许持有的权限：项目工厂的生成、查询、下载，项目列表与创建（`project new` 先登记项目再生成），
     * 清单同步写入的字典、配置、菜单，平台级的项目成员、项目角色管理（`access` 命令只服务平台管理员），
     * 以及对象存储的查看、绑定与连接测试（ADR 0040；账号的创建与修改仍被 {@code StorageController} 拒绝）。
     */
    public static final String PROJECT_ENTRY = "cli:project:entry";

    private static final Set<String> ALLOWED = Set.of(
            "system:project-factory:generate",
            "system:project-factory:list",
            "system:project-factory:download",
            "system:project:list",
            "system:project:create",
            "system:dict:save",
            "system:config:save",
            "system:project:menu",
            "system:project:member",
            "system:project:role",
            "system:storage:list",
            "system:storage:save",
            "system:storage:test");

    /** 工具类，不允许实例化。 */
    private CliSessionScope() {}

    /**
     * 按会话来源收窄权限。
     *
     * @param source      会话来源，{@code null} 视为网页会话
     * @param permissions 用户当前拥有的全部权限
     * @return CLI 会话返回与允许范围的交集并带上 {@link #MARKER}，其余来源原样返回
     */
    public static Set<String> limit(String source, Set<String> permissions) {
        if (!SOURCE.equals(source)) {
            return permissions;
        }
        Set<String> limited = new LinkedHashSet<>(permissions);
        limited.retainAll(ALLOWED);
        if (permissions.contains("system:project:update")) {
            limited.add(PROJECT_ENTRY);
        }
        limited.add(MARKER);
        return limited;
    }
}
