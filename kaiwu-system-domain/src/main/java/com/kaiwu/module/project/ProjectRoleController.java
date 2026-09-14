package com.kaiwu.module.project;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.*;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/projects/{projectId}/roles")
public class ProjectRoleController {

    private final ProjectService service;

    public ProjectRoleController(ProjectService service) {
        this.service = service;
    }

    @GetMapping
    @RequirePermission("system:project:role")
    public Result<List<ProjectRoleView>> list(@PathVariable String projectId) {
        return Result.ok(service.roles(projectId));
    }

    @PostMapping
    @RequirePermission("system:project:role")
    public Result<ProjectRoleView> create(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectRoleCreateRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.createRole(projectId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{roleId}")
    @RequirePermission("system:project:role")
    public Result<ProjectRoleView> update(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleUpdateRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.updateRole(
                projectId, roleId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{roleId}/status")
    @RequirePermission("system:project:role")
    public Result<ProjectRoleView> updateStatus(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleStatusRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.updateRoleStatus(
                projectId, roleId, request.status(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{roleId}/menus")
    @RequirePermission("system:project:role")
    public Result<ProjectRoleView> grantMenus(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleMenuRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.grantRoleMenus(
                projectId, roleId, request.menuIds(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 删除项目角色；仍被成员引用时拒绝。 */
    @DeleteMapping("/{roleId}")
    @RequirePermission("system:project:role")
    public Result<Void> delete(
            @PathVariable String projectId, @PathVariable String roleId, HttpServletRequest servletRequest) {
        service.deleteRole(projectId, roleId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }
}
