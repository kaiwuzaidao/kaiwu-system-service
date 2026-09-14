package com.kaiwu.module.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.auth.dto.ChangePasswordRequest;
import com.kaiwu.module.auth.dto.UpdateLocaleRequest;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.LocalizationPort;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * 自助修改密码的校验与会话下线行为。
 */
class AuthServiceTest {

    private static final String CURRENT_SESSION = "session-current";

    private AuthRepository repository;
    private PasswordEncoder passwordEncoder;
    private SessionSnapshotPort sessionSnapshots;
    private AuditPort auditService;
    private LocalizationPort localization;
    private AccessTokenService accessTokenService;
    private AuthService service;
    private KaiwuContext context;

    @BeforeEach
    void setUp() {
        repository = mock(AuthRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        sessionSnapshots = mock(SessionSnapshotPort.class);
        auditService = mock(AuditPort.class);
        localization = mock(LocalizationPort.class);
        accessTokenService = mock(AccessTokenService.class);
        service = new AuthService(
                repository,
                passwordEncoder,
                accessTokenService,
                new AuthProperties(),
                sessionSnapshots,
                auditService,
                mock(LoginAttemptGuard.class),
                localization);
        context = new KaiwuContext(
                "1",
                CURRENT_SESSION,
                null,
                null,
                Set.of(),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    @Test
    void refreshRotatesRefreshTokenWithoutExtendingAbsoluteSession() {
        String sessionId = "d812671a-cb29-44bb-81e1-7c40878bbaf7";
        String oldRefreshToken = sessionId + ".old-secret";
        Instant absoluteExpiry = Instant.now().plusSeconds(3600);
        when(repository.findSession(sessionId))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        sessionId, "1", sha256(oldRefreshToken), "ONLINE", absoluteExpiry)));
        givenCurrentUser("old-hash");
        when(repository.findPermissions("1")).thenReturn(Set.of("system:platform:read"));
        when(repository.rotateRefreshToken(eq(sessionId), eq(sha256(oldRefreshToken)), anyString()))
                .thenReturn(true);
        when(accessTokenService.issue("1", sessionId, "admin")).thenReturn("new-access-token");
        AuthService.AuthSession refreshed = service.refresh(oldRefreshToken);

        assertThat(refreshed.refreshToken()).startsWith(sessionId + ".").isNotEqualTo(oldRefreshToken);
        assertThat(refreshed.absoluteExpiresAt()).isEqualTo(absoluteExpiry);
        assertThat(refreshed.token().accessToken()).isEqualTo("new-access-token");
        verify(repository).rotateRefreshToken(sessionId, sha256(oldRefreshToken), sha256(refreshed.refreshToken()));
    }

