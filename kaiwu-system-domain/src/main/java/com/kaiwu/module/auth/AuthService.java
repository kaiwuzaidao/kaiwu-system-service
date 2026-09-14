package com.kaiwu.module.auth;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.auth.dto.ChangePasswordRequest;
import com.kaiwu.module.auth.dto.UpdateLocaleRequest;
import com.kaiwu.module.auth.vo.CurrentUserView;
import com.kaiwu.module.auth.vo.NavigationMenuView;
import com.kaiwu.module.auth.vo.TokenView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.LocalizationPort;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 用户名密码登录、刷新、登出与在线会话事实维护。
 */
@Service
public class AuthService {

    private final AuthRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final AccessTokenService accessTokenService;
    private final AuthProperties properties;
    private final SessionSnapshotPort sessionSnapshots;
    private final AuditPort auditService;
    private final LoginAttemptGuard loginAttemptGuard;
    private final LocalizationPort localization;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(
            AuthRepository repository,
            PasswordEncoder passwordEncoder,
            AccessTokenService accessTokenService,
            AuthProperties properties,
            SessionSnapshotPort sessionSnapshots,
            AuditPort auditService,
            LoginAttemptGuard loginAttemptGuard,
            LocalizationPort localization) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.accessTokenService = accessTokenService;
        this.properties = properties;
        this.sessionSnapshots = sessionSnapshots;
        this.auditService = auditService;
        this.loginAttemptGuard = loginAttemptGuard;
        this.localization = localization;
    }

    /**
     * 校验账号密码并建立在线会话。
     *
     * <p>用户名不存在与密码错误返回同一句提示，避免通过错误差异枚举账号。
     * 连续失败由 {@code LoginAttemptGuard} 限流。</p>
     */
    @Transactional
    public AuthSession login(String username, String password, RequestMetadata metadata) {
        // 锁定检查放在查库和校验密码之前：锁定期内不再消耗数据库与哈希计算。
        long lockedSeconds = loginAttemptGuard.lockedSeconds(username);
        if (lockedSeconds > 0) {
            AuthFailureException locked = accountLocked(lockedSeconds);
            auditService.recordLogin(username, null, "FAILED", locked.getMessage(), metadata);
            throw locked;
        }

        AuthRepository.UserAccount user;
        try {
            user = repository
                    .findUserByUsername(username)
                    .filter(account -> "ENABLED".equals(account.status()))
                    .orElseThrow(AuthService::invalidCredentials);
            if (!passwordEncoder.matches(password, user.passwordHash())) {
                throw invalidCredentials();
            }
        } catch (AuthFailureException exception) {
            boolean nowLocked = loginAttemptGuard.recordFailure(username);
            // 锁定这一刻单独记一条审计，便于从登录日志直接看出撞库被拦截。
            String message = nowLocked ? exception.getMessage() + "；连续失败次数过多，账号已临时锁定" : exception.getMessage();
            auditService.recordLogin(username, null, "FAILED", message, metadata);
            throw exception;
        }
        loginAttemptGuard.reset(username);

        String sessionId = UUID.randomUUID().toString();
        String refreshToken = sessionId + "." + randomSecret();
        Instant expiresAt = Instant.now().plusSeconds(properties.getRefreshTtlSeconds());
        Set<String> permissions = repository.findPermissions(user.id());
        repository.createSession(sessionId, user.id(), sha256(refreshToken), expiresAt);
        writeSessionSnapshot(sessionId, user, permissions, expiresAt);
        AuthSession result = authSession(user, permissions, sessionId, refreshToken, expiresAt);
        auditService.recordLogin(username, user.id(), "SUCCESS", "登录成功", metadata);
        return result;
    }

    /** 刷新令牌；会话必须仍为 ONLINE 且未过期，否则要求重新登录。 */
    @Transactional
    public AuthSession refresh(String refreshToken) {
        String sessionId = parseSessionId(refreshToken);
        AuthRepository.OnlineSession session =
                repository.findSession(sessionId).orElseThrow(AuthService::invalidRefreshToken);
        if (!"ONLINE".equals(session.status())
                || !session.expiresAt().isAfter(Instant.now())
                || !constantTimeEquals(session.refreshTokenHash(), sha256(refreshToken))) {
            throw invalidRefreshToken();
        }

        AuthRepository.UserAccount user = repository
                .findUserById(session.userId())
                .filter(account -> "ENABLED".equals(account.status()))
                .orElseThrow(AuthService::invalidRefreshToken);
        String rotatedRefreshToken = sessionId + "." + randomSecret();
        if (!repository.rotateRefreshToken(sessionId, sha256(refreshToken), sha256(rotatedRefreshToken))) {
            throw invalidRefreshToken();
        }
        Set<String> permissions = repository.findPermissions(user.id());
        writeSessionSnapshot(sessionId, user, permissions, session.expiresAt());
        return authSession(user, permissions, sessionId, rotatedRefreshToken, session.expiresAt());
    }

    /**
     * 主动登出：撤销会话事实与 Redis 快照，并写一条 LOGOUT 登录日志。
     *
     * <p>只记录用户自己发起的登出。管理员强制下线、改密码后踢其它会话都属于被动撤销，
     * 各自已有操作审计，不再重复写登录日志，避免安全运营中心出现噪音。
     *
     * @param context  当前登录上下文
     * @param metadata 审计用请求元数据
     */
    @Transactional
    public void logout(KaiwuContext context, RequestMetadata metadata) {
        repository.revokeSession(context.sessionId());
        sessionSnapshots.delete(context.sessionId());
        // 登录日志同时承载登出事件，安全运营中心才能看到完整的会话起止轨迹。
        repository
                .findUserById(context.userId())
                .ifPresent(user -> auditService.recordLogin(user.username(), user.id(), "LOGOUT", "退出登录", metadata));
    }

    /**
     * 当前登录用户自助修改密码。
     *
     * <p>校验旧密码后更新哈希，并撤销该用户除当前会话外的所有在线会话（含 Redis 快照），
     * 让其它端已泄露的凭据立即失效；当前会话保留，用户不必重新登录。
     *
     * <p>所有校验失败一律返回 400 而不是 401：前端 {@code apiRequest} 遇 401 会触发
     * 刷新令牌并跳登录页，旧密码输错不应把用户踢出登录态。
     *
     * @param context  当前登录上下文，提供用户 ID 与当前会话 ID
     * @param request  改密码请求（旧密码、新密码、确认密码）
     * @param metadata 审计用请求元数据
     * @throws ApiException 两次新密码不一致、超出 BCrypt 字节上限、旧密码错误或新旧密码相同
     */
    @Transactional
    public void changePassword(KaiwuContext context, ChangePasswordRequest request, RequestMetadata metadata) {
        if (!request.newPassword().equals(request.confirmPassword())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "两次输入的新密码不一致", "api.auth.password.mismatch");
        }
        // BCrypt 只取前 72 字节，中文密码可能字符数达标但字节数超限，需按字节再拦一次。
        if (request.newPassword().getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "新密码 UTF-8 编码后不能超过 72 字节", "api.auth.password.tooLong");
        }
        AuthRepository.UserAccount user = repository
                .findUserById(context.userId())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.user.notFound"));
        if (!passwordEncoder.matches(request.oldPassword(), user.passwordHash())) {
            // 审计走 REQUIRES_NEW，不受下面抛异常回滚影响，失败尝试可追溯。
            auditService.recordOperation(
                    context, "CHANGE_PASSWORD_FAILED", "/api/auth/password", "reason=旧密码错误", metadata);
            throw new ApiException(HttpStatus.BAD_REQUEST, "当前密码错误", "api.auth.password.incorrect");
        }
        if (passwordEncoder.matches(request.newPassword(), user.passwordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "新密码不能与当前密码相同", "api.auth.password.unchanged");
        }

        repository.updatePassword(user.id(), passwordEncoder.encode(request.newPassword()));
        revokeOtherSessions(user.id(), context.sessionId());
        auditService.recordOperation(context, "CHANGE_PASSWORD", "/api/auth/password", "self=true", metadata);
    }

    /** 下线该用户除当前会话外的所有在线会话，同时清理 Redis 会话快照。 */
    private void revokeOtherSessions(String userId, String keepSessionId) {
        List<String> sessionIds = repository.findOtherOnlineSessionIds(userId, keepSessionId);
        repository.revokeOtherSessions(userId, keepSessionId);
        sessionIds.forEach(sessionSnapshots::delete);
    }

    /** 当前登录用户的资料、权限码与导航菜单，供前端一次性初始化界面。 */
    public CurrentUserView currentUser(KaiwuContext context) {
        AuthRepository.UserAccount user = repository
                .findUserById(context.userId())
                .orElseThrow(() -> new AuthFailureException(HttpStatus.UNAUTHORIZED, "用户不存在", "api.user.notFound"));
        return new CurrentUserView(
                user.id(),
                user.username(),
                user.displayName(),
                context.permissions(),
                user.locale(),
                user.mustChangePassword());
    }

    /**
     * 修改当前用户自己的界面语言偏好。
     *
     * <p>userId 只取自已验证的 Gateway Context；请求体没有目标用户字段。locale 不进入
     * JWT、Context 或权限缓存，修改后当前会话继续有效。
     */
    @Transactional
    public CurrentUserView updateLocale(KaiwuContext context, UpdateLocaleRequest request) {
        String locale = request.locale().trim();
        if (!localization.selectableLocale(locale)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "暂不支持该语言", "api.locale.unsupported");
        }
        repository.updateLocale(context.userId(), locale);
        return currentUser(context);
    }

    /**
     * 当前用户的导航菜单树。
     *
     * <p>侧边栏由此驱动，前端不再维护第二份菜单定义。
     * 空目录会被剔除：用户对分组下所有页面都无权限时，留一个点不开的分组只会造成困惑。
     */
    public List<NavigationMenuView> navigationMenus(KaiwuContext context) {
        List<AuthRepository.NavigationRow> rows = repository.findNavigationMenus(context.userId());
        // 目录快照只取一次：一次导航要解析十余个菜单名，逐条解析会重复查 catalog revision。
        LocalizationPort.TextResolver localizedText = localization.resolver(
                repository
                        .findUserById(context.userId())
                        .map(AuthRepository.UserAccount::locale)
                        .orElse(null),
                false);
        Map<String, List<AuthRepository.NavigationRow>> childrenByParent = new LinkedHashMap<>();
        List<AuthRepository.NavigationRow> roots = new ArrayList<>();
        for (AuthRepository.NavigationRow row : rows) {
            if (row.parentId() == null) {
                roots.add(row);
            } else {
                childrenByParent
                        .computeIfAbsent(row.parentId(), ignored -> new ArrayList<>())
                        .add(row);
            }
        }
        List<NavigationMenuView> result = new ArrayList<>();
        for (AuthRepository.NavigationRow root : roots) {
            NavigationMenuView node = toNode(root, childrenByParent, localizedText);
            if (node != null) {
                result.add(node);
            }
        }
        return result;
    }

    private NavigationMenuView toNode(
            AuthRepository.NavigationRow row,
            Map<String, List<AuthRepository.NavigationRow>> childrenByParent,
            LocalizationPort.TextResolver localizedText) {
        List<NavigationMenuView> children = new ArrayList<>();
        for (AuthRepository.NavigationRow child : childrenByParent.getOrDefault(row.id(), List.of())) {
            NavigationMenuView node = toNode(child, childrenByParent, localizedText);
            if (node != null) {
                children.add(node);
            }
        }
        // 目录本身不可点击，没有可见子节点时整个分组都不返回。
        if ("DIRECTORY".equals(row.type()) && children.isEmpty()) {
            return null;
        }
        return new NavigationMenuView(
                row.id(), menuName(row, localizedText), row.type(), row.path(), row.icon(), children);
    }

    /**
     * 菜单名解析：引用的资源 → 录入原文（ADR 0015 起内联译文已退役）。
     *
     * <p>所有菜单都必须经过这里，绕开会让用户看到 key 或未翻译的原文。</p>
     */
    private String menuName(AuthRepository.NavigationRow row, LocalizationPort.TextResolver localizedText) {
        return localizedText.of(row.nameKey(), row.name());
    }

    private AuthSession authSession(
            AuthRepository.UserAccount user,
            Set<String> permissions,
            String sessionId,
            String refreshToken,
            Instant absoluteExpiresAt) {
        String accessToken = accessTokenService.issue(user.id(), sessionId, user.username());
        CurrentUserView currentUser = new CurrentUserView(
                user.id(), user.username(), user.displayName(), permissions, user.locale(), user.mustChangePassword());
        TokenView token = new TokenView(accessToken, properties.getAccessTtlSeconds(), currentUser);
        return new AuthSession(token, refreshToken, absoluteExpiresAt);
    }

    /** 仅供 Controller 将 Refresh Token 写入 HttpOnly Cookie，绝不进入响应 JSON。 */
    public record AuthSession(TokenView token, String refreshToken, Instant absoluteExpiresAt) {}

    private void writeSessionSnapshot(
            String sessionId, AuthRepository.UserAccount user, Set<String> permissions, Instant expiresAt) {
        sessionSnapshots.write(sessionId, user.id(), user.username(), permissions, expiresAt);
    }

    private String randomSecret() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String parseSessionId(String refreshToken) {
        if (refreshToken == null) {
            throw invalidRefreshToken();
        }
        int separator = refreshToken.indexOf('.');
        if (separator <= 0 || separator == refreshToken.length() - 1) {
            throw invalidRefreshToken();
        }
        try {
            UUID.fromString(refreshToken.substring(0, separator));
            return refreshToken.substring(0, separator);
        } catch (IllegalArgumentException exception) {
            throw invalidRefreshToken();
        }
    }

    private static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }

    private static boolean constantTimeEquals(String expected, String actual) {
        return expected != null
                && MessageDigest.isEqual(
                        expected.getBytes(StandardCharsets.US_ASCII), actual.getBytes(StandardCharsets.US_ASCII));
    }

    private static AuthFailureException invalidCredentials() {
        return new AuthFailureException(HttpStatus.UNAUTHORIZED, "用户名或密码错误", "api.auth.invalidCredentials");
    }

    /**
     * 锁定提示只给出剩余分钟数，不透露该用户名是否存在——否则锁定反而成了账号枚举渠道。
     */
    private static AuthFailureException accountLocked(long lockedSeconds) {
        long minutes = Math.max(1, (lockedSeconds + 59) / 60);
        return new AuthFailureException(
                HttpStatus.UNAUTHORIZED,
                "登录失败次数过多，请 " + minutes + " 分钟后再试",
                "api.auth.accountLocked",
                Map.of("minutes", minutes));
    }

    private static AuthFailureException invalidRefreshToken() {
        return new AuthFailureException(HttpStatus.UNAUTHORIZED, "刷新令牌无效或已过期", "api.auth.refreshInvalid");
    }
}
