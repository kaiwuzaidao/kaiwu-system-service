package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.factory.convert.ProjectManifestParser;
import com.kaiwu.module.factory.model.ProjectManifest;
import com.kaiwu.module.factory.service.impl.ProjectManifestExportServiceImpl;
import com.kaiwu.module.factory.vo.ProjectManifestExportView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/**
 * 项目配置移交包导出（ADR 0042）：内容完整、可被清单解析器接受、摘要稳定。
 */
class ProjectManifestExportServiceTest {

    private static final String PROJECT = "100";

    private MetadataService metadata;
    private I18nService i18n;
    private ProjectService projectService;
    private ProjectSchedulerService scheduler;
    private ProjectManifestExportService service;
    private com.kaiwu.module.project.service.ProjectDataScopeService dataScopes;

    /** 平台数据初始为空，项目管理员校验直接通过。 */
    @BeforeEach
    void setUp() {
        metadata = mock(MetadataService.class);
        i18n = mock(I18nService.class);
        projectService = mock(ProjectService.class);
        scheduler = mock(ProjectSchedulerService.class);
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(1, 100, 0, List.of()));
        ProjectGenerationProjectPort projects = mock(ProjectGenerationProjectPort.class);
        when(projects.requireProjectAdmin(eq(PROJECT), anyString())).thenReturn(project());
        when(i18n.projectMessages(PROJECT)).thenReturn(List.of());
        when(projectService.menus(PROJECT)).thenReturn(List.of());
        when(projectService.roles(PROJECT)).thenReturn(List.of());
        dataScopes = mock(com.kaiwu.module.project.service.ProjectDataScopeService.class);
        when(dataScopes.roleScopes(any(), any()))
                .thenReturn(new com.kaiwu.module.project.vo.ProjectRoleDataScopeView("", "", false, List.of()));
        service = new ProjectManifestExportServiceImpl(
                projects, projectService, metadata, i18n, JsonMapper.builder().build(), scheduler, dataScopes);
    }

    /** 字典、配置、菜单、角色全部导出，导出的清单能被解析器原样接受。 */
    @Test
    void exportedFilesAreAcceptedByManifestParser() {
        when(metadata.dictTypes(PROJECT))
                .thenReturn(List.of(
                        dictType("t1", PROJECT, "expense.type", "费用类型", "dict.expense.type"),
                        dictType("g1", "0", "common.global", "全局字典", null)));
        when(metadata.dictItems(PROJECT, "t1"))
                .thenReturn(List.of(item("TRAVEL", "差旅费", "dict.expense.type.TRAVEL", 10, true)));
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(
                        message("dict.expense.type", "费用类型", "{\"en-US\":\"Expense type\"}"),
                        message("dict.expense.type.TRAVEL", "差旅费", "{\"en-US\":\"Travel\"}")));
        when(metadata.configs(PROJECT))
                .thenReturn(List.of(
                        config("expense.max", "5000", "NUMBER", false), config("expense.token", "x", "STRING", true)));
        when(projectService.menus(PROJECT)).thenReturn(List.of(menuTree()));
        when(projectService.roles(PROJECT)).thenReturn(List.of(role("finance", Set.of("b1", "m1", "d1"))));

        ProjectManifestExportView view = service.export(PROJECT, actor(), "kaiwu-test.example.com");

        assertThat(view.projectCode()).isEqualTo("order-center");
        assertThat(view.stats()).containsEntry("dicts", 1).containsEntry("configs", 1);
        assertThat(view.warnings()).anyMatch(warning -> warning.contains("expense.token"));
        assertThat(view.files().get("dicts.yml"))
                .contains("i18nKey: dict.expense.type")
                .contains("en-US: Travel");
        assertThat(view.files().get("dicts.yml")).doesNotContain("common.global");
        assertThat(view.files().get("configs.yml")).doesNotContain("expense.token");

        Map<String, String> manifestFiles = Map.of(
                "dicts.yml", view.files().get("dicts.yml"),
                "configs.yml", view.files().get("configs.yml"),
                "menus.yml", view.files().get("menus.yml"));
        ProjectManifest parsed = new ProjectManifestParser().parse(manifestFiles);
        assertThat(parsed.dicts()).hasSize(1);
        assertThat(parsed.dicts().get(0).name().messageKey()).isEqualTo("dict.expense.type");
        assertThat(parsed.dicts().get(0).name().translations()).containsEntry("en-US", "Expense type");
        assertThat(parsed.dicts().get(0).items().get(0).defaultItem()).isTrue();
        assertThat(parsed.configs()).extracting(ProjectManifest.Config::key).containsExactly("expense.max");
        assertThat(parsed.menus()).hasSize(1);
        assertThat(parsed.menus().get(0).children()).hasSize(1);
    }

    /** 授权以业务键表示，不含数据库 ID；内置角色不导出。 */
    @Test
    void rolesUseBusinessKeysAndSkipBuiltInRole() {
        when(projectService.menus(PROJECT)).thenReturn(List.of(menuTree()));
        when(projectService.roles(PROJECT))
                .thenReturn(List.of(role("finance", Set.of("b1", "m1", "d1")), builtInRole()));

        String roles = service.export(PROJECT, actor(), null).files().get("roles.yml");

        assertThat(roles).contains("roleCode: finance").contains("expense:bill:approve");
        assertThat(roles).contains("/expense").contains("dir:订单");
        assertThat(roles).doesNotContain("project-admin").doesNotContain("b1");
    }

    /** 建项目时种入的成员管理菜单不导出。 */
    @Test
    void seededAccessMenusAreSkipped() {
        ProjectMenuView seeded = menu("s1", null, "成员管理", "MENU", "/project-members", null, 900, List.of());
        when(projectService.menus(PROJECT)).thenReturn(List.of(menuTree(), seeded));

        String menus = service.export(PROJECT, actor(), null).files().get("menus.yml");

        assertThat(menus).doesNotContain("/project-members");
    }

    /** 同一份数据两次导出摘要相同，数据变化后摘要变化。 */
    @Test
    void digestIsStableAndChangesWithContent() {
        when(metadata.configs(PROJECT)).thenReturn(List.of(config("expense.max", "5000", "NUMBER", false)));
        String first = service.export(PROJECT, actor(), "a").digest();
        String second = service.export(PROJECT, actor(), "b").digest();
        when(metadata.configs(PROJECT)).thenReturn(List.of(config("expense.max", "6000", "NUMBER", false)));
        String third = service.export(PROJECT, actor(), "a").digest();

        assertThat(second).isEqualTo(first);
        assertThat(third).isNotEqualTo(first);
    }

    /** 没有任何配置的项目导出空文件，stats 全为 0。 */
    @Test
    void emptyProjectExportsEmptyFiles() {
        ProjectManifestExportView view = service.export(PROJECT, actor(), null);

        assertThat(view.stats().values()).containsOnly(0);
        assertThat(view.files().values()).containsOnly("");
    }

    /** 定时任务与国际化资源进入移交包，且能被解析器接受；同名任务有歧义，不导出并警告。 */
    @Test
    void jobsAndMessagesAreExportedAndParseBack() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(
                        1,
                        100,
                        3,
                        List.of(
                                job("j1", "日结", "daily.settle", true),
                                job("j2", "周报", "weekly.report", false),
                                job("j3", "周报", "weekly.report", false))));
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(
                        message("order.title", "订单", "{\"en-US\":\"Orders\",\"ja-JP\":\"注文\"}"),
                        message("order.empty", "暂无", null)));

        ProjectManifestExportView view = service.export(PROJECT, actor(), null);

        assertThat(view.stats()).containsEntry("jobs", 1).containsEntry("i18n", 2);
        assertThat(view.warnings()).anyMatch(warning -> warning.contains("周报") && warning.contains("同名"));
        ProjectManifest parsed = new ProjectManifestParser()
                .parse(Map.of(
                        "jobs.yml",
                        view.files().get("jobs.yml"),
                        "i18n.yml",
                        view.files().get("i18n.yml")));
        assertThat(parsed.jobs()).extracting(ProjectManifest.Job::jobName).containsExactly("日结");
        assertThat(parsed.jobs().get(0).cronExpression()).isEqualTo("0 0 2 * * *");
        assertThat(parsed.messages())
                .extracting(ProjectManifest.Message::messageKey)
                .containsExactly("order.empty", "order.title");
        assertThat(parsed.messages().get(1).translations()).containsEntry("ja-JP", "注文");
    }

    /** 调用者不是项目成员读不了定时任务时，不影响其它资源的导出，只给警告。 */
    @Test
    void jobsReadFailureOnlyWarns() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenThrow(new ApiException(
                        org.springframework.http.HttpStatus.FORBIDDEN, "不是项目成员", "api.common.forbidden"));

        ProjectManifestExportView view = service.export(PROJECT, actor(), null);

        assertThat(view.warnings()).anyMatch(warning -> warning.contains("定时任务未导出"));
        assertThat(view.files().get("jobs.yml")).isEmpty();
    }

    /** 定时任务视图。 */
    private static SchedulerJobView job(String id, String name, String type, boolean enabled) {
        return new SchedulerJobView(
                id,
                PROJECT,
                "订单中心",
                name,
                type,
                "0 0 2 * * *",
                "Asia/Shanghai",
                "{\"day\":1}",
                enabled,
                1L,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 菜单树：目录 → 页面 → 按钮。 */
    private static ProjectMenuView menuTree() {
        ProjectMenuView button = menu("b1", "m1", "审批", "BUTTON", null, "expense:bill:approve", 10, List.of());
        ProjectMenuView page = menu("m1", "d1", "订单列表", "MENU", "/expense", null, 10, List.of(button));
        return menu("d1", null, "订单", "DIRECTORY", null, null, 10, List.of(page));
    }

    /** 构造菜单节点。 */
    private static ProjectMenuView menu(
            String id,
            String parentId,
            String name,
            String type,
            String route,
            String permission,
            int sort,
            List<ProjectMenuView> children) {
        return new ProjectMenuView(
                id,
                PROJECT,
                parentId,
                name,
                null,
                type,
                route,
                "MENU".equals(type) ? "Expense" : null,
                permission,
                null,
                sort,
                true,
                "ENABLED",
                LocalDateTime.now(),
                LocalDateTime.now(),
                children);
    }

    /** 构造自定义角色。 */
    /** 数据范围用部门编码导出，仅本人（含显式配置的 SELF）省略，导出再解析得到同样的内容。 */
    @Test
    void exportsRoleDataScopesWithDepartmentCodesAndOmitsTheDefault() {
        when(projectService.menus(PROJECT)).thenReturn(List.of(menuTree()));
        when(projectService.roles(PROJECT)).thenReturn(List.of(role("finance", Set.of("b1", "m1", "d1"))));
        when(dataScopes.roleScopes(PROJECT, "r-finance"))
                .thenReturn(new com.kaiwu.module.project.vo.ProjectRoleDataScopeView(
                        "r-finance",
                        "finance",
                        false,
                        List.of(
                                scopeItem("crm:contract", "CUSTOM_DEPT", true, true, List.of("9002", "9001")),
                                scopeItem("crm:customer", "DEPT_AND_CHILD", true, false, List.of()),
                                scopeItem("crm:followup", "SELF", true, false, List.of()),
                                scopeItem("crm:invoice", "SELF", false, false, List.of()))));
        when(dataScopes.departmentCodesById(any())).thenReturn(Map.of("9001", "SALES-EAST", "9002", "SALES-NORTH"));

        ProjectManifestExportView view = service.export(PROJECT, actor(), "kaiwu-test.example.com");

        String roles = view.files().get("roles.yml");
        assertThat(roles).contains("SALES-EAST").contains("SALES-NORTH").doesNotContain("9001");
        assertThat(roles).doesNotContain("crm:followup").doesNotContain("crm:invoice");

        ProjectManifest parsed = new ProjectManifestParser().parse(Map.of("roles.yml", roles));
        assertThat(parsed.roles().get(0).dataScopes())
                .containsExactly(
                        new ProjectManifest.RoleDataScope(
                                "crm:contract", "CUSTOM_DEPT", true, List.of("SALES-EAST", "SALES-NORTH")),
                        new ProjectManifest.RoleDataScope("crm:customer", "DEPT_AND_CHILD", false, List.of()));
    }

    /** 没有任何数据范围配置时不输出 dataScopes 键，导出格式与此前一致。 */
    @Test
    void rolesWithoutDataScopesKeepTheirPreviousShape() {
        when(projectService.menus(PROJECT)).thenReturn(List.of(menuTree()));
        when(projectService.roles(PROJECT)).thenReturn(List.of(role("finance", Set.of("b1"))));

        ProjectManifestExportView view = service.export(PROJECT, actor(), "kaiwu-test.example.com");

        assertThat(view.files().get("roles.yml")).doesNotContain("dataScopes");
    }

    /** 构造角色数据范围视图里的一项。 */
    private static com.kaiwu.module.project.vo.ProjectRoleDataScopeView.Item scopeItem(
            String resource, String scope, boolean configured, boolean includeChild, List<String> deptIds) {
        return new com.kaiwu.module.project.vo.ProjectRoleDataScopeView.Item(
                resource, resource, List.of("ALL", "SELF"), scope, configured, includeChild, deptIds);
    }

    /** 构造带指定菜单授权的自定义角色。 */
    private static ProjectRoleView role(String code, Set<String> menuIds) {
        return new ProjectRoleView(
                "r-" + code,
                PROJECT,
                code,
                "财务",
                "财务审批",
                "ENABLED",
                false,
                menuIds,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 构造内置项目管理员角色。 */
    private static ProjectRoleView builtInRole() {
        return new ProjectRoleView(
                "r-admin",
                PROJECT,
                "project-admin",
                "项目管理员",
                null,
                "ENABLED",
                true,
                Set.of("b1"),
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 构造字典类型。 */
    private static DictTypeView dictType(String id, String scope, String code, String name, String nameKey) {
        return new DictTypeView(id, scope, code, name, nameKey, false, 10, "ENABLED", null, LocalDateTime.now());
    }

    /** 构造字典项。 */
    private static DictItemView item(String value, String label, String labelKey, int sort, boolean defaultItem) {
        return new DictItemView("i-" + value, label, value, sort, defaultItem, null, null, labelKey, "ENABLED");
    }

    /** 构造项目国际化资源。 */
    private static I18nMessageView message(String key, String text, String translations) {
        return new I18nMessageView(
                "m-" + key, key, text, translations, "project", false, false, "ENABLED", null, 1L, LocalDateTime.now());
    }

    /** 构造参数配置。 */
    private static ConfigView config(String key, String value, String type, boolean secret) {
        return new ConfigView(
                "c-" + key,
                PROJECT,
                key,
                value,
                null,
                type,
                secret,
                "ENABLED",
                "说明",
                0,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 测试用项目。 */
    private static ProjectView project() {
        return new ProjectView(
                PROJECT,
                "order-center",
                "订单中心",
                null,
                "ACTIVE",
                false,
                "7",
                "com.example.order",
                null,
                null,
                "main",
                null,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 测试用调用者。 */
    private static KaiwuContext actor() {
        return new KaiwuContext(
                "7",
                "session-1",
                null,
                null,
                Set.of(),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }
}
