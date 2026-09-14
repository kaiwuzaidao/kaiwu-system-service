package com.kaiwu.module.project;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.i18n.I18nService;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import com.kaiwu.module.project.dto.ProjectMemberRequest;
import com.kaiwu.module.project.dto.ProjectMenuRequest;
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
        service = new ProjectService(repository, auditService, sessionService, mock(I18nService.class));
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
    void builtInSystemProjectCannotBeDisabledOrArchived() {
        when(repository.findProject("10")).thenReturn(Optional.of(systemProject()));

        assertThatThrownBy(() -> service.updateStatus("10", "ARCHIVED", actor, metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("system 项目");

        verify(repository, never()).updateProjectStatus(anyString(), anyString());
    }

    @Test
    void creatorMustRemainActiveProjectAdmin() {
        when(repository.findProject("10")).thenReturn(Optional.of(project("10", "ACTIVE")));
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
