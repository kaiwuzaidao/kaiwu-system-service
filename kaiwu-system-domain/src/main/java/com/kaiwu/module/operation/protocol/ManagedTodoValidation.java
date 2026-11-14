package com.kaiwu.module.operation.protocol;

import java.time.Duration;
import java.time.Instant;
import java.util.Set;

/** D05 投递入口的格式与重放窗口校验，不代替凭据认证或成员资格校验。 */
public final class ManagedTodoValidation {
    private static final Duration MAX_AGE = Duration.ofDays(30);

    /** 入口校验只读取传入时钟与操作，不注册客户端或持久化配置。 */
    private ManagedTodoValidation() {}

    /** 时间按 UTC 微秒精度校验，未来时钟容差须由服务器配置给定。 */
    public static void validate(ManagedTodoDigest.Operation op, Instant now, Duration futureTolerance) {
        if (op == null
                || now == null
                || futureTolerance == null
                || futureTolerance.isNegative()
                || op.projectCode() == null
                || !op.projectCode().matches("[a-z][a-z0-9-]{1,63}")
                || op.producerService() == null
                || !op.producerService().matches("[a-z][a-z0-9-]{0,15}")
                || op.bizKey() == null
                || !op.bizKey().matches("[A-Za-z0-9][A-Za-z0-9:_./#-]{0,127}")
                || op.recipientUserId() <= 0
                || op.sequence() <= 0
                || op.state() == null
                || !Set.of("OPEN", "DONE", "CANCELLED").contains(op.state())
                || (op.terminal() && op.state().equals("OPEN"))
                || (!op.terminal() && op.state().equals("DONE"))
                || op.operationCreatedAt() == null
                || op.operationCreatedAt().isBefore(now.minus(MAX_AGE))
                || op.operationCreatedAt().isAfter(now.plus(futureTolerance))
                || (op.title() != null
                        && op.title().codePointCount(0, op.title().length()) > 200)
                || (op.content() != null
                        && op.content().codePointCount(0, op.content().length()) > 2000)
                || (op.linkUrl() != null
                        && op.linkUrl().codePointCount(0, op.linkUrl().length()) > 512)
                || (op.state().equals("OPEN")
                        && (op.title() == null || op.title().isBlank())))
            throw new IllegalArgumentException("invalid managed todo operation");
        // 摘要编码检查非法 Unicode 及所有时间字段的微秒精度。
        ManagedTodoDigest.encode(op);
    }
}
