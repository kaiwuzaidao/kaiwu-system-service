package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Flyway 增量脚本的约定，每条都对应真实发生过的事故。
 *
 * <p>放在 {@code mvn verify} 里而不是写成 shell 脚本：需要人记得去跑的检查等于没有检查。
 * 这些都是纯文件扫描，不连数据库，任何环境都能跑。</p>
 *
 * <p>与 {@code scripts/check-flyway-compatibility.sh} 的区别：那个脚本查的是**数据库当前
 * 版本是否高于代码迁移线**（库里有 V28、代码只到 V26 会让 Flyway 拒启），需要数据库连接，
 * 在 Compose 启动时以 {@code schema-compat-check} 服务运行。它不检查也无法检查这里的事。</p>
 */
class MigrationConventionTest {

    private static final Pattern MIGRATION_NAME = Pattern.compile("^V(\\d+)__[A-Za-z0-9_]+\\.sql$");
    /** 平台 seed 使用的 19 位 ID 字面量。 */
    private static final Pattern SEED_ID = Pattern.compile("\\b(9[12]\\d{17})\\b");

    /**
     * 立本约定时的最后一个版本；只对其后的新迁移生效。
     *
     * <p>存量迁移不追溯：已发布的 V 脚本一律不可修改（CLAUDE.md），而且历史 ID 空间已经
     * 交织在一起，追溯只会得到一堆改不了的红灯。</p>
     */
    private static final int BASELINE_VERSION = 35;

    /**
     * 破坏性变更申报约定立本时的最后一个版本；只对其后的新迁移生效。
     *
     * <p>与上面同理：已发布的 V 脚本不可修改，追溯只会得到一堆改不了的红灯。
     * V36 删四张 legacy 表时已经手写了完整的背景说明，追认为符合本约定的范例。</p>
     */
    private static final int DESTRUCTIVE_BASELINE_VERSION = 38;

    /**
     * 会造成不可逆数据丢失的 DDL。
     *
     * <p>只收真正丢数据的四类：删表、删列、清空表、改列类型（宽变窄会静默截断）。
     * {@code DROP INDEX}、{@code DROP FOREIGN KEY} 不在内——它们丢的是约束不是数据，
     * 把它们算进来只会让申报块变成没人读的仪式。</p>
     */
    private static final Pattern DESTRUCTIVE_DDL =
            Pattern.compile("(?i)\\b(DROP\\s+TABLE|DROP\\s+COLUMN|TRUNCATE\\s+TABLE|TRUNCATE\\b"
                    + "|MODIFY\\s+COLUMN|CHANGE\\s+COLUMN)");

    /** 申报块的必填项；缺一不可，缺了说明这次删除没有被真正想过。 */
    private static final Pattern DESTRUCTIVE_MARKER = Pattern.compile("--\\s*kaiwu:destructive\\b");

    private static final Pattern STOP_WRITE_VERSION = Pattern.compile("--\\s*停写版本：\\s*V(\\d+)");
    private static final Pattern IMPACT_LINE = Pattern.compile("--\\s*影响：\\s*\\S+");
    private static final Pattern IRREVERSIBLE_LINE = Pattern.compile("--\\s*不可逆：\\s*\\S+");

    /**
     * 新 seed ID 必须落在这个下界之上。
     *
     * <p>为什么要换一块地址空间：V27 事故（2026-08-07）的根因是 V26 用
     * {@code 9100000000000003100 + ROW_NUMBER()} 做**运行期动态分配**——占用长度取决于库里
     * 有多少行数据，从 SQL 文件里根本读不出来。挑号时扫描文件中的最大字面量，
     * 正好挑进了那个段，{@code ON DUPLICATE KEY UPDATE} 撞主键后走更新分支，
     * 把两条真实数据覆盖成了错误码文案，而目标资源根本没种进去。
     *
     * <p>既然"动态段有多长"静态不可知，就不要再和它抢地址：全部历史字面量与动态基址都在
     * {@code 91…} 段内，新 seed 一律用 {@code 92…} 段，物理上不可能相撞。</p>
     */
    private static final long RESERVED_SEED_FLOOR = 9_200_000_000_000_000_000L;

    private static Path migrationDirectory() {
        Path current = Path.of("").toAbsolutePath();
        while (current != null) {
            Path candidate = current.resolve("sql/increment");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            current = current.getParent();
        }
        throw new IllegalStateException("未找到 sql/increment 迁移目录");
    }

