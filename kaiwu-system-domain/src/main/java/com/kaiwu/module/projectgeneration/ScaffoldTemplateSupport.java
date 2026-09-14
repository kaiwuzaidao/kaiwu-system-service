package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.codegen.CodegenTemplateRenderer;
import com.kaiwu.module.codegen.model.ColumnMeta;
import com.kaiwu.module.codegen.model.TableMeta;
import com.kaiwu.module.project.vo.ProjectView;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.util.StringUtils;

/** 集中维护脚手架渲染所需的确定性命名、转义和模板变量规则。 */
final class ScaffoldTemplateSupport {

    private final CodegenTemplateRenderer renderer;

    ScaffoldTemplateSupport(CodegenTemplateRenderer renderer) {
        this.renderer = renderer;
    }

    String render(String template, Map<String, Object> variables) {
        return renderer.render(template, variables);
    }

    Map<String, Object> rootVariables(ProjectView project) {
        Map<String, Object> variables = new LinkedHashMap<>();
        variables.put("projectId", project.id());
        variables.put("projectCode", project.projectCode());
        variables.put("projectName", safeText(project.projectName()));
        variables.put("normalizedProjectCode", project.projectCode().replace('-', '_'));
        variables.put("basePackage", project.packageName());
        variables.put("applicationClass", javaClassName(project.projectCode()) + "Application");
        variables.put("templateVersion", ProjectScaffoldGenerator.TEMPLATE_VERSION);
        variables.put("starterVersion", ProjectScaffoldGenerator.STARTER_VERSION);
        int portOffset = localPortOffset(project.projectCode());
        // 以字符串放入模板：FreeMarker 对数字默认按本地化格式输出，会渲染成 "3,323"。
        variables.put("localDbPort", String.valueOf(LOCAL_DB_PORT_BASE + portOffset));
        variables.put("localServerPort", String.valueOf(LOCAL_SERVER_PORT_BASE + portOffset));
        variables.put("localWebPort", String.valueOf(LOCAL_WEB_PORT_BASE + portOffset));
        return variables;
    }

    /**
     * 本地开发端口的基址，三段互不重叠，且避开平台自身占用的 8000/8080/8088。
     *
     * <p>Kaiwu 的常态是一台机器上有多个生成项目：固定默认端口意味着第二个项目起不来，
     * 而报错形式是 Docker 端口占用或 Spring 启动失败，都不指向真正原因。</p>
     */
    private static final int LOCAL_DB_PORT_BASE = 3307;

    private static final int LOCAL_SERVER_PORT_BASE = 8300;
    private static final int LOCAL_WEB_PORT_BASE = 8400;

    /**
     * 由项目编码派生端口偏移 [0, 100)。
     *
     * <p>用 {@link String#hashCode()}：它由 JLS 规定，跨 JVM 和跨次运行都稳定——
     * 同一个项目每次生成拿到同一组端口，README、Compose 和 Gateway 路由样例才对得上。
     * 不同项目仍可能撞号（100 个槽位），因此三个端口全部可用环境变量覆盖。</p>
     */
    private static int localPortOffset(String projectCode) {
        return Math.floorMod(projectCode.hashCode(), 100);
    }

