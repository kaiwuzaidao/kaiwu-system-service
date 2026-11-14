package com.kaiwu.module.project.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.identity.model.CliSessionScope;
import com.kaiwu.starter.KaiwuContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * 项目内成员与角色授权的权限守卫。
 *
 * <p>以调用者在目标项目里的有效权限码为准（{@link ProjectService#currentAccess}），而不是平台级
 * {@code system:project:*}。内置 system 项目不开放这组接口：它的成员与角色仍在平台的项目管理里维护，
 * 并且修改会撤销用户会话，行为与业务项目不同。</p>
 */
@Component
public class ProjectAccessGuard {

    private final ProjectService projects;

    /** 注入项目服务。 */
    public ProjectAccessGuard(ProjectService projects) {
        this.projects = projects;
    }

    /**
     * 要求调用者在指定项目里拥有某个权限码。
     *
     * @param projectId      目标项目
     * @param actor          当前登录上下文
     * @param permissionCode 需要的项目内权限码
     */
    public void require(String projectId, KaiwuContext actor, String permissionCode) {
        requireCliHoldsPlatformPermission(actor, permissionCode);
        var access = projects.currentAccess(projectId, actor.userId());
        if (access.project().builtIn() || !access.permissions().contains(permissionCode)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "没有该项目的此项权限", "api.common.forbidden");
        }
    }

    /**
     * 命令行会话只服务平台管理员（ADR 0035 补充）：成员相关操作要求平台级 {@code system:project:member}，
     * 角色与授权相关操作要求 {@code system:project:role}。网页会话不受此限制，项目管理员照常在页面里管理。
     */
    private static void requireCliHoldsPlatformPermission(KaiwuContext actor, String permissionCode) {
        if (!actor.permissions().contains(CliSessionScope.MARKER)) {
            return;
        }
        String platform = permissionCode.startsWith("access:member:") ? "system:project:member" : "system:project:role";
        if (!actor.permissions().contains(platform)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "命令行只允许平台管理员管理项目成员与角色授权", "api.common.forbidden");
        }
    }
}
