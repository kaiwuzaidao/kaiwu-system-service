package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * 约束 {@code query.explicit-projection}（MUST）：ORM 业务查询必须写出结果列。
 *
 * <p>{@code SELECT *} 的代价不是风格：表加一列，所有用它的查询都会多带一列出去，
 * 覆盖索引失效、实体映射漂移、不该外发的列（如密码哈希）顺手泄露，三件事同时发生
 * 而且没有任何报错。</p>
 *
 * <p>扫描范围覆盖约束声明的全部 ORM 出口，而不只是 domain 的 Java 注解 SQL：
 * ADR 0020 §7 要求复杂查询优先写 Mapper XML，只扫 Java 等于把门禁开在了
 * 规则鼓励大家去的那条路之外。boot 模块同样纳入——它虽然当前没有 SQL，
 * 但没有任何机制阻止它出现。</p>
 *
 * <p>{@code COUNT(*)} 不会误判：正则要求 {@code select} 后直接跟 {@code *} 或
 * {@code 别名.*}，函数调用形式不匹配。</p>
 */
class SqlProjectionConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("src/main/resources"),
            Path.of("../kaiwu-system-api/src/main/java"),
            Path.of("../kaiwu-system-boot/src/main/java"),
            Path.of("../kaiwu-system-boot/src/main/resources"));

    /** 只扫真正可能承载 SQL 的文件类型。 */
    private static final Pattern SQL_BEARING_FILE = Pattern.compile("\\.(java|xml)$");

    private static final Pattern SELECT_STAR = Pattern.compile("(?is)\\bselect\\s+(?:[a-z_][a-z0-9_]*\\.)?\\*");

    @Test
    void businessQueriesDeclareTheirResultColumns() {
        List<String> violations = new ArrayList<>();
        for (Path root : SOURCE_ROOTS) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            for (Path path : sqlBearingFiles(root)) {
                if (SELECT_STAR.matcher(read(path)).find()) {
                    violations.add(path.toString());
                }
            }
        }

        assertThat(violations)
                .as("ORM 查询必须显式声明字段，禁止 SELECT * 或 alias.*（含 Mapper XML）")
                .isEmpty();
    }

    private static List<Path> sqlBearingFiles(Path root) {
        try (Stream<Path> files = Files.walk(root)) {
            return files.filter(
                            path -> SQL_BEARING_FILE.matcher(path.toString()).find())
                    .toList();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    private static String read(Path path) {
        try {
            return Files.readString(path);
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }
}