    Map<String, Object> moduleVariables(
            ProjectView project,
            TableMeta table,
            String moduleCode,
            String moduleName,
            String resourceCode,
            String permissionPrefix) {
        Map<String, Object> variables = new LinkedHashMap<>();
        variables.put("basePackage", project.packageName());
        variables.put("projectCode", project.projectCode());
        variables.put("projectId", project.id());
        variables.put("moduleCode", moduleCode);
        variables.put("moduleNameSql", sqlText(moduleName));
        variables.put("resourceCode", resourceCode);
        variables.put("permissionPrefix", permissionPrefix);
        variables.put("table", table);
        variables.put("pkType", table.primaryKey().getJavaType());
        variables.put("pkField", table.primaryKey().getFieldName());
        variables.put("pkSample", pkSample(table.primaryKey().getJavaType()));
        variables.put("pkPathSample", pkPathSample(table.primaryKey().getJavaType()));
        variables.put("pkIsLongIdentifier", "Long".equals(table.primaryKey().getJavaType()));
        variables.put("imports", imports(table));
        ColumnMeta ownerColumn = table.ownerColumn();
        variables.put("ownerScoped", ownerColumn != null);
        variables.put("accessScope", table.accessScope());
        variables.put("ownerColumn", ownerColumn);
        variables.put("ownerField", ownerColumn == null ? null : ownerColumn.getFieldName());
        variables.put("ownerJavaType", ownerColumn == null ? null : ownerColumn.getJavaType());
        variables.put(
                "ownerValueExpression", ownerColumn == null ? null : ownerValueExpression(ownerColumn.getJavaType()));
        variables.put("ownerSample", ownerColumn == null ? null : ownerSample(ownerColumn.getJavaType()));
        variables.put("ownerUserIdSample", ownerColumn == null ? null : ownerUserIdSample(ownerColumn.getJavaType()));
        variables.put(
                "saveApiColumns",
                table.getColumns().stream()
                        .filter(column -> !column.isPrimaryKey()
                                && !column.isLogicDelete()
                                && !column.isAutoFillTime()
                                && column != ownerColumn)
                        .map(this::apiColumn)
                        .toList());
        variables.put(
                "hasNotBlank",
                table.editableColumns().stream()
                        .anyMatch(column -> !column.isNullable() && "String".equals(column.getJavaType())));
        variables.put(
                "hasNotNull",
                table.editableColumns().stream()
                        .anyMatch(column -> !column.isNullable() && !"String".equals(column.getJavaType())));
        variables.put("validRequestJson", javaJsonRequest(table));
        variables.put(
                "viewApiColumns",
                table.getColumns().stream().map(this::apiColumn).toList());
        variables.put("hasLogicDelete", table.getColumns().stream().anyMatch(ColumnMeta::isLogicDelete));
        variables.put("menuId", Long.toString(stableId(project.id() + ":" + permissionPrefix + ":menu")));
        variables.put("listMenuId", Long.toString(stableId(project.id() + ":" + permissionPrefix + ":list")));
        variables.put("saveMenuId", Long.toString(stableId(project.id() + ":" + permissionPrefix + ":save")));
        variables.put("deleteMenuId", Long.toString(stableId(project.id() + ":" + permissionPrefix + ":delete")));
        return variables;
    }

    ProjectScaffoldGenerator.ApiColumn apiColumn(ColumnMeta column) {
        boolean stringIdentifier = "Long".equals(column.getJavaType())
                && (column.isPrimaryKey()
                        || column.getColumnName().toLowerCase(Locale.ROOT).endsWith("_id"));
        String getter = "entity.get" + capitalize(column.getFieldName()) + "()";
        String request = "request." + column.getFieldName() + "()";
        return new ProjectScaffoldGenerator.ApiColumn(
                column.getFieldName(),
                stringIdentifier ? "String" : column.getJavaType(),
                stringIdentifier ? request + " == null ? null : Long.valueOf(" + request + ")" : request,
                stringIdentifier ? getter + " == null ? null : " + getter + ".toString()" : getter,
                column.isNullable(),
                "String".equals(column.getJavaType()));
    }

    void sanitizeMetadata(TableMeta table) {
        table.setComment(javaText(table.getComment()));
        table.getColumns().forEach(column -> {
            column.setComment(javaText(column.getComment()));
            column.setLabel(javaText(column.getLabel()));
        });
    }

