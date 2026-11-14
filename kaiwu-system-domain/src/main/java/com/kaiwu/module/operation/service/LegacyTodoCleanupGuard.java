package com.kaiwu.module.operation.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import java.time.LocalDateTime;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** 与共享配额协议兼容的单键清理；批量调度必须逐条调用事务代理。 */
@Service
public class LegacyTodoCleanupGuard {
    private final ManagedTodoLockMapper mapper;
    private final LegacyTodoCloseGuard closeGuard;
    /** 注入共享锁和旧关闭守卫。 */
    public LegacyTodoCleanupGuard(ManagedTodoLockMapper mapper, LegacyTodoCloseGuard closeGuard) {
        this.mapper = mapper;
        this.closeGuard = closeGuard;
    }

    /** 仅在条件仍成立时取消，过期候选的迟到执行不会覆盖重新打开的待办。 */
    @Transactional(isolation = Isolation.READ_COMMITTED, propagation = Propagation.REQUIRES_NEW)
    public int cancelStale(String project, String key, long recipient, LocalDateTime before, LocalDateTime now) {
        if (before == null || now == null) throw new IllegalArgumentException("cleanup time required");
        var locked = closeGuard.prepare(project, key, recipient);
        if (locked.quotas().isEmpty()) return 0;
        int changed = mapper.cancelLegacyStale(project, key, recipient, before, now);
        if (changed == 0) return 0;
        closeGuard.complete(locked, changed);
        return changed;
    }

    /** 清除关闭且超期的旧记录；占用 guard 仅在同键数据均消失后释放。 */
    @Transactional(isolation = Isolation.READ_COMMITTED, propagation = Propagation.REQUIRES_NEW)
    public int deleteClosed(String project, String key, long recipient, LocalDateTime before) {
        if (before == null) throw new IllegalArgumentException("cleanup time required");
        var locked = closeGuard.prepare(project, key, recipient);
        if (!locked.quotas().isEmpty()) return 0;
        mapper.ensureQuota(project, recipient);
        Long quota = mapper.lockQuota(project, recipient);
        if (quota == null || quota < 0) throw unavailable();
        String kind = mapper.lockGuard(project, key, recipient);
        long legacy = mapper.countLegacyKeyForUpdate(project, key, recipient);
        long managed = mapper.countManagedKeyForUpdate(project, key, recipient);
        long actual;
        try {
            actual = Math.addExact(
                    mapper.countLegacyOpenForUpdate(project, recipient),
                    mapper.countManagedOpenForUpdate(project, recipient));
        } catch (ArithmeticException ex) {
            throw unavailable();
        }
        if (actual != quota || (legacy > 0 && !"LEGACY".equals(kind)) || (legacy > 0 && managed > 0))
            throw unavailable();
        if (legacy == 0) return 0;
        int deleted = mapper.deleteLegacyClosed(project, key, recipient, before);
        if (deleted == 1 && mapper.deleteLegacyGuard(project, key, recipient) != 1) throw unavailable();
        return deleted;
    }
    /** 按业务键、额度、占用的统一顺序清理受管OPEN，和刷新互斥，条件不再成立时不改变任何版本事实。 */
    @Transactional(isolation = Isolation.READ_COMMITTED, propagation = Propagation.REQUIRES_NEW)
    public int cancelManaged(
            long id, String project, String key, long recipient, LocalDateTime before, LocalDateTime now) {
        if (before == null || now == null) throw new IllegalArgumentException("cleanup time required");
        mapper.ensureBusinessKey(project, key);
        if (mapper.lockBusinessKey(project, key) == null) throw unavailable();
        mapper.ensureQuota(project, recipient);
        Long quota = mapper.lockQuota(project, recipient);
        if (quota == null
                || quota < 0
                || !"MANAGED".equals(mapper.lockGuard(project, key, recipient))
                || mapper.countLegacyKeyForUpdate(project, key, recipient) != 0) throw unavailable();
        long actual;
        try {
            actual = Math.addExact(
                    mapper.countLegacyOpenForUpdate(project, recipient),
                    mapper.countManagedOpenForUpdate(project, recipient));
        } catch (ArithmeticException failure) {
            throw unavailable();
        }
        if (actual != quota) throw unavailable();
        int changed = mapper.cancelManagedStale(id, project, key, recipient, before, now);
        if (changed == 1 && (quota == 0 || mapper.replaceQuota(project, recipient, quota, quota - 1) != 1))
            throw unavailable();
        return changed;
    }

    /** 配额或占用数据异常时禁止清理并交由对账。 */
    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "待办配额需要对账", "api.common.serviceUnavailable");
    }
}
