package ${basePackage}.common;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Kaiwu 约束 {@code query.explicit-projection}（MUST）：ORM 业务查询必须写出结果列。
 *
 * <p>{@code SELECT *} 的代价不是风格：表加一列，所有用它的查询都会多带一列出去，
 * 覆盖索引失效、实体映射漂移、不该外发的列顺手泄露，三件事同时发生且没有任何报错。</p>
 *
 * <p>扫描三个模块的 {@code .java} 与 {@code .xml}：复杂查询推荐写 Mapper XML，
 * 只扫 Java 等于把门禁开在规则鼓励你去的那条路之外。</p>
 *
 * <p>{@code COUNT(*)} 不会误判：正则要求 {@code select} 后直接跟 {@code *} 或
 * {@code 别名.*}，函数调用形式不匹配。</p>
 */
class SqlProjectionConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("src/main/resources"),
            Path.of("../kaiwu-${projectCode}-api/src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/resources"));

    private static final Pattern SQL_BEARING_FILE = Pattern.compile("\\.(java|xml)$");

    private static final Pattern SELECT_STAR = Pattern.compile(
            "(?is)\\bselect\\s+(?:[a-z_][a-z0-9_]*\\.)?\\*");

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
            return files
                    .filter(path -> SQL_BEARING_FILE.matcher(path.toString()).find())
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
