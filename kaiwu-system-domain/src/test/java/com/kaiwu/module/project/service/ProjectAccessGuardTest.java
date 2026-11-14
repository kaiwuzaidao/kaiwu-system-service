package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.identity.model.CliSessionScope;
import com.kaiwu.module.project.model.ProjectAccessPermissions;
import com.kaiwu.module.project.vo.CurrentProjectAccessView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** 项目内成员与角色授权守卫：以调用者在该项目里的权限码为准，内置项目不开放。 */
class ProjectAccessGuardTest {

    private final ProjectService projects = mock(ProjectService.class);
    private final ProjectAccessGuard guard = new ProjectAccessGuard(projects);
    private final KaiwuContext actor = new KaiwuContext(
            "7",
            "session-1",
            null,
            null,
            Set.of(),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "context-1");

    /** 持有对应权限码即放行。 */
    @Test
    void allowsCallerHoldingTheProjectPermission() {
        when(projects.currentAccess("10", "7")).thenReturn(access(false, Set.of(ProjectAccessPermissions.MEMBER_LIST)));

        assertThatCode(() -> guard.require("10", actor, ProjectAccessPermissions.MEMBER_LIST))
                .doesNotThrowAnyException();
    }

    /** 只有成员查看权限的人不能保存成员，也不能给角色授权。 */
    @Test
    void rejectsCallerWithoutTheRequestedPermission() {
        when(projects.currentAccess("10", "7")).thenReturn(access(false, Set.of(ProjectAccessPermissions.MEMBER_LIST)));

        assertThatThrownBy(() -> guard.require("10", actor, ProjectAccessPermissions.MEMBER_SAVE))
                .isInstanceOfSatisfying(
                        ApiException.class, e -> org.assertj.core.api.Assertions.assertThat(e.getStatus())
                                .isEqualTo(HttpStatus.FORBIDDEN));
        assertThatThrownBy(() -> guard.require("10", actor, ProjectAccessPermissions.ROLE_GRANT))
                .isInstanceOf(ApiException.class);
    }

    /** 内置 system 项目即使碰巧有同名权限码也不开放，它的成员与角色在平台项目管理里维护。 */
    @Test
    void rejectsBuiltInProjectEvenWithTheCode() {
        when(projects.currentAccess("1", "7")).thenReturn(access(true, Set.of(ProjectAccessPermissions.MEMBER_SAVE)));

        assertThatThrownBy(() -> guard.require("1", actor, ProjectAccessPermissions.MEMBER_SAVE))
                .isInstanceOf(ApiException.class);
    }

    /** 命令行会话只服务平台管理员：只有项目内权限码、没有平台级成员/角色管理权限时被拒。 */
    @Test
    void cliSessionWithoutPlatformPermissionIsRejected() {
        when(projects.currentAccess("10", "7"))
                .thenReturn(access(
                        false, Set.of(ProjectAccessPermissions.MEMBER_SAVE, ProjectAccessPermissions.ROLE_GRANT)));
        KaiwuContext cli = context(Set.of(CliSessionScope.MARKER));

        assertThatThrownBy(() -> guard.require("10", cli, ProjectAccessPermissions.MEMBER_SAVE))
                .isInstanceOfSatisfying(
                        ApiException.class, e -> org.assertj.core.api.Assertions.assertThat(e.getMessage())
                                .contains("平台管理员"));
        assertThatThrownBy(() -> guard.require("10", cli, ProjectAccessPermissions.ROLE_GRANT))
                .isInstanceOf(ApiException.class);
    }

    /** 命令行会话持有平台级权限时放行，且成员权限与角色权限各管各的。 */
    @Test
    void cliSessionWithPlatformPermissionIsAllowedPerArea() {
        when(projects.currentAccess("10", "7"))
                .thenReturn(access(
                        false, Set.of(ProjectAccessPermissions.MEMBER_SAVE, ProjectAccessPermissions.ROLE_GRANT)));
        KaiwuContext membersOnly = context(Set.of(CliSessionScope.MARKER, "system:project:member"));
        KaiwuContext rolesOnly = context(Set.of(CliSessionScope.MARKER, "system:project:role"));

        assertThatCode(() -> guard.require("10", membersOnly, ProjectAccessPermissions.MEMBER_SAVE))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> guard.require("10", membersOnly, ProjectAccessPermissions.ROLE_GRANT))
                .isInstanceOf(ApiException.class);
        assertThatCode(() -> guard.require("10", rolesOnly, ProjectAccessPermissions.ROLE_GRANT))
                .doesNotThrowAnyException();
    }

    /** 网页会话（没有标记）不受平台级限制，项目管理员照常在页面里管理。 */
    @Test
    void webSessionIsNotSubjectToThePlatformRequirement() {
        when(projects.currentAccess("10", "7")).thenReturn(access(false, Set.of(ProjectAccessPermissions.MEMBER_SAVE)));

        assertThatCode(() -> guard.require(
                        "10", context(Set.of("system:platform:read")), ProjectAccessPermissions.MEMBER_SAVE))
                .doesNotThrowAnyException();
    }

    private static KaiwuContext context(Set<String> permissions) {
        return new KaiwuContext(
                "7",
                "session-1",
                null,
                null,
                permissions,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    private static CurrentProjectAccessView access(boolean builtIn, Set<String> permissions) {
        LocalDateTime now = LocalDateTime.now();
        ProjectView project = new ProjectView(
                "10",
                "demo",
                "演示项目",
                null,
                "ACTIVE",
                builtIn,
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
        return new CurrentProjectAccessView(project, Set.of(), permissions, List.of(), "zh-CN");
    }
}
