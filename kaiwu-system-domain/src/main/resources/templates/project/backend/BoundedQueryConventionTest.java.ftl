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
 * Kaiwu 约束 {@code query.bounded-result}（MUST）：外部可控的查询必须有行数上限。
 *
 * <p>结果集会整体驻留内存，未设上限的 {@code size} 等于允许调用方要求全表。
 * 因此拼出 {@code LIMIT} 的地方——{@code new Page<>}、{@code selectPage}、手写 LIMIT——
 * 所在文件本身必须调用 {@link PageBounds}，不依赖上游是否校验过。</p>
 *
 * <p>这是文本扫描，不连数据库，任何环境都能跑。删掉它等于把一条 MUST 降级成口头约定；
 * 确有理由收紧或放宽上限，请改 {@code PageBounds.MAX_SIZE} 并在项目 ADR 写明原因。</p>
 */
class BoundedQueryConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/java"));

    private static final Pattern PAGING_SINK =
            Pattern.compile("new Page<>\\(|Page\\.of\\(|\\.selectPage\\(|\"LIMIT ");

    @Test
    void everyPagingSinkValidatesInPlace() {
        List<String> offenders = new ArrayList<>();
        for (Path root : SOURCE_ROOTS) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            for (Path source : javaSources(root)) {
                String content = read(source);
                if (PAGING_SINK.matcher(content).find() && !content.contains("PageBounds")) {
                    offenders.add(source.toString());
                }
            }
        }

        assertThat(offenders)
                .withFailMessage("以下文件直接拼出分页 LIMIT 却没有调用 PageBounds，"
                        + "调用方可以用超大 size 让整表进内存：%s", offenders)
                .isEmpty();
    }

    private static List<Path> javaSources(Path root) {
        try (Stream<Path> files = Files.walk(root)) {
            return files.filter(path -> path.toString().endsWith(".java")).toList();
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
