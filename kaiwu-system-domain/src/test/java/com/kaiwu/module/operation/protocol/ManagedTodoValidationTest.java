package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;

/** 重放窗口、截断前校验及状态组合应当失败关闭。 */
class ManagedTodoValidationTest {
    private static final Instant NOW = Instant.parse("2026-11-01T00:00:00Z");

    /** 构造使用固定项目和收件人的边界测试投递。 */
    private static ManagedTodoDigest.Operation operation(Instant time, String state, boolean terminal, String key) {
        return new ManagedTodoDigest.Operation(
                "sample", "workflow", key, 1, 1, state, terminal, time, "title", null, null, null);
    }
    /** 两个时间边界均允许，超限立即拒绝。 */
    @Test
    void replayWindow() {
        var tolerance = Duration.ofSeconds(30);
        assertThatCode(() -> ManagedTodoValidation.validate(
                        operation(NOW.minus(Duration.ofDays(30)), "OPEN", false, "k"), NOW, tolerance))
                .doesNotThrowAnyException();
        assertThatCode(() -> ManagedTodoValidation.validate(
                        operation(NOW.plusSeconds(30), "OPEN", false, "k"), NOW, tolerance))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> ManagedTodoValidation.validate(
                        operation(NOW.minus(Duration.ofDays(30)).minusNanos(1000), "OPEN", false, "k"), NOW, tolerance))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ManagedTodoValidation.validate(
                        operation(NOW.plusSeconds(31), "OPEN", false, "k"), NOW, tolerance))
                .isInstanceOf(IllegalArgumentException.class);
    }
    /** 不允许字段截断、非法状态或负的时钟容差。 */
    @Test
    void invalidInputs() {
        assertThatThrownBy(() -> ManagedTodoValidation.validate(operation(NOW, "DONE", false, "k"), NOW, Duration.ZERO))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ManagedTodoValidation.validate(operation(NOW, "OPEN", true, "k"), NOW, Duration.ZERO))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ManagedTodoValidation.validate(
                        operation(NOW, "OPEN", false, "a".repeat(129)), NOW, Duration.ZERO))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() ->
                        ManagedTodoValidation.validate(operation(NOW, "OPEN", false, "k"), NOW, Duration.ofSeconds(-1)))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
