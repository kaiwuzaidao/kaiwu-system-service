package com.kaiwu.module.user;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.audit.FieldChange;
import com.kaiwu.module.notification.NotificationService;
import com.kaiwu.module.user.dto.ResetPasswordRequest;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.dto.UserUpdateRequest;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 平台用户管理最小闭环。
 */
@Service
public class UserService {

    private static final AtomicLong USER_ID_SEQUENCE = new AtomicLong(System.currentTimeMillis() * 1_000_000L);

    private final UserRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final SessionSnapshotPort sessionSnapshots;
    private final AuditService auditService;
    private final NotificationService notificationService;
    private final Clock clock;

    public UserService(
            UserRepository repository,
            PasswordEncoder passwordEncoder,
            SessionSnapshotPort sessionSnapshots,
            AuditService auditService,
            NotificationService notificationService,
            Clock clock) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.sessionSnapshots = sessionSnapshots;
        this.auditService = auditService;
        this.notificationService = notificationService;
        this.clock = clock;
    }

    /** 用户分页；边界由 {@link PageBounds} 统一裁决，超出直接拒绝而不是静默截断。 */
    public PageResult<UserView> page(String keyword, long current, long size) {
        PageBounds.require(current, size);
        return repository.page(keyword, current, size);
    }

    /** 新建用户；初始密码由创建者设定并人工转达，强制首次登录改密。 */
    @Transactional
    public UserView create(UserCreateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        String username = request.username().trim();
        if (repository.existsByUsername(username)) {
            throw new ApiException(HttpStatus.CONFLICT, "用户名已存在", "api.user.usernameExists");
        }
        try {
            String id = String.valueOf(USER_ID_SEQUENCE.incrementAndGet());
            repository.create(
                    id,
                    username,
                    request.displayName().trim(),
                    request.email(),
                    passwordEncoder.encode(request.password()));
            UserView created = requireUser(id);
            auditService.recordOperation(actor, "CREATE_USER", "/api/users", "targetUserId=" + id, metadata);
            return created;
        } catch (DuplicateKeyException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "用户名已存在", "api.user.usernameExists");
        }
    }

    /** 编辑用户资料；用户名不可改，邮箱允许清空。 */
    @Transactional
    public UserView update(String id, UserUpdateRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireUser(id);
        repository.update(id, request.displayName().trim(), request.email());
        auditService.recordOperation(actor, "UPDATE_USER", "/api/users/" + id, "targetUserId=" + id, metadata);
        return requireUser(id);
    }

    /** 启停用户；停用会同时撤销其全部在线会话，避免已登录的人继续操作。 */
    @Transactional
    public UserView updateStatus(String id, String status, KaiwuContext actor, RequestMetadata metadata) {
        UserView target = requireUser(id);
        if (actor.userId().equals(id) && "DISABLED".equals(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能停用当前登录用户", "api.user.cannotDisableSelf");
        }
        repository.updateStatus(id, status);
        if ("DISABLED".equals(status)) {
            revokeSessions(id);
        }
        List<FieldChange> changes = new ArrayList<>();
        if (!Objects.equals(target.status(), status)) {
            changes.add(new FieldChange("status", target.status(), status));
        }
        auditService.recordOperationWithDiff(
                actor, "user", "CHANGE_USER_STATUS", "/api/users/" + id + "/status", "user", id, changes, metadata);
        return new UserView(
                target.id(),
                target.username(),
                target.displayName(),
                target.email(),
                status,
                target.createdAt(),
                java.time.LocalDateTime.now(clock));
    }

    /**
     * 管理员重置他人密码。
     *
     * <p>置强制改密标记并撤销该用户所有会话：临时密码经人工渠道传递，
     * 不应长期使用，也不能让旧会话绕过改密。</p>
     */
    @Transactional
    public void resetPassword(String id, ResetPasswordRequest request, KaiwuContext actor, RequestMetadata metadata) {
        requireUser(id);
        if (actor.userId().equals(id)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "请通过个人安全设置修改自己的密码", "api.user.changeOwnPassword");
        }
        repository.updatePassword(id, passwordEncoder.encode(request.newPassword()));
        revokeSessions(id);
        auditService.recordOperation(
                actor, "RESET_USER_PASSWORD", "/api/users/" + id + "/reset-password", "targetUserId=" + id, metadata);
        // 密码被他人重置、会话被强制下线，用户需要知情。
        notificationService.notifyUser(id, "SYSTEM", "你的密码已被管理员重置", "所有登录会话已失效，请使用新密码重新登录。若非本人知情，请联系平台管理员。", null);
    }

    private void revokeSessions(String userId) {
        List<String> sessionIds = repository.findOnlineSessionIds(userId);
        repository.revokeOnlineSessions(userId);
        sessionIds.forEach(sessionSnapshots::delete);
    }

    private UserView requireUser(String id) {
        return repository
                .findView(id)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "用户不存在", "api.user.notFound"));
    }
}
