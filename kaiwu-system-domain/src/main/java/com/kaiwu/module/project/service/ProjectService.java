package com.kaiwu.module.project.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.project.dto.*;
import com.kaiwu.module.project.vo.*;
import com.kaiwu.starter.KaiwuContext;
import java.util.*;

/** Application use cases; implementation owns transactions and resource authorization. */
public interface ProjectService {

    PageResult<ProjectView> page(String keyword, long current, long size);

    /**
     * 按关键字、状态与是否内置筛选的项目分页。
     *
     * @param keyword 编码或名称关键字，空表示不过滤
     * @param status 项目状态，空表示不过滤
     * @param builtIn 是否平台内置项目，空表示不过滤
     * @param current 页码，从 1 开始
     * @param size 每页条数
     * @return 当前页项目与总数
     */
    PageResult<ProjectView> page(String keyword, String status, Boolean builtIn, long current, long size);

    ProjectView create(ProjectCreateRequest request, KaiwuContext actor, RequestMetadata metadata);

    ProjectView update(String projectId, ProjectUpdateRequest request, KaiwuContext actor, RequestMetadata metadata);

    /** 登记三个入口字段，同步默认服务并审计。 */
    ProjectView updateEntry(String projectId, ProjectEntryRequest entry, KaiwuContext actor, RequestMetadata metadata);

    String gatewayRoute(String projectId);

    ProjectView updateStatus(String projectId, String status, KaiwuContext actor, RequestMetadata metadata);

    ProjectView project(String projectId);

    ProjectView updateStatusForAgent(
            String projectId,
            String status,
            ProjectStatusExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectView renameProjectForAgent(
            String projectId,
            String projectName,
            ProjectRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    List<ProjectMemberView> members(String projectId);

    /** 项目内可授予的权限码（按钮节点拍平），供按权限码授权前查询。 */
    List<ProjectPermissionView> permissions(String projectId);

    /** 按登录名与角色编码保存成员；登录名或角色编码不存在时 404/400。 */
    List<ProjectMemberView> saveMemberByUsername(
            String projectId,
            String username,
            Set<String> roleCodes,
            String status,
            KaiwuContext actor,
            RequestMetadata metadata);

    /** 按登录名移除成员。 */
    void deleteMemberByUsername(String projectId, String username, KaiwuContext actor, RequestMetadata metadata);

    /** 按权限码整体替换某个角色的授权；权限码不存在时 400 并列出缺失项。 */
    ProjectRoleView grantRolePermissions(
            String projectId,
            String roleCode,
            Set<String> permissionCodes,
            KaiwuContext actor,
            RequestMetadata metadata);

    /** 选人候选：按关键字查找尚未加入项目的启用用户，最多返回 {@code limit} 条。 */
    List<ProjectMemberCandidateView> memberCandidates(String projectId, String keyword, int limit);

    List<ProjectMemberView> saveMember(
            String projectId,
            String userId,
            ProjectMemberRequest request,
            KaiwuContext actor,
            RequestMetadata metadata);

    void deleteMember(String projectId, String userId, KaiwuContext actor, RequestMetadata metadata);

    Optional<ProjectMemberView> previewMemberSave(String projectId, String userId, ProjectMemberRequest request);

    void saveMemberForAgent(
            String projectId,
            String userId,
            ProjectMemberRequest request,
            ProjectMemberExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectMemberView previewMemberDeletion(String projectId, String userId, KaiwuContext actor);

    void deleteMemberForAgent(
            String projectId,
            String userId,
            ProjectMemberExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    List<ProjectRoleView> roles(String projectId);

    ProjectRoleView editableRole(String projectId, String roleId);

    ProjectRoleView createRole(
            String projectId, ProjectRoleCreateRequest request, KaiwuContext actor, RequestMetadata metadata);

    ProjectRoleView updateRole(
            String projectId,
            String roleId,
            ProjectRoleUpdateRequest request,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectRoleView updateRoleForAgent(
            String projectId,
            String roleId,
            ProjectRoleUpdateRequest request,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectRoleView updateRoleStatus(
            String projectId, String roleId, String status, KaiwuContext actor, RequestMetadata metadata);

    ProjectRoleView updateRoleStatusForAgent(
            String projectId,
            String roleId,
            String status,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    void deleteRole(String projectId, String roleId, KaiwuContext actor, RequestMetadata metadata);

    ProjectRoleView previewRoleDeletion(String projectId, String roleId);

    void deleteRoleForAgent(
            String projectId,
            String roleId,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectRoleView grantRoleMenus(
            String projectId, String roleId, Set<String> menuIds, KaiwuContext actor, RequestMetadata metadata);

    ProjectRoleView previewRoleMenuGrant(String projectId, String roleId, Set<String> menuIds);

    ProjectRoleView grantRoleMenusForAgent(
            String projectId,
            String roleId,
            Set<String> menuIds,
            ProjectRoleMenuExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    List<ProjectMenuView> menus(String projectId);

    ProjectMenuView menuForAgent(String projectId, String menuId);

    ProjectMenuView previewMenuDeletion(String projectId, String menuId);

    ProjectMenuView updateMenuStatusForAgent(
            String projectId,
            String menuId,
            String status,
            ProjectMenuEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    void deleteMenuForAgent(
            String projectId,
            String menuId,
            ProjectMenuEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectMenuView createMenu(
            String projectId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata);

    ProjectView previewMenuCreation(String projectId, ProjectMenuRequest request);

    ProjectMenuView createMenuForAgent(
            String projectId,
            ProjectMenuRequest request,
            ProjectRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectMenuView updateMenu(
            String projectId, String menuId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata);

    ProjectMenuView previewMenuUpdate(String projectId, String menuId, ProjectMenuRequest request);

    ProjectMenuView updateMenuForAgent(
            String projectId,
            String menuId,
            ProjectMenuRequest request,
            ProjectMenuFullExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata);

    ProjectMenuView updateMenuStatus(
            String projectId, String menuId, String status, KaiwuContext actor, RequestMetadata metadata);

    void deleteMenu(String projectId, String menuId, KaiwuContext actor, RequestMetadata metadata);

    List<ProjectView> currentProjects(String userId);

    CurrentProjectAccessView currentAccess(String projectId, String userId);

    public record ProjectStatusExpectation(String projectCode, String projectName, String status) {}

    public record ProjectRenameExpectation(String projectCode, String projectName, String status) {}

    public record ProjectMemberExpectation(boolean existed, String username, String status, Set<String> roleIds) {}

    public record ProjectRoleEditExpectation(String roleCode, String roleName, String description, String status) {}

    public record ProjectRoleMenuExpectation(
            String roleCode, String roleName, String description, String status, Set<String> menuIds) {}

    public record ProjectMenuEditExpectation(
            String parentId, String menuName, String menuType, String permissionCode, String status) {}

    public record ProjectMenuFullExpectation(
            String parentId,
            String menuName,
            String menuNameKey,
            String menuType,
            String routePath,
            String componentPath,
            String permissionCode,
            String icon,
            int sortNo,
            boolean visible,
            String status) {}
}
