package com.kaiwu.module.agent.execution;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityResult;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.ai.vo.AiProviderView;
import com.kaiwu.module.audit.vo.LoginLogView;
import com.kaiwu.module.audit.vo.OnlineSessionView;
import com.kaiwu.module.audit.vo.OperationLogView;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.connector.service.AiProviderService;
import com.kaiwu.module.factory.service.ProjectGenerationService;
import com.kaiwu.module.i18n.vo.I18nLocaleView;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.operation.service.LogCenterService;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMemberView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationView;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/**
 * 回归防护：每条能力都必须把收窄参数传给被调 Service。
 *
 * <p>可见性收窄发生在 Service 内部，依赖传入的 Context 或 userId。本类是
 * in-process 调用、不经过 Controller，**漏传就等于越权**。各模块的收窄方式还不统一，
 * 所以逐条锁死，而不是假设「调 Service 就安全」。</p>
 */
class CapabilityInvokerTest {

    private static final KaiwuContext ACTOR = new KaiwuContext(
            "42",
            "session-1",
            null,
            null,
            Set.of(
                    "system:project:list",
                    "system:project-factory:list",
                    "system:scheduler:list",
                    "system:user:list",
                    "system:org:list",
                    "system:project:health",
                    "system:config:list",
                    "system:dict:list",
                    "system:project:member",
                    "system:project:role",
                    "system:audit:list",
                    "system:session:list",
                    "system:ai:list",
                    "system:git:list",
                    "system:i18n:list",
                    "system:project:menu"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "context-1");

    private ProjectService projectService;
    private ProjectGenerationService generationService;
    private ProjectSchedulerService schedulerService;
    private UserService userService;
    private OrgService orgService;
    private MetadataService metadataService;
    private LogCenterService logCenterService;
    private AiProviderService aiProviderService;
    private I18nService i18nService;
    private CapabilityInvoker invoker;
    private CapabilityCatalog catalog;

    @BeforeEach
    void setUp() {
        projectService = mock(ProjectService.class);
        generationService = mock(ProjectGenerationService.class);
        schedulerService = mock(ProjectSchedulerService.class);
        userService = mock(UserService.class);
        orgService = mock(OrgService.class);
        metadataService = mock(MetadataService.class);
        logCenterService = mock(LogCenterService.class);
        aiProviderService = mock(AiProviderService.class);
        i18nService = mock(I18nService.class);
        catalog = new CapabilityCatalog();
        invoker = new CapabilityInvoker(
                projectService,
                generationService,
                schedulerService,
                userService,
                orgService,
                metadataService,
                logCenterService,
                aiProviderService,
                i18nService);
    }

    private Capability capability(String code) {
        return catalog.findVisible(code, ACTOR).orElseThrow();
    }

    @Test
    void i18nDirectoryPaginatesAndOmitsTranslationBodies() {
        when(i18nService.messages())
                .thenReturn(List.of(
                        new I18nMessageView(
                                "1",
                                "public.one",
                                "private text one",
                                "{\"en-US\":\"secret one\"}",
                                "public",
                                true,
                                false,
                                "ENABLED",
                                "private description",
                                1,
                                null),
                        new I18nMessageView(
                                "2",
                                "public.two",
                                "private text two",
                                "{\"en-US\":\"secret two\"}",
                                "public",
                                false,
                                true,
                                "ENABLED",
                                "private description",
                                1,
                                null)));
        var result = invoker.invoke(capability(CapabilityCatalog.I18N_MESSAGE_LIST), Map.of("pageSize", 1), ACTOR);
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("messageKey", "public.one")
                .containsEntry("moreAvailable", true)
                .doesNotContainKeys("defaultText", "translationsJson", "description"));
        assertThat(result.toString()).doesNotContain("private text", "secret one", "private description");
    }

