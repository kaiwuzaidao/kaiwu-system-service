package com.kaiwu.module.agent.protocol;

/**
 * 送模型前的脱敏方式（ADR 0030 第 10 条）。
 *
 * <p>脱敏只作用于模型投影；卡片投影走用户自己的浏览器，不经过外部 Provider，
 * 因此仍可显示原值。</p>
 */
public enum RedactRule {

    /** 保留首字符，其余以 * 替代，如「张三」→「张*」。模型只需知道存在这么一个对象。 */
    PARTIAL,

    /** 整体替换为固定占位符。 */
    MASK
}
