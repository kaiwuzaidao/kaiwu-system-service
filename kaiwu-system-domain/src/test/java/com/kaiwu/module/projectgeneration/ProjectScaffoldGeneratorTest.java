package com.kaiwu.module.projectgeneration;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.codegen.CodegenTemplateRenderer;
import com.kaiwu.module.codegen.DdlParser;
import com.kaiwu.module.codegen.model.TableMeta;
import com.kaiwu.module.project.vo.ProjectView;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ProjectScaffoldGeneratorTest {

    @Test
    void rendersTwoIndependentRepositoriesFromOneBlueprint() {
        // ddl 与 tables 必须同源：Flyway 用 ddl 建表，Mapper 按 tables 选列。
        // 两者不一致时生成物照样编译通过，却会在真正查一次的时候 500——
        // 这正是 ApiSmokeTest 第一次跑就抓到的问题。
        String ddl =
                """
                CREATE TABLE biz_order (
                  id BIGINT NOT NULL COMMENT '主键',
                  owner_user_id BIGINT NOT NULL COMMENT '数据归属用户',
                  order_no VARCHAR(64) NOT NULL COMMENT '订单号',
                  status VARCHAR(32) NOT NULL COMMENT '状态',
                  created_at DATETIME NOT NULL COMMENT '创建时间',
                  PRIMARY KEY (id)
                ) COMMENT='订单管理'
                """;
        List<TableMeta> tables = new DdlParser().parseAll(ddl);
        ProjectView project = new ProjectView(
                "9000000000000001001",
                "order-center",
                "订单中心",
                "订单后台",
                "ACTIVE",
                false,
                "1",
                "com.example.order",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectBlueprintService.ProjectBlueprint blueprint =
                new ProjectBlueprintService.ProjectBlueprint("AI_PROJECT", ddl, "test-model", "第一版订单后台", tables, "{}");

        ProjectScaffoldGenerator.GeneratedRepositories generated =
                new ProjectScaffoldGenerator(new CodegenTemplateRenderer()).generate(project, blueprint);

        assertThat(generated.backendFiles())
                .containsKeys(
                        "pom.xml",
                        "kaiwu-order-center-api/pom.xml",
                        "kaiwu-order-center-api/src/main/java/com/example/order/common/Result.java",
                        "kaiwu-order-center-api/src/main/java/com/example/order/module/order/dto/BizOrderSaveRequest.java",
                        "kaiwu-order-center-api/src/main/java/com/example/order/module/order/vo/BizOrderView.java",
                        "kaiwu-order-center-domain/pom.xml",
                        "kaiwu-order-center-domain/src/main/java/com/example/order/module/order/entity/BizOrder.java",
                        "kaiwu-order-center-domain/src/main/java/com/example/order/module/order/controller/BizOrderController.java",
                        "kaiwu-order-center-boot/pom.xml",
                        "kaiwu-order-center-boot/src/main/java/com/example/order/OrderCenterApplication.java",
                        "kaiwu-order-center-boot/src/main/java/com/example/order/config/MybatisPlusConfig.java",
                        "sql/schema.sql",
                        "kaiwu-order-center-boot/src/main/resources/db/migration/V1__init_business_schema.sql",
                        "sql/menu.sql",
                        "scripts/check-permission-seed.sh",
                        "scripts/check-test-baseline.sh",
                        "scripts/check-constraints.sh",
                        "scripts/dev-check.sh",
                        "scripts/dev.sh",
                        "compose.local.yml",
                        "docs/gateway-route-local.yml",
                        "deploy/server/compose.yml",
                        "deploy/server/gateway-route.yml",
                        "deploy/k8s/deployment.yaml",
                        "deploy/k8s/service.yaml",
                        "deploy/k8s/kustomization.yaml",
                        "deploy/k8s/gateway-route-values.yaml",
                        "docs/kaiwu-constraints.json",
                        "docs/kaiwu-constraint-waivers.json",
                        "docs/api-contract.txt",
                        "kaiwu-order-center-domain/src/test/java/com/example/order/ApiContractTest.java",
                        "kaiwu-order-center-domain/src/test/java/com/example/order/module/order/service/BizOrderServiceTest.java",
                        "kaiwu-order-center-domain/src/test/java/com/example/order/common/SqlProjectionConventionTest.java",
                        "kaiwu-order-center-domain/src/test/java/com/example/order/common/ManagedThreadConventionTest.java",
                        "kaiwu-order-center-domain/src/test/java/com/example/order/module/order/controller/BizOrderControllerTest.java",
                        "AGENTS.md",
                        "CLAUDE.md");
        assertThat(generated.backendFiles().keySet()).noneMatch(path -> path.startsWith("sql/increment/"));
        assertThat(generated.backendFiles().keySet()).noneMatch(path -> path.startsWith("src/main/"));
        assertThat(generated.backendFiles().get("pom.xml"))
                .contains("<packaging>pom</packaging>")
                .contains("<module>kaiwu-order-center-api</module>")
                .contains("<module>kaiwu-order-center-domain</module>")
                .contains("<module>kaiwu-order-center-boot</module>");
        assertThat(generated.backendFiles().get("kaiwu-order-center-domain/pom.xml"))
                .contains("<artifactId>kaiwu-order-center-api</artifactId>");
        assertThat(generated.backendFiles().get("kaiwu-order-center-boot/pom.xml"))
                .contains("<artifactId>kaiwu-order-center-domain</artifactId>")
                .contains("<finalName>kaiwu-order-center-service</finalName>");
        assertThat(
                        generated
                                .backendFiles()
                                .get(
                                        "kaiwu-order-center-api/src/main/java/com/example/order/module/order/dto/BizOrderSaveRequest.java"))
                .doesNotContain("String id")
                .doesNotContain("ownerUserId")
                .contains("@NotBlank")
                .contains("String orderNo");
        assertThat(
                        generated
                                .backendFiles()
                                .get(
                                        "kaiwu-order-center-api/src/main/java/com/example/order/module/order/vo/BizOrderView.java"))
                .contains("String id");
        assertThat(
                        generated
                                .backendFiles()
                                .get(
                                        "kaiwu-order-center-domain/src/main/java/com/example/order/module/order/controller/BizOrderController.java"))
                .contains("@Valid @RequestBody")
                .contains("@PutMapping(\"/{id}\")")
                .doesNotContain("request.id()")
                .contains("entity.getId() == null ? null : entity.getId().toString()");
        assertThat(
                        generated
                                .backendFiles()
                                .get(
                                        "kaiwu-order-center-domain/src/main/java/com/example/order/module/order/service/BizOrderService.java"))
                .contains("StarterContext.userId()")
                .contains("BizOrder::getOwnerUserId")
                .contains("资源不存在或无权访问")
                .contains("new LambdaUpdateWrapper<BizOrder>()")
                .doesNotContain("selectById(id)")
                .doesNotContain("deleteById(id)");
        assertThat(generated.frontendFiles())
                .containsKeys(
                        "package.json",
                        "pnpm-lock.yaml",
                        "config/config.ts",
                        "src/app.tsx",
                        "src/providers/ProjectAccessProvider.tsx",
                        "src/components/PermissionButton/index.tsx",
                        "src/components/ManagedDictSelect/index.tsx",
                        "src/components/ManagedDictText/index.tsx",
                        "src/components/RightContent/index.tsx",
                        "src/components/GlobalSearch/index.tsx",
                        "src/components/NotificationBell/index.tsx",
                        "src/hooks/useManagedDictionary.ts",
                        "src/services/request.ts",
                        "src/services/platform.ts",
                        "ci.env",
                        "src/services/order.ts",
                        "src/utils/accessToken.ts",
                        "src/pages/Order/index.tsx",
                        "scripts/check-dict-consistency.mjs",
                        "scripts/check-permission-consistency.mjs",
                        "scripts/check-constraints.sh",
                        "scripts/dev.sh",
                        "docs/kaiwu-project-blueprint.json",
                        "docs/kaiwu-constraints.json",
                        "docs/kaiwu-constraint-waivers.json",
                        "deploy/server/compose.yml",
                        "deploy/server/nginx-locations.conf",
                        "deploy/k8s/deployment.yaml",
                        "deploy/k8s/service.yaml",
                        "deploy/k8s/gateway-service.yaml",
                        "deploy/k8s/ingress.yaml",
                        "deploy/k8s/kustomization.yaml",
                        ".prettierrc.json",
                        "AGENTS.md",
                        "CLAUDE.md");
        assertThat(generated.frontendFiles())
                .doesNotContainKey("src/shell/index.tsx")
                .doesNotContainKey("src/pages/Order/api.ts");
        assertThat(generated.backendFiles().keySet()).noneMatch(path -> path.startsWith("admin-web/"));
        assertThat(generated.backendFiles().values())
                .anyMatch(value -> value.contains("@RequirePermission(\"order:order:list\")"));
        assertThat(generated.frontendFiles().values())
                .anyMatch(value -> value.contains("permission=\"order:order:list\""));
        assertThat(generated.frontendFiles().values())
                .noneMatch(value ->
                        value.contains("AuthButton") || value.contains("pfRequest") || value.contains("usePermission"));
        // 观感与平台端一致：侧栏底部区域、品牌方块、统一的纵向间距，
        // 这三样此前只在手工调过的 reimburse 里有，生成项目是光板。
        assertThat(generated.frontendFiles().get("src/app.tsx"))
                .contains("rightContentRender")
                .contains("RightContent")
                .contains("paddingBlockPageContainerContent")
                .contains("breadcrumbRender: false");
        // run_untagged=false 的 runner 上少了这行 tag，作业永远排队不执行。
        assertThat(generated.frontendFiles().get(".gitlab-ci.yml")).contains("tags: [docker]");
        // 生成物要能被任何组织直接使用：镜像走变量、默认值是公共镜像，
        // 私有仓库由 CI 变量覆盖。模板里不允许出现任何具体组织的地址。
        assertThat(generated.frontendFiles().get(".gitlab-ci.yml"))
                .contains("NODE_BUILD_IMAGE: \"node:20-bookworm\"")
                .contains("TRIVY_IMAGE: \"aquasec/trivy:0.64.1\"")
                .contains("image: $UTIL_IMAGE")
                // GitOps 仓的主机名用 GitLab 内置的 CI_SERVER_HOST，而不是自定义变量：
                // 同样不写死任何组织地址，但不需要任何人去配一个变量。
                .contains("${CI_SERVER_HOST}");
        // 生成物不得带出私网地址。只查 IP 字面量：本测试自身也随开源发布，写死组织名
        // 等于把它公开一遍；而按 ".internal" 子串查会误伤 i18n key（error.internal）。
        // 组织专有的主机名由 scripts/check.sh 的 KAIWU_INTERNAL_PATTERN 负责，
        // 那条可以按采用方配置，不必进仓库。
        assertThat(generated.frontendFiles().values())
                .noneMatch(value -> value.matches("(?s).*\\b(10\\.\\d{1,3}|192\\.168|172\\.(1[6-9]|2\\d|3[01]))"
                        + "\\.\\d{1,3}\\.\\d{1,3}\\b.*"));
        assertThat(generated.frontendFiles().get("src/utils/accessToken.ts"))
                .contains("configureAccessToken")
                .contains("KAIWU_ACCESS_REQUEST")
                .contains("window.location.origin");
        assertThat(generated.frontendFiles().get("src/services/request.ts"))
                .contains("requestJson")
                .doesNotContain("localStorage")
                .doesNotContain("sessionStorage");
        assertThat(generated.frontendFiles().get("src/hooks/useManagedDictionary.ts"))
                .contains("DICTIONARY_RETRY_MS")
                .doesNotContain("localStorage")
                .doesNotContain("sessionStorage");
        assertThat(generated.frontendFiles().get("src/services/order.ts"))
                .doesNotContain("const projectId")
                .doesNotContain("projectId,");
        assertThat(generated.frontendFiles().get("Dockerfile"))
                .contains("COPY package.json pnpm-lock.yaml .npmrc ./")
                .contains("pnpm install --frozen-lockfile")
                .contains("/usr/share/nginx/html/apps/order-center");
        assertThat(generated.frontendFiles().get("nginx.conf")).contains("/apps/order-center/index.html");
        assertThat(generated.backendFiles().get("sql/menu.sql"))
                .contains("'order:order:list'")
                .contains("'/order'")
                .doesNotContain("'/order/order'");
        assertThat(generated.backendFiles().get("kaiwu-order-center-boot/src/main/resources/application.yml"))
                .contains("${DB_NAME:kaiwu_order_center}")
                .contains("baseline-on-migrate: false")
                .doesNotContain("baseline-version")
                .contains("project-id: 9000000000000001001")
                .contains("credential: ${KAIWU_SCHEDULER_CREDENTIAL:}")
                .doesNotContain("zsch_");
        assertThat(generated.backendFiles().get("compose.local.yml"))
                .contains("mysql:8.4")
                .contains("${DB_PASSWORD:?请设置 DB_PASSWORD}")
                .doesNotContain("password: root");
        // 启动方式必须是可执行 jar：`mvn -pl <boot> spring-boot:run` 会去本地仓库找兄弟模块，
        // 而 verify/package 并不安装它们，干净机器上必然 Could not find artifact。
        assertThat(generated.backendFiles().get("scripts/dev.sh"))
                .contains("bash scripts/dev-check.sh")
                .contains("docker compose -f compose.local.yml up --detach --wait mysql")
                .contains("${JAVA_HOME:+$JAVA_HOME/bin/}java\" -jar")
                .contains("kaiwu-order-center-boot/target/kaiwu-order-center-service.jar")
                // 脚本里保留了「为什么不用 spring-boot:run」的注释，所以只断言启动命令本身。
                .doesNotContain("exec mvn");
        assertThat(generated.backendFiles().get("docs/gateway-route-local.yml"))
                .contains("Path=/order-center-api/**")
                .contains("accessMode: PROJECT")
                .contains("audience: kaiwu-order-center-service")
                .contains("projectCode: order-center")
                .contains("RewritePath=/order-center-api/(?<segment>.*), /${segment}");
        assertThat(generated.backendFiles().get("deploy/server/compose.yml"))
                .contains("name: kaiwu-order-center")
                .contains("kaiwu-order-center-service:")
                .contains("name: ${KAIWU_PLATFORM_NETWORK:-kaiwu_default}")
                .contains("${KAIWU_CONTEXT_PUBLIC_KEY:?请设置 KAIWU_CONTEXT_PUBLIC_KEY}");
        assertThat(generated.backendFiles().get("deploy/server/gateway-route.yml"))
                .contains("uri: http://kaiwu-order-center-service:8080")
                .contains("accessMode: PROJECT");
        assertThat(generated.backendFiles().get("deploy/k8s/deployment.yaml"))
                .contains("image: kaiwu-order-center-service:replace-me")
                .contains("name: kaiwu-order-center-runtime")
                .doesNotContain("db-password:");
        assertThat(generated.frontendFiles().get("deploy/server/nginx-locations.conf"))
                .contains("location /apps/order-center/")
                .contains("location /order-center-api/")
                .contains("proxy_pass http://127.0.0.1:8088");
        assertThat(generated.frontendFiles().get("deploy/k8s/ingress.yaml"))
                .contains("name: kaiwu-order-center-web")
                .contains("name: kaiwu-platform-gateway");
        assertThat(generated.frontendFiles().get("deploy/k8s/gateway-service.yaml"))
                .contains("type: ExternalName")
                .contains("externalName: kaiwu-kaiwu-gateway.kaiwu.svc.cluster.local");
        assertThat(generated.frontendFiles().get("deploy/k8s/kustomization.yaml"))
                .contains("gateway-service.yaml");
        assertThat(generated.frontendFiles().get("scripts/dev.sh"))
                .contains("pnpm install --frozen-lockfile --ignore-scripts")
                .contains("PORT=${PORT:-8416} pnpm dev");
        // 端口由项目编码派生：同一台机器上跑多个生成项目不该互相顶掉。
        assertThat(generated.backendFiles().get("compose.local.yml")).contains("${DB_PORT:-3323}:3306");
        assertThat(generated.backendFiles().get("scripts/dev.sh")).contains("${SERVER_PORT:-8316}");
        // 独立 dev server 必须能把业务请求转给本机 Gateway，否则 /xxx-api 打到自己身上 404。
        assertThat(generated.frontendFiles().get("config/config.ts"))
                .contains("'/order-center-api': {")
                .contains("target: 'http://127.0.0.1:8088'");
        assertThat(generated.backendFiles().get("docs/kaiwu-project-blueprint.json"))
                .contains("\"templateVersion\": \"kaiwu-project-v13\"")
                .contains("\"accessScope\":\"OWNER_ONLY\"")
                .contains("\"ownerColumn\":\"owner_user_id\"")
                .contains("\"supportedLocales\": [\"zh-CN\"]");
        // 门禁只有进 CI 才算数：脚本随仓库交付但没人执行，等于只写在文档里的约定。
        assertThat(generated.frontendFiles().get("package.json"))
                .contains("\"check:dict\"")
                .contains("\"check:perm\"")
                .contains("\"check:constraints\"")
                .contains("\"format\"")
                .contains("\"prettier\": \"3.9.6\"");
        // 门禁逐条列出而不是一句 pnpm verify：与 reimburse 在跑的管线一致。
        // verify 里还串了 audit:prod，那条由 dependencies 任务的 trivy 覆盖，
        // 放在 build 阶段会让一条新公告直接卡住构建。
        assertThat(generated.frontendFiles().get(".gitlab-ci.yml"))
                .contains("pnpm typecheck")
                .contains("pnpm check:dict")
                .contains("pnpm check:perm")
                .contains("pnpm check:log")
                .contains("pnpm check:constraints")
                .contains("pnpm build")
                .contains("gitleaks dir")
                .contains("gl-sbom.cdx.json")
                .contains("trivy image");
        assertThat(generated.backendFiles().get(".gitlab-ci.yml"))
                .contains("bash scripts/check-permission-seed.sh")
                .contains("bash scripts/check-test-baseline.sh")
                .contains("gitleaks dir")
                .contains("gl-sbom.cdx.json")
                .contains("trivy image");
        assertThat(generated.frontendFiles()).doesNotContainKey("src/locales/en-US.ts");
        assertThat(generated.backendFiles().get("scripts/check-test-baseline.sh"))
                .contains("--strict")
                .contains("默认模式只报告");
        assertThat(generated
                        .backendFiles()
                        .get("kaiwu-order-center-domain/src/test/java/com/example/order/ApiContractTest.java"))
                .contains("removedOrChanged")
                .contains("kaiwu.api-contract.update");
        assertThat(generated.backendFiles().get("pom.xml")).contains("spotless-maven-plugin");
        // API 模块用 HttpStatus 表达状态码，缺 spring-web 会让生成后端第一个模块就编译失败。
        assertThat(generated.backendFiles().get("kaiwu-order-center-api/pom.xml"))
                .contains("<artifactId>spring-web</artifactId>");
        assertThat(generated.backendFiles().get("kaiwu-order-center-domain/pom.xml"))
                .contains("<artifactId>spring-boot-starter-test</artifactId>");
        // 契约快照必须与 ApiContractTest 反射出的结果一致，否则新项目第一次跑 CI 就红。
        // 逐字节一致性由 verify-generated-scaffold.sh 的真实 mvn verify 保证。
        assertThat(generated.backendFiles().get("docs/api-contract.txt"))
                .isEqualTo(
                        """
                        DELETE /api/order/order/{id}
                        FIELD BizOrderSaveRequest.orderNo : String
                        FIELD BizOrderSaveRequest.status : String
                        FIELD BizOrderView.createdAt : LocalDateTime
                        FIELD BizOrderView.id : String
                        FIELD BizOrderView.orderNo : String
                        FIELD BizOrderView.ownerUserId : String
                        FIELD BizOrderView.status : String
                        GET /api/order/order
                        GET /api/order/order/{id}
                        POST /api/order/order
                        PUT /api/order/order/{id}
                        """);
        // 长整型 ID 必须以字符串出现在 JSON 里，这条契约要有测试守着。
        assertThat(
                        generated
                                .backendFiles()
                                .get(
                                        "kaiwu-order-center-domain/src/test/java/com/example/order/module/order/controller/BizOrderControllerTest.java"))
                .contains("jsonPath(\"$.data.records[0].id\").isString()");
        // check:perm 靠 manifest 认识合法模块前缀，前端用到的前缀必须已登记，
        // 否则新生成的项目第一次跑 CI 就红。
        assertThat(generated.frontendFiles().get("docs/kaiwu-project-blueprint.json"))
                .contains("\"permissionPrefix\":\"order:order\"");

        // 交付后必做的两步不在任何门禁里，漏掉的表现是"页面能开、按钮和下拉全是空的"，
        // 所以 README 首屏必须显式写出来，测试守住它别被后来的编辑挤掉。
        assertThat(generated.backendFiles().get("README.md"))
                .contains("交付后必做")
                .contains("import-project-menu")
                .contains("sql/dict.sql");
        // 字典种子：脚手架不猜业务枚举，但格式、scope 约定和导入命令要给全。
        assertThat(generated.backendFiles().get("sql/dict.sql"))
                .contains("SET NAMES utf8mb4")
                .contains("9000000000000001001")
                .contains("inherit_global");
        // 唯一加载完整 Spring 上下文的测试。没有它，"编译通过"就被当成了"能启动"。
        // 有业务模块时产出的是 ApiSmokeTest：真 HTTP、真鉴权、真库打一次列表接口。
        assertThat(generated
                        .backendFiles()
                        .get("kaiwu-order-center-boot/src/test/java/com/example/order/ApiSmokeTest.java"))
                .contains("@SpringBootTest")
                .contains("MySQLContainer")
                .contains("/actuator/health")
                .contains("/api/order/order")
                .contains("X-Kaiwu-Context")
                .contains("order:order:list")
                .contains("isEqualTo(401)")
                .contains("isEqualTo(403)");
        assertThat(generated.backendFiles())
                .doesNotContainKey("kaiwu-order-center-boot/src/test/java/com/example/order/BootSmokeTest.java");
        assertThat(generated.backendFiles().get("kaiwu-order-center-boot/pom.xml"))
                .contains("testcontainers-mysql")
                // Spring Boot 4.0 把 Flyway 自动配置拆到了独立模块。只引 flyway-core 时
                // 应用照常启动、迁移一次都不跑，第一次查业务表才炸 "Table doesn't exist"。
                // ApiSmokeTest 第一次真跑就是栽在这里，这条断言守住别再掉回去。
                .contains("spring-boot-flyway");
        // 前后端是同一批模板生成的，路径漂移只会来自模板改动——在这里逐条对住，
        // 比等到运行期再发现便宜得多。前端多一层 /{projectCode}-api 前缀，由 nginx 反代剥掉。
        String backendContract = generated.backendFiles().get("docs/api-contract.txt");
        assertThat(backendContract)
                .contains("GET /api/order/order")
                .contains("POST /api/order/order")
                .contains("PUT /api/order/order/{id}")
                .contains("DELETE /api/order/order/{id}");
        assertThat(generated.frontendFiles().get("src/services/order.ts"))
                .contains("const API_BASE = '/order-center-api/api/order/order'");
        // 前端按 {records, total} 解分页，后端 View 字段名必须能对上。
        assertThat(generated.frontendFiles().get("src/services/order.ts"))
                .contains("records")
                .contains("total");
        assertThat(backendContract).contains("FIELD BizOrderView.orderNo").contains("FIELD BizOrderView.status");
        assertThat(generated.frontendFiles().get("src/pages/Order/index.tsx"))
                .contains("orderNo")
                .contains("status");

        write(Path.of("target/project-scaffold-sample/backend"), generated.backendFiles());
        write(Path.of("target/project-scaffold-sample/frontend"), generated.frontendFiles());
    }

    @Test
    void removesProjectPrefixFromGeneratedBusinessModuleNames() {
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE reimburse_membership_plan (
                  id BIGINT NOT NULL COMMENT '主键',
                  plan_name VARCHAR(64) NOT NULL COMMENT '套餐名称',
                  PRIMARY KEY (id)
                ) COMMENT '会员套餐'
                """);
        ProjectView project = new ProjectView(
                "9000000000000001002",
                "reimburse",
                "记账管理",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.reimburse",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectBlueprintService.ProjectBlueprint blueprint = new ProjectBlueprintService.ProjectBlueprint(
                "AI_PROJECT",
                "CREATE TABLE reimburse_membership_plan (id BIGINT);",
                "test-model",
                "记账后台",
                tables,
                "{}");

        ProjectScaffoldGenerator.GeneratedRepositories generated =
                new ProjectScaffoldGenerator(new CodegenTemplateRenderer()).generate(project, blueprint);

        assertThat(generated.backendFiles())
                .containsKey(
                        "kaiwu-reimburse-domain/src/main/java/com/example/reimburse/module/membershipplan/entity/ReimburseMembershipPlan.java");
        assertThat(generated.frontendFiles())
                .containsKeys("src/pages/MembershipPlan/index.tsx", "src/services/membershipplan.ts")
                .doesNotContainKey("src/pages/Reimbursemembershipplan/index.tsx");
        assertThat(generated.frontendFiles().get("config/config.ts")).contains("component: './MembershipPlan'");
        assertThat(generated.backendFiles().get("sql/menu.sql"))
                .contains("'会员套餐'")
                .contains("'/membershipplan'")
                .doesNotContain("'/membershipplan/membershipplan'");
    }

    @Test
    void rendersEmptyScaffoldWithoutAnyBusinessModule() {
        // 空脚手架是产品明确支持的一条路径（不调 AI、不生成业务表），
        // 但此前没有任何用例走过它——一旦某个模板假设"至少有一个模块"就会当场崩。
        ProjectView project = new ProjectView(
                "9000000000000001004",
                "blank-desk",
                "空白工作台",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.blank",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectBlueprintService.ProjectBlueprint blueprint =
                new ProjectBlueprintService.ProjectBlueprint("BASIC", "", "", "空脚手架", List.of(), "{}");

        ProjectScaffoldGenerator.GeneratedRepositories generated =
                new ProjectScaffoldGenerator(new CodegenTemplateRenderer()).generate(project, blueprint);

        assertThat(generated.backendFiles())
                .containsKeys(
                        "pom.xml",
                        "sql/menu.sql",
                        "sql/dict.sql",
                        "README.md",
                        // 零模块时没有接口可打，冒烟退回只验启动的那一条。
                        "kaiwu-blank-desk-boot/src/test/java/com/example/blank/BootSmokeTest.java")
                .doesNotContainKey("kaiwu-blank-desk-boot/src/test/java/com/example/blank/ApiSmokeTest.java");
        assertThat(generated.frontendFiles())
                .containsKeys(
                        "package.json",
                        "config/config.ts",
                        "src/app.tsx",
                        "src/components/RightContent/index.tsx",
                        "src/pages/Home/index.tsx");
        // 首页在零模块时不能渲染成半截 JSX。
        assertThat(generated.frontendFiles().get("src/pages/Home/index.tsx"))
                .contains("PageContainer")
                .doesNotContain("<Card title=\"\"");
        assertThat(generated.frontendFiles().get("config/config.ts")).contains("component: './Home'");
    }

    @Test
    void rendersWideColumnTypesWithoutFallingBackToObject() {
        // 单一形状的样例蓝图掩盖了类型分支：金额、布尔、日期、可空与逻辑删除
        // 走的是 Entity/View/SaveRequest 里不同的模板分支，这里一次覆盖到。
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE biz_invoice (
                  id BIGINT NOT NULL COMMENT '主键',
                  amount DECIMAL(18,2) NOT NULL COMMENT '金额',
                  paid TINYINT(1) NOT NULL COMMENT '是否已付',
                  issued_on DATE NULL COMMENT '开票日期',
                  remark VARCHAR(255) NULL COMMENT '备注',
                  deleted TINYINT(1) NOT NULL DEFAULT 0 COMMENT '逻辑删除',
                  created_at DATETIME NOT NULL COMMENT '创建时间',
                  PRIMARY KEY (id)
                ) COMMENT='发票'
                """);
        ProjectView project = new ProjectView(
                "9000000000000001005",
                "invoice-hub",
                "发票中心",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.invoice",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectBlueprintService.ProjectBlueprint blueprint = new ProjectBlueprintService.ProjectBlueprint(
                "AI_PROJECT", "CREATE TABLE biz_invoice (id BIGINT PRIMARY KEY);", "test-model", "发票后台", tables, "{}");

        ProjectScaffoldGenerator.GeneratedRepositories generated =
                new ProjectScaffoldGenerator(new CodegenTemplateRenderer()).generate(project, blueprint);

        String entity = generated
                .backendFiles()
                .get(
                        "kaiwu-invoice-hub-domain/src/main/java/com/example/invoice/module/invoice/entity/BizInvoice.java");
        assertThat(entity)
                .contains("BigDecimal amount")
                .contains("LocalDate issuedOn")
                .contains("LocalDateTime createdAt")
                .doesNotContain("Object ");
        // 类型不认识时回落成 Object 会一路编译通过，却让接口契约失真——必须拦住。
        assertThat(generated.backendFiles().values()).noneMatch(value -> value.contains("private Object "));
    }

    @Test
    void rendersNonStringSearchFieldsWithNullSafeEquality() {
        List<TableMeta> tables = new DdlParser()
                .parseAll(
                        """
                CREATE TABLE biz_payment (
                  id BIGINT NOT NULL COMMENT '主键',
                  amount DECIMAL(18,2) COMMENT '金额',
                  PRIMARY KEY (id)
                ) COMMENT='支付'
                """);
        tables.getFirst().getColumns().stream()
                .filter(column -> "amount".equals(column.getFieldName()))
                .findFirst()
                .orElseThrow()
                .setSearchable(true);
        ProjectView project = new ProjectView(
                "9000000000000001003",
                "billing",
                "账单",
                null,
                "ACTIVE",
                false,
                "1",
                "com.example.billing",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
        ProjectBlueprintService.ProjectBlueprint blueprint = new ProjectBlueprintService.ProjectBlueprint(
                "AI_PROJECT", "CREATE TABLE biz_payment (id BIGINT);", "test-model", "支付", tables, "{}");

        ProjectScaffoldGenerator.GeneratedRepositories generated =
                new ProjectScaffoldGenerator(new CodegenTemplateRenderer()).generate(project, blueprint);
        String service = generated
                .backendFiles()
                .get(
                        "kaiwu-billing-domain/src/main/java/com/example/billing/module/payment/service/BizPaymentService.java");

        assertThat(service)
                .contains(".eq(")
                .contains("query.getAmount() != null")
                .doesNotContain("StringUtils.hasText(query.getAmount())");
    }

    private void write(Path root, Map<String, String> files) {
        if (Files.exists(root)) {
            try (var paths = Files.walk(root)) {
                paths.sorted(java.util.Comparator.reverseOrder()).forEach(path -> {
                    try {
                        Files.delete(path);
                    } catch (Exception exception) {
                        throw new IllegalStateException(exception);
                    }
                });
            } catch (Exception exception) {
                throw new IllegalStateException(exception);
            }
        }
        files.forEach((relative, content) -> {
            try {
                Path target = root.resolve(relative);
                Files.createDirectories(target.getParent());
                Files.writeString(target, content);
            } catch (Exception exception) {
                throw new IllegalStateException(exception);
            }
        });
    }
}
