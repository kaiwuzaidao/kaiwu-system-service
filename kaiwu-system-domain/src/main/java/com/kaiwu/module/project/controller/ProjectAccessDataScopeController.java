package com.kaiwu.module.project.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.model.ProjectAccessPermissions;
import com.kaiwu.module.project.service.ProjectAccessGuard;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 业务项目管理员自助维护角色的数据范围（ADR 0044）。
 *
 * <p>与 {@link ProjectAccessAdminController} 同一套规则：权限由 {@link ProjectAccessGuard} 按调用者在该项目里的
 * 权限码判定，查看要求「角色列表」，保存要求「角色授权」，不要求平台级权限。</p>
 */
@RestController
@RequestMapping("/api/current/projects/{projectId}/access-admin/roles/{roleId}/data-scopes")
public class ProjectAccessDataScopeController {

    private final ProjectDataScopeService service;
    private final ProjectAccessGuard guard;

    /** 注入数据范围服务与权限守卫。 */
    public ProjectAccessDataScopeController(ProjectDataScopeService service, ProjectAccessGuard guard) {
        this.service = service;
        this.guard = guard;
    }

    /** 角色在项目各已启用受控资源上的当前范围。 */
    @GetMapping
    public Result<ProjectRoleDataScopeView> get(@PathVariable String projectId, @PathVariable String roleId) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.ROLE_LIST);
        return Result.ok(service.roleScopes(projectId, roleId));
    }

    /** 整体替换角色的数据范围；请求里缺省的资源回到仅本人。 */
    @PutMapping
    public Result<ProjectRoleDataScopeView> save(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleDataScopeRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_GRANT);
        return Result.ok(
                service.saveRoleScopes(projectId, roleId, request, actor, RequestMetadata.from(servletRequest)));
    }
}
