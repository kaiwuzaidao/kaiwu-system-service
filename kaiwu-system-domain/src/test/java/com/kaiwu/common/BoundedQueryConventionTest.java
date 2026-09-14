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
 * 约束 {@code query.bounded-result}：外部可控的查询必须有行数上限。
 *
 * <p>起因不是缺上限，而是**同一条上限被复制了五份、语义还不一致**：四处越界拒绝，
 * 站内信静默截断成 100。复制出来的规则没有任何机制阻止第六个接口漏写，
 * 而漏写的代价是调用方一个 {@code ?size=99999999} 就能让整表进内存
 * ——与导出上限是同一类 OOM。</p>
 *
 * <p>两级判定：</p>
 * <ul>
 *   <li><b>文件级（精确）</b>：拼出 {@code LIMIT} 的地方——{@code Page.of}、
 *       {@code selectPage}、手写 {@code LIMIT}——所在文件本身必须调用 {@link PageBounds}。
 *       为此各 Repository 在出口处会再校验一次，即使 Service 已经校验过：
 *       多一次整数比较换来的是这条断言不再依赖调用链分析。</li>
 *   <li><b>模块级（粗判）</b>：Mapper 接口里的 {@code LIMIT #{size}} 无法自行校验，
 *       Controller 的外部 {@code size} 参数也只是入口，这两类只要求同模块内出现
 *       {@code PageBounds}。它挡的是「新模块整个忘了上限」，挡不住
 *       「模块内有 PageBounds、但新接口没走它」。</li>
 * </ul>
 */
class BoundedQueryConventionTest {

    private static final Path MAIN_SOURCES = Path.of("src/main/java/com/kaiwu/module");

    /** 分页出口：MyBatis-Plus 分页对象、分页查询，以及手写 LIMIT 拼接。 */
    private static final Pattern PAGING_SINK = Pattern.compile("Page\\.of\\(|\\.selectPage\\(|\"LIMIT ");

    /** Mapper 注解/XML 里的 LIMIT；只能由调用方保证有界，因此只做模块级判定。 */
    private static final Pattern MAPPER_LIMIT = Pattern.compile("LIMIT\\s+#\\{");

    /** 外部可传入的分页参数：Controller 上的 size 请求参数。 */
    private static final Pattern PAGE_SIZE_PARAM =
            Pattern.compile("@RequestParam[^)]*\\)\\s*(long|int|Integer|Long)\\s+size\\b");

    /** 文件级：拼 LIMIT 的地方自己必须校验，不依赖调用方。 */
    @Test
    void everyPagingSinkValidatesInPlace() {
        List<String> offenders = new ArrayList<>();
        for (Path module : modules()) {
            for (Path source : javaSources(module)) {
                String content = read(source);
                if (PAGING_SINK.matcher(content).find() && !content.contains("PageBounds")) {
                    offenders.add(MAIN_SOURCES.relativize(source).toString());
                }
            }
        }

        assertThat(offenders)
                .withFailMessage("以下文件直接拼出分页 LIMIT 却没有调用 PageBounds，" + "一旦上游漏校验就等于允许全表进内存：%s", offenders)
                .isEmpty();
    }

    /** 模块级：Mapper 注解 SQL 与 Controller 入参无法自行校验，至少同模块要有边界。 */
    @Test
    void everyModuleWithPagingGoesThroughPageBounds() {
        List<String> offenders = new ArrayList<>();
        for (Path module : modules()) {
            List<Path> sources = javaSources(module);
            boolean hasPaging = sources.stream().anyMatch(source -> {
                String content = read(source);
                return PAGING_SINK.matcher(content).find()
                        || MAPPER_LIMIT.matcher(content).find()
                        || PAGE_SIZE_PARAM.matcher(content).find();
            });
            if (!hasPaging) {
                continue;
            }
            boolean bounded = sources.stream().anyMatch(source -> read(source).contains("PageBounds"));
            if (!bounded) {
                offenders.add(module.getFileName().toString());
            }
        }

        assertThat(offenders)
                .withFailMessage("以下模块存在分页查询但没有经过 PageBounds，" + "调用方可以用超大 size 让整表进内存：%s", offenders)
                .isEmpty();
    }

    /** 上限只允许有一个来源；重新出现手写的 {@code size > 100} 说明约束又被复制了一份。 */
    @Test
    void pageSizeLimitIsNotReintroducedByHand() {
        Pattern handRolled = Pattern.compile("size\\s*>\\s*\\d+");
        List<String> offenders = new ArrayList<>();
        for (Path module : modules()) {
            for (Path source : javaSources(module)) {
                if (handRolled.matcher(read(source)).find()) {
                    offenders.add(MAIN_SOURCES.relativize(source).toString());
                }
            }
        }

        assertThat(offenders)
                .withFailMessage("以下文件重新手写了分页上限，请改用 PageBounds.require：%s", offenders)
                .isEmpty();
    }

    private static List<Path> modules() {
        try (Stream<Path> children = Files.list(MAIN_SOURCES)) {
            return children.filter(Files::isDirectory).sorted().toList();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    private static List<Path> javaSources(Path module) {
        try (Stream<Path> files = Files.walk(module)) {
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
