package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * 约束 {@code runtime.managed-threads}（MUST）：生产线程必须由显式线程池管理。
 *
 * <p>{@code Executors} 工厂方法给的是无界队列或无上限线程数，压力下的表现是内存涨到 OOM
 * 而不是拒绝；裸 {@code new Thread(...)} 则没有命名、没有归属、没有关闭路径，
 * 出问题时线程栈里看不出它属于谁。要显式构造 {@code ThreadPoolExecutor}
 * 并写明线程名、拒绝策略和关闭行为。</p>
 *
 * <p>合规的写法是 {@code Thread.ofPlatform().daemon(true).name(...).factory()} 配合显式
 * {@code ThreadPoolExecutor} / {@code ScheduledThreadPoolExecutor}。</p>
 *
 * <p>本文件与 Gateway、Starter 仓的同名测试保持一致：三仓各自独立版本化，
 * 门禁只能各仓自带一份——这是仓库边界的代价，不是重复代码。</p>
 */
class ManagedThreadConventionTest {

    private static final List<Path> SOURCE_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("../kaiwu-system-api/src/main/java"),
            Path.of("../kaiwu-system-boot/src/main/java"));

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

        assertThat(violations).as("生产线程必须由显式 ThreadPoolExecutor 管理容量、拒绝与关闭").isEmpty();
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
