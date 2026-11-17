package ${basePackage}.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * Kaiwu 行级数据范围门禁（ADR 0044）：不连库、不起容器，只读源码和清单。
 *
 * <p>它保证「声明了受控资源就必须配套正确」，并让「不需要隔离」成为显式决定。五条里前四条失败即构建变红；
 * 第五条只打印提示。<b>没有提示不代表安全</b>：第五条按方法名做启发式判断，既有误报也有漏报，
 * 新增表或接口时仍要先回答 Skill {@code kaiwu-data-scope} 的第一个问题。</p>
 */
class DataScopeConventionTest {

    private static final Path MANIFEST = Files.exists(Path.of("../kaiwu/frontend-manifests"))
            ? Path.of(System.getenv().getOrDefault("KAIWU_FRONTEND_DIR", "../../${projectCode}-web")).resolve("kaiwu/data-scopes.yml")
            : Path.of("../kaiwu/data-scopes.yml");

    private static final List<Path> JAVA_ROOTS = List.of(
            Path.of("src/main/java"),
            Path.of("../kaiwu-${projectCode}-api/src/main/java"),
            Path.of("../kaiwu-${projectCode}-boot/src/main/java"));

    private static final List<Path> SQL_ROOTS = List.of(
            Path.of("../kaiwu-${projectCode}-boot/src/main/resources/db/migration"), Path.of("../sql"));

    private static final Pattern BLOCK_COMMENT = Pattern.compile("(?s)/\\*.*?\\*/");
    private static final Pattern LINE_COMMENT = Pattern.compile("(?m)//.*$");
    private static final Pattern TABLE_NAME = Pattern.compile("@TableName\\(\\s*\"([^\"]+)\"");
    private static final Pattern REASON_CALL = Pattern.compile("DataScopes\\s*\\.\\s*(unrestricted|reassign)\\s*\\(");
    private static final Pattern PERMISSION = Pattern.compile("@RequirePermission\\(\\s*\"([^\"]+)\"");

    /**
     * 清单里的一个受控资源。
     *
     * @param code       资源码
     * @param table      表名
     * @param userColumn 归属人列
     * @param deptColumn 归属部门列
     */
    private record Resource(String code, String table, String userColumn, String deptColumn) {}

    /**
     * 第 1 条：清单中每个资源的表在实体里存在，归属列有对应字段并声明了插入填充与禁止更新，
     * 且建表 SQL 里两个归属列各有一个单列索引。
     */
    @Test
    void everyDeclaredResourceHasMatchingEntityAndIndexes() {
        List<String> violations = new ArrayList<>();
        List<String> sqlTexts = sqlTexts();
        for (Resource resource : resources()) {
            String entity = javaFiles().stream()
                    .map(DataScopeConventionTest::read)
                    .filter(text -> hasTableName(text, resource.table()))
                    .findFirst()
                    .orElse(null);
            if (entity == null) {
                violations.add(resource.code() + "：找不到 @TableName(\"" + resource.table() + "\") 的实体");
            } else {
                for (String column : List.of(resource.userColumn(), resource.deptColumn())) {
                    String property = camel(column);
                    if (!Pattern.compile("private\\s+[\\w<>]+\\s+" + property + "\\b").matcher(entity).find()) {
                        violations.add(resource.code() + "：实体缺少归属字段 " + property);
                    }
                }
                if (count(entity, "FieldFill.INSERT") < 2 || count(entity, "FieldStrategy.NEVER") < 2) {
                    violations.add(resource.code() + "：归属字段必须声明 fill = FieldFill.INSERT 与 updateStrategy = FieldStrategy.NEVER");
                }
            }
            List<String> creating = sqlTexts.stream()
                    .filter(text -> Pattern.compile("(?i)\\b" + Pattern.quote(resource.table()) + "\\b")
                            .matcher(text)
                            .find())
                    .toList();
            if (creating.isEmpty()) {
                violations.add(resource.code() + "：找不到包含表 " + resource.table() + " 的建表 SQL");
            }
            for (String column : List.of(resource.userColumn(), resource.deptColumn())) {
                if (creating.stream().noneMatch(text -> hasSingleColumnIndex(text, resource.table(), column))) {
                    violations.add(resource.code() + "：归属列 " + column + " 缺少单列索引");
                }
            }
        }
        assertThat(violations)
                .as("kaiwu/data-scopes.yml 声明的受控资源必须配套实体注解和归属列索引")
                .isEmpty();
    }