    @Test
    void i18nLocaleStatusUsesFixedChineseDisplayLocale() {
        when(i18nService.locales("zh-CN")).thenReturn(List.of(new I18nLocaleView("en-US", "英语", true, false, 2, 3, 4)));
        var result = invoker.invoke(capability(CapabilityCatalog.I18N_LOCALE_LIST), Map.of(), ACTOR);
        verify(i18nService).locales("zh-CN");
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("locale", "en-US")
                .containsEntry("missingMenus", 3L));
    }

    @Test
    void projectMenuDirectoryFlattensTreeAndOmitsExecutablePaths() {
        var child = new ProjectMenuView(
                "m-2",
                "p-1",
                "m-1",
                "记录",
                null,
                "MENU",
                "/private/record",
                "private/component",
                "record:record:list",
                null,
                1,
                true,
                "ACTIVE",
                null,
                null,
                List.of());
        var root = new ProjectMenuView(
                "m-1",
                "p-1",
                null,
                "业务",
                null,
                "GROUP",
                "/private",
                "private/root",
                "secret:permission",
                null,
                0,
                true,
                "ACTIVE",
                null,
                null,
                List.of(child));
        when(projectService.menus("p-1")).thenReturn(List.of(root));

        var first = invoker.invoke(
                capability(CapabilityCatalog.PROJECT_MENU_LIST), Map.of("projectId", "p-1", "pageSize", 1), ACTOR);
        var second = invoker.invoke(
                capability(CapabilityCatalog.PROJECT_MENU_LIST),
                Map.of("projectId", "p-1", "page", 2, "pageSize", 1),
                ACTOR);

        verify(projectService, org.mockito.Mockito.times(2)).menus("p-1");
        assertThat(first.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("menuName", "业务")
                .containsEntry("moreAvailable", true)
                .doesNotContainKeys("routePath", "componentPath", "permissionCode", "children"));
        assertThat(second.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("parentId", "m-1")
                .containsEntry("moreAvailable", false));
        assertThat(first.toString()).doesNotContain("/private", "secret:permission");
    }

    @Test
    void configurationStatusOmitsUrlsSecretsAndDiagnosticMessages() {
        when(aiProviderService.current())
                .thenReturn(new AiProviderView(
                        "provider",
                        "https://private-ai.test",
                        true,
                        "model",
                        BigDecimal.ONE,
                        30,
                        "SUCCESS",
                        "private diagnostic",
                        LocalDateTime.of(2026, 9, 25, 1, 2)));

        var ai = invoker.invoke(capability(CapabilityCatalog.AI_PROVIDER_STATUS), Map.of(), ACTOR);

        assertThat(ai.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("model", "model")
                .containsEntry("apiKeyConfigured", true)
                .doesNotContainKeys("baseUrl", "lastTestMessage", "temperature", "timeoutSeconds", "enabled"));
        assertThat(ai.toString()).doesNotContain("private-ai", "private diagnostic");
    }

    /** 生成任务按发起人过滤：必须传当前用户 id，否则会看到别人的任务。 */
    @Test
    void generationListPassesTheCallerUserId() {
        when(generationService.list(eq("42"), any())).thenReturn(List.of());
        invoker.invoke(capability(CapabilityCatalog.GENERATION_LIST), Map.of("pageSize", 20), ACTOR);
        verify(generationService).list(eq("42"), any());
    }

    @Test
    void generationDetailUsesOwnerAndOmitsInputsFilesUrlsAndErrors() {
        var view = new ProjectGenerationView(
                "PG-1",
                "p-1",
                "project",
                "项目",
                "BASIC_SCAFFOLD",
                "SUCCESS",
                "private-model",
                "private-summary",
                "v1",
                List.of("private-backend"),
                List.of("private-frontend"),
                "private error",
                null,
                null,
                null,
                null);
        when(generationService.get("PG-1", "42")).thenReturn(view);

        var result = invoker.invoke(capability(CapabilityCatalog.GENERATION_DETAIL), Map.of("taskNo", "PG-1"), ACTOR);

        verify(generationService).get("PG-1", "42");
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("status", "SUCCESS")
                .containsEntry("templateVersion", "v1")
                .doesNotContainKeys("aiModel", "designSummary", "backendFiles", "frontendFiles", "lastError"));
        assertThat(result.toString())
                .doesNotContain("private-model", "private-summary", "private-backend", "private error");
    }

    @Test
    void unavailableGenerationTaskUsesTheSamePermissionDenialAsWrongOwner() {
        when(generationService.get("PG-hidden", "42"))
                .thenThrow(new ApiException(HttpStatus.NOT_FOUND, "任务不存在或不属于当前用户", "api.common.notFound"));
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> invoker.invoke(
                        capability(CapabilityCatalog.GENERATION_DETAIL), Map.of("taskNo", "PG-hidden"), ACTOR))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
    }

    /** 调度任务的收窄在 Service 内部完成：必须把整个 Context 交进去。 */
    @Test
    void schedulerListPassesTheWholeContext() {
        when(schedulerService.jobs(any(), anyLong(), anyLong(), eq(ACTOR)))
                .thenReturn(new PageResult<>(1, 20, 0, List.of()));
        invoker.invoke(capability(CapabilityCatalog.SCHEDULER_LIST), Map.of("pageSize", 20), ACTOR);
        verify(schedulerService).jobs(any(), anyLong(), anyLong(), eq(ACTOR));
    }

    @Test
    void schedulerExecutionsPassTheWholeContextAndOmitLogMessage() {
        var execution = new com.kaiwu.module.operation.vo.SchedulerExecutionView(
                "e-1", "j-1", "结算", "p-1", "项目", Instant.now(), "pod-1", "FAILED", "secret", null, null);
        when(schedulerService.executions(eq("p-1"), eq("j-1"), eq(1L), eq(10L), eq(ACTOR)))
                .thenReturn(new PageResult<>(1, 10, 1, List.of(execution)));

        var result = invoker.invoke(
                capability(CapabilityCatalog.SCHEDULER_EXECUTION_LIST),
                Map.of("projectId", "p-1", "jobId", "j-1", "pageSize", 10),
                ACTOR);

        verify(schedulerService).executions("p-1", "j-1", 1, 10, ACTOR);
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("status", "FAILED")
                .doesNotContainKey("message")
                .doesNotContainKey("instanceId"));
        assertThat(result.sourceProjects()).containsExactly("p-1");
    }

    @Test
    void userListReturnsOnlyNonSensitiveFields() {
        var user = new UserView("7", "alice", "Alice", "private@example.test", "ENABLED", null, null);
        when(userService.page("alice", 1, 10)).thenReturn(new PageResult<>(1, 10, 1, List.of(user)));

        var result = invoker.invoke(
                capability(CapabilityCatalog.USER_LIST), Map.of("keyword", "alice", "pageSize", 10), ACTOR);

        verify(userService).page("alice", 1, 10);
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("username", "alice")
                .doesNotContainKey("email"));
    }

    @Test
    void departmentListUsesExistingTreeAndBoundedPublicFields() {
        var child = new DepartmentView("d-2", "d-1", "财务", "FIN", 1, "ENABLED", null, null, List.of());
        var root = new DepartmentView("d-1", null, "总部", "HQ", 0, "ENABLED", null, null, List.of(child));
        when(orgService.departments()).thenReturn(List.of(root));

        var result = invoker.invoke(capability(CapabilityCatalog.DEPARTMENT_LIST), Map.of("pageSize", 2), ACTOR);

        verify(orgService, org.mockito.Mockito.atLeastOnce()).departments();
        assertThat(result.rows()).hasSize(2);
        assertThat(result.rows().get(1))
                .containsEntry("parentId", "d-1")
                .containsEntry("moreAvailable", false)
                .doesNotContainKey("children");

        var firstPage =
                invoker.invoke(capability(CapabilityCatalog.DEPARTMENT_LIST), Map.of("page", 1, "pageSize", 1), ACTOR);
        var secondPage =
                invoker.invoke(capability(CapabilityCatalog.DEPARTMENT_LIST), Map.of("page", 2, "pageSize", 1), ACTOR);
        assertThat(firstPage.rows())
                .singleElement()
                .satisfies(row -> assertThat(row).containsEntry("id", "d-1").containsEntry("moreAvailable", true));
        assertThat(secondPage.rows())
                .singleElement()
                .satisfies(row -> assertThat(row).containsEntry("id", "d-2").containsEntry("moreAvailable", false));
    }

    @Test
    void globalConfigDirectoryExcludesSecretRowsAndAllValues() {
        when(metadataService.configs("0"))
                .thenReturn(List.of(
                        new ConfigView(
                                "1",
                                "0",
                                "public.key",
                                "internal-value",
                                null,
                                "STRING",
                                false,
                                "ENABLED",
                                "说明",
                                0,
                                null,
                                null),
                        new ConfigView(
                                "2",
                                "0",
                                "secret.key",
                                "******",
                                null,
                                "STRING",
                                true,
                                "ENABLED",
                                "隐藏",
                                1,
                                null,
                                null)));
        var result = invoker.invoke(capability(CapabilityCatalog.CONFIG_LIST), Map.of("pageSize", 10), ACTOR);
        verify(metadataService).configs("0");
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("configKey", "public.key")
                .doesNotContainKey("configValue"));
        assertThat(result.toString()).doesNotContain("internal-value", "secret.key");
    }

    @Test
    void configDetailExcludesValuesAndSecretOrMissingIds() {
        when(metadataService.configs("0"))
                .thenReturn(List.of(
                        new ConfigView(
                                "1",
                                "0",
                                "public.key",
                                "private-value",
                                null,
                                "STRING",
                                false,
                                "ENABLED",
                                "说明",
                                0,
                                null,
                                null),
                        new ConfigView(
                                "2",
                                "0",
                                "secret.key",
                                "******",
                                null,
                                "STRING",
                                true,
                                "ENABLED",
                                "隐藏",
                                1,
                                null,
                                null)));

        var capability = capability(CapabilityCatalog.CONFIG_DETAIL);
        var result = invoker.invoke(capability, Map.of("configId", "1"), ACTOR);
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("configKey", "public.key")
                .doesNotContainKey("configValue"));
        assertThat(result.toString()).doesNotContain("private-value");
        assertThatThrownBy(() -> invoker.invoke(capability, Map.of("configId", "2"), ACTOR))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
        assertThatThrownBy(() -> invoker.invoke(capability, Map.of("configId", "missing"), ACTOR))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
        verify(metadataService, org.mockito.Mockito.times(3)).configs("0");
    }

    @Test
    void localExecutorRechecksPermissionBeforeServiceCall() {
        var actor = mock(KaiwuContext.class);
        assertThatThrownBy(() ->
                        invoker.invoke(capability(CapabilityCatalog.CONFIG_DETAIL), Map.of("configId", "1"), actor))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
        verifyNoInteractions(metadataService);
    }

    @Test
    void globalDictionaryQueriesAreBoundedAndCannotSelectProjectScope() {
        when(metadataService.dictTypes("0"))
                .thenReturn(List.of(
                        new DictTypeView("1", "0", "a", "甲", null, false, 0, "ENABLED", null, null),
                        new DictTypeView("2", "0", "b", "乙", null, false, 1, "ENABLED", null, null)));
        var types = invoker.invoke(capability(CapabilityCatalog.DICT_TYPE_LIST), Map.of("pageSize", 1), ACTOR);
        assertThat(types.rows())
                .singleElement()
                .satisfies(row -> assertThat(row).containsEntry("dictCode", "a").containsEntry("moreAvailable", true));
        verify(metadataService).dictTypes("0");

        when(metadataService.dictItems("0", "1"))
                .thenReturn(
                        List.of(new DictItemView("3", "是", "yes", 0, false, null, "private-extra", null, "ENABLED")));
        var items = invoker.invoke(capability(CapabilityCatalog.DICT_ITEM_LIST), Map.of("typeId", "1"), ACTOR);
        verify(metadataService).dictItems("0", "1");
        assertThat(items.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("itemValue", "yes")
                .doesNotContainKey("extraJson"));
    }

    @Test
    void projectMemberAndRoleReadsUseRequestedProjectAndLimitFields() {
        when(projectService.members("p-1"))
                .thenReturn(List.of(
                        new ProjectMemberView("u-1", "alice", "Alice", "ACTIVE", Set.of("r-1"), null, null),
                        new ProjectMemberView("u-2", "bob", "Bob", "ACTIVE", Set.of("r-2"), null, null)));
        var members = invoker.invoke(
                capability(CapabilityCatalog.PROJECT_MEMBER_LIST), Map.of("projectId", "p-1", "pageSize", 1), ACTOR);
        verify(projectService).members("p-1");
        assertThat(members.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("username", "alice")
                .containsEntry("moreAvailable", true)
                .doesNotContainKey("createdAt"));
        assertThat(members.sourceProjects()).containsExactly("p-1");

        when(projectService.roles("p-1"))
                .thenReturn(List.of(new ProjectRoleView(
                        "r-1",
                        "p-1",
                        "project-admin",
                        "管理员",
                        "private-description",
                        "ACTIVE",
                        true,
                        Set.of("menu-1"),
                        null,
                        null)));
        var roles = invoker.invoke(capability(CapabilityCatalog.PROJECT_ROLE_LIST), Map.of("projectId", "p-1"), ACTOR);
        verify(projectService).roles("p-1");
        assertThat(roles.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("roleCode", "project-admin")
                .doesNotContainKey("menuIds")
                .doesNotContainKey("description"));
        assertThat(roles.toString()).doesNotContain("private-description", "menu-1");
    }

    @Test
    void securityReadsKeepLogsAndSessionIdentifiersOutOfModel() {
        var at = LocalDateTime.of(2026, 9, 25, 12, 0);
        when(logCenterService.operations("alice", "project", 2, 10))
                .thenReturn(new PageResult<>(
                        2,
                        10,
                        21,
                        List.of(new OperationLogView(
                                "op-1",
                                "u-1",
                                "alice",
                                "project",
                                "UPDATE",
                                "POST",
                                "/private",
                                200,
                                "secret-detail",
                                "project",
                                "p-1",
                                "secret-diff",
                                "private-ip",
                                "private-trace",
                                at))));
        var operation = invoker.invoke(
                capability(CapabilityCatalog.OPERATION_LOG_LIST),
                Map.of("username", "alice", "module", "project", "page", 2, "pageSize", 10),
                ACTOR);
        assertThat(operation.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("operation", "UPDATE")
                .containsEntry("moreAvailable", true)
                .doesNotContainKeys("detail", "changeJson", "clientIp", "traceId", "requestPath", "userId"));
        assertThat(operation.toString()).doesNotContain("secret-detail", "secret-diff", "private-ip", "private-trace");

        when(logCenterService.logins("alice", "FAILED", 1, 10))
                .thenReturn(new PageResult<>(
                        1,
                        10,
                        1,
                        List.of(new LoginLogView(
                                "login-1",
                                "u-1",
                                "alice",
                                "FAILED",
                                "private-reason",
                                "private-ip",
                                "private-trace",
                                at))));
        var login = invoker.invoke(
                capability(CapabilityCatalog.LOGIN_LOG_LIST),
                Map.of("username", "alice", "status", "FAILED", "pageSize", 10),
                ACTOR);
        assertThat(login.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("status", "FAILED")
                .doesNotContainKeys("message", "clientIp", "traceId", "userId"));
        assertThat(login.toString()).doesNotContain("private-reason", "private-ip");

        when(logCenterService.sessions("alice", "ONLINE", 1, 10))
                .thenReturn(new PageResult<>(
                        1,
                        10,
                        1,
                        List.of(new OnlineSessionView(
                                "private-session",
                                "u-1",
                                "alice",
                                "ONLINE",
                                at,
                                at,
                                at.plusHours(1),
                                null,
                                "WEB",
                                null))));
        var session = invoker.invoke(
                capability(CapabilityCatalog.SESSION_LIST),
                Map.of("username", "alice", "status", "ONLINE", "pageSize", 10),
                ACTOR);
        assertThat(session.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("status", "ONLINE")
                .doesNotContainKeys("sessionId", "userId"));
        assertThat(session.toString()).doesNotContain("private-session");
        verify(logCenterService).operations("alice", "project", 2, 10);
        verify(logCenterService).logins("alice", "FAILED", 1, 10);
        verify(logCenterService).sessions("alice", "ONLINE", 1, 10);
    }

    @Test
    void securityReadCapabilitiesAreInvisibleWithoutTheirPermissions() {
        var denied = mock(KaiwuContext.class);
        assertThat(catalog.findVisible(CapabilityCatalog.OPERATION_LOG_LIST, denied))
                .isEmpty();
        assertThat(catalog.findVisible(CapabilityCatalog.LOGIN_LOG_LIST, denied))
                .isEmpty();
        assertThat(catalog.findVisible(CapabilityCatalog.SESSION_LIST, denied)).isEmpty();
    }

    /**
     * 项目列表调的 ProjectService.page 不接收 Context——它的可见性由平台级权限
     * system:project:list 决定，与 UI 行为一致，这是能力声明 dataScope=ALL 的依据。
     * 一旦该方法将来加上收窄参数，本测试会因签名变化而失败，提醒同步能力声明。
     */
    @Test
    void projectListRequiresPlatformPermissionRatherThanMembership() {
        when(projectService.page(any(), anyLong(), anyLong())).thenReturn(new PageResult<>(1, 20, 0, List.of()));
        invoker.invoke(capability(CapabilityCatalog.PROJECT_LIST), Map.of("pageSize", 20), ACTOR);
        verify(projectService).page(any(), anyLong(), anyLong());
        assertThat(capability(CapabilityCatalog.PROJECT_LIST).dataScope()).isEqualTo(DataScope.ALL);
    }

    @Test
    void projectListCarriesBackendEntryForTheAgentCard() {
        ProjectView project = new ProjectView(
                "10",
                "demo",
                "Demo",
                null,
                "ACTIVE",
                false,
                "42",
                "com.example.demo",
                null,
                null,
                "main",
                "https://demo.example.test",
                "Demo backend",
                null,
                null,
                null);
        when(projectService.page(any(), anyLong(), anyLong())).thenReturn(new PageResult<>(1, 20, 1, List.of(project)));

        CapabilityResult result =
                invoker.invoke(capability(CapabilityCatalog.PROJECT_LIST), Map.of("pageSize", 20), ACTOR);

        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("backendUrl", "https://demo.example.test"));
    }

    @Test
    void projectDetailUsesPlatformPermissionAndOmitsInternalAddresses() {
        ProjectView project = new ProjectView(
                "10",
                "demo",
                "Demo",
                "Description",
                "ACTIVE",
                false,
                "42",
                "com.example.demo",
                "https://git.internal/repo",
                "123",
                "main",
                "https://admin.example.test",
                "Admin",
                "lb://private-service",
                null,
                null);
        when(projectService.project("10")).thenReturn(project);

        CapabilityResult result =
                invoker.invoke(capability(CapabilityCatalog.PROJECT_DETAIL), Map.of("projectId", "10"), ACTOR);

        assertThat(capability(CapabilityCatalog.PROJECT_DETAIL).dataScope()).isEqualTo(DataScope.ALL);
        assertThat(result.rows()).singleElement().satisfies(row -> assertThat(row)
                .containsEntry("projectCode", "demo")
                .containsEntry("description", "Description")
                .doesNotContainKeys("repositoryUrl", "gitlabProjectId", "backendUrl", "serviceUrl"));
        verify(projectService).project("10");
    }

    /** 被调 Service 抛错时，该条能力记为失败，不把异常抛给整次提问。 */
    @Test
    void failingServiceIsReportedAsCapabilityFailureNotAnException() {
        when(schedulerService.jobs(any(), anyLong(), anyLong(), any())).thenThrow(new IllegalStateException("boom"));
        CapabilityResult result =
                invoker.invoke(capability(CapabilityCatalog.SCHEDULER_LIST), Map.of("pageSize", 20), ACTOR);
        assertThat(result.succeeded()).isFalse();
        assertThat(result.failure()).isNotBlank();
    }

    @Test
    void deniedBusinessServiceIsNotReportedAsTransientDataFailure() {
        when(schedulerService.jobs(any(), anyLong(), anyLong(), any()))
                .thenThrow(new ApiException(HttpStatus.FORBIDDEN, "不是项目成员", "api.common.forbidden"));

        org.assertj.core.api.Assertions.assertThatThrownBy(
                        () -> invoker.invoke(capability(CapabilityCatalog.SCHEDULER_LIST), Map.of(), ACTOR))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
    }
}
