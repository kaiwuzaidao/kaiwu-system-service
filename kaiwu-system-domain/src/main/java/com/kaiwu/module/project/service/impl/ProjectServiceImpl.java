package com.kaiwu.module.project.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.dto.*;
import com.kaiwu.module.project.model.GatewayRouteFragment;
import com.kaiwu.module.project.model.ProjectAccessPermissions;
import com.kaiwu.module.project.model.ProjectFilePermissions;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.service.SystemPermissionSessionService;
import com.kaiwu.module.project.vo.*;
import com.kaiwu.starter.KaiwuContext;
import java.util.*;
import java.util.concurrent.atomic.AtomicLong;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service("projectService")
public class ProjectServiceImpl implements ProjectService {

    private static final AtomicLong ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);
    private static final Pattern PERMISSION_CODE = Pattern.compile("[a-z][a-z0-9-]*:[a-z][a-z0-9-]*:[a-z][a-z0-9-]*");

    private final ProjectRepository repository;
    private final AuditService auditService;
    private final SystemPermissionSessionService sessionService;
    private final I18nService i18nService;

    private final boolean fileRegistryEnabled;

    @Autowired
    public ProjectServiceImpl(
            ProjectRepository repository,
            AuditService auditService,
            SystemPermissionSessionService sessionService,
            I18nService i18nService) {
        this(repository, auditService, sessionService, i18nService, ProjectFilePermissions.REGISTRY_ENABLED);
    }

    /** 可显式指定是否种入「文件」菜单，供测试在开关打开时验证。 */
    public ProjectServiceImpl(
            ProjectRepository repository,
            AuditService auditService,
            SystemPermissionSessionService sessionService,
            I18nService i18nService,
            boolean fileRegistryEnabled) {
        this.repository = repository;
        this.auditService = auditService;
        this.sessionService = sessionService;
        this.i18nService = i18nService;
        this.fileRegistryEnabled = fileRegistryEnabled;
    }

    /**
     * 项目分页；边界由 {@link PageBounds} 统一裁决，超出直接拒绝而不是静默截断，
     * 避免调用方以为拿到了全量。
     */
    public PageResult<ProjectView> page(String keyword, long current, long size) {
        return page(keyword, null, null, current, size);
    }

    /**
     * 按关键字、状态与是否内置筛选的项目分页；边界校验同 {@link #page(String, long, long)}。
     *
     * @param keyword 编码或名称关键字，空表示不过滤
     * @param status 项目状态，空表示不过滤
     * @param builtIn 是否平台内置项目，空表示不过滤
     * @param current 页码，从 1 开始
     * @param size 每页条数
     * @return 当前页项目与总数
     */
    @Override
    public PageResult<ProjectView> page(String keyword, String status, Boolean builtIn, long current, long size) {
        PageBounds.require(current, size);
        return repository.page(keyword, status, builtIn, current, size);
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
            repository.syncDefaultBackendService(projectId);
            repository.createRole(adminRoleId, projectId, "project-admin", "项目管理员", "拥有当前项目全部菜单与权限", true);
            repository.upsertMember(projectId, actor.userId(), "ACTIVE");
            repository.replaceMemberRoles(projectId, actor.userId(), Set.of(adminRoleId));
            seedAccessMenus(projectId);
            auditService.recordOperation(
                    actor, "project", "CREATE_PROJECT", "/api/projects", "targetProjectId=" + projectId, metadata);
            return requireProject(projectId);
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "项目编码已存在", "api.common.conflict");
        }
    }

    /**
     * 种入「成员管理」「角色授权」两组默认菜单（开关打开时还有「文件」）并授予项目管理员。
     *
     * <p>业务后台的项目成员、角色授权页面（项目模板自带）依赖这组按钮权限；项目一建好就有，
     * 项目创建人（管理员）立刻能用，也可以再把其中的按钮授予其他角色。菜单排在业务模块之后。</p>
     */
    private void seedAccessMenus(String projectId) {
        seedAccessMenu(
                projectId,
                "成员管理",
                "/project-members",
                "ProjectMembers",
                "TeamOutlined",
                900,
                List.of(
                        new AccessButton(ProjectAccessPermissions.MEMBER_LIST, "查看成员"),
                        new AccessButton(ProjectAccessPermissions.MEMBER_SAVE, "添加/编辑成员"),
                        new AccessButton(ProjectAccessPermissions.MEMBER_DELETE, "移除成员")));
        seedAccessMenu(
                projectId,
                "角色授权",
                "/project-roles",
                "ProjectRoles",
                "SafetyCertificateOutlined",
                910,
                List.of(
                        new AccessButton(ProjectAccessPermissions.ROLE_LIST, "查看角色"),
                        new AccessButton(ProjectAccessPermissions.ROLE_SAVE, "新增/编辑角色"),
                        new AccessButton(ProjectAccessPermissions.ROLE_GRANT, "授权菜单"),
                        new AccessButton(ProjectAccessPermissions.ROLE_DELETE, "删除角色")));
        if (fileRegistryEnabled) {
            // 文件管理页：数据在业务项目自己的库里（ADR 0041），平台只种入菜单与按钮。
            seedAccessMenu(
                    projectId,
                    "文件",
                    "/project-files",
                    "ProjectFiles",
                    "FolderOpenOutlined",
                    920,
                    List.of(
                            new AccessButton(ProjectFilePermissions.FILE_LIST, "查看文件"),
                            new AccessButton(ProjectFilePermissions.FILE_DOWNLOAD, "下载文件"),
                            new AccessButton(ProjectFilePermissions.FILE_DELETE, "删除文件")));
        }
    }

    private void seedAccessMenu(
            String projectId,
            String name,
            String route,
            String component,
            String icon,
            int sortNo,
            List<AccessButton> buttons) {
        String menuId = nextId();
        repository.createMenu(
                menuId,
                projectId,
                new ProjectRepository.MenuFields(null, name, null, "MENU", route, component, null, icon, sortNo, true));
        repository.grantMenuToAdmin(projectId, menuId);
        int buttonSort = 10;
        for (AccessButton button : buttons) {
            String buttonId = nextId();
            repository.createMenu(
                    buttonId,
                    projectId,
                    new ProjectRepository.MenuFields(
                            menuId,
                            button.name(),
                            null,
                            "BUTTON",
                            null,
                            null,
                            button.permission(),
                            null,
                            buttonSort,
                            true));
            repository.grantMenuToAdmin(projectId, buttonId);
            buttonSort += 10;
        }
    }

    /** 默认菜单下的一个按钮：权限码与显示名。 */
    private record AccessButton(String permission, String name) {}

    /** 专用写入只触及业务项目入口，其他元数据即使并发编辑也会保留。 */
    @Override
    @Transactional
    public ProjectView updateEntry(
            String projectId, ProjectEntryRequest entry, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        if (project.builtIn() || !"ACTIVE".equals(project.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "只有启用的业务项目可以登记入口", "api.common.conflict");
        }
        repository.updateEntry(
                projectId,
                "/apps/" + project.projectCode() + "/",
                entry.backendLabel().strip(),
                entry.serviceUrl());
        repository.syncDefaultBackendService(projectId);
        auditService.recordOperationInCallerTransaction(
                actor,
                "project",
                "UPDATE_PROJECT_ENTRY",
                "/api/projects/" + projectId + "/entry",
                "targetProjectId=" + projectId,
                metadata);
        return requireProject(projectId);
    }

    /** 编辑项目元数据；项目编码与内置标记不可改，不在本方法的入参里。 */
    @Transactional
    public ProjectView update(
            String projectId, ProjectUpdateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView previous = requireProject(projectId);
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
        repository.syncDefaultBackendService(projectId);
        if (!java.util.Objects.equals(
                previous.serviceUrl(),
                repository.findProject(projectId).map(ProjectView::serviceUrl).orElse(null))) {
            auditService.recordOperationInCallerTransaction(
                    actor,
                    "project",
                    "UPDATE_BACKEND_SERVICE",
                    "/api/projects/" + projectId + "/backend-services/default",
                    "projectId=" + projectId + ",serviceCode=default",
                    metadata);
        }
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

    public ProjectView project(String projectId) {
        return requireProject(projectId);
    }

    /** Agent status change locks the project and compares the server-frozen preview before writing. */
    @Transactional
    public ProjectView updateStatusForAgent(
            String projectId,
            String status,
            ProjectStatusExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (status == null || !Set.of("ACTIVE", "DISABLED", "ARCHIVED").contains(status) || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目状态非法", "api.common.badRequest");
        ProjectView project = repository
                .findProjectForUpdate(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound"));
        if (project.builtIn())
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置 system 项目不可停用或归档", "api.common.badRequest");
        if (!Objects.equals(project.projectCode(), expected.projectCode())
                || !Objects.equals(project.projectName(), expected.projectName())
                || !Objects.equals(project.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "项目已变化，请重新预览", "api.common.conflict");
        if (status.equals(project.status()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目状态没有变化", "api.common.badRequest");
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

    /** Rename only the project name, preserving routing and repository metadata. */
    @Transactional
    public ProjectView renameProjectForAgent(
            String projectId,
            String projectName,
            ProjectRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        if (projectName == null || projectName.isBlank() || projectName.trim().length() > 100 || expected == null)
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目名称不合法", "api.common.badRequest");
        ProjectView current = repository
                .findProjectForUpdate(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound"));
        if (!Objects.equals(current.projectCode(), expected.projectCode())
                || !Objects.equals(current.projectName(), expected.projectName())
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "项目已变化，请重新预览", "api.common.conflict");
        String name = projectName.trim();
        if (name.equals(current.projectName()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目名称没有变化", "api.common.badRequest");
        repository.updateProjectName(projectId, name);
        auditService.recordOperation(
                actor,
                "project",
                "UPDATE_PROJECT",
                "/api/projects/" + projectId,
                "targetProjectId=" + projectId,
                metadata);
        return requireProject(projectId);
    }

    public List<ProjectMemberView> members(String projectId) {
        requireProject(projectId);
        return repository.findMembers(projectId);
    }

    /** 项目内可授予的权限码：只取带权限码的按钮节点，附带所属菜单名。 */
    public List<ProjectPermissionView> permissions(String projectId) {
        requireProject(projectId);
        List<ProjectMenuView> all = repository.findMenus(projectId);
        Map<String, String> menuNames = new HashMap<>();
        all.forEach(menu -> menuNames.put(menu.id(), menu.menuName()));
        return all.stream()
                .filter(menu -> StringUtils.hasText(menu.permissionCode()))
                .map(menu -> new ProjectPermissionView(
                        menu.permissionCode(), menu.menuName(), menuNames.getOrDefault(menu.parentId(), "")))
                .sorted(Comparator.comparing(ProjectPermissionView::code))
                .toList();
    }

    /** 按登录名与角色编码保存成员；规则与按 ID 保存完全一致，只是先把名字解析成 ID。 */
    @Transactional
    public List<ProjectMemberView> saveMemberByUsername(
            String projectId,
            String username,
            Set<String> roleCodes,
            String status,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        String userId = repository
                .findEnabledUserId(username)
                .orElseThrow(
                        () -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在或已停用：" + username, "api.common.notFound"));
        Set<String> roleIds = roleIdsByCode(projectId, roleCodes);
        return saveMember(projectId, userId, new ProjectMemberRequest(roleIds, status), actor, metadata);
    }

    /** 按登录名移除成员。 */
    @Transactional
    public void deleteMemberByUsername(
            String projectId, String username, KaiwuContext actor, RequestMetadata metadata) {
        requireProject(projectId);
        String userId = repository
                .findEnabledUserId(username)
                .orElseThrow(
                        () -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在或已停用：" + username, "api.common.notFound"));
        deleteMember(projectId, userId, actor, metadata);
    }

    /** 按权限码整体替换角色授权；缺失的权限码一次性全部列出，方便调用方修正。 */
    @Transactional
    public ProjectRoleView grantRolePermissions(
            String projectId,
            String roleCode,
            Set<String> permissionCodes,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectRoleView role = repository.findRoles(projectId).stream()
                .filter(candidate -> candidate.roleCode().equals(roleCode))
                .findFirst()
                .orElseThrow(
                        () -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在：" + roleCode, "api.common.notFound"));
        Map<String, String> menuIdByPermission = new HashMap<>();
        repository.findMenus(projectId).stream()
                .filter(menu -> StringUtils.hasText(menu.permissionCode()))
                .forEach(menu -> menuIdByPermission.put(menu.permissionCode(), menu.id()));
        List<String> missing = permissionCodes.stream()
                .filter(code -> !menuIdByPermission.containsKey(code))
                .sorted()
                .toList();
        if (!missing.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "项目里没有这些权限码：" + String.join("、", missing), "api.common.badRequest");
        }
        Set<String> menuIds = new LinkedHashSet<>();
        permissionCodes.forEach(code -> menuIds.add(menuIdByPermission.get(code)));
        return grantRoleMenus(projectId, role.id(), menuIds, actor, metadata);
    }

    private Set<String> roleIdsByCode(String projectId, Set<String> roleCodes) {
        Map<String, String> idByCode = new HashMap<>();
        repository.findRoles(projectId).forEach(role -> idByCode.put(role.roleCode(), role.id()));
        List<String> missing = roleCodes.stream()
                .filter(code -> !idByCode.containsKey(code))
                .sorted()
                .toList();
        if (!missing.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST, "项目里没有这些角色：" + String.join("、", missing), "api.common.badRequest");
        }
        Set<String> ids = new LinkedHashSet<>();
        roleCodes.forEach(code -> ids.add(idByCode.get(code)));
        return ids;
    }

    /** 选人候选：关键字至少一个字符，避免空关键字一次列出全部用户。 */
    public List<ProjectMemberCandidateView> memberCandidates(String projectId, String keyword, int limit) {
        requireProject(projectId);
        if (!StringUtils.hasText(keyword)) {
            return List.of();
        }
        return repository.memberCandidates(projectId, keyword, limit);
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
        ProjectView project = lockedProject(projectId);
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
        ProjectView project = lockedProject(projectId);
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

    /** Project row serializes both UI and Agent member writes, including creation of a previously absent member. */
    private ProjectView lockedProject(String projectId) {
        return repository
                .findProjectForUpdate(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound"));
    }

    public Optional<ProjectMemberView> previewMemberSave(
            String projectId, String userId, ProjectMemberRequest request) {
        ProjectView project = requireProject(projectId);
        if (!repository.userExists(userId))
            throw new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.common.notFound");
        validateRoles(projectId, request.roleIds());
        if (project.createdBy().equals(userId)) {
            String adminRoleId = repository
                    .findProjectAdminRoleId(projectId)
                    .orElseThrow(() -> new ApiException(
                            HttpStatus.INTERNAL_SERVER_ERROR, "项目缺少内置 project-admin 角色", "api.common.internalError"));
            if (!"ACTIVE".equals(request.status()) || !request.roleIds().contains(adminRoleId))
                throw new ApiException(
                        HttpStatus.BAD_REQUEST, "项目创建人必须保持 ACTIVE 且保留 project-admin 角色", "api.common.badRequest");
        }
        Optional<ProjectMemberView> current = repository.findMember(projectId, userId);
        if (current.isPresent()
                && current.get().status().equals(request.status())
                && current.get().roleIds().equals(request.roleIds()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目成员没有变化", "api.common.badRequest");
        return current;
    }

    @Transactional
    public void saveMemberForAgent(
            String projectId,
            String userId,
            ProjectMemberRequest request,
            ProjectMemberExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        lockedProject(projectId);
        verifyMemberExpectation(projectId, userId, expected);
        saveMember(projectId, userId, request, actor, metadata);
    }

    public ProjectMemberView previewMemberDeletion(String projectId, String userId, KaiwuContext actor) {
        ProjectView project = requireProject(projectId);
        if (project.createdBy().equals(userId))
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能移除项目创建人", "api.common.badRequest");
        if (actor.userId().equals(userId))
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能移除当前登录用户自己", "api.common.badRequest");
        return repository
                .findMember(projectId, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目成员不存在", "api.common.notFound"));
    }

    @Transactional
    public void deleteMemberForAgent(
            String projectId,
            String userId,
            ProjectMemberExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        lockedProject(projectId);
        verifyMemberExpectation(projectId, userId, expected);
        deleteMember(projectId, userId, actor, metadata);
    }

    private void verifyMemberExpectation(String projectId, String userId, ProjectMemberExpectation expected) {
        Optional<ProjectMemberView> current = repository.findMember(projectId, userId);
        if (expected == null
                || current.isPresent() != expected.existed()
                || current.isPresent()
                        && (!Objects.equals(current.get().status(), expected.status())
                                || !Objects.equals(current.get().roleIds(), expected.roleIds())
                                || !Objects.equals(current.get().username(), expected.username())))
            throw new ApiException(HttpStatus.CONFLICT, "项目成员已变化，请重新确认", "api.common.conflict");
    }

    public List<ProjectRoleView> roles(String projectId) {
        requireProject(projectId);
        return repository.findRoles(projectId);
    }

    /** Agent preview uses the same immutable-role guard as the management page. */
    public ProjectRoleView editableRole(String projectId, String roleId) {
        requireProject(projectId);
        return requireMutableRole(projectId, roleId);
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

    /** Reject a pending Agent edit if the role changed after its confirmation preview. */
    @Transactional
    public ProjectRoleView updateRoleForAgent(
            String projectId,
            String roleId,
            ProjectRoleUpdateRequest request,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectRoleView current = repository
                .findRoleForUpdate(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
        if (current.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        }
        if (expected == null
                || !java.util.Objects.equals(current.roleCode(), expected.roleCode())
                || !java.util.Objects.equals(current.roleName(), expected.roleName())
                || !java.util.Objects.equals(current.description(), expected.description())
                || !java.util.Objects.equals(current.status(), expected.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "项目角色已变化，请重新确认", "api.common.conflict");
        }
        return updateRole(projectId, roleId, request, actor, metadata);
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

    /** Agent confirmation rejects a role whose identity or state changed after preview. */
    @Transactional
    public ProjectRoleView updateRoleStatusForAgent(
            String projectId,
            String roleId,
            String status,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectRoleView current = repository
                .findRoleForUpdate(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
        if (current.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        }
        if (expected == null
                || !java.util.Objects.equals(current.roleCode(), expected.roleCode())
                || !java.util.Objects.equals(current.roleName(), expected.roleName())
                || !java.util.Objects.equals(current.description(), expected.description())
                || !java.util.Objects.equals(current.status(), expected.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "项目角色已变化，请重新确认", "api.common.conflict");
        }
        if (!"ACTIVE".equals(status) && !"DISABLED".equals(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "角色状态非法", "api.common.badRequest");
        }
        if (status.equals(current.status())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目角色状态没有变化", "api.common.badRequest");
        }
        return updateRoleStatus(projectId, roleId, status, actor, metadata);
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

    /** Show only removable roles in an Agent deletion preview. */
    public ProjectRoleView previewRoleDeletion(String projectId, String roleId) {
        ProjectRoleView role = editableRole(projectId, roleId);
        if (repository.roleAssigned(projectId, roleId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目角色仍有成员使用", "api.common.badRequest");
        }
        return role;
    }

    /** The locked identity check and existing assigned-member guard run in one transaction. */
    @Transactional
    public void deleteRoleForAgent(
            String projectId,
            String roleId,
            ProjectRoleEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectRoleView current = repository
                .findRoleForUpdate(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
        if (current.builtIn()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        }
        if (expected == null
                || !java.util.Objects.equals(current.roleCode(), expected.roleCode())
                || !java.util.Objects.equals(current.roleName(), expected.roleName())
                || !java.util.Objects.equals(current.description(), expected.description())
                || !java.util.Objects.equals(current.status(), expected.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "项目角色已变化，请重新确认", "api.common.conflict");
        }
        deleteRole(projectId, roleId, actor, metadata);
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
        ProjectRoleView role = repository
                .findRoleForUpdate(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
        if (role.builtIn()) throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
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

    /** Validates the proposed full replacement without changing any role-menu rows. */
    public ProjectRoleView previewRoleMenuGrant(String projectId, String roleId, Set<String> menuIds) {
        ProjectRoleView role = editableRole(projectId, roleId);
        if (!repository.allMenusBelongToProject(projectId, menuIds))
            throw new ApiException(HttpStatus.BAD_REQUEST, "菜单集合包含其他项目的菜单", "api.common.badRequest");
        Set<String> expanded = expandAncestors(repository.findMenus(projectId), menuIds);
        if (expanded.equals(role.menuIds()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "角色菜单授权没有变化", "api.common.badRequest");
        return role;
    }

    /** The ordinary UI and Agent grant paths both lock the role row before replacing permissions. */
    @Transactional
    public ProjectRoleView grantRoleMenusForAgent(
            String projectId,
            String roleId,
            Set<String> menuIds,
            ProjectRoleMenuExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectRoleView current = repository
                .findRoleForUpdate(projectId, roleId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目角色不存在", "api.common.notFound"));
        if (current.builtIn()) throw new ApiException(HttpStatus.BAD_REQUEST, "内置项目管理员角色不可修改", "api.common.badRequest");
        if (expected == null
                || !Objects.equals(current.roleCode(), expected.roleCode())
                || !Objects.equals(current.roleName(), expected.roleName())
                || !Objects.equals(current.description(), expected.description())
                || !Objects.equals(current.status(), expected.status())
                || !Objects.equals(current.menuIds(), expected.menuIds()))
            throw new ApiException(HttpStatus.CONFLICT, "角色菜单授权已变化，请重新确认", "api.common.conflict");
        if (!repository.allMenusBelongToProject(projectId, menuIds))
            throw new ApiException(HttpStatus.BAD_REQUEST, "菜单集合包含其他项目的菜单", "api.common.badRequest");
        Set<String> expanded = expandAncestors(repository.findMenus(projectId), menuIds);
        if (expanded.equals(current.menuIds()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "角色菜单授权没有变化", "api.common.badRequest");
        return grantRoleMenus(projectId, roleId, menuIds, actor, metadata);
    }

    public List<ProjectMenuView> menus(String projectId) {
        requireProject(projectId);
        return tree(repository.findMenus(projectId), null, null);
    }

    /** Current target snapshot for an Agent write preview; project ownership comes from the repository lookup. */
    public ProjectMenuView menuForAgent(String projectId, String menuId) {
        requireProject(projectId);
        return requireMenu(projectId, menuId);
    }

    public ProjectMenuView previewMenuDeletion(String projectId, String menuId) {
        ProjectMenuView menu = menuForAgent(projectId, menuId);
        if (repository.menuHasChildren(projectId, menuId))
            throw new ApiException(HttpStatus.BAD_REQUEST, "请先删除项目子菜单", "api.common.badRequest");
        return menu;
    }

    /** Rechecks the preview against a locked row so a changed permission menu cannot be acted on silently. */
    @Transactional
    public ProjectMenuView updateMenuStatusForAgent(
            String projectId,
            String menuId,
            String status,
            ProjectMenuEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        verifyMenuPreview(projectId, menuId, expected);
        if (status.equals(expected.status()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目菜单状态没有变化", "api.common.badRequest");
        return updateMenuStatus(projectId, menuId, status, actor, metadata);
    }

    /** Deletion keeps the ordinary child guard and audit path after the locked preview comparison. */
    @Transactional
    public void deleteMenuForAgent(
            String projectId,
            String menuId,
            ProjectMenuEditExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        verifyMenuPreview(projectId, menuId, expected);
        deleteMenu(projectId, menuId, actor, metadata);
    }

    private void verifyMenuPreview(String projectId, String menuId, ProjectMenuEditExpectation expected) {
        requireProject(projectId);
        ProjectMenuView current = repository
                .findMenuForUpdate(projectId, menuId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目菜单不存在", "api.common.notFound"));
        if (expected == null
                || !Objects.equals(current.parentId(), expected.parentId())
                || !Objects.equals(current.menuName(), expected.menuName())
                || !Objects.equals(current.menuType(), expected.menuType())
                || !Objects.equals(current.permissionCode(), expected.permissionCode())
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "项目菜单已变化，请重新确认", "api.common.conflict");
    }

    /** 新建项目菜单；权限码在项目内唯一，父菜单必须同属该项目。 */
    @Transactional
    public ProjectMenuView createMenu(
            String projectId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        ProjectRepository.MenuFields fields = menuFields(projectId, request);
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

    /** Validates a proposed menu before presenting it for confirmation. */
    public ProjectView previewMenuCreation(String projectId, ProjectMenuRequest request) {
        ProjectView project = requireProject(projectId);
        validateMenu(projectId, null, menuFields(projectId, request));
        return project;
    }

    @Transactional
    public ProjectMenuView createMenuForAgent(
            String projectId,
            ProjectMenuRequest request,
            ProjectRenameExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        ProjectView current = repository
                .findProjectForUpdate(projectId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目不存在", "api.common.notFound"));
        if (expected == null
                || !Objects.equals(current.projectCode(), expected.projectCode())
                || !Objects.equals(current.projectName(), expected.projectName())
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "项目已变化，请重新确认", "api.common.conflict");
        return createMenu(projectId, request, actor, metadata);
    }

    /** 编辑项目菜单；权限码变更会影响已授权角色的实际权限，因此同样走唯一性校验。 */
    @Transactional
    public ProjectMenuView updateMenu(
            String projectId, String menuId, ProjectMenuRequest request, KaiwuContext actor, RequestMetadata metadata) {
        ProjectView project = requireProject(projectId);
        ProjectMenuView locked = repository
                .findMenuForUpdate(projectId, menuId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目菜单不存在", "api.common.notFound"));
        ProjectRepository.MenuFields fields = menuFields(projectId, request);
        validateMenu(projectId, menuId, fields);
        if ("BUTTON".equals(fields.menuType()) && repository.menuHasChildren(projectId, menuId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "存在子节点的菜单不能改为 BUTTON", "api.common.badRequest");
        }
        ensureNoMenuCycle(projectId, menuId, fields.parentId());
        repository.updateMenu(locked.id(), fields);
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

    /** Validates the proposed full edit while retaining the original menu for the confirmation preview. */
    public ProjectMenuView previewMenuUpdate(String projectId, String menuId, ProjectMenuRequest request) {
        ProjectMenuView current = menuForAgent(projectId, menuId);
        ProjectRepository.MenuFields fields = menuFields(projectId, request);
        validateMenu(projectId, menuId, fields);
        if ("BUTTON".equals(fields.menuType()) && repository.menuHasChildren(projectId, menuId))
            throw new ApiException(HttpStatus.BAD_REQUEST, "存在子节点的菜单不能改为 BUTTON", "api.common.badRequest");
        ensureNoMenuCycle(projectId, menuId, fields.parentId());
        if (sameMenuFields(current, fields))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目菜单没有变化", "api.common.badRequest");
        return current;
    }

    @Transactional
    public ProjectMenuView updateMenuForAgent(
            String projectId,
            String menuId,
            ProjectMenuRequest request,
            ProjectMenuFullExpectation expected,
            KaiwuContext actor,
            RequestMetadata metadata) {
        requireProject(projectId);
        ProjectMenuView current = repository
                .findMenuForUpdate(projectId, menuId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "项目菜单不存在", "api.common.notFound"));
        if (expected == null
                || !Objects.equals(current.parentId(), expected.parentId())
                || !Objects.equals(current.menuName(), expected.menuName())
                || !Objects.equals(normalize(current.menuNameKey()), expected.menuNameKey())
                || !Objects.equals(current.menuType(), expected.menuType())
                || !Objects.equals(normalize(current.routePath()), expected.routePath())
                || !Objects.equals(normalize(current.componentPath()), expected.componentPath())
                || !Objects.equals(normalize(current.permissionCode()), expected.permissionCode())
                || !Objects.equals(normalize(current.icon()), expected.icon())
                || current.sortNo() != expected.sortNo()
                || current.visible() != expected.visible()
                || !Objects.equals(current.status(), expected.status()))
            throw new ApiException(HttpStatus.CONFLICT, "项目菜单已变化，请重新确认", "api.common.conflict");
        if (sameMenuFields(current, menuFields(projectId, request)))
            throw new ApiException(HttpStatus.BAD_REQUEST, "项目菜单没有变化", "api.common.badRequest");
        return updateMenu(projectId, menuId, request, actor, metadata);
    }

    private static boolean sameMenuFields(ProjectMenuView current, ProjectRepository.MenuFields fields) {
        return Objects.equals(current.parentId(), fields.parentId())
                && Objects.equals(current.menuName(), fields.menuName())
                && Objects.equals(normalize(current.menuNameKey()), fields.menuNameKey())
                && Objects.equals(current.menuType(), fields.menuType())
                && Objects.equals(normalize(current.routePath()), fields.routePath())
                && Objects.equals(normalize(current.componentPath()), fields.componentPath())
                && Objects.equals(normalize(current.permissionCode()), fields.permissionCode())
                && Objects.equals(normalize(current.icon()), fields.icon())
                && current.sortNo() == fields.sortNo()
                && current.visible() == fields.visible();
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

    private ProjectRepository.MenuFields menuFields(String projectId, ProjectMenuRequest request) {
        String menuNameKey = normalize(request.menuNameKey());
        // 引用的 key 必须已存在，写入时就拒绝：留到展示时才发现意味着保存已经成功、
        // 界面却显示不出文案，错误发生地和暴露地相隔很远（ADR 0013 第 6 节）。
        if (StringUtils.hasText(menuNameKey) && !i18nService.messageKeyExists(projectId, menuNameKey)) {
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
