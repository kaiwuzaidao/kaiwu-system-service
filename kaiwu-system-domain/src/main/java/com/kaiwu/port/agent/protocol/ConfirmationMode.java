package com.kaiwu.port.agent.protocol;

/** 写能力的用户确认策略。 */
public enum ConfirmationMode {
    /** 只读能力；仅在平台确认其只读性后才允许使用。 */
    NONE,
    /** 普通写能力，显示参数摘要并要求点击确认。 */
    REQUIRED,
    /** 停用、删除、凭据轮换等高风险写能力，需要确认短语。 */
    STRONG
}
