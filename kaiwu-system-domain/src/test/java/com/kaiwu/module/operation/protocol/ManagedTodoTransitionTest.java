package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

/** 以独立向量验证终态、乱序、重复和临时关闭恢复。 */
class ManagedTodoTransitionTest {
    private static final byte[] ONE = new byte[32];
    private static final byte[] TWO = new byte[32];

    static {
        TWO[0] = 1;
    }

    /** 版本相同须校验摘要，旧版本不能覆盖新版本。 */
    @Test
    void versionRules() {
        var current = new ManagedTodoTransition.Stored(2, "OPEN", false, ONE);
        assertThat(ManagedTodoTransition.decide(current, 2, "OPEN", false, ONE))
                .isEqualTo(ManagedTodoTransition.Result.DUPLICATE);
        assertThat(ManagedTodoTransition.decide(current, 2, "OPEN", false, TWO))
                .isEqualTo(ManagedTodoTransition.Result.SEQUENCE_CONFLICT);
        assertThat(ManagedTodoTransition.decide(current, 1, "OPEN", false, ONE))
                .isEqualTo(ManagedTodoTransition.Result.SUPERSEDED);
        assertThat(ManagedTodoTransition.decide(current, 3, "DONE", true, TWO))
                .isEqualTo(ManagedTodoTransition.Result.APPLIED);
    }

    /** 永久关闭不可复活，临时关闭允许更高版本重开。 */
    @Test
    void permanentAndTemporaryClose() {
        var terminal = new ManagedTodoTransition.Stored(2, "CANCELLED", true, ONE);
        assertThat(ManagedTodoTransition.decide(terminal, 1, "OPEN", false, TWO))
                .isEqualTo(ManagedTodoTransition.Result.TERMINAL_CONFLICT);
        assertThat(ManagedTodoTransition.decide(terminal, 3, "OPEN", false, TWO))
                .isEqualTo(ManagedTodoTransition.Result.TERMINAL_CONFLICT);
        var temporary = new ManagedTodoTransition.Stored(2, "CANCELLED", false, ONE);
        assertThat(ManagedTodoTransition.decide(temporary, 3, "OPEN", false, TWO))
                .isEqualTo(ManagedTodoTransition.Result.APPLIED);
        assertThat(ManagedTodoTransition.decide(null, 2, "CANCELLED", true, ONE))
                .isEqualTo(ManagedTodoTransition.Result.APPLIED);
    }

    /** 非法状态和非 32 字节摘要不能参与版本比较。 */
    @Test
    void rejectsInvalidState() {
        assertThatThrownBy(() -> ManagedTodoTransition.decide(null, 1, "DONE", false, ONE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ManagedTodoTransition.decide(null, 1, "OPEN", true, ONE))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ManagedTodoTransition.decide(null, 1, "OPEN", false, new byte[1]))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
