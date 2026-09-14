package com.kaiwu.module.project;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.i18n.I18nService;
import com.kaiwu.module.project.dto.*;
import com.kaiwu.module.project.vo.*;
import com.kaiwu.starter.KaiwuContext;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.regex.Pattern;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ProjectService {

    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);
    private static final Pattern PERMISSION_CODE = Pattern.compile("[a-z][a-z0-9-]*:[a-z][a-z0-9-]*:[a-z][a-z0-9-]*");

    private final ProjectRepository repository;
    private final AuditService auditService;
    private final SystemPermissionSessionService sessionService;
    private final I18nService i18nService;

    public ProjectService(
            ProjectRepository repository,
            AuditService auditService,
            SystemPermissionSessionService sessionService,
            I18nService i18nService) {
        this.repository = repository;
        this.auditService = auditService;
        this.sessionService = sessionService;
        this.i18nService = i18nService;
    }

    /**
     * 项目分页；边界由 {@link PageBounds} 统一裁决，超出直接拒绝而不是静默截断，
     * 避免调用方以为拿到了全量。
     */
    public PageResult<ProjectView> page(String keyword, long current, long size) {
        PageBounds.require(current, size);
        return repository.page(keyword, current, size);
    }

    /**
     * 新建项目，并在同一事务内完成「项目 + 内置 project-admin 角色 + 创建人成员关系」三件事。
     *
     * <p>三者必须原子：只建项目不建管理员角色，会得到一个谁都进不去的项目。
     * 未指定包名时按项目编码推导默认值。</p>
     */
    @Transactional
    public ProjectView create(ProjectCreateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        String code = request.projectCode().trim();
        if (repository.projectCodeExists(code)) {
            throw new ApiException(HttpStatus.CONFLICT, "项目编码已存在", "api.common.conflict");
        }
        try {
            String projectId = nextId();
            String adminRoleId = nextId();
            String packageName = StringUtils.hasText(request.packageName())
                    ? request.packageName().trim()
                    : defaultPackageName(code);
            repository.createProject(
                    projectId, code, request.projectName().trim(), request.description(), actor.userId(), packageName);
            repository.createRole(adminRoleId, projectId, "project-admin", "项目管理员", "拥有当前项目全部菜单与权限", true);
            repository.upsertMember(projectId, actor.userId(), "ACTIVE");
            repository.replaceMemberRoles(projectId, actor.userId(), Set.of(adminRoleId));
            auditService.recordOperation(
                    actor, "project", "CREATE_PROJECT", "/api/projects", "targetProjectId=" + projectId, metadata);
            return requireProject(projectId);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "项目编码已存在", "api.common.conflict");
        }
    }

    /** 编辑项目元数据；项目编码与内置标记不可改，不在本方法的入参里。 */
    @Transactional
    public ProjectView update(
            String projectId, ProjectUpdateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireProject(projectId);
        repository.updateProject(
                projectId,
                request.projectName().trim(),
                request.description(),
                request.packageName().trim(),
                request.repositoryUrl(),
                request.gitlabProjectId(),
                request.defaultBranch(),
                request.backendUrl(),
                request.backendLabel(),
                request.serviceUrl());
        auditService.recordOperation(
                actor,
                "project",
                "UPDATE_PROJECT",
                "/api/projects/" + projectId,
                "targetProjectId=" + projectId,
                metadata);
        return requireProject(projectId);
    }

    /**
     * 生成该项目的 Gateway 显式路由片段。
     *
     * <p>未登记 {@code serviceUrl} 时拒绝而不是生成一段占位路由：一段 uri 写着占位符的
     * route 粘进配置后，表现是请求 502 而不是"没配"，排查方向会被带偏。</p>
     */
    public String gatewayRoute(String projectId) {
        ProjectView project = requireProject(projectId);
        if (project.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置 system 项目的路由由平台自身配置管理", "api.common.badRequest");
        }
        if (!StringUtils.hasText(project.serviceUrl())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "请先登记项目的服务地址", "api.project.serviceUrlRequired");
        }
        return GatewayRouteFragment.render(project);
    }

    /** 停用或归档项目；内置 system 项目被拒绝（CLAUDE.md 工程约束第 10 条）。 */
    @Transactional
    public ProjectView updateStatus(String projectId, String status, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        if (project.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置 system 项目不可停用或归档", "api.common.badRequest");
        }
        repository.updateProjectStatus(projectId, status);
        auditService.recordOperation(
                actor,
                "project",
                "CHANGE_PROJECT_STATUS",
                "/api/projects/" + projectId + "/status",
                "targetProjectId=" + projectId + ",status=" + status,
                metadata);
        return requireProject(projectId);
    }

    public List<ProjectMemberView> members(String projectId) {
        requireProject(projectId);
        return repository.findMembers(projectId);
    }

    /**
     * 新增或调整项目成员及其角色。
     *
     * <p>两条硬约束：角色必须属于本项目；**项目创建人必须保持 ACTIVE 且保留
     * project-admin 角色**——否则项目会失去唯一的管理入口。改动内置项目的成员时
     * 撤销该用户会话，避免旧权限快照继续生效。</p>
     */
    @Transactional
    public List<ProjectMemberView> saveMember(
            String projectId,
            String userId,
            ProjectMemberRequest request,
            KaiwuContext actor,
            RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        if (!repository.userExists(userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.common.notFound");
        }
        validateRoles(projectId, request.roleIds());
        if (project.createdBy().equals(userId)) {
            String projectAdminRoleId = repository
                    .findProjectAdminRoleId(projectId)
                    .orElseThrow(() -> new ApiException(
                            HttpStatus.INTERNAL_SERVER_ERROR, "项目缺少内置 project-admin 角色", "api.common.internalError"));
            if (!"ACTIVE".equals(request.status()) || !request.roleIds().contains(projectAdminRoleId)) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST, "项目创建人必须保持 ACTIVE 且保留 project-admin 角色", "api.common.badRequest");
            }
        }
        repository.upsertMember(projectId, userId, request.status());
        repository.replaceMemberRoles(projectId, userId, request.roleIds());
        if (project.builtIn()) sessionService.revokeUser(userId);
        auditService.recordOperation(
                actor,
                "project",
                "SAVE_PROJECT_MEMBER",
                "/api/projects/" + projectId + "/members/" + userId,
                "targetProjectId=" + projectId + ",targetUserId=" + userId,
                metadata);
        return repository.findMembers(projectId);
    }

    /** 移除项目成员；创建人和当前登录用户自己都不允许被移除。 */
    @Transactional
    public void deleteMember(String projectId, String userId, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        if (project.createdBy().equals(userId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能移除项目创建人", "api.common.badRequest");
        }
        if (actor.userId().equals(userId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能移除当前登录用户自己", "api.common.badRequest");
        }
        if (!repository.memberExists(projectId, userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "项目成员不存在", "api.common.notFound");
        }
        repository.deleteMember(projectId, userId);
        if (project.builtIn()) sessionService.revokeUser(userId);
        auditService.recordOperation(
                actor,
                "project",
                "DELETE_PROJECT_MEMBER",
                "/api/projects/" + projectId + "/members/" + userId,
                "targetProjectId=" + projectId + ",targetUserId=" + userId,
                metadata);
    }

    public List<ProjectRoleView> roles(String projectId) {
        requireProject(projectId);
        return repository.findRoles(projectId);
    }

    /** 新建项目角色；角色编码在项目内唯一。 */
    @Transactional
    public ProjectRoleView createRole(
            String projectId, ProjectRoleCreateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireProject(projectId);
        String code = request.roleCode().trim();
        if (repository.roleCodeExists(projectId, code)) {
            throw new ApiException(HttpStatus.CONFLICT, "项目角色编码已存在", "api.common.conflict");
        }
        String id = nextId();
        repository.createRole(id, projectId, code, request.roleName().trim(), request.description(), false);
        auditService.recordOperation(
                actor,
                "project",
                "CREATE_PROJECT_ROLE",
                "/api/projects/" + projectId + "/roles",
                "targetProjectId=" + projectId + ",targetRoleId=" + id,
                metadata);
        return requireRole(projectId, id);
    }

    /** 编辑项目角色名称与描述；内置角色不可改（见 requireMutableRole）。 */
    @Transactional
    public ProjectRoleView updateRole(
            String projectId,
            String roleId,
            ProjectRoleUpdateRequest request,
            KaiwuContext actor,
            RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMutableRole(projectId, roleId);
        repository.updateRole(roleId, request.roleName().trim(), request.description());
        if (project.builtIn()) sessionService.revokeRoleMembers(projectId, roleId);
        auditService.recordOperation(
                actor,
                "project",
                "UPDATE_PROJECT_ROLE",
                "/api/projects/" + projectId + "/roles/" + roleId,
                "targetProjectId=" + projectId + ",targetRoleId=" + roleId,
                metadata);
        return requireRole(projectId, roleId);
    }

    /** 启停项目角色；停用会让持有该角色的成员立即失去对应权限。 */
    @Transactional
    public ProjectRoleView updateRoleStatus(
            String projectId, String roleId, String status, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMutableRole(projectId, roleId);
        repository.updateRoleStatus(roleId, status);
        if (project.builtIn()) sessionService.revokeRoleMembers(projectId, roleId);
        auditService.recordOperation(
                actor,
                "project",
                "CHANGE_PROJECT_ROLE_STATUS",
                "/api/projects/" + projectId + "/roles/" + roleId + "/status",
                "targetProjectId=" + projectId + ",targetRoleId=" + roleId + ",status=" + status,
                metadata);
        return requireRole(projectId, roleId);
    }

    /**
     * 删除项目角色。
     *
     * <p>仍被成员引用时拒绝删除——先解绑再删，避免留下指向空角色的成员关系。
     * 内置角色不可删。</p>
     */
    @Transactional
    public void deleteRole(String projectId, String roleId, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMutableRole(projectId, roleId);
        if (repository.roleAssigned(projectId, roleId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目角色仍有成员使用", "api.common.badRequest");
        }
        repository.deleteRole(projectId, roleId);
        if (project.builtIn()) sessionService.revokeRoleMembers(projectId, roleId);
        auditService.recordOperation(
                actor,
                "project",
                "DELETE_PROJECT_ROLE",
                "/api/projects/" + projectId + "/roles/" + roleId,
                "targetProjectId=" + projectId + ",targetRoleId=" + roleId,
                metadata);
    }

    /**
     * 重设角色可见的菜单集合（全量覆盖，不是增量）。
     *
     * <p>菜单必须属于本项目，否则视为越权引用。内置项目授权变更后撤销受影响成员的会话。</p>
     */
    @Transactional
    public ProjectRoleView grantRoleMenus(
            String projectId, String roleId, Set<String> menuIds, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMutableRole(projectId, roleId);
        if (!repository.allMenusBelongToProject(projectId, menuIds)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "菜单集合包含其他项目的菜单", "api.common.badRequest");
        }
        Set<String> expanded = expandAncestors(repository.findMenus(projectId), menuIds);
        repository.replaceRoleMenus(projectId, roleId, expanded);
        if (project.builtIn()) sessionService.revokeRoleMembers(projectId, roleId);
        auditService.recordOperation(
                actor,
                "project",
                "GRANT_PROJECT_ROLE_MENUS",
                "/api/projects/" + projectId + "/roles/" + roleId + "/menus",
                "targetProjectId=" + projectId + ",targetRoleId=" + roleId + ",menuCount=" + expanded.size(),
                metadata);
        return requireRole(projectId, roleId);
    }

    public List<ProjectMenuView> menus(String projectId) {
        requireProject(projectId);
        return tree(repository.findMenus(projectId), null, null);
    }

    /** 新建项目菜单；权限码在项目内唯一，父菜单必须同属该项目。 */
    @Transactional
    public ProjectMenuView createMenu(
            String projectId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        ProjectRepository.MenuFields fields = menuFields(request);
        validateMenu(projectId, null, fields);
        String id = nextId();
        try {
            repository.createMenu(id, projectId, fields);
            repository.grantMenuToAdmin(projectId, id);
            if (project.builtIn()) sessionService.revokeProjectMembers(projectId);
            auditService.recordOperation(
                    actor,
                    "project",
                    "CREATE_PROJECT_MENU",
                    "/api/projects/" + projectId + "/menus",
                    "targetProjectId=" + projectId + ",targetMenuId=" + id,
                    metadata);
            return requireMenu(projectId, id);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "项目权限码已被使用", "api.common.conflict");
        }
    }

    /** 编辑项目菜单；权限码变更会影响已授权角色的实际权限，因此同样走唯一性校验。 */
    @Transactional
    public ProjectMenuView updateMenu(
            String projectId, String menuId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMenu(projectId, menuId);
        ProjectRepository.MenuFields fields = menuFields(request);
        validateMenu(projectId, menuId, fields);
        if ("BUTTON".equals(fields.menuType()) && repository.menuHasChildren(projectId, menuId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "存在子节点的菜单不能改为 BUTTON", "api.common.badRequest");
        }
        ensureNoMenuCycle(projectId, menuId, fields.parentId());
        repository.updateMenu(menuId, fields);
        if (project.builtIn()) sessionService.revokeProjectMembers(projectId);
        auditService.recordOperation(
                actor,
                "project",
                "UPDATE_PROJECT_MENU",
                "/api/projects/" + projectId + "/menus/" + menuId,
                "targetProjectId=" + projectId + ",targetMenuId=" + menuId,
                metadata);
        return requireMenu(projectId, menuId);
    }

    /** 启停项目菜单；停用即刻从所有角色的可见范围中消失。 */
    @Transactional
    public ProjectMenuView updateMenuStatus(
            String projectId, String menuId, String status, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMenu(projectId, menuId);
        repository.updateMenuStatus(menuId, status);
        if (project.builtIn()) sessionService.revokeProjectMembers(projectId);
        auditService.recordOperation(
                actor,
                "project",
                "CHANGE_PROJECT_MENU_STATUS",
                "/api/projects/" + projectId + "/menus/" + menuId + "/status",
                "targetProjectId=" + projectId + ",targetMenuId=" + menuId + ",status=" + status,
                metadata);
        return requireMenu(projectId, menuId);
    }

    /** 删除项目菜单；有子菜单时拒绝，先删子节点避免留下孤儿。 */
    @Transactional
    public void deleteMenu(String projectId, String menuId, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        requireMenu(projectId, menuId);
        if (repository.menuHasChildren(projectId, menuId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "请先删除项目子菜单", "api.common.badRequest");
        }
        repository.deleteMenu(projectId, menuId);
        if (project.builtIn()) sessionService.revokeProjectMembers(projectId);
        auditService.recordOperation(
                actor,
                "project",
                "DELETE_PROJECT_MENU",
                "/api/projects/" + projectId + "/menus/" + menuId,
                "targetProjectId=" + projectId + ",targetMenuId=" + menuId,
                metadata);
    }

    public List<ProjectView> currentProjects(String userId) {
        return repository.findCurrentProjects(userId);
    }

    /**
     * 当前用户在该项目下的访问快照：角色码、菜单 ID 与权限码。
     *
     * <p>供内嵌业务前端渲染菜单与按钮。项目非 ACTIVE、或用户不是有效成员时直接 403——
     * 这里是业务前端唯一的权限来源，宁可拒绝也不能返回空集合让前端以为「没有权限项」。</p>
     */
    public CurrentProjectAccessView currentAccess(String projectId, String userId) {
        ProjectView project = requireProject(projectId);
        if (!"ACTIVE".equals(project.status()) || !repository.activeMemberExists(projectId, userId)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "当前用户不是有效项目成员", "api.common.forbidden");
        }
        List<ProjectMenuView> all = repository.findMenus(projectId);
        Set<String> directIds = repository.findCurrentMenuIds(projectId, userId);
        Set<String> effectiveIds = expandAncestors(all, directIds);
        List<ProjectMenuView> effectiveTree = tree(all, null, effectiveIds);
        Set<String> permissions = new LinkedHashSet<>();
        flatten(effectiveTree).stream()
                .filter(menu -> StringUtils.hasText(menu.permissionCode()))
                .map(ProjectMenuView::permissionCode)
                .forEach(permissions::add);
        return new CurrentProjectAccessView(
                project,
                repository.findCurrentRoleCodes(projectId, userId),
                permissions,
                effectiveTree,
                repository.findUserLocale(userId));
    }

    private void validateRoles(String projectId, Set<String> roleIds) {
        if (roleIds.isEmpty() || !repository.allRolesBelongToProject(projectId, roleIds)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "必须选择当前项目的有效角色", "api.common.badRequest");
        }
        for (String roleId : roleIds) {
            if (!"ACTIVE".equals(requireRole(projectId, roleId).status())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "不能分配已停用的项目角色", "api.common.badRequest");
            }
        }
    }

    private void validateMenu(String projectId, String menuId, ProjectRepository.MenuFields fields) {
        if (fields.parentId() != null) {
            ProjectMenuView parent = requireMenu(projectId, fields.parentId());
            if ("BUTTON".equals(parent.menuType())) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "BUTTON 不能作为父节点", "api.common.badRequest");
            }
        }
        if ("MENU".equals(fields.menuType()) && !StringUtils.hasText(fields.routePath())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "MENU 必须配置路由路径", "api.common.badRequest");
        }
        if ("BUTTON".equals(fields.menuType()) && !StringUtils.hasText(fields.permissionCode())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "BUTTON 必须配置权限码", "api.common.badRequest");
        }
        if (StringUtils.hasText(fields.permissionCode())) {
            if (!PERMISSION_CODE.matcher(fields.permissionCode()).matches()) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "权限码必须符合 mod:res:act", "api.common.badRequest");
            }
            if (repository.menuPermissionUsed(projectId, fields.permissionCode(), menuId)) {
                throw new ApiException(HttpStatus.CONFLICT, "项目权限码已被使用", "api.common.conflict");
            }
        }
    }

    private ProjectRepository.MenuFields menuFields(ProjectMenuRequest request) {
        String menuNameKey = normalize(request.menuNameKey());
        // 引用的 key 必须已存在，写入时就拒绝：留到展示时才发现意味着保存已经成功、
        // 界面却显示不出文案，错误发生地和暴露地相隔很远（ADR 0013 第 6 节）。
        if (StringUtils.hasText(menuNameKey) && !i18nService.messageKeyExists(menuNameKey)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "国际化资源不存在：" + menuNameKey,
                    "api.i18n.keyNotFound",
                    Map.of("key", menuNameKey));
        }
        return new ProjectRepository.MenuFields(
                StringUtils.hasText(request.parentId()) ? request.parentId().trim() : null,
                request.menuName().trim(),
                menuNameKey,
                request.menuType(),
                request.routePath(),
                request.componentPath(),
                request.permissionCode(),
                request.icon(),
                request.sortNo(),
                request.visible());
    }

    private static String normalize(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private void ensureNoMenuCycle(String projectId, String menuId, String parentId) {
        Set<String> visited = new HashSet<>();
        String cursor = parentId;
        while (cursor != null) {
            if (menuId.equals(cursor) || !visited.add(cursor)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "项目菜单父子关系不能形成循环", "api.common.badRequest");
            }
            cursor = requireMenu(projectId, cursor).parentId();
        }
    }

    private Set<String> expandAncestors(List<ProjectMenuView> all, Set<String> selected) {
        Map<String, ProjectMenuView> byId = new HashMap<>();
        all.forEach(menu -> byId.put(menu.id(), menu));
        Set<String> result = new LinkedHashSet<>(selected);
        for (String id : selected) {
            ProjectMenuView cursor = byId.get(id);
            while (cursor != null && cursor.parentId() != null) {
                ProjectMenuView parent = byId.get(cursor.parentId());
                if (parent == null || !"ACTIVE".equals(parent.status())) break;
                result.add(parent.id());
                cursor = parent;
            }
        }
        return result;
    }

    private List<ProjectMenuView> tree(List<ProjectMenuView> all, String parentId, Set<String> allowedIds) {
        return all.stream()
                .filter(menu -> Objects.equals(menu.parentId(), parentId))
                .filter(menu -> allowedIds == null || allowedIds.contains(menu.id()))
                .filter(menu -> allowedIds == null || "ACTIVE".equals(menu.status()))
                .map(menu -> copyMenu(menu, tree(all, menu.id(), allowedIds)))
                .toList();
    }

    private ProjectMenuView copyMenu(ProjectMenuView menu, List<ProjectMenuView> children) {
        return new ProjectMenuView(
                menu.id(),
                menu.projectId(),
                menu.parentId(),
                menu.menuName(),
                menu.menuNameKey(),
                menu.menuType(),
                menu.routePath(),
                menu.componentPath(),
                menu.permissionCode(),
                menu.icon(),
                menu.sortNo(),
                menu.visible(),
                menu.status(),
                menu.createdAt(),
                menu.updatedAt(),
                children);
    }

    private List<ProjectMenuView> flatten(List<ProjectMenuView> tree) {
        List<ProjectMenuView> result = new ArrayList<>();
        tree.forEach(menu -> {
            result.add(menu);
            result.addAll(flatten(menu.children()));
        });
        return result;
    }

    private ProjectView requireProject(String id) {
        return repository
                .findProject(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound"));
    }

    private ProjectRoleView requireRole(String projectId, String roleId) {
        return repository
                .findRole(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
    }

    private ProjectRoleView requireMutableRole(String projectId, String roleId) {
        ProjectRoleView role = requireRole(projectId, roleId);
        if (role.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        }
        return role;
    }

    private ProjectMenuView requireMenu(String projectId, String menuId) {
        return repository
                .findMenu(projectId, menuId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目菜单不存在", "api.common.notFound"));
    }

    private static String nextId() {
        return String.valueOf(ID_SEQUENCE.incrementAndGet());
    }

    private static String defaultPackageName(String projectCode) {
        String suffix = projectCode.replaceAll("[^a-z0-9_]", "");
        return "com.kaiwu.business." + suffix;
    }
}
