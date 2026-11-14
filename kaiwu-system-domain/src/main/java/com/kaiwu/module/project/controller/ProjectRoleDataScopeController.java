package com.kaiwu.module.project.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.starter.RequirePermission;
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
 * 平台管理员查看与保存项目角色的数据范围（ADR 0044）。
 *
 * <p>与角色菜单授权同一权限码：数据范围同样是「这个角色能做什么」的授权，不单列权限，避免出现只能改菜单
 * 却不能改范围、或反过来的半截授权状态。业务后台的同类入口见 {@link ProjectAccessDataScopeController}。</p>
 */
@RestController
@RequestMapping("/api/projects/{projectId}/roles/{roleId}/data-scopes")
public class ProjectRoleDataScopeController {

    private final ProjectDataScopeService service;

    /** 注入数据范围服务。 */
    public ProjectRoleDataScopeController(ProjectDataScopeService service) {
        this.service = service;
    }

    /** 角色在项目各已启用受控资源上的当前范围。 */
    @GetMapping
    @RequirePermission("system:project:role")
    public Result<ProjectRoleDataScopeView> get(@PathVariable String projectId, @PathVariable String roleId) {
        return Result.ok(service.roleScopes(projectId, roleId));
    }

    /** 整体替换角色的数据范围；请求里缺省的资源回到仅本人。 */
    @PutMapping
    @RequirePermission("system:project:role")
    public Result<ProjectRoleDataScopeView> save(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleDataScopeRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.saveRoleScopes(
                projectId, roleId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }
}