    String businessStem(String tableName, String projectCode) {
        String value = tableName.toLowerCase(Locale.ROOT);
        for (String prefix : List.of("biz_", "t_", "sys_", "tb_")) {
            if (value.startsWith(prefix)) {
                value = value.substring(prefix.length());
                break;
            }
        }
        String projectPrefix = projectCode
                .toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9]+", "_")
                .replaceAll("^_+|_+$", "");
        if (!projectPrefix.isBlank() && value.startsWith(projectPrefix + "_")) {
            value = value.substring(projectPrefix.length() + 1);
        }
        return value;
    }

    String uniqueModuleCode(String preferred, Set<String> used) {
        String candidate = preferred;
        int index = 2;
        while (!used.add(candidate)) candidate = preferred + index++;
        return candidate;
    }

    static String compactCode(String value) {
        String compact = value.replaceAll("[^a-z0-9]", "");
        return compact.isBlank() ? "business" : compact;
    }

    static String javaClassName(String value) {
        if (!StringUtils.hasText(value)) return "Business";
        StringBuilder result = new StringBuilder();
        for (String part : value.split("[^a-zA-Z0-9]+")) {
            if (!part.isBlank()) result.append(capitalize(part));
        }
        return result.isEmpty() ? "Business" : result.toString();
    }

    static String safeText(String value) {
        if (!StringUtils.hasText(value)) return "业务模块";
        return value.replace("\r", " ").replace("\n", " ").trim();
    }

    static String ts(String value) {
        return safeText(value)
                .replace("\\", "\\\\")
                .replace("'", "\\'")
                .replace("\r", " ")
                .replace("\n", " ");
    }

    static String json(String value) {
        if (value == null) return "";
        return value.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private static List<String> imports(TableMeta table) {
        Set<String> imports = new LinkedHashSet<>();
        for (ColumnMeta column : table.getColumns()) {
            switch (column.getJavaType()) {
                case "BigDecimal" -> imports.add(BigDecimal.class.getName());
                case "LocalDate" -> imports.add("java.time.LocalDate");
                case "LocalDateTime" -> imports.add("java.time.LocalDateTime");
                default -> {}
            }
        }
        return List.copyOf(imports);
    }

    private static String capitalize(String value) {
        if (!StringUtils.hasText(value)) return "Business";
        return Character.toUpperCase(value.charAt(0)) + value.substring(1);
    }

    private static String sqlText(String value) {
        return safeText(value).replace("'", "''");
    }

    private static String javaText(String value) {
        return safeText(value).replace("*/", "* /");
    }

    private static String pkSample(String javaType) {
        return switch (javaType) {
            case "Long" -> "9000000000000001001L";
            case "Integer" -> "1001";
            case "String" -> "\"sample-id\"";
            default -> "null";
        };
    }

    private static String pkPathSample(String javaType) {
        return switch (javaType) {
            case "Long" -> "\"9000000000000001001\"";
            case "Integer" -> "\"1001\"";
            case "String" -> "\"sample-id\"";
            default -> "\"1\"";
        };
    }

    private static String ownerValueExpression(String javaType) {
        return switch (javaType) {
            case "Long" -> "Long.valueOf(StarterContext.userId())";
            case "Integer" -> "Integer.valueOf(StarterContext.userId())";
            case "String" -> "StarterContext.userId()";
            default -> throw new IllegalArgumentException("资源归属列只支持 BIGINT/INT/VARCHAR，实际 Java 类型：" + javaType);
        };
    }

    private static String ownerSample(String javaType) {
        return switch (javaType) {
            case "Long" -> "9000000000000002001L";
            case "Integer" -> "2001";
            case "String" -> "\"user-2001\"";
            default -> throw new IllegalArgumentException("不支持的资源归属类型：" + javaType);
        };
    }

    private static String ownerUserIdSample(String javaType) {
        return switch (javaType) {
            case "Long" -> "9000000000000002001";
            case "Integer" -> "2001";
            case "String" -> "user-2001";
            default -> throw new IllegalArgumentException("不支持的资源归属类型：" + javaType);
        };
    }

    private static String javaJsonRequest(TableMeta table) {
        return table.editableColumns().stream()
                .map(column -> "\\\"" + json(column.getFieldName()) + "\\\":" + jsonSample(column.getJavaType()))
                .reduce((left, right) -> left + "," + right)
                .map(body -> "{" + body + "}")
                .orElse("{}");
    }

    private static String jsonSample(String javaType) {
        return switch (javaType) {
            case "String" -> "\\\"sample\\\"";
            case "Long" -> "\\\"9000000000000003001\\\"";
            case "Integer", "BigDecimal", "Double" -> "1";
            case "Boolean" -> "true";
            case "LocalDate" -> "\\\"2026-01-01\\\"";
            case "LocalDateTime" -> "\\\"2026-01-01T00:00:00\\\"";
            default -> "null";
        };
    }

    private static long stableId(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            long raw = 0L;
            for (int index = 0; index < Long.BYTES; index++) {
                raw = (raw << 8) | (digest[index] & 0xffL);
            }
            long positive = raw == Long.MIN_VALUE ? 0 : Math.abs(raw);
            return 8_000_000_000_000_000_000L + positive % 1_000_000_000_000_000_000L;
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }
}
