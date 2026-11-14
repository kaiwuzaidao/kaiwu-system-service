package com.kaiwu.module.identity.model;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Set;
import org.junit.jupiter.api.Test;

/** CLI 会话权限范围：只保留允许的权限，其余来源原样返回。 */
class CliSessionScopeTest {

    private static final Set<String> USER_PERMISSIONS = Set.of(
            "system:project-factory:generate",
            "system:project:create",
            "system:project-factory:push",
            "system:dict:save",
            "system:user:save",
            "system:role:save",
            "system:project:update");

    /** CLI 会话拿不到用户管理、角色、仓库推送等范围外权限。 */
    @Test
    void cliSessionKeepsOnlyAllowedPermissions() {
        assertThat(CliSessionScope.limit("CLI", USER_PERMISSIONS))
                .containsExactlyInAnyOrder(
                        "system:project-factory:generate",
                        "system:project:create",
                        "system:dict:save",
                        CliSessionScope.PROJECT_ENTRY,
                        CliSessionScope.MARKER);
    }

    /** 用户本来就没有的权限不会被范围凭空补上。 */
    @Test
    void scopeNeverGrantsPermissionTheUserLacks() {
        assertThat(CliSessionScope.limit("CLI", Set.of("system:user:save"))).containsExactly(CliSessionScope.MARKER);
    }

    /** 平台级的项目成员、角色管理权限在范围内：命令行的 access 命令只服务平台管理员。 */
    @Test
    void platformMemberAndRoleManagementAreInScope() {
        assertThat(CliSessionScope.limit("CLI", Set.of("system:project:member", "system:project:role")))
                .contains("system:project:member", "system:project:role");
    }

    /** 对象存储的查看、保存（绑定）与测试在范围内（ADR 0040）。 */
    @Test
    void objectStorageManagementIsInScope() {
        assertThat(CliSessionScope.limit(
                        "CLI", Set.of("system:storage:list", "system:storage:save", "system:storage:test")))
                .contains("system:storage:list", "system:storage:save", "system:storage:test");
    }

    /** 标记只出现在 CLI 会话里。 */
    @Test
    void markerIsOnlyAddedToCliSessions() {
        assertThat(CliSessionScope.limit("WEB", USER_PERMISSIONS)).doesNotContain(CliSessionScope.MARKER);
        assertThat(CliSessionScope.limit(null, USER_PERMISSIONS)).doesNotContain(CliSessionScope.MARKER);
    }

    /** 网页会话和来源缺失的旧会话不受影响。 */
    @Test
    void webAndLegacySessionsAreUnchanged() {
        assertThat(CliSessionScope.limit("WEB", USER_PERMISSIONS)).isEqualTo(USER_PERMISSIONS);
        assertThat(CliSessionScope.limit(null, USER_PERMISSIONS)).isEqualTo(USER_PERMISSIONS);
    }
}
