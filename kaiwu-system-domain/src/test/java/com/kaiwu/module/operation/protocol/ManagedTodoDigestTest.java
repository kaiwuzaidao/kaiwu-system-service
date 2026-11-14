package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.HexFormat;
import org.junit.jupiter.api.Test;

/** 复核 D05 跨语言向量，固定空值、时间精度和大整数的编码语义。 */
class ManagedTodoDigestTest {
    private static final HexFormat HEX = HexFormat.of();

    /** 中文、空字符串、长 ID 和链接必须匹配已冻结的公开向量。 */
    @Test
    void openVector() {
        var op = new ManagedTodoDigest.Operation(
                "sample",
                "workflow",
                "wf:123:456",
                9007199254740993L,
                1,
                "OPEN",
                false,
                Instant.parse("2026-11-01T00:00:00.123456Z"),
                "待审批：采购",
                "",
                "/workspace/42?route=%2Fworkflow%2Ftasks%2F456",
                null);
        assertThat(HEX.formatHex(ManagedTodoDigest.sha256(op)))
                .isEqualTo("1b67b64c1b642f76e2d37e0c14f4a625a22e0d940dc6540d998062e41e3c7f39");
    }

    /** 空文本和缺失文本的操作不能获得相同摘要。 */
    @Test
    void terminalAndEmptyVectors() {
        var t = Instant.parse("2026-11-01T00:01:00Z");
        var tombstone = new ManagedTodoDigest.Operation(
                "sample", "workflow", "wf:123:456", 9007199254740993L, 2, "CANCELLED", true, t, null, null, null, null);
        var empty = new ManagedTodoDigest.Operation(
                "sample", "workflow", "wf:123:456", 9007199254740993L, 2, "CANCELLED", true, t, "", null, null, null);
        assertThat(HEX.formatHex(ManagedTodoDigest.sha256(tombstone)))
                .isEqualTo("69239b093fcb50096b4fd81b58d7747063459d6776bfbca38604d43d9f6e591e");
        assertThat(HEX.formatHex(ManagedTodoDigest.sha256(empty)))
                .isEqualTo("31a4abbadd3a31271774d7fd3db5e8d3aeb56fdc9a9c6c87fec807a514f942c5");
    }

    /** 纳秒不能静默截为数据库微秒。 */
    @Test
    void rejectsNanosecondPrecision() {
        var op = new ManagedTodoDigest.Operation(
                "sample",
                "workflow",
                "k",
                1,
                1,
                "OPEN",
                false,
                Instant.parse("2026-11-01T00:00:00.000000001Z"),
                "x",
                null,
                null,
                null);
        assertThatThrownBy(() -> ManagedTodoDigest.sha256(op)).isInstanceOf(IllegalArgumentException.class);
    }

    /** 非法代理项不能被编码器替换为问号并与合法输入碰撞。 */
    @Test
    void rejectsInvalidUnicode() {
        var op = new ManagedTodoDigest.Operation(
                "sample",
                "workflow",
                "k",
                1,
                1,
                "OPEN",
                false,
                Instant.parse("2026-11-01T00:00:00Z"),
                "\ud800",
                null,
                null,
                null);
        assertThatThrownBy(() -> ManagedTodoDigest.sha256(op)).isInstanceOf(IllegalArgumentException.class);
    }
}
