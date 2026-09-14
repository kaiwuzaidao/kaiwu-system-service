package com.kaiwu.module.project;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.project.entity.ProjectMenuRow;
import com.kaiwu.module.project.entity.ProjectRoleRow;
import com.kaiwu.module.project.entity.ProjectRow;
import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.mapper.ProjectMenuMapper;
import com.kaiwu.module.project.mapper.ProjectRoleMapper;
import com.kaiwu.module.project.vo.ProjectMemberView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.ProjectMembershipPort;
import java.util.*;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

@Repository
public class ProjectRepository implements ProjectMembershipPort {

    private final ProjectMapper mapper;
    private final ProjectRoleMapper roleMapper;
    private final ProjectMenuMapper menuMapper;

    public ProjectRepository(ProjectMapper mapper, ProjectRoleMapper roleMapper, ProjectMenuMapper menuMapper) {
        this.mapper = mapper;
        this.roleMapper = roleMapper;
        this.menuMapper = menuMapper;
    }

    /** 项目分页；关键字同时匹配项目编码与名称，内置项目固定排在最前。 */
    public PageResult<ProjectView> page(String keyword, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        String like = StringUtils.hasText(keyword) ? "%" + keyword.trim() + "%" : null;
        Long total = mapper.countProjects(like);
        List<ProjectView> records = mapper.pageProjects(like, size, (current - 1) * size).stream()
                .map(ProjectRepository::toProject)
                .toList();
        return new PageResult<>(current, size, total == null ? 0 : total, records);
    }

    public List<ProjectView> findCurrentProjects(String userId) {
        return mapper.findCurrentProjects(userId).stream()
                .map(ProjectRepository::toProject)
                .toList();
    }

    public Optional<ProjectView> findProject(String projectId) {
        return Optional.ofNullable(mapper.findProject(projectId)).map(ProjectRepository::toProject);
    }

    public boolean projectCodeExists(String code) {
        return mapper.countProjectCode(code) > 0;
    }

    public boolean enabledLocale(String locale) {
        return mapper.countEnabledLocale(locale) > 0;
    }

    public void createProject(
            String id, String code, String name, String description, String createdBy, String packageName) {
        mapper.createProject(id, code, name, normalize(description), createdBy, packageName);
    }

    /**
     * 更新项目元数据。
     *
     * <p>描述、仓库地址、GitLab 项目 ID、后端地址与标签都允许清空，因此逐列 SET，
     * 不能用实体更新（MyBatis-Plus 会跳过 null 字段，让清空静默失效）。</p>
     */
    public void updateProject(
            String id,
            String name,
            String description,
            String packageName,
            String repositoryUrl,
            String gitlabProjectId,
            String defaultBranch,
            String backendUrl,
            String backendLabel,
            String serviceUrl) {
        mapper.updateProject(
                id,
                name,
                normalize(description),
                packageName,
                normalize(repositoryUrl),
                normalize(gitlabProjectId),
                defaultBranch.trim(),
                normalize(backendUrl),
                normalize(backendLabel),
                normalize(serviceUrl));
    }

    public void updateProjectStatus(String id, String status) {
        mapper.updateProjectStatus(id, status);
    }

    /** 项目成员列表，逐个带出其角色 ID 集合；成员数量在几十条量级，未做批量优化。 */
    public List<ProjectMemberView> findMembers(String projectId) {
        return mapper.findMembers(projectId).stream()
                .map(row -> new ProjectMemberView(
                        row.getUserId(),
                        row.getUsername(),
                        row.getDisplayName(),
                        row.getStatus(),
                        findMemberRoleIds(projectId, row.getUserId()),
                        row.getCreatedAt(),
                        row.getUpdatedAt()))
                .toList();
    }

    public boolean memberExists(String projectId, String userId) {
        return mapper.countMember(projectId, userId) > 0;
    }

    @Override
    public boolean activeMemberExists(String projectId, String userId) {
        return mapper.countActiveMember(projectId, userId) > 0;
    }

    /**
     * 当前用户的语言偏好。内嵌业务前端据此跟随平台语言，避免各自维护一份语言状态导致
     * 平台与内嵌页面显示不同语言。
     */
    public String findUserLocale(String userId) {
        return mapper.findUserLocale(userId);
    }

    public boolean userExists(String userId) {
        return mapper.countUser(userId) > 0;
    }

    public void upsertMember(String projectId, String userId, String status) {
        mapper.upsertMember(projectId, userId, status);
    }

