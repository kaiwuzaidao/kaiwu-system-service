package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import com.kaiwu.module.project.dto.ProjectEntryRequest;
import com.kaiwu.module.project.dto.ProjectMemberRequest;
import com.kaiwu.module.project.dto.ProjectMenuRequest;
import com.kaiwu.module.project.dto.ProjectRoleUpdateRequest;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.impl.ProjectServiceImpl;
import com.kaiwu.module.project.vo.CurrentProjectAccessView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ProjectServiceTest {

    private ProjectRepository repository;
    private AuditService auditService;
    private SystemPermissionSessionService sessionService;
    private ProjectService service;
    private KaiwuContext actor;

    @BeforeEach
    void setUp() {
        repository = mock(ProjectRepository.class);
        auditService = mock(AuditService.class);
        sessionService = mock(SystemPermissionSessionService.class);
        service = new ProjectServiceImpl(repository, auditService, sessionService, mock(I18nService.class));
        actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:project:create"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    /** 入口登记仅写专用字段，并沿用同一事务的审计。 */
    @Test
    void cliEntryWritesOnlyEntryAndAuditsInSameTransaction() {
        when(repository.findProject("42")).thenReturn(Optional.of(project("42", "ACTIVE")));
        var request = new ProjectEntryRequest("书房", "http://demo:8080");
        service.updateEntry("42", request, actor, metadata());
        verify(repository).updateEntry("42", "/apps/demo/", "书房", "http://demo:8080");
        verify(repository).syncDefaultBackendService("42");
        verify(auditService)
                .recordOperationInCallerTransaction(
                        eq(actor),
                        eq("project"),
                        eq("UPDATE_PROJECT_ENTRY"),
                        eq("/api/projects/42/entry"),
                        eq("targetProjectId=42"),
                        any());
        verify(repository, never()).updateProject(any(), any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    /** 内置项目和停用项目即使收到合法请求也不能写入。 */
    @Test
    void cliEntryRejectsSystemAndInactiveProjects() {
        var request = new ProjectEntryRequest("书房", "http://demo:8080");
        for (var target : List.of(systemProject(), project("42", "DISABLED"))) {
            when(repository.findProject(target.id())).thenReturn(Optional.of(target));
            assertThatThrownBy(() -> service.updateEntry(target.id(), request, actor, metadata()))
                    .isInstanceOf(ApiException.class);
        }
        verify(repository, never()).updateEntry(any(), any(), any(), any());
    }

    @Test
    void createSeedsProjectAdminAndCreatorMembership() {
        when(repository.projectCodeExists("demo")).thenReturn(false);
        when(repository.findProject(anyString()))
                .thenAnswer(invocation -> Optional.of(project(invocation.getArgument(0), "ACTIVE")));

        ProjectView created = service.create(new ProjectCreateRequest("demo", "演示项目", null, null), actor, metadata());

        assertThat(created.id()).hasSize(19);
        verify(repository)
                .createProject(
                        eq(created.id()), eq("demo"), eq("演示项目"), isNull(), eq("1"), eq("com.kaiwu.business.demo"));
        verify(repository)
                .createRole(anyString(), eq(created.id()), eq("project-admin"), eq("项目管理员"), anyString(), eq(true));
        verify(repository).upsertMember(created.id(), "1", "ACTIVE");
        verify(repository).replaceMemberRoles(eq(created.id()), eq("1"), argThat(ids -> ids.size() == 1));
    }

    /** 「文件」开关打开后，新项目多一组「文件」菜单与三个按钮，同样授予项目管理员（ADR 0041）。 */
    @Test
    void createSeedsFileMenuWhenFileRegistryEnabled() {
        ProjectServiceImpl withFiles =
                new ProjectServiceImpl(repository, auditService, sessionService, mock(I18nService.class), true);
        when(repository.projectCodeExists("demo")).thenReturn(false);
        when(repository.findProject(anyString()))
                .thenAnswer(invocation -> Optional.of(project(invocation.getArgument(0), "ACTIVE")));

        ProjectView created = withFiles.create(new ProjectCreateRequest("demo", "演示项目", null, null), actor, metadata());

        ArgumentCaptor<ProjectRepository.MenuFields> fields =
                ArgumentCaptor.forClass(ProjectRepository.MenuFields.class);
        verify(repository, times(13)).createMenu(anyString(), eq(created.id()), fields.capture());
        assertThat(fields.getAllValues())
                .filteredOn(menu -> "/project-files".equals(menu.routePath()))
                .extracting(ProjectRepository.MenuFields::componentPath)
                .containsExactly("ProjectFiles");
        assertThat(fields.getAllValues())
                .extracting(ProjectRepository.MenuFields::permissionCode)
                .contains("file:record:list", "file:record:download", "file:record:delete");
    }

    /** 新项目默认带「成员管理」「角色授权」两组菜单与全部按钮，并授予项目管理员（创建人立刻可用）。 */
    @Test
    void createSeedsDefaultAccessMenusAndGrantsThemToProjectAdmin() {
        when(repository.projectCodeExists("demo")).thenReturn(false);
        when(repository.findProject(anyString()))
                .thenAnswer(invocation -> Optional.of(project(invocation.getArgument(0), "ACTIVE")));

        ProjectView created = service.create(new ProjectCreateRequest("demo", "演示项目", null, null), actor, metadata());

        ArgumentCaptor<ProjectRepository.MenuFields> fields =
                ArgumentCaptor.forClass(ProjectRepository.MenuFields.class);
        verify(repository, times(9)).createMenu(anyString(), eq(created.id()), fields.capture());
        assertThat(fields.getAllValues())
                .filteredOn(menu -> "MENU".equals(menu.menuType()))
                .extracting(ProjectRepository.MenuFields::routePath, ProjectRepository.MenuFields::componentPath)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("/project-members", "ProjectMembers"),
                        org.assertj.core.groups.Tuple.tuple("/project-roles", "ProjectRoles"));
        assertThat(fields.getAllValues())
                .filteredOn(menu -> "BUTTON".equals(menu.menuType()))
                .extracting(ProjectRepository.MenuFields::permissionCode)
                .containsExactly(
                        "access:member:list",
                        "access:member:save",
                        "access:member:delete",
                        "access:role:list",
                        "access:role:save",
                        "access:role:grant",
                        "access:role:delete");
        verify(repository, times(9)).grantMenuToAdmin(eq(created.id()), anyString());
    }

    /** 选人候选：空关键字不查库，避免一次列出全部用户。 */
    @Test
    void memberCandidatesRequireAKeyword() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.memberCandidates("10", "al", 20))
                .thenReturn(List.of(new com.kaiwu.module.project.vo.ProjectMemberCandidateView("2", "alice", "Alice")));

        assertThat(service.memberCandidates("10", "  ", 20)).isEmpty();
        assertThat(service.memberCandidates("10", "al", 20))
                .extracting(com.kaiwu.module.project.vo.ProjectMemberCandidateView::username)
                .containsExactly("alice");
        verify(repository, never()).memberCandidates(eq("10"), eq("  "), anyInt());
    }

    /** 按登录名与角色编码保存成员：服务端解析成 ID 后走与按 ID 保存相同的规则。 */
    @Test
    void saveMemberByUsernameResolvesUserAndRoleCodes() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findEnabledUserId("alice")).thenReturn(Optional.of("42"));
        when(repository.findRoles("10")).thenReturn(List.of(role(false)));
        when(repository.userExists("42")).thenReturn(true);
        when(repository.allRolesBelongToProject("10", Set.of("11"))).thenReturn(true);
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role(false)));

        service.saveMemberByUsername("10", "alice", Set.of("project-admin"), "ACTIVE", actor, metadata());

        verify(repository).upsertMember("10", "42", "ACTIVE");
        verify(repository).replaceMemberRoles("10", "42", Set.of("11"));
    }

    /** 登录名不存在、角色编码不存在都会得到明确错误，且不写库。 */
    @Test
    void saveMemberByUsernameRejectsUnknownUserAndUnknownRole() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findEnabledUserId("ghost")).thenReturn(Optional.empty());
        when(repository.findEnabledUserId("alice")).thenReturn(Optional.of("42"));
        when(repository.findRoles("10")).thenReturn(List.of(role(false)));

        assertThatThrownBy(() -> service.saveMemberByUsername(
                        "10", "ghost", Set.of("project-admin"), "ACTIVE", actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("ghost");
        assertThatThrownBy(
                        () -> service.saveMemberByUsername("10", "alice", Set.of("nope"), "ACTIVE", actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("nope");
        verify(repository, never()).upsertMember(anyString(), anyString(), anyString());
    }

    /** 按权限码授权：码解析成菜单节点，缺失的码一次性列全。 */
    @Test
    void grantRolePermissionsMapsCodesToMenusAndListsMissingOnes() {
        ProjectRoleView viewer = new ProjectRoleView(
                "12", "10", "viewer", "查看者", null, "ACTIVE", false, Set.of(), LocalDateTime.now(), LocalDateTime.now());
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findRoles("10")).thenReturn(List.of(viewer));
        when(repository.findRoleForUpdate("10", "12")).thenReturn(Optional.of(viewer));
        when(repository.findRole("10", "12")).thenReturn(Optional.of(viewer));
        List<ProjectMenuView> menus = List.of(menu("m1", null, null), menu("b1", "m1", "demo:order:list"));
        when(repository.findMenus("10")).thenReturn(menus);
        when(repository.allMenusBelongToProject(eq("10"), anySet())).thenReturn(true);

        service.grantRolePermissions("10", "viewer", Set.of("demo:order:list"), actor, metadata());

        verify(repository).replaceRoleMenus("10", "12", Set.of("b1", "m1"));
        assertThatThrownBy(() -> service.grantRolePermissions(
                        "10", "viewer", Set.of("demo:order:list", "x:y:z", "a:b:c"), actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("a:b:c")
                .hasMessageContaining("x:y:z");
    }

    /** 权限码清单只含带权限码的按钮，并附带所属菜单名。 */
    @Test
    void permissionsListOnlyButtonsWithTheirMenuName() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findMenus("10"))
                .thenReturn(List.of(menu("m1", null, null), menu("b1", "m1", "demo:order:list")));

        assertThat(service.permissions("10")).singleElement().satisfies(view -> {
            assertThat(view.code()).isEqualTo("demo:order:list");
            assertThat(view.menuName()).isEqualTo("m1");
        });
    }

    @Test
    void builtInProjectAdminCannotBeModified() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role(true)));

        assertThatThrownBy(() -> service.updateRoleStatus("10", "11", "DISABLED", actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("内置项目管理员");

        verify(repository, never()).updateRoleStatus(anyString(), anyString());
    }

    @Test
    void agentRoleEditUsesLockedSnapshotAndExistingServiceAudit() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var oldRole = new ProjectRoleView("11", "10", "reviewer", "旧名称", "旧描述", "ACTIVE", false, Set.of(), null, null);
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(oldRole));
        when(repository.findRole("10", "11")).thenReturn(Optional.of(oldRole));

        service.updateRoleForAgent(
                "10",
                "11",
                new ProjectRoleUpdateRequest("新名称", null),
                new ProjectService.ProjectRoleEditExpectation("reviewer", "旧名称", "旧描述", "ACTIVE"),
                actor,
                metadata());

        verify(repository).updateRole("11", "新名称", null);
        verify(auditService)
                .recordOperation(eq(actor), eq("project"), eq("UPDATE_PROJECT_ROLE"), anyString(), anyString(), any());
    }

    @Test
    void agentRoleEditRejectsChangedOrBuiltInRole() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findRoleForUpdate("10", "11"))
                .thenReturn(Optional.of(new ProjectRoleView(
                        "11", "10", "reviewer", "已改名", null, "ACTIVE", false, Set.of(), null, null)));
        assertThatThrownBy(() -> service.updateRoleForAgent(
                        "10",
                        "11",
                        new ProjectRoleUpdateRequest("新名称", null),
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "旧名称", null, "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(role(true)));
        assertThatThrownBy(() -> service.updateRoleForAgent(
                        "10",
                        "11",
                        new ProjectRoleUpdateRequest("新名称", null),
                        new ProjectService.ProjectRoleEditExpectation("project-admin", "项目管理员", null, "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("内置项目管理员");
        verify(repository, never()).updateRole(anyString(), anyString(), any());
    }

    @Test
    void agentRoleDeleteRechecksLockedIdentityAndMemberAssignments() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var role = new ProjectRoleView("11", "10", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null);
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role));
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(role));
        assertThat(service.previewRoleDeletion("10", "11").roleCode()).isEqualTo("reviewer");
        var expected = new ProjectService.ProjectRoleEditExpectation("reviewer", "审核员", null, "ACTIVE");
        when(repository.roleAssigned("10", "11")).thenReturn(true);
        assertThatThrownBy(() -> service.deleteRoleForAgent("10", "11", expected, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("仍有成员");
        verify(repository, never()).deleteRole(anyString(), anyString());
        when(repository.roleAssigned("10", "11")).thenReturn(false);
        service.deleteRoleForAgent("10", "11", expected, actor, metadata());
        verify(repository).deleteRole("10", "11");
    }

    @Test
    void agentRoleDeleteRejectsChangedRoleAndAssignedPreview() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var role = new ProjectRoleView("11", "10", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null);
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role));
        when(repository.roleAssigned("10", "11")).thenReturn(true);
        assertThatThrownBy(() -> service.previewRoleDeletion("10", "11"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("仍有成员");
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(role));
        assertThatThrownBy(() -> service.deleteRoleForAgent(
                        "10",
                        "11",
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "旧名称", null, "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).deleteRole(anyString(), anyString());
    }

    @Test
    void agentRoleStatusChecksLockedPreviewAndCallsExistingStatusService() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var role = new ProjectRoleView("11", "10", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null);
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(role));
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role));
        var expected = new ProjectService.ProjectRoleEditExpectation("reviewer", "审核员", null, "ACTIVE");

        service.updateRoleStatusForAgent("10", "11", "DISABLED", expected, actor, metadata());
        verify(repository).updateRoleStatus("11", "DISABLED");

        assertThatThrownBy(() -> service.updateRoleStatusForAgent(
                        "10",
                        "11",
                        "DISABLED",
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "旧名称", null, "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        assertThatThrownBy(() -> service.updateRoleStatusForAgent("10", "11", "ARCHIVED", expected, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("角色状态非法");
        verify(repository, times(1)).updateRoleStatus(anyString(), anyString());
    }

    @Test
    void agentRoleMenuGrantRejectsForeignMenusAndStalePermissions() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var role = new ProjectRoleView("11", "10", "reviewer", "审核员", null, "ACTIVE", false, Set.of("31"), null, null);
        when(repository.findRole("10", "11")).thenReturn(Optional.of(role));
        when(repository.findRoleForUpdate("10", "11")).thenReturn(Optional.of(role));
        when(repository.allMenusBelongToProject("10", Set.of("32"))).thenReturn(false);
        assertThatThrownBy(() -> service.previewRoleMenuGrant("10", "11", Set.of("32")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("其他项目");
        when(repository.allMenusBelongToProject("10", Set.of("32"))).thenReturn(true);
        assertThat(service.previewRoleMenuGrant("10", "11", Set.of("32")).menuIds())
                .containsExactly("31");
        var stale = new ProjectService.ProjectRoleMenuExpectation("reviewer", "审核员", null, "ACTIVE", Set.of("30"));
        assertThatThrownBy(() -> service.grantRoleMenusForAgent("10", "11", Set.of("32"), stale, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).replaceRoleMenus(anyString(), anyString(), anySet());
        var expected = new ProjectService.ProjectRoleMenuExpectation("reviewer", "审核员", null, "ACTIVE", Set.of("31"));
        service.grantRoleMenusForAgent("10", "11", Set.of("32"), expected, actor, metadata());
        verify(repository).replaceRoleMenus("10", "11", Set.of("32"));
        verify(auditService)
                .recordOperation(
                        eq(actor), eq("project"), eq("GRANT_PROJECT_ROLE_MENUS"), anyString(), anyString(), any());
    }

    @Test
    void agentMenuStatusRejectsStalePreviewBeforeRevokingPermissions() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var current = new ProjectMenuView(
                "12",
                "10",
                null,
                "新名称",
                null,
                "BUTTON",
                null,
                null,
                "demo:edit",
                null,
                1,
                true,
                "ACTIVE",
                null,
                null,
                null);
        when(repository.findMenuForUpdate("10", "12")).thenReturn(Optional.of(current));
        var expected = new ProjectService.ProjectMenuEditExpectation(null, "旧名称", "BUTTON", "demo:edit", "ACTIVE");
        assertThatThrownBy(() -> service.updateMenuStatusForAgent("10", "12", "DISABLED", expected, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).updateMenuStatus(anyString(), anyString());

        when(repository.findMenu("10", "12")).thenReturn(Optional.of(current));
        service.updateMenuStatusForAgent(
                "10",
                "12",
                "DISABLED",
                new ProjectService.ProjectMenuEditExpectation(null, "新名称", "BUTTON", "demo:edit", "ACTIVE"),
                actor,
                metadata());
        verify(repository).updateMenuStatus("12", "DISABLED");
    }

    @Test
    void agentMenuDeletionKeepsChildGuardAndLockedIdentity() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var current = new ProjectMenuView(
                "12", "10", null, "菜单", null, "MENU", "/demo", null, null, null, 1, true, "ACTIVE", null, null, null);
        when(repository.findMenu("10", "12")).thenReturn(Optional.of(current));
        when(repository.findMenuForUpdate("10", "12")).thenReturn(Optional.of(current));
        when(repository.menuHasChildren("10", "12")).thenReturn(true);
        assertThatThrownBy(() -> service.previewMenuDeletion("10", "12"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("子菜单");
        var expected = new ProjectService.ProjectMenuEditExpectation(null, "菜单", "MENU", null, "ACTIVE");
        assertThatThrownBy(() -> service.deleteMenuForAgent("10", "12", expected, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("子菜单");
        verify(repository, never()).deleteMenu(anyString(), anyString());
        when(repository.menuHasChildren("10", "12")).thenReturn(false);
        service.deleteMenuForAgent("10", "12", expected, actor, metadata());
        verify(repository).deleteMenu("10", "12");
    }

    @Test
    void agentMenuCreationRejectsChangedProjectBeforeWrite() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var request = new ProjectMenuRequest(null, "菜单", null, "DIR", null, null, null, null, 0, true);
        assertThatThrownBy(() -> service.createMenuForAgent(
                        "10",
                        request,
                        new ProjectService.ProjectRenameExpectation("demo", "旧名称", "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).createMenu(anyString(), anyString(), any());
    }

    @Test
    void agentFullMenuEditRejectsChangedRouteAndPermission() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        var current = new ProjectMenuView(
                "12",
                "10",
                null,
                "菜单",
                null,
                "MENU",
                "/new-route",
                "Demo",
                "demo:menu:view",
                null,
                1,
                true,
                "ACTIVE",
                null,
                null,
                null);
        when(repository.findMenuForUpdate("10", "12")).thenReturn(Optional.of(current));
        var request =
                new ProjectMenuRequest(null, "新菜单", null, "MENU", "/updated", "Demo", "demo:menu:view", null, 1, true);
        var expected = new ProjectService.ProjectMenuFullExpectation(
                null, "菜单", null, "MENU", "/old-route", "Demo", "demo:menu:view", null, 1, true, "ACTIVE");
        assertThatThrownBy(() -> service.updateMenuForAgent("10", "12", request, expected, actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).updateMenu(anyString(), any());
    }

    @Test
    void builtInSystemProjectCannotBeDisabledOrArchived() {
        when(repository.findProject("10")).thenReturn(Optional.of(systemProject()));

        assertThatThrownBy(() -> service.updateStatus("10", "ARCHIVED", actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("system 项目");

        verify(repository, never()).updateProjectStatus(anyString(), anyString());
    }

    @Test
    void agentProjectStatusUpdatePreservesIdentityAfterLockedPreviewCheck() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "DISABLED")));

        var updated = service.updateStatusForAgent(
                "10",
                "DISABLED",
                new ProjectService.ProjectStatusExpectation("demo", "演示项目", "ACTIVE"),
                actor,
                metadata());

        assertThat(updated.status()).isEqualTo("DISABLED");
        verify(repository).updateProjectStatus("10", "DISABLED");
    }

    @Test
    void agentProjectStatusUpdateRejectsChangedOrBuiltInProject() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        assertThatThrownBy(() -> service.updateStatusForAgent(
                        "10",
                        "DISABLED",
                        new ProjectService.ProjectStatusExpectation("demo", "旧项目名", "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("项目已变化");
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(systemProject()));
        assertThatThrownBy(() -> service.updateStatusForAgent(
                        "10",
                        "DISABLED",
                        new ProjectService.ProjectStatusExpectation("system", "Kaiwu System", "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("内置 system 项目");
        verify(repository, never()).updateProjectStatus(anyString(), anyString());
    }

    @Test
    void agentProjectRenameChangesOnlyNameAfterLockedComparison() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));

        service.renameProjectForAgent(
                "10", "新项目名", new ProjectService.ProjectRenameExpectation("demo", "演示项目", "ACTIVE"), actor, metadata());

        verify(repository).updateProjectName("10", "新项目名");
        verify(repository, never()).updateProject(any(), any(), any(), any(), any(), any(), any(), any(), any(), any());
    }

    @Test
    void agentProjectRenameRejectsStaleName() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));

        assertThatThrownBy(() -> service.renameProjectForAgent(
                        "10",
                        "新项目名",
                        new ProjectService.ProjectRenameExpectation("demo", "别人已改名", "ACTIVE"),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("项目已变化");
        verify(repository, never()).updateProjectName(anyString(), anyString());
    }

    @Test
    void creatorMustRemainActiveProjectAdmin() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.userExists("1")).thenReturn(true);
        when(repository.allRolesBelongToProject("10", Set.of("12"))).thenReturn(true);
        when(repository.findRole("10", "12"))
                .thenReturn(Optional.of(new ProjectRoleView(
                        "12",
                        "10",
                        "developer",
                        "开发者",
                        null,
                        "ACTIVE",
                        false,
                        Set.of(),
                        LocalDateTime.now(),
                        LocalDateTime.now())));
        when(repository.findProjectAdminRoleId("10")).thenReturn(Optional.of("11"));

        assertThatThrownBy(() -> service.saveMember(
                        "10", "1", new ProjectMemberRequest(Set.of("12"), "ACTIVE"), actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("project-admin");

        verify(repository, never()).upsertMember(anyString(), anyString(), anyString());
    }

    @Test
    void agentMemberSaveRejectsChangedSnapshotBeforeWrite() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.findMember("10", "20"))
                .thenReturn(Optional.of(new com.kaiwu.module.project.vo.ProjectMemberView(
                        "20", "alice", "Alice", "DISABLED", Set.of("12"), null, null)));

        assertThatThrownBy(() -> service.saveMemberForAgent(
                        "10",
                        "20",
                        new ProjectMemberRequest(Set.of("12"), "ACTIVE"),
                        new ProjectService.ProjectMemberExpectation(true, "alice", "ACTIVE", Set.of("12")),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).upsertMember(anyString(), anyString(), anyString());
    }

    @Test
    void agentMemberCreateUsesExistingServiceAndProjectRoleValidation() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.userExists("20")).thenReturn(true);
        when(repository.allRolesBelongToProject("10", Set.of("12"))).thenReturn(true);
        when(repository.findRole("10", "12"))
                .thenReturn(Optional.of(new ProjectRoleView(
                        "12", "10", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null)));

        service.saveMemberForAgent(
                "10",
                "20",
                new ProjectMemberRequest(Set.of("12"), "ACTIVE"),
                new ProjectService.ProjectMemberExpectation(false, "", "", Set.of()),
                actor,
                metadata());

        verify(repository).upsertMember("10", "20", "ACTIVE");
        verify(repository).replaceMemberRoles("10", "20", Set.of("12"));
        verify(auditService)
                .recordOperation(eq(actor), eq("project"), eq("SAVE_PROJECT_MEMBER"), anyString(), anyString(), any());
    }

    @Test
    void agentMemberDeleteRejectsMissingMemberBeforeWrite() {
        when(repository.findProjectForUpdate("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        assertThatThrownBy(() -> service.deleteMemberForAgent(
                        "10",
                        "20",
                        new ProjectService.ProjectMemberExpectation(true, "alice", "ACTIVE", Set.of("12")),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("已变化");
        verify(repository, never()).deleteMember(anyString(), anyString());
    }

    @Test
    void projectButtonPermissionMustUseThreePartCode() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));

        assertThatThrownBy(() -> service.createMenu(
                        "10",
                        new ProjectMenuRequest(
                                null, "错误按钮", null, "BUTTON", null, null, "invalid-permission", null, 1, true),
                        actor,
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("mod:res:act");

        verify(repository, never()).createMenu(anyString(), anyString(), any());
    }

    @Test
    void createMenuPersistsConfiguredIcon() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        LocalDateTime now = LocalDateTime.now();
        when(repository.findMenu(eq("10"), anyString()))
                .thenReturn(Optional.of(new ProjectMenuView(
                        "20",
                        "10",
                        null,
                        "工作台",
                        null,
                        "MENU",
                        "/dashboard",
                        "Dashboard",
                        null,
                        "DashboardOutlined",
                        1,
                        true,
                        "ACTIVE",
                        now,
                        now,
                        List.of())));

        service.createMenu(
                "10",
                new ProjectMenuRequest(
                        null, "工作台", null, "MENU", "/dashboard", "Dashboard", null, "DashboardOutlined", 1, true),
                actor,
                metadata());

        ArgumentCaptor<ProjectRepository.MenuFields> fields =
                ArgumentCaptor.forClass(ProjectRepository.MenuFields.class);
        verify(repository).createMenu(anyString(), eq("10"), fields.capture());
        assertThat(fields.getValue().icon()).isEqualTo("DashboardOutlined");
    }

    @Test
    void currentAccessAddsAncestorsAndReturnsOnlyMemberMenus() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
        when(repository.activeMemberExists("10", "1")).thenReturn(true);
        ProjectMenuView root = menu("20", null, "demo:dashboard:view");
        ProjectMenuView child = menu("21", "20", "demo:orders:list");
        when(repository.findMenus("10")).thenReturn(List.of(root, child));
        when(repository.findCurrentMenuIds("10", "1")).thenReturn(Set.of("21"));
        when(repository.findCurrentRoleCodes("10", "1")).thenReturn(Set.of("developer"));

        CurrentProjectAccessView access = service.currentAccess("10", "1");

        assertThat(access.roleCodes()).containsExactly("developer");
        assertThat(access.permissions()).containsExactly("demo:dashboard:view", "demo:orders:list");
        assertThat(access.menus())
                .singleElement()
                // 用 hasSize(1) 而不是 singleElement()：后者会把子节点抽出来返回一个新断言，
                // 不接着断言就等于抽了个寂寞——这里要表达的就是「只有一个子菜单」。
                .satisfies(item -> assertThat(item.children()).hasSize(1));
    }

    private static ProjectView project(String id, String status) {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectView(
                id,
                "demo",
                "演示项目",
                null,
                status,
                false,
                "1",
                "com.kaiwu.business.demo",
                null,
                null,
                "main",
                null,
                null,
                null,
                now,
                now);
    }

    private static ProjectView systemProject() {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectView(
                "10",
                "system",
                "Kaiwu System",
                null,
                "ACTIVE",
                true,
                "1",
                "com.kaiwu",
                null,
                null,
                "main",
                null,
                null,
                null,
                now,
                now);
    }

    private static ProjectRoleView role(boolean builtIn) {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectRoleView("11", "10", "project-admin", "项目管理员", null, "ACTIVE", builtIn, Set.of(), now, now);
    }

    private static ProjectMenuView menu(String id, String parentId, String permission) {
        LocalDateTime now = LocalDateTime.now();
        return new ProjectMenuView(
                id,
                "10",
                parentId,
                id,
                null,
                parentId == null ? "MENU" : "BUTTON",
                parentId == null ? "/demo" : null,
                null,
                permission,
                null,
                1,
                true,
                "ACTIVE",
                now,
                now,
                List.of());
    }

    private static RequestMetadata metadata() {
        return new RequestMetadata("127.0.0.1", "trace-project");
    }
}
