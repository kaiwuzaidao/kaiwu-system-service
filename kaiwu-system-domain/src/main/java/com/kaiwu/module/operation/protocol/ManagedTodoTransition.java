package com.kaiwu.module.operation.protocol;

import java.security.MessageDigest;
import java.util.Set;

/** D05 版本与终态判断；必须由调用方在持有投影行及跨域业务键锁的事务中使用。 */
public final class ManagedTodoTransition {
    /** 版本判定无运行时状态，禁止实例跨请求保留投影事实。 */
    private ManagedTodoTransition() {}

    /** 已保存的版本和受保护的摘要；调用方从锁定的当前行读取。 */
    public record Stored(long sequence, String state, boolean terminal, byte[] digest) {
        /** 复制摘要，避免调用方改变判定依据。 */
        public Stored {
            digest = digest == null ? null : digest.clone();
        }
        /** 返回副本，防止持有记录者修改内部摘要。 */
        @Override
        public byte[] digest() {
            return digest == null ? null : digest.clone();
        }
    }

    /** 判断结果；冲突不得改变存量，旧版本不得刷新存活时间。 */
    public enum Result {
        APPLIED,
        DUPLICATE,
        SUPERSEDED,
        SEQUENCE_CONFLICT,
        TERMINAL_CONFLICT
    }

    /** 在已完成参数校验、时间窗口校验和授权之后比较版本。 */
    public static Result decide(Stored stored, long sequence, String state, boolean terminal, byte[] digest) {
        validate(sequence, state, terminal, digest);
        if (stored == null) return Result.APPLIED;
        validate(stored.sequence(), stored.state(), stored.terminal(), stored.digest());
        if (stored.terminal() && "OPEN".equals(state)) return Result.TERMINAL_CONFLICT;
        if (sequence < stored.sequence()) return Result.SUPERSEDED;
        if (sequence == stored.sequence())
            return MessageDigest.isEqual(stored.digest(), digest) ? Result.DUPLICATE : Result.SEQUENCE_CONFLICT;
        // 永久终结不能被后续较新版本改写成非终态。
        if (stored.terminal() && !terminal) return Result.TERMINAL_CONFLICT;
        return Result.APPLIED;
    }

    /** 拒绝无效状态和摘要，避免未判定输入进入持久化层。 */
    private static void validate(long sequence, String state, boolean terminal, byte[] digest) {
        if (sequence <= 0
                || state == null
                || !Set.of("OPEN", "DONE", "CANCELLED").contains(state)
                || ("OPEN".equals(state) && terminal)
                || ("DONE".equals(state) && !terminal)
                || digest == null
                || digest.length != 32) throw new IllegalArgumentException("invalid managed todo state");
    }
}
