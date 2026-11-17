package com.kaiwu.module.factory.renderer;

import com.kaiwu.module.factory.model.ColumnMeta;
import com.kaiwu.module.factory.service.ProjectBlueprintService;
import com.kaiwu.module.project.vo.ProjectView;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import org.springframework.util.StringUtils;

/** 组装生成项目后端仓库的固定根文件、模块契约与菜单种子。 */
final class BackendScaffoldRenderer {

    private final ScaffoldTemplateSupport templates;

    BackendScaffoldRenderer(ScaffoldTemplateSupport templates) {
        this.templates = templates;
    }

    /**
     * 组装新业务后端的基础文件、质量契约和中文 Javadoc 门禁。
     *
     * @param variables 模板渲染变量
     * @param project 项目元数据
     * @param blueprint 表结构与资源范围蓝图
     * @return 相对路径到文件内容的有序映射
     */
    Map<String, String> root(
            Map<String, Object> variables, ProjectView project, ProjectBlueprintService.ProjectBlueprint blueprint) {
        Map<String, String> files = new LinkedHashMap<>();
        String packagePath = project.packageName().replace('.', '/');
        String modulePrefix = "kaiwu-" + project.projectCode();
        files.put("pom.xml", templates.render("project/backend/parent-pom.xml.ftl", variables));
        files.put(modulePrefix + "-api/pom.xml", templates.render("project/backend/api-pom.xml.ftl", variables));
        files.put(modulePrefix + "-domain/pom.xml", templates.render("project/backend/domain-pom.xml.ftl", variables));
        files.put(modulePrefix + "-boot/pom.xml", templates.render("project/backend/boot-pom.xml.ftl", variables));
        files.put(
                modulePrefix + "-boot/src/main/java/" + packagePath + "/" + variables.get("applicationClass") + ".java",
                templates.render("project/backend/Application.java.ftl", variables));
        files.put(
                modulePrefix + "-boot/src/main/java/" + packagePath + "/config/MybatisPlusConfig.java",
                templates.render("project/backend/MybatisPlusConfig.java.ftl", variables));
        files.put(
                modulePrefix + "-boot/src/main/resources/application.yml",
                templates.render("project/backend/application.yml.ftl", variables));

        files.put(
                modulePrefix + "-api/src/main/java/" + packagePath + "/common/Result.java",
                templates.render("project/backend/Result.java.ftl", variables));
        files.put(
                modulePrefix + "-api/src/main/java/" + packagePath + "/common/PageResult.java",
                templates.render("project/backend/PageResult.java.ftl", variables));
        files.put(
                modulePrefix + "-api/src/main/java/" + packagePath + "/common/ApiException.java",
                templates.render("project/backend/ApiException.java.ftl", variables));
        files.put(
                modulePrefix + "-api/src/main/java/" + packagePath + "/common/PageBounds.java",
                templates.render("project/backend/PageBounds.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/main/java/" + packagePath + "/common/GlobalExceptionHandler.java",
                templates.render("project/backend/GlobalExceptionHandler.java.ftl", variables));
        // 两条 MUST 约束的门禁随仓库一起生成：写在 AGENTS.md 里的规则只是意图，
        // 只有能让构建变红的才是约束。
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/BoundedQueryConventionTest.java",
                templates.render("project/backend/BoundedQueryConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/SensitiveLoggingConventionTest.java",
                templates.render("project/backend/SensitiveLoggingConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/DataScopeConventionTest.java",
                templates.render("project/backend/DataScopeConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/SqlProjectionConventionTest.java",
                templates.render("project/backend/SqlProjectionConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/ManagedThreadConventionTest.java",
                templates.render("project/backend/ManagedThreadConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/PackageLayoutContractTest.java",
                templates.render("project/backend/PackageLayoutContractTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/ChineseJavadocConventionTest.java",
                templates.render("project/backend/ChineseJavadocConventionTest.java.ftl", variables));
        files.put("docs/PACKAGE_STRUCTURE.md", templates.render("project/backend/PACKAGE_STRUCTURE.md.ftl", variables));
        files.put("docs/JAVA_STYLE.md", templates.render("project/backend/JAVA_STYLE.md.ftl", variables));
        files.put(
                "scripts/MenuPermissions.java",
                templates.render("project/backend/MenuPermissions.java.ftl", variables));
        files.put(
                "scripts/check-permission-seed.sh",
                templates.render("project/backend/check-permission-seed.sh.ftl", variables));
        files.put(
                "scripts/check-test-baseline.sh",
                templates.render("project/backend/check-test-baseline.sh.ftl", variables));
        files.put("scripts/verify.sh", templates.render("project/backend/verify.sh.ftl", variables));
        files.put(
                "scripts/check-constraints.sh", templates.render("project/common/check-constraints.sh.ftl", variables));
        files.put("scripts/dev-check.sh", templates.render("project/backend/dev-check.sh.ftl", variables));
        files.put("scripts/dev.sh", templates.render("project/backend/dev.sh.ftl", variables));
        files.put("compose.local.yml", templates.render("project/backend/compose.local.yml.ftl", variables));
        files.put(
                "docs/gateway-route-local.yml",
                templates.render("project/backend/gateway-route-local.yml.ftl", variables));
        files.put("deploy/server/compose.yml", templates.render("project/backend/compose.server.yml.ftl", variables));
        files.put(
                "deploy/server/gateway-route.yml",
                templates.render("project/backend/gateway-route-managed.yml.ftl", variables));
        files.put("deploy/k8s/deployment.yaml", templates.render("project/backend/k8s-deployment.yaml.ftl", variables));
        files.put("deploy/k8s/service.yaml", templates.render("project/backend/k8s-service.yaml.ftl", variables));
        files.put(
                "deploy/k8s/kustomization.yaml",
                templates.render("project/backend/k8s-kustomization.yaml.ftl", variables));
        files.put(
                "deploy/k8s/gateway-route-values.yaml",
                templates.render("project/backend/gateway-route-managed.yml.ftl", variables));
        files.put("docs/kaiwu-constraints.json", templates.render("project/common/constraints.json.ftl", variables));
        files.put(
                "docs/kaiwu-constraint-waivers.json",
                templates.render("project/common/constraint-waivers.json.ftl", variables));
        files.put("Dockerfile", templates.render("project/backend/Dockerfile.ftl", variables));
        files.put("README.md", templates.render("project/backend/README.md.ftl", variables));
        files.put(
                "docs/AGENT_CAPABILITIES.md", templates.render("project/backend/AGENT_CAPABILITIES.md.ftl", variables));
        files.put("AGENTS.md", templates.render("project/backend/AGENTS.md.ftl", variables));
        files.put("CLAUDE.md", templates.render("project/backend/CLAUDE.md.ftl", variables));
        files.put(".gitlab-ci.yml", templates.render("project/backend/gitlab-ci.yml.ftl", variables));
        files.put(
                ".gitignore",
                """
                **/target/
                .idea/
                .vscode/
                *.iml
                .env
                .env.*
                .kaiwu/
                """
                        + (templates.fileRegistry() ? "data/\n" : ""));
        String migrationDir = modulePrefix + "-boot/src/main/resources/db/migration/";
        // 平台资源清单（ADR 0036）：字典、配置随代码版本化，用 `./kaiwu project sync` 同步；
        // 脚手架不猜业务枚举与配置，初始为空并附带可复制的示例。
        files.put("kaiwu/dicts.yml", templates.render("project/backend/kaiwu-dicts.yml.ftl", variables));
        files.put("kaiwu/configs.yml", templates.render("project/backend/kaiwu-configs.yml.ftl", variables));
        files.put("kaiwu/data-scopes.yml", templates.render("project/backend/kaiwu-data-scopes.yml.ftl", variables));
        // 数据范围 Skill：源文件在 kaiwu-system-starter 的 data-scope/skill/，.agents 下放正文，.claude 下放转发指针。
        files.put(
                ".agents/skills/kaiwu-data-scope/SKILL.md",
                templates.render("project/backend/skill-kaiwu-data-scope.md.ftl", variables));
        files.put(
                ".claude/skills/kaiwu-data-scope/SKILL.md",
                templates.render("project/backend/skill-pointer-kaiwu-data-scope.md.ftl", variables));
        // 项目内统一文件表（ADR 0041）：随首个迁移与快照一起建，业务表只存 file_id。
        String fileTable = templates.fileRegistry()
                ? "\n" + templates.render("project/backend/kaiwu-file.sql.ftl", variables)
                : "";
        if (StringUtils.hasText(blueprint.ddl())) {
            String ddl = withOwnerIndexes(blueprint.ddl().trim(), blueprint.tables()) + "\n" + fileTable;
            files.put("sql/schema.sql", ddl);
            files.put(migrationDir + "V1__init_business_schema.sql", ddl);
        } else {
            files.put("sql/schema.sql", "-- 当前是空脚手架；新增业务表时同步本快照。\n" + fileTable);
            files.put(
                    migrationDir + "V1__init_business_schema.sql",
                    "-- 当前是空脚手架；首个业务表变更从本 migration 开始。\n" + "-- 新增迁移请追加 V{n}__desc.sql，Spring Boot 启动会自动执行。\n"
                            + fileTable);
        }
        return files;
    }

    /**
     * 行级数据范围表的两个归属列必须各有单列索引，否则谓词会退化成全表扫描。
     *
     * <p>用户粘贴的 DDL 已经建了就不动；没建的在 DDL 末尾追加 {@code CREATE INDEX}，同时进入迁移与快照。</p>
     */
    static String withOwnerIndexes(String ddl, List<com.kaiwu.module.factory.model.TableMeta> tables) {
        StringBuilder out = new StringBuilder(ddl);
        for (var table : tables) {
            if (!table.dataScoped()) {
                continue;
            }
            String name = table.getTableName();
            java.util.regex.Matcher start = java.util.regex.Pattern.compile(
                            "(?is)CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?`?"
                                    + java.util.regex.Pattern.quote(name) + "`?\\s*\\(")
                    .matcher(ddl);
            String block = "";
            if (start.find()) {
                int next = ddl.toLowerCase(java.util.Locale.ROOT).indexOf("create table", start.end());
                block = ddl.substring(start.start(), next < 0 ? ddl.length() : next);
            }
            for (String column : List.of("owner_user_id", "owner_dept_id")) {
                String col = "`?" + column + "`?";
                boolean inline = java.util.regex.Pattern.compile(
                                "(?is)\\b(?:KEY|INDEX)\\s+`?\\w+`?\\s*\\(\\s*" + col + "\\s*\\)")
                        .matcher(block)
                        .find();
                boolean separate = java.util.regex.Pattern.compile("(?is)CREATE\\s+INDEX\\s+`?\\w+`?\\s+ON\\s+`?"
                                + java.util.regex.Pattern.quote(name) + "`?\\s*\\(\\s*" + col + "\\s*\\)")
                        .matcher(ddl)
                        .find();
                if (!inline && !separate) {
                    // 用户粘贴的 DDL 常常不带结尾分号；追加语句前先补上，否则两条语句会粘成一条。
                    if (!out.toString().stripTrailing().endsWith(";")) {
                        out.append(';');
                    }
                    String stem = name.length() > 40 ? name.substring(0, 40) : name;
                    out.append("\nCREATE INDEX idx_")
                            .append(stem)
                            .append(column.equals("owner_user_id") ? "_owner_user" : "_owner_dept")
                            .append(" ON ")
                            .append(name)
                            .append(" (")
                            .append(column)
                            .append(");");
                }
            }
        }
        return out.toString();
    }

    void complete(
            Map<String, String> files, ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        files.put("kaiwu/menus.yml", menuManifest(modules));
        List<Map<String, String>> scoped = modules.stream()
                .filter(module -> module.table().dataScoped())
                .map(module -> Map.of(
                        "code", module.permissionPrefix(),
                        "name", module.moduleName().replace("'", ""),
                        "table", module.table().getTableName()))
                .toList();
        if (!scoped.isEmpty()) {
            Map<String, Object> scopeVariables = new LinkedHashMap<>(templates.rootVariables(project));
            scopeVariables.put("dataScopeResources", scoped);
            files.put(
                    "kaiwu/data-scopes.yml",
                    templates.render("project/backend/kaiwu-data-scopes.yml.ftl", scopeVariables));
        }
        files.put("docs/api-contract.txt", apiContract(modules));
        Map<String, Object> layoutVariables = new LinkedHashMap<>(templates.rootVariables(project));
        layoutVariables.put(
                "layoutCategories",
                modules.stream()
                        .map(ProjectScaffoldGenerator.GeneratedModule::moduleCode)
                        .distinct()
                        .sorted()
                        .toList());
        files.put(
                "docs/package-layout.json",
                templates.render("project/backend/package-layout.json.ftl", layoutVariables));
        files.put(
                "kaiwu-" + project.projectCode() + "-domain/src/test/java/"
                        + project.packageName().replace('.', '/') + "/ApiContractTest.java",
                apiContractTest(project, modules));
        files.putAll(smokeTest(project, modules));
    }

    /**
     * 生成唯一一条会加载完整 Spring 上下文的测试。
     *
     * <p>其余测试全是切片或纯单测，发现不了缺 Bean、配置写错、Mapper XML 没扫到、
     * 迁移脚本语法错、拦截器没装上这几类问题——它们只有真启动一次才暴露。</p>
     *
     * <p>有业务模块时产出 ApiSmokeTest：除启动外还会带着当场签发的 Context 打一次
     * 列表接口，顺带验证无 Context 401、权限不足 403。没有业务模块（空脚手架）时
     * 没有接口可打，退回只验启动的 BootSmokeTest。两者二选一，保证整个构建里
     * 只启动一次应用、只拉起一个 MySQL 容器。</p>
     */
    private Map<String, String> smokeTest(ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        String testDir = "kaiwu-" + project.projectCode() + "-boot/src/test/java/"
                + project.packageName().replace('.', '/') + "/";
        Map<String, Object> variables = new LinkedHashMap<>();
        variables.put("basePackage", project.packageName());
        variables.put("projectCode", project.projectCode());
        variables.put("projectId", project.id());
        variables.put("normalizedProjectCode", project.projectCode().replace('-', '_'));
        if (modules.isEmpty()) {
            return Map.of(
                    testDir + "BootSmokeTest.java",
                    templates.render("project/backend/BootSmokeTest.java.ftl", variables));
        }
        ProjectScaffoldGenerator.GeneratedModule first = modules.get(0);
        variables.put("smokePermission", first.permissionPrefix() + ":list");
        variables.put("smokeListPath", "/api/" + first.moduleCode() + "/" + first.resourceCode());
        return Map.of(
                testDir + "ApiSmokeTest.java", templates.render("project/backend/ApiSmokeTest.java.ftl", variables));
    }

    private String menuManifest(List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        if (modules.isEmpty()) {
            return "# 基础脚手架尚无业务菜单；新增模块时保持权限三端同码，并在这里补菜单与 BUTTON。\n[]\n";
        }
        return modules.stream()
                .map(ProjectScaffoldGenerator.GeneratedModule::menuManifest)
                .reduce((left, right) -> left + "\n" + right)
                .orElse("");
    }

    private String apiContract(List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        Set<String> lines = new TreeSet<>();
        for (ProjectScaffoldGenerator.GeneratedModule module : modules) {
            String base = "/api/" + module.moduleCode() + "/" + module.resourceCode();
            lines.add("GET " + base);
            lines.add("GET " + base + "/{id}");
            lines.add("POST " + base);
            lines.add("PUT " + base + "/{id}");
            lines.add("DELETE " + base + "/{id}");
            String entity = module.table().getEntityName();
            for (ColumnMeta column : module.table().editableColumns()) {
                lines.add(field(entity + "SaveRequest", templates.apiColumn(column)));
            }
            for (ColumnMeta column : module.table().getColumns()) {
                lines.add(field(entity + "View", templates.apiColumn(column)));
            }
        }
        return String.join("\n", lines) + "\n";
    }

    private String field(String owner, ProjectScaffoldGenerator.ApiColumn column) {
        return "FIELD " + owner + "." + column.fieldName() + " : " + column.apiType();
    }

    private String apiContractTest(ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        List<String> controllers = new ArrayList<>();
        List<String> payloads = new ArrayList<>();
        for (ProjectScaffoldGenerator.GeneratedModule module : modules) {
            String entity = module.table().getEntityName();
            String base = project.packageName() + ".module." + module.moduleCode();
            controllers.add(base + ".controller." + entity + "Controller");
            payloads.add(base + ".dto.request." + entity + "SaveRequest");
            payloads.add(base + ".vo." + entity + "View");
        }
        Map<String, Object> variables = new LinkedHashMap<>();
        variables.put("basePackage", project.packageName());
        variables.put("contractControllers", controllers);
        variables.put("contractPayloads", payloads);
        return templates.render("project/backend/ApiContractTest.java.ftl", variables);
    }
}
