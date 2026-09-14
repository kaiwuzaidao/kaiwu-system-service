package com.kaiwu.common;

import java.util.UUID;

/**
 * 生成可存入 MySQL 有符号 BIGINT 的分布式随机 ID。
 */
public final class LongIdGenerator {

    private LongIdGenerator() {}

    /**
     * 生成一个可存入 MySQL 有符号 BIGINT 的正整数 ID，以字符串返回。
     *
     * <p>返回字符串而不是 long：19 位 ID 超出 JS 的安全整数范围，全链路以字符串传递
     * 才不会在前端静默丢精度（CLAUDE.md 工程约束第 5 条）。</p>
     */
    public static String nextId() {
        long value;
        do {
            UUID uuid = UUID.randomUUID();
            /*
             * UUID v4 的高半部分包含固定的版本位。将高低 64 位混合后再清除
             * 符号位，可使用完整的 63-bit BIGINT 正数空间，降低纯随机碰撞概率。
             */
            value = (uuid.getMostSignificantBits() ^ Long.rotateLeft(uuid.getLeastSignificantBits(), 17))
                    & Long.MAX_VALUE;
        } while (value == 0);
        return Long.toString(value);
    }
}