    /** 第 2 条：使用 JdbcTemplate 的源码里不得出现受控表名，它绕过了数据范围拦截器。 */
    @Test
    void jdbcTemplateNeverTouchesControlledTables() {
        List<String> violations = new ArrayList<>();
        for (Path path : javaFiles()) {
            String text = stripComments(read(path));
            if (!text.contains("JdbcTemplate") && !text.contains("JdbcClient")) {
                continue;
            }
            for (Resource resource : resources()) {
                if (Pattern.compile("(?i)(?<![a-z0-9_])" + Pattern.quote(resource.table()) + "(?![a-z0-9_])")
                        .matcher(text)
                        .find()) {
                    violations.add(path + " 通过 JDBC 访问受控表 " + resource.table());
                }
            }
        }
        assertThat(violations)
                .as("受控表只能经过 MyBatis 访问，JdbcTemplate/JdbcClient 不受数据范围保护")
                .isEmpty();
    }

    /** 第 3 条：DataScopes.unrestricted / reassign 的第一个参数必须是非空白的字符串字面量。 */
    @Test
    void bypassCallsStateALiteralReason() {
        List<String> violations = new ArrayList<>();
        Pattern literal = Pattern.compile("^\\s*\"([^\"]*)\"");
        for (Path path : javaFiles()) {
            String text = stripComments(read(path));
            Matcher call = REASON_CALL.matcher(text);
            while (call.find()) {
                Matcher reason = literal.matcher(text.substring(call.end()));
                if (!reason.find() || reason.group(1).isBlank()) {
                    violations.add(path + " 中 DataScopes." + call.group(1) + " 的 reason 不是非空字符串字面量");
                }
            }
        }
        assertThat(violations)
                .as("旁路和归属转移必须写明具体理由，且理由要能在评审时被看到")
                .isEmpty();
    }

    /** 第 4 条：SaveRequest / UpdateRequest 不得包含与归属列同名的字段，归属只能由服务端决定。 */
    @Test
    void writeRequestsDoNotCarryOwnerFields() {
        List<String> properties = new ArrayList<>();
        for (Resource resource : resources()) {
            properties.add(camel(resource.userColumn()));
            properties.add(camel(resource.deptColumn()));
        }
        List<String> violations = new ArrayList<>();
        for (Path path : javaFiles()) {
            String name = path.getFileName().toString();
            if (!name.endsWith("SaveRequest.java") && !name.endsWith("UpdateRequest.java")) {
                continue;
            }
            String text = stripComments(read(path));
            for (String property : properties) {
                if (Pattern.compile("\\b" + property + "\\b").matcher(text).find()) {
                    violations.add(path + " 含归属字段 " + property);
                }
            }
        }
        assertThat(violations)
                .as("请求体不得包含 owner 列，归属变更只能走 DataScopes.reassign")
                .isEmpty();
    }

    /**
     * 第 5 条（仅提示，不失败）：被 {@code @RequirePermission} 保护的 list/page/export 方法，
     * 若其资源既不在受控资源清单里、也不对应豁免表，就打印提示，迫使「不需要隔离」成为显式决定。
     *
     * <p>按权限码的资源段与表名后缀做启发式匹配，误报和漏报都会有；<b>没有提示不代表安全</b>。</p>
     */
    @Test
    void hintsAtListEndpointsWithoutAnExplicitScopeDecision() {
        String manifest = manifestText();
        List<String> decided = new ArrayList<>();
        for (Resource resource : resources()) {
            decided.add(resource.code());
        }
        List<String> exemptTables = new ArrayList<>();
        int exempt = manifest.indexOf("exempt:");
        if (exempt >= 0) {
            Matcher table = Pattern.compile("\\btable:\\s*['\"]?([a-z][a-z0-9_]*)").matcher(manifest.substring(exempt));
            while (table.find()) {
                exemptTables.add(table.group(1));
            }
        }
        List<String> hints = new ArrayList<>();
        for (Path path : javaFiles()) {
            if (!path.getFileName().toString().endsWith("Controller.java")) {
                continue;
            }
            Matcher permission = PERMISSION.matcher(read(path));
            while (permission.find()) {
                String code = permission.group(1);
                String[] parts = code.split(":");
                String last = parts[parts.length - 1].toLowerCase(Locale.ROOT);
                if (parts.length < 3 || !(last.contains("list") || last.contains("page") || last.contains("export"))) {
                    continue;
                }
                String resourceCode = parts[0] + ":" + parts[1];
                String suffix = "_" + parts[1].replace('-', '_');
                boolean exemptMatch = exemptTables.stream().anyMatch(t -> t.equals(parts[1].replace('-', '_'))
                        || t.endsWith(suffix));
                if (!decided.contains(resourceCode) && !exemptMatch) {
                    hints.add(path.getFileName() + "：" + code + " 对应的资源 " + resourceCode
                            + " 既未声明为受控资源，也不在 exempt 中");
                }
            }
        }
        if (!hints.isEmpty()) {
            System.out.println("[DataScope 提示] 以下列表/分页/导出接口没有显式的数据范围决定："
                    + "请回答「同一菜单下不同用户应该看到不同的行吗？」，是则加入 kaiwu/data-scopes.yml，否则写进 exempt 并附理由。");
            hints.forEach(hint -> System.out.println("  - " + hint));
        }
        System.out.println("[DataScope 提示] 第 5 条只做启发式提示：没有提示不代表安全。");
    }

