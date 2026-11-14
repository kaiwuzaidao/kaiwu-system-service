package com.kaiwu.module.project.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.*;
import com.kaiwu.module.project.model.ProjectAccessPermissions;
import com.kaiwu.module.project.service.ProjectAccessGuard;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMemberCandidateView;
import com.kaiwu.module.project.vo.ProjectMemberView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectPermissionView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

/**
 * 业务项目内的成员与角色授权（项目管理员自助）。
 *
 * <p>业务后台的「项目成员」「角色授权」页面调用本控制器。权限由 {@link ProjectAccessGuard} 按调用者
 * 在该项目里的权限码判定，不要求平台级 {@code system:project:*}；成员、角色、授权的业务规则与平台项目管理
 * 完全复用同一个 {@link ProjectService}，因此「创建人不可移除」「内置角色不可改」等约束一致。</p>
 */
@RestController
@RequestMapping("/api/current/projects/{projectId}/access-admin")
public class ProjectAccessAdminController {

    private static final int CANDIDATE_LIMIT = 20;

    private final ProjectService service;
    private final ProjectAccessGuard guard;

    /** 注入项目服务与权限守卫。 */
    public ProjectAccessAdminController(ProjectService service, ProjectAccessGuard guard) {
        this.service = service;
        this.guard = guard;
    }

    /** 成员列表。 */
    @GetMapping("/members")
    public Result<List<ProjectMemberView>> members(@PathVariable String projectId) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.MEMBER_LIST);
        return Result.ok(service.members(projectId));
    }

    /** 选人：按关键字查找尚未加入本项目的启用用户，只返回选人所需的最少字段。 */
    @GetMapping("/members/candidates")
    public Result<List<ProjectMemberCandidateView>> candidates(
            @PathVariable String projectId, @RequestParam(defaultValue = "") String keyword) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.MEMBER_SAVE);
        return Result.ok(service.memberCandidates(projectId, keyword, CANDIDATE_LIMIT));
    }

    /** 添加或编辑成员。 */
    @PutMapping("/members/{userId}")
    public Result<List<ProjectMemberView>> saveMember(
            @PathVariable String projectId,
            @PathVariable String userId,
            @Valid @RequestBody ProjectMemberRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.MEMBER_SAVE);
        return Result.ok(service.saveMember(projectId, userId, request, actor, RequestMetadata.from(servletRequest)));
    }

    /** 移除成员。 */
    @DeleteMapping("/members/{userId}")
    public Result<Void> deleteMember(
            @PathVariable String projectId, @PathVariable String userId, HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.MEMBER_DELETE);
        service.deleteMember(projectId, userId, actor, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /** 角色列表。 */
    @GetMapping("/roles")
    public Result<List<ProjectRoleView>> roles(@PathVariable String projectId) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.ROLE_LIST);
        return Result.ok(service.roles(projectId));
    }

    /** 本项目全部菜单与按钮，供授权时勾选。 */
    @GetMapping("/menus")
    public Result<List<ProjectMenuView>> menus(@PathVariable String projectId) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.ROLE_LIST);
        return Result.ok(service.menus(projectId));
    }

    /** 按登录名与角色编码保存成员（命令行与 AI 工具使用）。 */
    @PutMapping("/members/by-username/{username}")
    public Result<List<ProjectMemberView>> saveMemberByUsername(
            @PathVariable String projectId,
            @PathVariable String username,
            @Valid @RequestBody ProjectMemberByNameRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.MEMBER_SAVE);
        return Result.ok(service.saveMemberByUsername(
                projectId,
                username,
                request.roleCodes(),
                request.status(),
                actor,
                RequestMetadata.from(servletRequest)));
    }

    /** 按登录名移除成员。 */
    @DeleteMapping("/members/by-username/{username}")
    public Result<Void> deleteMemberByUsername(
            @PathVariable String projectId, @PathVariable String username, HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.MEMBER_DELETE);
        service.deleteMemberByUsername(projectId, username, actor, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /** 项目内可授予的权限码。 */
    @GetMapping("/permissions")
    public Result<List<ProjectPermissionView>> permissions(@PathVariable String projectId) {
        guard.require(projectId, StarterContext.require(), ProjectAccessPermissions.ROLE_LIST);
        return Result.ok(service.permissions(projectId));
    }

    /** 按权限码整体替换角色授权。 */
    @PutMapping("/roles/by-code/{roleCode}/permissions")
    public Result<ProjectRoleView> grantPermissions(
            @PathVariable String projectId,
            @PathVariable String roleCode,
            @Valid @RequestBody ProjectRolePermissionRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_GRANT);
        return Result.ok(service.grantRolePermissions(
                projectId, roleCode, request.permissionCodes(), actor, RequestMetadata.from(servletRequest)));
    }

    /** 新增角色。 */
    @PostMapping("/roles")
    public Result<ProjectRoleView> createRole(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectRoleCreateRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_SAVE);
        return Result.ok(service.createRole(projectId, request, actor, RequestMetadata.from(servletRequest)));
    }

    /** 编辑角色。 */
    @PutMapping("/roles/{roleId}")
    public Result<ProjectRoleView> updateRole(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleUpdateRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_SAVE);
        return Result.ok(service.updateRole(projectId, roleId, request, actor, RequestMetadata.from(servletRequest)));
    }

    /** 启停角色。 */
    @PutMapping("/roles/{roleId}/status")
    public Result<ProjectRoleView> updateRoleStatus(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleStatusRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_SAVE);
        return Result.ok(service.updateRoleStatus(
                projectId, roleId, request.status(), actor, RequestMetadata.from(servletRequest)));
    }

    /** 给角色授权菜单与按钮。 */
    @PutMapping("/roles/{roleId}/menus")
    public Result<ProjectRoleView> grantMenus(
            @PathVariable String projectId,
            @PathVariable String roleId,
            @Valid @RequestBody ProjectRoleMenuRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_GRANT);
        return Result.ok(service.grantRoleMenus(
                projectId, roleId, request.menuIds(), actor, RequestMetadata.from(servletRequest)));
    }

    /** 删除角色；仍被成员引用时拒绝。 */
    @DeleteMapping("/roles/{roleId}")
    public Result<Void> deleteRole(
            @PathVariable String projectId, @PathVariable String roleId, HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        guard.require(projectId, actor, ProjectAccessPermissions.ROLE_DELETE);
        service.deleteRole(projectId, roleId, actor, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }
}
