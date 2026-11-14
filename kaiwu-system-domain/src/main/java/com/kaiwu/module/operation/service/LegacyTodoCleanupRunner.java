package com.kaiwu.module.operation.service;

import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/** 扫描旧/新候选并经事务代理逐条清理，不跨业务键持有长事务。 */
@Service
public class LegacyTodoCleanupRunner {
    private final ManagedTodoLockMapper mapper;
    private final LegacyTodoCleanupGuard cleanup;
    private final Clock clock;
    /** 注入扫描器与具独立事务的清理器。 */
    public LegacyTodoCleanupRunner(ManagedTodoLockMapper mapper, LegacyTodoCleanupGuard cleanup) {
        this(mapper, cleanup, Clock.systemUTC());
    }
    /** 与调度器共用配置时钟，受管存活时间比较始终转换为UTC。 */
    @Autowired
    public LegacyTodoCleanupRunner(ManagedTodoLockMapper mapper, LegacyTodoCleanupGuard cleanup, Clock clock) {
        this.mapper = mapper;
        this.cleanup = cleanup;
        this.clock = clock;
    }

    /** 扫描过期 OPEN 候选并重新校验，返回实际取消条数。 */
    public int cancelBatch(LocalDateTime before, LocalDateTime now, int limit) {
        validateLimit(limit);
        int changed = 0;
        for (Map<String, Object> row : mapper.findStaleLegacy(before, limit)) {
            Key key = key(row);
            changed += cleanup.cancelStale(key.project(), key.biz(), key.recipient(), before, now);
        }
        int remaining = limit - changed;
        if (remaining > 0)
            for (Map<String, Object> row : mapper.findStaleManaged(utc(before), remaining)) {
                Key key = key(row);
                changed += cleanup.cancelManaged(
                        Long.parseLong(String.valueOf(value(row, "id"))),
                        key.project(),
                        key.biz(),
                        key.recipient(),
                        utc(before),
                        utc(now));
            }
        return changed;
    }
    /** 扫描超过保留期的关闭候选，删除与 guard 更新在独立事务内完成。 */
    public int deleteBatch(LocalDateTime before, int limit) {
        validateLimit(limit);
        int changed = 0;
        for (Map<String, Object> row : mapper.findClosedLegacy(before, limit)) {
            Key key = key(row);
            changed += cleanup.deleteClosed(key.project(), key.biz(), key.recipient(), before);
        }
        return changed;
    }
    /** 仅转换受管列的比较时刻，旧清理保留原本地日历时间。 */
    private LocalDateTime utc(LocalDateTime local) {
        return local.atZone(clock.getZone()).withZoneSameInstant(ZoneOffset.UTC).toLocalDateTime();
    }

    /** 扫描数量只允许受限正整数，避免一次调度无界。 */
    private static void validateLimit(int limit) {
        if (limit < 1 || limit > 10000) throw new IllegalArgumentException("invalid cleanup batch size");
    }
    /** 兼容不同 JDBC 对别名大小写的处理，缺失字段时失败关闭。 */
    private static Key key(Map<String, Object> row) {
        Object project = value(row, "projectCode"),
                biz = value(row, "bizKey"),
                recipient = value(row, "recipientUserId");
        return new Key(String.valueOf(project), String.valueOf(biz), Long.parseLong(String.valueOf(recipient)));
    }

    /** 别名必须精确匹配唯一非空值，禁止扫描行缺失时猜测清理目标。 */
    private static Object value(Map<String, Object> row, String key) {
        List<Object> values = row.entrySet().stream()
                .filter(entry -> entry.getKey().equalsIgnoreCase(key))
                .map(Map.Entry::getValue)
                .filter(java.util.Objects::nonNull)
                .toList();
        if (values.size() != 1) throw new IllegalStateException("invalid cleanup scan row");
        return values.getFirst();
    }

    /** 只承载数据库扫描的可信锁键，不接收浏览器输入。 */
    private record Key(String project, String biz, long recipient) {}
}
