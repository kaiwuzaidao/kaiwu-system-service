package ${basePackage}.common;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Kaiwu 约束 {@code runtime.managed-threads}（MUST）：生产线程必须由显式线程池管理。
 *
 * <p>{@code Executors} 工厂方法给的是无界队列或无上限线程数，压力下的表现是内存涨到 OOM
 * 而不是拒绝；裸 {@code new Thread(...)} 没有命名、没有归属、没有关闭路径，
 * 出问题时线程栈里看不出它属于谁。</p>
 *
 * <p>合规写法：{@code Thread.ofPlatform().daemon(true).name("业务前缀-", 0).factory()}
 * 配合显式 {@code ThreadPoolExecutor}，并写明容量、拒绝策略与关闭行为。
 * 需要分布式调度时优先用 Kaiwu Scheduler Starter，它已经处理多副本抢占与审计。</p>
 */
class ManagedThreadConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("../kaiwu-${projectCode}-api/src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/java"));

    @Test
    void productionCodeUsesExplicitLifecycleManagedExecutors() {
        List<String> violations = new ArrayList<>();
        for (Path root : SOURCE_ROOTS) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            for (Path path : javaSources(root)) {
                String source = read(path);
                if (source.contains("Executors.") || source.contains("new Thread(")) {
                    violations.add(path.toString());
                }
            }
        }

        assertThat(violations)
                .as("生产线程必须由显式 ThreadPoolExecutor 管理容量、拒绝与关闭")
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
