package com.kaiwu.module.projectgeneration;

import com.kaiwu.module.codegen.model.ColumnMeta;
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
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/SqlProjectionConventionTest.java",
                templates.render("project/backend/SqlProjectionConventionTest.java.ftl", variables));
        files.put(
                modulePrefix + "-domain/src/test/java/" + packagePath + "/common/ManagedThreadConventionTest.java",
                templates.render("project/backend/ManagedThreadConventionTest.java.ftl", variables));
        files.put(
                "scripts/check-permission-seed.sh",
                templates.render("project/backend/check-permission-seed.sh.ftl", variables));
        files.put(
                "scripts/check-test-baseline.sh",
                templates.render("project/backend/check-test-baseline.sh.ftl", variables));
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
                """);
        String migrationDir = modulePrefix + "-boot/src/main/resources/db/migration/";
        // 受管字典种子：脚手架不猜业务枚举，但把格式、scope 约定和导入命令给全，
        // 免得每个项目重新摸索一遍（check:dict 在零字典时是通过的，靠门禁发现不了）。
        files.put("sql/dict.sql", templates.render("project/backend/dict.sql.ftl", variables));
        if (StringUtils.hasText(blueprint.ddl())) {
            String ddl = blueprint.ddl().trim() + "\n";
            files.put("sql/schema.sql", ddl);
            files.put(migrationDir + "V1__init_business_schema.sql", ddl);
        } else {
            files.put("sql/schema.sql", "-- 当前是空脚手架；新增业务表时同步本快照。\n");
            files.put(
                    migrationDir + "V1__init_business_schema.sql",
                    "-- 当前是空脚手架；首个业务表变更从本 migration 开始。\n" + "-- 新增迁移请追加 V{n}__desc.sql，Spring Boot 启动会自动执行。\n");
        }
        return files;
    }

    void complete(
            Map<String, String> files, ProjectView project, List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        files.put("sql/menu.sql", menuSql(modules));
        files.put("docs/api-contract.txt", apiContract(modules));
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

    private String menuSql(List<ProjectScaffoldGenerator.GeneratedModule> modules) {
        if (modules.isEmpty()) {
            return "-- 基础脚手架尚无业务菜单；新增模块时保持权限三端同码。\n";
        }
        return modules.stream()
                .map(ProjectScaffoldGenerator.GeneratedModule::menuSql)
                .reduce((left, right) -> left + "\n\n" + right)
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
            payloads.add(base + ".dto." + entity + "SaveRequest");
            payloads.add(base + ".vo." + entity + "View");
        }
        Map<String, Object> variables = new LinkedHashMap<>();
        variables.put("basePackage", project.packageName());
        variables.put("contractControllers", controllers);
        variables.put("contractPayloads", payloads);
        return templates.render("project/backend/ApiContractTest.java.ftl", variables);
    }
}