    public Set<String> findMemberRoleIds(String projectId, String userId) {
        return new LinkedHashSet<>(mapper.findMemberRoleIds(projectId, userId));
    }

    public void replaceMemberRoles(String projectId, String userId, Set<String> roleIds) {
        mapper.deleteMemberRoles(projectId, userId);
        roleIds.forEach(roleId -> mapper.insertMemberRole(projectId, userId, roleId));
    }

    public void deleteMember(String projectId, String userId) {
        mapper.deleteMemberRoles(projectId, userId);
        mapper.deleteMember(projectId, userId);
    }

    public List<ProjectRoleView> findRoles(String projectId) {
        return mapper.findRoles(projectId).stream()
                .map(row -> toRole(row, projectId))
                .toList();
    }

    public Optional<ProjectRoleView> findRole(String projectId, String roleId) {
        return Optional.ofNullable(mapper.findRole(projectId, roleId)).map(row -> toRole(row, projectId));
    }

    public boolean roleCodeExists(String projectId, String code) {
        return mapper.countRoleCode(projectId, code) > 0;
    }

    public void createRole(String id, String projectId, String code, String name, String description, boolean builtIn) {
        mapper.createRole(id, projectId, code, name, normalize(description), builtIn);
    }

    public void updateRole(String id, String name, String description) {
        mapper.updateRole(id, name, normalize(description));
    }

    public void updateRoleStatus(String id, String status) {
        mapper.updateRoleStatus(id, status);
    }

    public boolean roleAssigned(String projectId, String roleId) {
        return mapper.countRoleAssignments(projectId, roleId) > 0;
    }

    public void deleteRole(String projectId, String roleId) {
        mapper.deleteRoleMenus(projectId, roleId);
        mapper.deleteRole(roleId);
    }

    public Set<String> findRoleMenuIds(String projectId, String roleId) {
        return new LinkedHashSet<>(mapper.findRoleMenuIds(projectId, roleId));
    }

    public void replaceRoleMenus(String projectId, String roleId, Set<String> menuIds) {
        mapper.deleteRoleMenus(projectId, roleId);
        menuIds.forEach(menuId -> mapper.insertRoleMenu(projectId, roleId, menuId));
    }

    public Optional<String> findProjectAdminRoleId(String projectId) {
        return mapper.findProjectAdminRoleIds(projectId).stream().findFirst();
    }

    public List<ProjectMenuView> findMenus(String projectId) {
        return mapper.findMenus(projectId).stream()
                .map(ProjectRepository::toMenu)
                .toList();
    }

    public Optional<ProjectMenuView> findMenu(String projectId, String menuId) {
        return Optional.ofNullable(mapper.findMenu(projectId, menuId)).map(ProjectRepository::toMenu);
    }

    public boolean menuPermissionUsed(String projectId, String permissionCode, String excludedId) {
        return mapper.countMenuPermissionUsage(projectId, permissionCode, normalize(excludedId)) > 0;
    }

    public boolean menuHasChildren(String projectId, String menuId) {
        return mapper.countMenuChildren(projectId, menuId) > 0;
    }

    /** 新建项目菜单；ID 由调用方生成，初始状态 ACTIVE。 */
    public void createMenu(String id, String projectId, MenuFields fields) {
        mapper.createMenu(
                id,
                projectId,
                fields.parentId(),
                fields.menuName(),
                fields.menuNameKey(),
                fields.menuType(),
                normalize(fields.routePath()),
                normalize(fields.componentPath()),
                normalize(fields.permissionCode()),
                normalize(fields.icon()),
                fields.sortNo(),
                fields.visible());
    }

    /**
     * 将确定性代码生成产出的菜单登记到目标项目。
     * 同一项目重复生成时更新原节点；若同权限码已有人工节点，则复用该节点 ID，
     * 避免出现两套权限事实。
     */
    public String upsertGeneratedMenu(
            String id,
            String projectId,
            String parentId,
            String menuName,
            String menuType,
            String routePath,
            String componentPath,
            String permissionCode,
            int sortNo) {
        mapper.upsertGeneratedMenu(
                id,
                projectId,
                parentId,
                menuName,
                menuType,
                normalize(routePath),
                normalize(componentPath),
                normalize(permissionCode),
                sortNo);
        if (StringUtils.hasText(permissionCode)) {
            return mapper.findMenuIdsByPermission(projectId, permissionCode).stream()
                    .findFirst()
                    .orElseThrow();
        }
        return id;
    }