    @Test
    void refreshRejectsConcurrentUseOfAlreadyRotatedToken() {
        String sessionId = "d812671a-cb29-44bb-81e1-7c40878bbaf7";
        String oldRefreshToken = sessionId + ".old-secret";
        when(repository.findSession(sessionId))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        sessionId,
                        "1",
                        sha256(oldRefreshToken),
                        "ONLINE",
                        Instant.now().plusSeconds(3600))));
        givenCurrentUser("old-hash");
        when(repository.rotateRefreshToken(eq(sessionId), eq(sha256(oldRefreshToken)), anyString()))
                .thenReturn(false);

        assertThatThrownBy(() -> service.refresh(oldRefreshToken))
                .isInstanceOf(AuthFailureException.class)
                .hasMessageContaining("刷新令牌");
    }

    @Test
    void changesPasswordAndRevokesOnlyOtherSessions() {
        givenCurrentUser("old-hash");
        when(passwordEncoder.matches("old-password", "old-hash")).thenReturn(true);
        when(passwordEncoder.matches("new-password", "old-hash")).thenReturn(false);
        when(passwordEncoder.encode("new-password")).thenReturn("new-hash");
        when(repository.findOtherOnlineSessionIds("1", CURRENT_SESSION)).thenReturn(List.of("session-a", "session-b"));

        service.changePassword(
                context, new ChangePasswordRequest("old-password", "new-password", "new-password"), metadata());

        verify(repository).updatePassword("1", "new-hash");
        verify(repository).revokeOtherSessions("1", CURRENT_SESSION);
        verify(sessionSnapshots).delete("session-a");
        verify(sessionSnapshots).delete("session-b");
        // 当前会话必须保留，否则用户改完自己的密码就被踢下线。
        verify(sessionSnapshots, never()).delete(CURRENT_SESSION);
    }

    @Test
    void rejectsWrongOldPasswordWithoutTouchingPassword() {
        givenCurrentUser("old-hash");
        when(passwordEncoder.matches("wrong", "old-hash")).thenReturn(false);

        assertThatThrownBy(() -> service.changePassword(
                        context, new ChangePasswordRequest("wrong", "new-password", "new-password"), metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("当前密码错误");

        verify(repository, never()).updatePassword(anyString(), anyString());
        // 旧密码错误必须是 400：401 会让前端把用户踢去登录页。
        verify(auditService)
                .recordOperation(context, "CHANGE_PASSWORD_FAILED", "/api/auth/password", "reason=旧密码错误", metadata());
    }

    @Test
    void rejectsMismatchedConfirmation() {
        assertThatThrownBy(() -> service.changePassword(
                        context,
                        new ChangePasswordRequest("old-password", "new-password", "other-password"),
                        metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("两次输入的新密码不一致");

        verify(repository, never()).updatePassword(anyString(), anyString());
    }

    @Test
    void rejectsSamePassword() {
        givenCurrentUser("old-hash");
        when(passwordEncoder.matches("old-password", "old-hash")).thenReturn(true);

        assertThatThrownBy(() -> service.changePassword(
                        context, new ChangePasswordRequest("old-password", "old-password", "old-password"), metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("不能与当前密码相同");

        verify(repository, never()).updatePassword(anyString(), anyString());
    }

    @Test
    void rejectsPasswordExceedingBcryptByteLimit() {
        // 25 个三字节中文字符 = 75 字节，字符数合规但超出 BCrypt 的 72 字节上限。
        String longPassword = "密".repeat(25);

        assertThatThrownBy(() -> service.changePassword(
                        context, new ChangePasswordRequest("old-password", longPassword, longPassword), metadata()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("72 字节");

        verify(repository, never()).updatePassword(anyString(), anyString());
    }

    @Test
    void logoutRevokesSessionAndRecordsLoginLog() {
        givenCurrentUser("old-hash");

        service.logout(context, metadata());

        verify(repository).revokeSession(CURRENT_SESSION);
        verify(sessionSnapshots).delete(CURRENT_SESSION);
        verify(auditService).recordLogin("admin", "1", "LOGOUT", "退出登录", metadata());
    }

    @Test
    void logoutStillRevokesWhenUserRecordMissing() {
        // 用户已被删除但会话仍在时，撤销动作不能因为查不到用户名而被跳过。
        when(repository.findUserById("1")).thenReturn(Optional.empty());

        service.logout(context, metadata());

        verify(repository).revokeSession(CURRENT_SESSION);
        verify(sessionSnapshots).delete(CURRENT_SESSION);
        verify(auditService, never()).recordLogin(anyString(), anyString(), anyString(), anyString(), any());
    }

    @Test
    void navigationBuildsTreeAndDropsEmptyDirectories() {
        // 空目录快照：本用例只验树的组装与空目录剔除，菜单名一律回退录入原文。
        when(localization.resolver(org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyBoolean()))
                .thenReturn((key, fallback) -> fallback);
        when(repository.findNavigationMenus("1"))
                .thenReturn(java.util.List.of(
                        new AuthRepository.NavigationRow("10", null, "工作台", null, "MENU", "/", "DashboardOutlined", 10),
                        new AuthRepository.NavigationRow(
                                "9000000000000014000", null, "平台管理", null, "DIRECTORY", null, "SettingOutlined", 20),
                        new AuthRepository.NavigationRow(
                                "21", "9000000000000014000", "用户管理", null, "MENU", "/users", "UserOutlined", 10),
                        // 该目录下没有任何已授权子节点，不应出现在导航里。
                        new AuthRepository.NavigationRow(
                                "30", null, "研发交付", null, "DIRECTORY", null, "RocketOutlined", 60)));

        var tree = service.navigationMenus(context);

        assertThat(tree).hasSize(2);
        assertThat(tree.get(0).path()).isEqualTo("/");
        assertThat(tree.get(1).name()).isEqualTo("平台管理");
        assertThat(tree.get(1).children()).hasSize(1);
        assertThat(tree.get(1).children().getFirst().path()).isEqualTo("/users");
        assertThat(tree).noneMatch(node -> "研发交付".equals(node.name()));
    }

    @Test
    void updatesOnlyCurrentUsersDynamicallySelectedLocale() {
        when(localization.selectableLocale("ja-JP")).thenReturn(true);
        givenCurrentUser("old-hash");
        when(repository.findUserById("1"))
                .thenReturn(Optional.of(
                        new AuthRepository.UserAccount("1", "admin", "old-hash", "管理员", "ENABLED", "ja-JP", false)));

        var user = service.updateLocale(context, new UpdateLocaleRequest("ja-JP"));

        verify(repository).updateLocale("1", "ja-JP");
        assertThat(user.locale()).isEqualTo("ja-JP");
        assertThat(user.id()).isEqualTo("1");
    }

    @Test
    void rejectsUnsupportedLocaleWithoutUpdatingUser() {
        when(localization.selectableLocale("fr-FR")).thenReturn(false);
        assertThatThrownBy(() -> service.updateLocale(context, new UpdateLocaleRequest("fr-FR")))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("暂不支持");

        verify(repository, never()).updateLocale(anyString(), anyString());
    }

    private void givenCurrentUser(String passwordHash) {
        when(repository.findUserById("1"))
                .thenReturn(Optional.of(
                        new AuthRepository.UserAccount("1", "admin", passwordHash, "管理员", "ENABLED", "zh-CN", false)));
    }

    private static RequestMetadata metadata() {
        return new RequestMetadata("127.0.0.1", "trace-1");
    }

    private static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }
}
