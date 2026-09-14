package com.kaiwu.module.audit;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.audit.entity.LoginLogEntity;
import com.kaiwu.module.audit.entity.OnlineSessionJoinRow;
import com.kaiwu.module.audit.entity.OperationLogEntity;
import com.kaiwu.module.audit.mapper.LoginLogMapper;
import com.kaiwu.module.audit.mapper.OnlineSessionQueryMapper;
import com.kaiwu.module.audit.mapper.OperationLogMapper;
import com.kaiwu.module.audit.vo.LoginLogView;
import com.kaiwu.module.audit.vo.OnlineSessionView;
import com.kaiwu.module.audit.vo.OperationLogView;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;
import org.springframework.util.StringUtils;

/** 登录、操作审计与在线会话的只读查询及定点撤销。 */
@Repository
public class LogCenterRepository {

    private final OperationLogMapper operationLogMapper;
    private final LoginLogMapper loginLogMapper;
    private final OnlineSessionQueryMapper sessionMapper;

    public LogCenterRepository(
            OperationLogMapper operationLogMapper,
            LoginLogMapper loginLogMapper,
            OnlineSessionQueryMapper sessionMapper) {
        this.operationLogMapper = operationLogMapper;
        this.loginLogMapper = loginLogMapper;
        this.sessionMapper = sessionMapper;
    }

    /** 操作日志分页；用户名模糊匹配，模块精确匹配。 */
    public PageResult<OperationLogView> operations(String username, String module, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        LambdaQueryWrapper<OperationLogEntity> query = new LambdaQueryWrapper<OperationLogEntity>()
                .like(StringUtils.hasText(username), OperationLogEntity::getUsername, trim(username))
                .eq(StringUtils.hasText(module), OperationLogEntity::getModule, trim(module))
                .orderByDesc(OperationLogEntity::getCreatedAt)
                .orderByDesc(OperationLogEntity::getId);
        Page<OperationLogEntity> page = operationLogMapper.selectPage(Page.of(current, size), query);
        return new PageResult<>(
                current,
                size,
                page.getTotal(),
                page.getRecords().stream().map(LogCenterRepository::toView).toList());
    }

    /** 登录日志分页；用户名模糊匹配，登录结果精确匹配。 */
    public PageResult<LoginLogView> logins(String username, String status, long current, long size) {
        // 出口处兜底，见 PageBounds#requireSize 的说明。
        PageBounds.require(current, size);
        LambdaQueryWrapper<LoginLogEntity> query = new LambdaQueryWrapper<LoginLogEntity>()
                .like(StringUtils.hasText(username), LoginLogEntity::getUsername, trim(username))
                .eq(StringUtils.hasText(status), LoginLogEntity::getLoginStatus, trim(status))
                .orderByDesc(LoginLogEntity::getCreatedAt)
                .orderByDesc(LoginLogEntity::getId);
        Page<LoginLogEntity> page = loginLogMapper.selectPage(Page.of(current, size), query);
        return new PageResult<>(
                current,
                size,
                page.getTotal(),
                page.getRecords().stream().map(LogCenterRepository::toView).toList());
    }

    /**
     * 在线会话分页。
     *
     * <p>要连 {@code sys_user} 取用户名，因此走 Mapper 的注解 SQL 而不是条件构造器；
     * 计数与列表用同一组筛选参数，两条 SQL 里的 {@code <where>} 块也保持一致。</p>
     */
    public PageResult<OnlineSessionView> sessions(String username, String status, long current, long size) {
        // 出口处兜底：这条走 Mapper 注解 SQL 的 LIMIT，同样不依赖上游是否校验过。
        PageBounds.require(current, size);
        String usernameLike = StringUtils.hasText(username) ? "%" + username.trim() + "%" : null;
        String sessionStatus = trim(status);
        long total = sessionMapper.count(usernameLike, sessionStatus);
        List<OnlineSessionView> records =
                sessionMapper.page(usernameLike, sessionStatus, size, (current - 1) * size).stream()
                        .map(LogCenterRepository::toView)
                        .toList();
        return new PageResult<>(current, size, total, records);
    }

    public Optional<SessionRow> findSession(String sessionId) {
        return Optional.ofNullable(sessionMapper.findById(sessionId)).map(LogCenterRepository::toRow);
    }

    public boolean forceOffline(String sessionId) {
        return sessionMapper.forceOffline(sessionId) == 1;
    }

    private static OperationLogView toView(OperationLogEntity entity) {
        return new OperationLogView(
                String.valueOf(entity.getId()),
                entity.getUserId() == null ? null : String.valueOf(entity.getUserId()),
                entity.getUsername(),
                entity.getModule(),
                entity.getOperation(),
                entity.getRequestMethod(),
                entity.getRequestPath(),
                entity.getResponseStatus() == null ? 0 : entity.getResponseStatus(),
                entity.getDetail(),
                entity.getTargetType(),
                entity.getTargetId(),
                entity.getChangeJson(),
                entity.getClientIp(),
                entity.getTraceId(),
                entity.getCreatedAt());
    }

    private static LoginLogView toView(LoginLogEntity entity) {
        return new LoginLogView(
                String.valueOf(entity.getId()),
                entity.getUserId() == null ? null : String.valueOf(entity.getUserId()),
                entity.getUsername(),
                entity.getLoginStatus(),
                entity.getMessage(),
                entity.getClientIp(),
                entity.getTraceId(),
                entity.getCreatedAt());
    }

    private static OnlineSessionView toView(OnlineSessionJoinRow row) {
        return new OnlineSessionView(
                row.getId(),
                row.getUserId(),
                row.getUsername(),
                row.getSessionStatus(),
                row.getCreatedAt(),
                row.getLastSeenAt(),
                row.getExpiresAt(),
                row.getRevokedAt());
    }

    private static SessionRow toRow(OnlineSessionJoinRow row) {
        return new SessionRow(
                row.getId(),
                row.getUserId(),
                row.getUsername(),
                row.getSessionStatus(),
                row.getCreatedAt(),
                row.getLastSeenAt(),
                row.getExpiresAt(),
                row.getRevokedAt());
    }

    private static String trim(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    public record SessionRow(
            String sessionId,
            String userId,
            String username,
            String status,
            LocalDateTime createdAt,
            LocalDateTime lastSeenAt,
            LocalDateTime expiresAt,
            LocalDateTime revokedAt) {}
}
