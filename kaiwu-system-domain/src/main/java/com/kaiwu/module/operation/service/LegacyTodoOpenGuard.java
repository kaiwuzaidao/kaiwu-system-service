package com.kaiwu.module.operation.service;

import com.kaiwu.common.ApiException;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** 旧待办打开事务的共享锁前置步骤；必须与实际写入在同一事务执行。 */
@Service
public class LegacyTodoOpenGuard {
    private final ManagedTodoLockMapper mapper;

    /** 共用 D05 的业务键、额度和占用域锁。 */
    public LegacyTodoOpenGuard(ManagedTodoLockMapper mapper) {
        this.mapper = mapper;
    }

    /** 记录锁内原有额度和本次是否需要增加。 */
    public record Reservation(String project, long recipient, long previous, boolean increase) {}

    /** 在业务写入之前调用；状态不一致时拒绝并保留数据供对账。 */
    @Transactional(propagation = Propagation.MANDATORY)
    public Reservation prepare(String project, String key, long recipient, int limit) {
        if (project == null
                || !project.matches("[a-z][a-z0-9-]{1,63}")
                || key == null
                || !key.matches("[A-Za-z0-9][A-Za-z0-9:_./#-]{0,127}")
                || recipient <= 0
                || limit < 1) throw new ApiException(HttpStatus.BAD_REQUEST, "待办键无效", "api.common.badRequest");
        mapper.ensureBusinessKey(project, key);
        if (mapper.lockBusinessKey(project, key) == null) throw unavailable();
        mapper.ensureQuota(project, recipient);
        Long quota = mapper.lockQuota(project, recipient);
        if (quota == null || quota < 0) throw unavailable();
        String kind = mapper.lockGuard(project, key, recipient);
        if (kind == null) {
            if (mapper.countLegacyKeyForUpdate(project, key, recipient) != 0
                    || mapper.countManagedKeyForUpdate(project, key, recipient) != 0) throw unavailable();
            mapper.insertGuard(project, key, recipient, "LEGACY");
        } else if (!kind.equals("LEGACY")) {
            throw new ApiException(HttpStatus.CONFLICT, "待办键已被受管投影占用", "api.common.conflict");
        }
        long actual;
        try {
            actual = Math.addExact(
                    mapper.countLegacyOpenForUpdate(project, recipient),
                    mapper.countManagedOpenForUpdate(project, recipient));
        } catch (ArithmeticException ex) {
            throw unavailable();
        }
        if (actual != quota) throw unavailable();
        boolean increase = mapper.countLegacyOpenKeyForUpdate(project, key, recipient) == 0;
        if (increase && quota >= limit)
            throw new ApiException(HttpStatus.CONFLICT, "该处理人未处理的待办数量已达上限", "api.common.conflict");
        return new Reservation(project, recipient, quota, increase);
    }

    /** 旧待办写入成功后调用，条件更新失败必须回滚整个事务。 */
    @Transactional(propagation = Propagation.MANDATORY)
    public void complete(Reservation reservation) {
        if (reservation == null) throw unavailable();
        if (reservation.increase()
                && (reservation.previous() == Long.MAX_VALUE
                        || mapper.replaceQuota(
                                        reservation.project(),
                                        reservation.recipient(),
                                        reservation.previous(),
                                        reservation.previous() + 1)
                                != 1)) throw unavailable();
    }

    /** 配额不可置信时失败关闭，不修改计数掩盖不一致。 */
    private static ApiException unavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "待办配额需要对账", "api.common.serviceUnavailable");
    }
}