    /** 编辑项目菜单；路由、组件路径、权限码、图标都允许清空，因此逐列 SET。 */
    public void updateMenu(String id, MenuFields fields) {
        mapper.updateMenu(
                id,
                fields.parentId(),
                fields.menuName(),
                fields.menuNameKey(),
                fields.menuType(),
                normalize(fields.routePath()),
                normalize(fields.componentPath()),
                normalize(fields.permissionCode()),
                normalize(fields.icon()),
                fields.sortNo(),
                fields.visible());
    }

    public void updateMenuStatus(String id, String status) {
        mapper.updateMenuStatus(id, status);
    }

    public void deleteMenu(String projectId, String menuId) {
        mapper.deleteRoleMenusByMenu(projectId, menuId);
        mapper.deleteMenu(menuId);
    }

    /** 授权前的归属校验：给出的角色必须全部属于该项目，否则视为越权引用。 */
    public boolean allRolesBelongToProject(String projectId, Set<String> roleIds) {
        if (roleIds.isEmpty()) return true;
        return roleMapper.selectCount(new LambdaQueryWrapper<ProjectRoleRow>()
                        .eq(ProjectRoleRow::getProjectId, projectId)
                        .in(ProjectRoleRow::getId, roleIds))
                == roleIds.size();
    }

    /** 授权前的归属校验：给出的菜单必须全部属于该项目，否则视为越权引用。 */
    public boolean allMenusBelongToProject(String projectId, Set<String> menuIds) {
        if (menuIds.isEmpty()) return true;
        return menuMapper.selectCount(new LambdaQueryWrapper<ProjectMenuRow>()
                        .eq(ProjectMenuRow::getProjectId, projectId)
                        .in(ProjectMenuRow::getId, menuIds))
                == menuIds.size();
    }

    public void grantMenuToAdmin(String projectId, String menuId) {
        findProjectAdminRoleId(projectId).ifPresent(roleId -> mapper.grantMenuToRole(projectId, roleId, menuId));
    }

    public Set<String> findCurrentRoleCodes(String projectId, String userId) {
        return new LinkedHashSet<>(mapper.findCurrentRoleCodes(projectId, userId));
    }

    public Set<String> findCurrentMenuIds(String projectId, String userId) {
        return new LinkedHashSet<>(mapper.findCurrentMenuIds(projectId, userId));
    }

    public Set<String> findCurrentPermissions(String projectId, String userId) {
        return new LinkedHashSet<>(mapper.findCurrentPermissions(projectId, userId));
    }

    private static ProjectView toProject(ProjectRow row) {
        return new ProjectView(
                row.getId(),
                row.getProjectCode(),
                row.getProjectName(),
                row.getDescription(),
                row.getStatus(),
                Boolean.TRUE.equals(row.getBuiltIn()),
                row.getCreatedBy(),
                row.getPackageName(),
                row.getRepositoryUrl(),
                row.getGitlabProjectId(),
                row.getDefaultBranch(),
                row.getBackendUrl(),
                row.getBackendLabel(),
                row.getServiceUrl(),
                row.getCreatedAt(),
                row.getUpdatedAt());
    }

    private ProjectRoleView toRole(ProjectRoleRow row, String projectId) {
        return new ProjectRoleView(
                row.getId(),
                projectId,
                row.getRoleCode(),
                row.getRoleName(),
                row.getDescription(),
                row.getStatus(),
                Boolean.TRUE.equals(row.getBuiltIn()),
                findRoleMenuIds(projectId, row.getId()),
                row.getCreatedAt(),
                row.getUpdatedAt());
    }

    private static ProjectMenuView toMenu(ProjectMenuRow row) {
        return new ProjectMenuView(
                row.getId(),
                row.getProjectId(),
                row.getParentId(),
                row.getMenuName(),
                row.getMenuNameKey(),
                row.getMenuType(),
                row.getRoutePath(),
                row.getComponentPath(),
                row.getPermissionCode(),
                row.getIcon(),
                row.getSortNo() == null ? 0 : row.getSortNo(),
                Boolean.TRUE.equals(row.getVisible()),
                row.getStatus(),
                row.getCreatedAt(),
                row.getUpdatedAt(),
                List.of());
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    public record MenuFields(
            String parentId,
            String menuName,
            String menuNameKey,
            String menuType,
            String routePath,
            String componentPath,
            String permissionCode,
            String icon,
            int sortNo,
            boolean visible) {}
}
