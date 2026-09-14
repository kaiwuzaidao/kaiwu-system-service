package com.kaiwu.module.audit;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageBounds;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.audit.vo.LoginLogView;
import com.kaiwu.module.audit.vo.OnlineSessionView;
import com.kaiwu.module.audit.vo.OperationLogView;
import com.kaiwu.port.SessionSnapshotPort;
import com.kaiwu.starter.KaiwuContext;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/** 安全运营中心应用服务。 */
@Service
public class LogCenterService {

    private final LogCenterRepository repository;
    private final SessionSnapshotPort sessionSnapshots;
    private final AuditService auditService;

    public LogCenterService(
            LogCenterRepository repository, SessionSnapshotPort sessionSnapshots, AuditService auditService) {
        this.repository = repository;
        this.sessionSnapshots = sessionSnapshots;
        this.auditService = auditService;
    }

    public PageResult<OperationLogView> operations(String username, String module, long current, long size) {
        requirePage(current, size);
        return repository.operations(username, module, current, size);
    }

    public PageResult<LoginLogView> logins(String username, String status, long current, long size) {
        requirePage(current, size);
        return repository.logins(username, status, current, size);
    }

    public PageResult<OnlineSessionView> sessions(String username, String status, long current, long size) {
        requirePage(current, size);
        return repository.sessions(username, status, current, size);
    }

    /** 定点强制下线：撤销数据库会话并清掉 Redis 快照，两者缺一都会让旧令牌继续可用。 */
    public void forceOffline(String sessionId, String reason, KaiwuContext actor, RequestMetadata metadata) {
        if (actor.sessionId().equals(sessionId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "不能在安全运营中心强制下线当前会话", "api.common.badRequest");
        }
        LogCenterRepository.SessionRow session = repository
                .findSession(sessionId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "会话不存在", "api.common.notFound"));
        if (!"ONLINE".equals(session.status())) {
            throw new ApiException(HttpStatus.CONFLICT, "会话已经离线", "api.common.conflict");
        }
        if (!repository.forceOffline(sessionId)) {
            throw new ApiException(HttpStatus.CONFLICT, "会话状态已变化，请刷新后重试", "api.common.conflict");
        }
        sessionSnapshots.delete(sessionId);
        String normalizedReason = StringUtils.hasText(reason) ? reason.trim() : "管理员强制下线";
        auditService.recordOperation(
                actor,
                "security",
                "FORCE_OFFLINE",
                "/api/logs/sessions/" + sessionId + "/force-offline",
                "sessionId=" + sessionId + ", reason=" + normalizedReason,
                metadata);
    }

    private static void requirePage(long current, long size) {
        PageBounds.require(current, size);
    }
}