    /** 读取清单正文，去掉注释；文件不存在时视为空。 */
    private static String manifestText() {
        if (!Files.isRegularFile(MANIFEST)) {
            return "";
        }
        return Pattern.compile("(?m)^\\s*#.*$|\\s#.*$").matcher(read(MANIFEST)).replaceAll("");
    }

    /** 解析清单中的受控资源；同时兼容块状和行内写法。 */
    private static List<Resource> resources() {
        String text = manifestText();
        int exempt = text.indexOf("exempt:");
        String section = exempt >= 0 ? text.substring(0, exempt) : text;
        List<Resource> result = new ArrayList<>();
        for (String chunk : section.split("(?m)^\\s*-\\s+")) {
            String code = field(chunk, "code");
            String table = field(chunk, "table");
            if (code == null || table == null) {
                continue;
            }
            String user = field(chunk, "ownerUserColumn");
            String dept = field(chunk, "ownerDeptColumn");
            result.add(new Resource(
                    code, table, user == null ? "owner_user_id" : user, dept == null ? "owner_dept_id" : dept));
        }
        return result;
    }

    /** 取 {@code key: value} 的值，兼容引号。 */
    private static String field(String chunk, String key) {
        Matcher match = Pattern.compile("(?<![A-Za-z])" + key + "\\s*:\\s*['\"]?([^\\s,'\"}\\]]+)").matcher(chunk);
        return match.find() ? match.group(1) : null;
    }

    /** 建表 SQL 中是否有该表该列的单列索引（表内 KEY/INDEX 或独立 CREATE INDEX）。 */
    private static boolean hasSingleColumnIndex(String sql, String table, String column) {
        String col = "`?" + Pattern.quote(column) + "`?";
        Pattern inline = Pattern.compile("(?is)\\b(?:KEY|INDEX)\\s+`?\\w+`?\\s*\\(\\s*" + col + "\\s*\\)");
        Pattern separate = Pattern.compile("(?is)CREATE\\s+INDEX\\s+`?\\w+`?\\s+ON\\s+`?"
                + Pattern.quote(table) + "`?\\s*\\(\\s*" + col + "\\s*\\)");
        return inline.matcher(sql).find() || separate.matcher(sql).find();
    }

    /** 实体源码是否映射到指定表。 */
    private static boolean hasTableName(String source, String table) {
        Matcher match = TABLE_NAME.matcher(source);
        while (match.find()) {
            if (match.group(1).equalsIgnoreCase(table)) {
                return true;
            }
        }
        return false;
    }

    /** 蛇形列名转驼峰属性名。 */
    private static String camel(String column) {
        StringBuilder out = new StringBuilder();
        boolean upper = false;
        for (char c : column.toCharArray()) {
            if (c == '_') {
                upper = true;
            } else {
                out.append(upper ? Character.toUpperCase(c) : c);
                upper = false;
            }
        }
        return out.toString();
    }

    /** 统计子串出现次数。 */
    private static int count(String text, String part) {
        int count = 0;
        for (int i = text.indexOf(part); i >= 0; i = text.indexOf(part, i + part.length())) {
            count++;
        }
        return count;
    }

    /** 去掉 Java 注释，避免在注释里提到表名或字段名造成误报。 */
    private static String stripComments(String source) {
        return LINE_COMMENT.matcher(BLOCK_COMMENT.matcher(source).replaceAll("")).replaceAll("");
    }

    /** 列出三个模块下的全部 Java 源文件。 */
    private static List<Path> javaFiles() {
        List<Path> files = new ArrayList<>();
        for (Path root : JAVA_ROOTS) {
            if (Files.isDirectory(root)) {
                try (Stream<Path> walk = Files.walk(root)) {
                    walk.filter(path -> path.toString().endsWith(".java")).forEach(files::add);
                } catch (IOException exception) {
                    throw new UncheckedIOException(exception);
                }
            }
        }
        return files;
    }

    /** 读取全部迁移与累积快照 SQL 的正文。 */
    private static List<String> sqlTexts() {
        List<String> texts = new ArrayList<>();
        for (Path root : SQL_ROOTS) {
            if (!Files.isDirectory(root)) {
                continue;
            }
            try (Stream<Path> walk = Files.walk(root)) {
                walk.filter(path -> path.toString().endsWith(".sql")).forEach(path -> texts.add(read(path)));
            } catch (IOException exception) {
                throw new UncheckedIOException(exception);
            }
        }
        return texts;
    }

    /** 以 UTF-8 读取文件。 */
    private static String read(Path path) {
        try {
            return Files.readString(path);
        } catch (IOException exception) {
            throw new UncheckedIOException(exception);
        }
    }
}