    private static List<Path> migrations() {
        try (Stream<Path> files = Files.list(migrationDirectory())) {
            return files.filter(path -> MIGRATION_NAME
                            .matcher(path.getFileName().toString())
                            .matches())
                    .sorted()
                    .toList();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    private static int versionOf(Path migration) {
        Matcher matcher = MIGRATION_NAME.matcher(migration.getFileName().toString());
        if (!matcher.matches()) throw new IllegalStateException(migration.toString());
        return Integer.parseInt(matcher.group(1));
    }

    private static String read(Path path) {
        try {
            return Files.readString(path);
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    /**
     * 版本号不得重复。
     *
     * <p>两个人（或一个人和一个 AI）并行开发时各自新建 {@code V36__…}，Flyway 只会执行其中
     * 一个、另一个永远不生效，而且从 {@code flyway_schema_history} 上看不出任何异常。</p>
     */
    @Test
    void migrationVersionsAreUnique() {
        Map<Integer, List<String>> byVersion = new LinkedHashMap<>();
        for (Path migration : migrations()) {
            byVersion
                    .computeIfAbsent(versionOf(migration), ignored -> new ArrayList<>())
                    .add(migration.getFileName().toString());
        }
        List<String> duplicated = byVersion.entrySet().stream()
                .filter(entry -> entry.getValue().size() > 1)
                .map(entry -> "V" + entry.getKey() + " -> " + entry.getValue())
                .toList();

        assertThat(duplicated)
                .withFailMessage("Flyway 版本号重复，只有一个会被执行、另一个静默失效：%s", duplicated)
                .isEmpty();
    }

    /**
     * 迁移文件名必须能被 Flyway 解析。
     *
     * <p>命名不合规的文件会被 Flyway 直接忽略——不报错、不执行，和「写了但没生效」是
     * 同一种沉默失败。</p>
     */
    @Test
    void migrationFileNamesAreParseable() {
        try (Stream<Path> files = Files.list(migrationDirectory())) {
            List<String> invalid = files.map(path -> path.getFileName().toString())
                    .filter(name -> name.endsWith(".sql"))
                    .filter(name -> !MIGRATION_NAME.matcher(name).matches())
                    .sorted()
                    .toList();
            assertThat(invalid)
                    .withFailMessage("以下迁移文件名 Flyway 解析不了，会被静默忽略：%s", invalid)
                    .isEmpty();
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }

    /**
     * 破坏性结构变更必须两阶段执行，并在脚本里申报（约束 {@code database.destructive-change}）。
     *
     * <p>Flyway 只保证「已发布的迁移不可改写」，对「这次删除该不该发生」没有任何意见。
     * 删表和删列是**唯一**一类事后无法用代码回滚的变更——回滚只能靠备份，而备份是否可用
     * 通常在需要它的那一刻才知道。</p>
     *
     * <p>因此要求申报块，并且 {@code 停写版本} 必须**严格小于**本次版本：先有一个版本让代码停止
     * 读写目标结构、跑一段时间确认没有遗漏调用方，下一个版本才回收结构。写在同一个版本里的
     * 「停写 + 删除」等于没有观察窗口，一旦有漏改的调用方，发现时数据已经没了。</p>
     *
     * <pre>{@code
     * -- kaiwu:destructive
     * -- 停写版本：V35
     * -- 影响：sys_role 等四张表及其全部数据
     * -- 不可逆：是，回滚需从备份恢复
     * }</pre>
     *
     * <p>这条规则挡不住「申报了但理由是编的」——它挡的是**无声删除**：让每一次数据回收都在
     * diff 里留下可审阅的痕迹，而不是混在一堆 seed 变更里被扫过去。</p>
     */
    @Test
    void destructiveMigrationsDeclareTheirTwoPhasePlan() {
        List<String> offenders = new ArrayList<>();

        for (Path migration : migrations()) {
            int version = versionOf(migration);
            if (version <= DESTRUCTIVE_BASELINE_VERSION) {
                continue;
            }
            String content = read(migration);
            // 先剥掉注释再找 DDL：背景说明里提到 "DROP TABLE" 不等于这个脚本在删表。
            String statements = content.replaceAll("(?m)--.*$", "");
            if (!DESTRUCTIVE_DDL.matcher(statements).find()) {
                continue;
            }
            String name = migration.getFileName().toString();
            if (!DESTRUCTIVE_MARKER.matcher(content).find()) {
                offenders.add(name + " 缺少 `-- kaiwu:destructive` 申报块");
                continue;
            }
            if (!IMPACT_LINE.matcher(content).find()) {
                offenders.add(name + " 申报块缺少「影响：」");
            }
            if (!IRREVERSIBLE_LINE.matcher(content).find()) {
                offenders.add(name + " 申报块缺少「不可逆：」");
            }
            Matcher stopWrite = STOP_WRITE_VERSION.matcher(content);
            if (!stopWrite.find()) {
                offenders.add(name + " 申报块缺少「停写版本：V{n}」");
            } else if (Integer.parseInt(stopWrite.group(1)) >= version) {
                offenders.add(name + " 的停写版本 V" + stopWrite.group(1) + " 不早于本次 V" + version + "，等于没有观察窗口");
            }
        }

        assertThat(offenders)
                .withFailMessage(
                        """
                        以下迁移会造成不可逆数据丢失，但没有按两阶段约定申报：
                        %s
                        请在脚本头部写明：
                          -- kaiwu:destructive
                          -- 停写版本：V{早于本次的版本号}
                          -- 影响：{被删除的表/列及数据范围}
                          -- 不可逆：{是/否，以及回滚方式}""",
                        offenders)
                .isEmpty();
    }

    /**
     * 新迁移引入的 seed ID 必须落在保留段。
     *
     * <p>判定方式刻意选成「新迁移里出现的 {@code 91…} 字面量，必须在更早的迁移里已经出现过」：
     * 修复类迁移需要回引旧 ID（V28 就要引 V27 写坏的那两个）来做纠正，一刀切禁止
     * {@code 91…} 会把这类迁移全部误伤。**新造的 ID 必须是 {@code 92…}，回引旧 ID 不受限。**</p>
     *
     * <p>这条规则不试图推断「动态段有多长」——那是静态不可知的，我第一版就栽在这上面：
     * 按 1000 的容量假设去判，连正确的 V28 都被判违规。换地址空间才是能成立的做法。</p>
     */
    @Test
    /**
     * 去掉 {@code COALESCE(MAX(id), …)} 这类"取当前最大值、否则用某个下界"的表达式所在行。
     *
     * <p>本检查要抓的是"在 91… 段里新建 seed 行"，而下界字面量并不会成为任何一行的主键：
     * 真实分配出的 ID 取决于运行期的 MAX(id)。V42 就是这种写法，把它误判成新造 seed 之后，
     * 只要该迁移出现在 sql/increment 下检查就必然失败，而它其实没有在 91 段写入任何行。
     *
     * <p>只跳过含 {@code MAX(id)} 的行：seed 行的字面量 ID 不会与它同行，因此不削弱检查强度。
     */
    private static String withoutIdFloorExpressions(String sql) {
        return sql.lines().filter(line -> !line.contains("MAX(id)")).collect(java.util.stream.Collectors.joining("\n"));
    }

    void newMigrationsAllocateSeedIdsFromTheReservedBand() {
        Set<String> knownIds = new HashSet<>();
        List<String> offenders = new ArrayList<>();

        for (Path migration : migrations()) {
            int version = versionOf(migration);
            String name = migration.getFileName().toString();
            Set<String> idsInThisFile = new HashSet<>();

            Matcher matcher = SEED_ID.matcher(withoutIdFloorExpressions(read(migration)));
            while (matcher.find()) {
                String id = matcher.group(1);
                idsInThisFile.add(id);
                boolean isNew = !knownIds.contains(id);
                if (version > BASELINE_VERSION && isNew && Long.parseLong(id) < RESERVED_SEED_FLOOR) {
                    offenders.add(name + " 新引入 " + id);
                }
            }
            knownIds.addAll(idsInThisFile);
        }

        assertThat(offenders)
                .withFailMessage(
                        """
                        以下迁移在 91… 段里新造了 seed ID，可能与运行期动态分配的 ID 撞主键并静默覆盖：
                        %s
                        新 seed 一律从 %d 起（92… 段）。回引已有的旧 ID 不受此限。
                        缘由见 sql/increment/README.md 的「ID 分段约定」。""",
                        offenders, RESERVED_SEED_FLOOR)
                .isEmpty();
    }
}
