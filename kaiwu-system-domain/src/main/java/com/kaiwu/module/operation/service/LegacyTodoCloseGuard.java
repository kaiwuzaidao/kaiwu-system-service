package com.kaiwu.module.operation.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** 旧待办单人或批量关闭的锁前置；调用者必须在 READ COMMITTED 事务内写入和结算。 */
@Service
public class LegacyTodoCloseGuard {
    private final ManagedTodoLockMapper mapper;
    /** 构造与受管写入共用的锁访问器。 */
    public LegacyTodoCloseGuard(ManagedTodoLockMapper mapper) {
        this.mapper = mapper;
    }
    /** 单个收件人的锁定额度。 */
    public record Quota(long recipient, long previous) {}
    /** 关闭前的稳定收件人集合。 */
    public record Reservation(String project, List<Quota> quotas) {
        /** 冻结锁定顺序和额度快照，禁止调用方在结算前改变目标集合。 */
        public Reservation {
            quotas = List.copyOf(quotas);
        }
    }

    /** 业务键锁消除批量关闭和并发插入之间的幻读。 */
    @Transactional(propagation = Propagation.MANDATORY)
    public Reservation prepare(String project, String key, Long recipient) {
        if (!Integer.valueOf(Connection.TRANSACTION_READ_COMMITTED)
                .equals(TransactionSynchronizationManager.getCurrentTransactionIsolationLevel())) throw unavailable();
        if (project == null
                || !project.matches("[a-z][a-z0-9-]{1,63}")
                || key == null
                || !key.matches("[A-Za-z0-9][A-Za-z0-9:_./#-]{0,127}")
                || (recipient != null && recipient <= 0))
            throw new ApiException(HttpStatus.BAD_REQUEST, "待办键无效", "api.common.badRequest");
        mapper.ensureBusinessKey(project, key);
        if (mapper.lockBusinessKey(project, key) == null) throw unavailable();
        List<Long> recipients = mapper.legacyOpenRecipients(project, key, recipient);
        var quotas = new ArrayList<Quota>();
        // 先按收件人顺序取得全部额度，再检查键域和目标行。
        for (long user : recipients) {
            mapper.ensureQuota(project, user);
            Long quota = mapper.lockQuota(project, user);
            if (quota == null || quota <= 0) throw unavailable();
            quotas.add(new Quota(user, quota));
        }
        for (Quota quota : quotas) {
            if (!"LEGACY".equals(mapper.lockGuard(project, key, quota.recipient()))) throw unavailable();
        }
        for (Quota quota : quotas) {
            long actual;
            try {
                actual = Math.addExact(
                        mapper.countLegacyOpenForUpdate(project, quota.recipient()),
                        mapper.countManagedOpenForUpdate(project, quota.recipient()));
            } catch (ArithmeticException ex) {
                throw unavailable();
            }
            if (actual != quota.previous() || mapper.countLegacyOpenKeyForUpdate(project, key, quota.recipient()) != 1)
                throw unavailable();
        }
        return new Reservation(project, quotas);
    }

    /** 调用方关闭的实际行数必须与锁定目标一致，配额更新随业务写入原子提交。 */
    @Transactional(propagation = Propagation.MANDATORY)
    public void complete(Reservation reservation, long closedCount) {
        if (reservation == null || closedCount != reservation.quotas().size()) throw unavailable();
        for (Quota quota : reservation.quotas()) {
            if (mapper.replaceQuota(reservation.project(), quota.recipient(), quota.previous(), quota.previous() - 1)
                    != 1) throw unavailable();
        }
    }
    /** 任何不确定的计数或错误事务隔离均失败关闭。 */
    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "待办配额需要对账", "api.common.serviceUnavailable");
    }
}
