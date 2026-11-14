package com.kaiwu.module.agent.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.audit.AgentEvalTrace;
import com.kaiwu.module.agent.audit.EvaluationRecorder;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentConversationTurn;
import com.kaiwu.module.agent.execution.AccessReChecker;
import com.kaiwu.module.agent.execution.CapabilityInvoker;
import com.kaiwu.module.agent.execution.RemoteWriteActionCoordinator;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.planning.AgentPlanValidator;
import com.kaiwu.module.agent.planning.AgentPlanner;
import com.kaiwu.module.agent.planning.AgentPromptBuilder;
import com.kaiwu.module.agent.presentation.ResultProjector;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityResult;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.OutputViewSpec;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.service.impl.AgentServiceImpl;
import com.kaiwu.module.agent.vo.AgentAnswerView;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.port.AgentAiPort;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ModelCallFailure;
import com.kaiwu.port.ProjectMembershipPort;
import com.kaiwu.starter.KaiwuContext;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * 编排层的安全行为。
 *
 * <p>重点是越权、执行时复核与失败处理，不是 happy path 的字段对不对。</p>
 */
class AgentServiceTest {

    @Test
    void localCatalogShowsPermissionStateWithoutBroadeningChatVisibility() {
        CapabilityCatalog localCatalog = new CapabilityCatalog();
        KaiwuContext actor = actorWith("system:agent:ask", "system:project:list");
        var rows = localCatalog.localCapabilities();
        assertThat(rows).hasSizeGreaterThan(4);
        assertThat(rows).extracting(Capability::code).contains(CapabilityCatalog.PROJECT_LIST);
        assertThat(localCatalog.visibleTo(actor))
                .extracting(Capability::code)
                .contains(CapabilityCatalog.PROJECT_LIST)
                .doesNotContain(CapabilityCatalog.PROJECT_CREATE);
    }

    @Test
    void localCatalogRequiresAgentPermissionAndMarksDeniedOperations() {
        assertThatThrownBy(() -> service.localCapabilities(actorWith("system:project:list")))
                .isInstanceOf(ApiException.class);
        var rows = service.localCapabilities(actorWith("system:agent:ask", "system:project:list"));
        assertThat(rows)
                .filteredOn(row -> row.code().equals(CapabilityCatalog.PROJECT_LIST))
                .allMatch(row -> row.available() && row.readOnly());
        assertThat(rows)
                .filteredOn(row -> row.code().equals(CapabilityCatalog.PROJECT_CREATE))
                .allMatch(row -> !row.available() && !row.readOnly());
    }

    private static final RequestMetadata METADATA = new RequestMetadata("127.0.0.1", "test-agent");

    private AgentAiPort ai;
    private ProjectMembershipPort membership;
    private AuditPort audit;
    private ProjectService projectService;
    private AuthRepository authRepository;
    private CapabilityInvoker invoker;
    private AgentRateLimiter rateLimiter;
    private AgentPromptBuilder prompts;
    private AgentServiceImpl service;
    private AgentActionService actions;
    private CapabilityCatalog catalog;
    private AccessReChecker accessReChecker;
    private CapturingRecorder recorder;

    @BeforeEach
    void setUp() {
        recorder = new CapturingRecorder();
        ai = mock(AgentAiPort.class);
        membership = mock(ProjectMembershipPort.class);
        audit = mock(AuditPort.class);
        projectService = mock(ProjectService.class);
        authRepository = mock(AuthRepository.class);
        invoker = mock(CapabilityInvoker.class);
        rateLimiter = mock(AgentRateLimiter.class);
        prompts = new AgentPromptBuilder(mock(MetadataService.class));
        actions = mock(AgentActionService.class);

        catalog = new CapabilityCatalog();
        when(rateLimiter.tryAcquire(anyString())).thenReturn(true);
        when(ai.effectiveConfig())
                .thenReturn(Optional.of(
                        new AgentAiPort.RuntimeConfig("p", "http://localhost", "k", "test-model", BigDecimal.ONE, 30)));
        when(ai.effectiveFor(anyString())).thenAnswer(invocation -> ai.effectiveConfig()
                .map(config -> new AgentAiPort.RoutedConfig("1", config)));
        when(projectService.currentProjects(anyString())).thenReturn(List.of());
        when(authRepository.findSession("session-1"))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        "session-1", "1", "", "ONLINE", "WEB", Instant.now().plusSeconds(300))));
        when(authRepository.findUserById("1"))
                .thenReturn(Optional.of(
                        new AuthRepository.UserAccount("1", "admin", "", "Admin", "ENABLED", "zh-CN", false, false)));
        when(authRepository.findPermissions("1"))
                .thenReturn(Set.of(
                        "system:agent:ask",
                        "system:project:list",
                        "system:project:create",
                        "system:project-factory:list",
                        "system:scheduler:list"));

        accessReChecker = new AccessReChecker(membership, authRepository, java.time.Clock.systemUTC());
        service = new AgentServiceImpl(
                catalog,
                prompts,
                new AgentPlanner(ai, new tools.jackson.databind.ObjectMapper()),
                new AgentPlanValidator(catalog),
                accessReChecker,
                invoker,
                new ResultProjector(),
                rateLimiter,
                recorder,
                projectService,
                authRepository,
                audit,
                actions);
    }

    private static KaiwuContext actorWith(String... permissions) {
        return new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of(permissions),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    private void modelReturns(String planJson, String answer) {
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new AgentAiPort.ChatOutcome(planJson, 10L, 5L))
                .thenReturn(new AgentAiPort.ChatOutcome(answer, 20L, 8L));
    }

    /** 无权限的能力不进提示词——先给模型再过滤等于把目录泄露出去。 */
    @Test
    void capabilitiesWithoutPermissionNeverEnterThePrompt() {
        modelReturns("{\"understood\":true,\"calls\":[]}", "好的");
        service.ask("有哪些定时任务", actorWith("system:project:list"), METADATA);

        ArgumentCaptor<String> systemPrompt = ArgumentCaptor.forClass(String.class);
        verify(ai, times(2)).chat(any(), systemPrompt.capture(), anyString(), anyInt());
        assertThat(systemPrompt.getAllValues().get(0))
                .contains(CapabilityCatalog.PROJECT_LIST)
                .doesNotContain(CapabilityCatalog.SCHEDULER_LIST);
    }

    @Test
    void revokedSystemPermissionIsRemovedBeforePlanningAndReturnsDenial() {
        when(authRepository.findPermissions("1")).thenReturn(Set.of("system:agent:ask"));

        AgentAnswerView view = service.ask("列出所有项目", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verifyNoInteractions(ai);
    }

    @Test
    void explicitQueryForHiddenCapabilityReturnsDenialBeforeCallingModel() {
        when(authRepository.findPermissions("1")).thenReturn(Set.of("system:agent:ask", "system:project:list"));

        AgentAnswerView view = service.ask("查看登录日志", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verifyNoInteractions(ai);
    }

    @Test
    void explicitWriteWithoutPermissionReturnsDenialBeforeCallingModel() {
        when(authRepository.findPermissions("1")).thenReturn(Set.of("system:agent:ask", "system:project:list"));

        AgentAnswerView view = service.ask("停用用户 35", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verifyNoInteractions(ai);
    }

    @Test
    void revokedSessionCannotExecuteUsingOldContext() {
        when(authRepository.findSession("session-1"))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        "session-1", "1", "", "REVOKED", "WEB", Instant.now().plusSeconds(300))));

        AgentAnswerView view = service.ask("列出所有项目", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verifyNoInteractions(ai);
    }

    @Test
    void revokedAgentPermissionCannotUsePreviouslyIssuedContext() {
        when(authRepository.findPermissions("1")).thenReturn(Set.of("system:project:list"));

        AgentAnswerView view = service.ask("列出所有项目", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verifyNoInteractions(ai);
    }

    @Test
    void permissionRevokedDuringPlanningCannotExecute() {
        when(authRepository.findPermissions("1"))
                .thenReturn(Set.of("system:agent:ask", "system:project:list"))
                .thenReturn(Set.of("system:agent:ask"));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "不该回答");

        AgentAnswerView view = service.ask("列出所有项目", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("无权限操作");
        assertThat(view.cards()).isEmpty();
        verifyNoInteractions(invoker);
        verify(ai, times(1)).chat(any(), anyString(), anyString(), anyInt());
    }

    @Test
    void approvedRemoteWriteOnlyCreatesPendingPreviewWithoutExecution() {
        var remote = mock(RemoteCapabilitySource.class);
        var write = new Capability(
                "crm",
                "crm.record.update",
                "1",
                "修改记录",
                "record:record:update",
                DataScope.SELF,
                Map.of("name", ParamSpec.optionalString(30)),
                Set.of("name"),
                Map.of(),
                false,
                false,
                true);
        var actor = actorWith("system:agent:ask");
        when(remote.visibleTo(actor)).thenReturn(List.of());
        when(remote.visibleWritesTo(actor)).thenReturn(List.of(write));
        when(remote.findVisible(write.code(), actor)).thenReturn(Optional.empty());
        when(remote.findVisibleWrite(write.code(), actor)).thenReturn(Optional.of(write));
        catalog.remoteSource(remote);
        accessReChecker.remoteSource(remote);
        var remoteActions = mock(RemoteWriteActionCoordinator.class);
        service.remoteWriteActions(remoteActions);
        var pending = new com.kaiwu.module.agent.vo.AgentRemoteActionView(
                "action-1",
                "123",
                "crm",
                write.code(),
                "更新客户记录",
                "1",
                "PENDING",
                "STRONG",
                Map.of("name", "新名称"),
                Map.of("name", "名称"),
                1,
                Instant.now().plusSeconds(300),
                "one-time-token",
                "确认 abcdef12",
                null,
                null);
        when(remoteActions.preview(any(), eq(actor), eq(METADATA), anyString())).thenReturn(pending);
        modelReturns(
                "{\"understood\":true,\"calls\":[{\"code\":\"crm.record.update\"," + "\"params\":{\"name\":\"新名称\"}}]}",
                "不应总结");

        AgentAnswerView answer = service.ask("把记录改成新名称", actor, METADATA);
        assertThat(answer.pendingRemoteAction()).isEqualTo(pending);
        verify(remoteActions).preview(any(), eq(actor), eq(METADATA), anyString());
        verify(remoteActions, never()).confirm(anyString(), anyString(), any(), any(), any());
        verifyNoInteractions(invoker);
    }

    @Test
    void remoteWriteRevokedAfterPlanningReturnsPermissionDenial() {
        var remote = mock(RemoteCapabilitySource.class);
        var write = new Capability(
                "crm",
                "crm.record.update",
                "1",
                "修改记录",
                "record:record:update",
                DataScope.SELF,
                Map.of("name", ParamSpec.optionalString(30)),
                Set.of("name"),
                Map.of(),
                false,
                false,
                true);
        var actor = actorWith("system:agent:ask");
        when(remote.visibleTo(actor)).thenReturn(List.of());
        when(remote.visibleWritesTo(actor)).thenReturn(List.of(write));
        when(remote.findVisible(write.code(), actor)).thenReturn(Optional.empty());
        when(remote.findVisibleWrite(write.code(), actor))
                .thenReturn(Optional.of(write), Optional.of(write), Optional.of(write), Optional.empty());
        catalog.remoteSource(remote);
        accessReChecker.remoteSource(remote);
        var remoteActions = mock(RemoteWriteActionCoordinator.class);
        service.remoteWriteActions(remoteActions);
        modelReturns(
                "{\"understood\":true,\"calls\":[{\"code\":\"crm.record.update\"," + "\"params\":{\"name\":\"新名称\"}}]}",
                "不应总结");

        AgentAnswerView answer = service.ask("把记录改成新名称", actor, METADATA);

        assertThat(answer.answer()).isEqualTo("无权限操作");
        assertThat(answer.pendingRemoteAction()).isNull();
        verifyNoInteractions(remoteActions, invoker);
    }

    /** 模型挑了用户无权的能力：拒绝，且不产生任何能力调用。 */
    @Test
    void planPickingAnUnauthorizedCapabilityIsRejectedWithoutInvoking() {
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.scheduler.list\",\"params\":{}}]}", "不该到这");
        AgentAnswerView view = service.ask("查定时任务", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded()).isNotNull();
        assertThat(view.degraded().reason()).isEqualTo("PLAN_INVALID");
        verify(invoker, never()).invoke(any(), any(), any());
    }

    /** 模型返回非 JSON：明确失败，不猜测、不退化为关键词匹配。 */
    @Test
    void nonJsonModelOutputFailsExplicitly() {
        modelReturns("这不是 JSON", "不该到这");
        AgentAnswerView view = service.ask("随便问问", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded().reason()).isEqualTo("PLAN_INVALID");
        verify(invoker, never()).invoke(any(), any(), any());
    }

    /** Provider 未配置：整体不可用并明确提示，不做降级猜测。 */
    @Test
    void missingProviderMakesTheWholeFeatureUnavailable() {
        when(ai.effectiveConfig()).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.ask("问点什么", actorWith("system:project:list"), METADATA))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Provider");
    }

    /** 超过频率上限时直接拒绝，且一次模型都不调。 */
    @Test
    void rateLimitedRequestNeverReachesTheModel() {
        when(rateLimiter.tryAcquire(anyString())).thenReturn(false);
        AgentAnswerView view = service.ask("问点什么", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded().reason()).isEqualTo("RATE_LIMITED");
        verify(ai, never()).chat(any(), anyString(), anyString(), anyInt());
    }

    /**
     * 执行时复核：规划通过之后成员关系被撤销，执行前仍会拦下。
     *
     * <p>规划与执行之间存在时间差，沿用规划时的判定就等于放行一次已被收回的权限。</p>
     */
    @Test
    void membershipRevokedBetweenPlanningAndExecutionIsStillBlocked() {
        when(projectService.currentProjects(anyString())).thenReturn(List.of(projectView("10")));
        // 规划阶段项目可见，执行前复核时成员关系已不存在。
        when(membership.activeMemberExists(eq("10"), anyString())).thenReturn(false);
        modelReturns(
                "{\"understood\":true,\"calls\":[{\"code\":\"system.scheduler.list\","
                        + "\"params\":{\"projectId\":\"10\"}}]}",
                "不该到这");

        AgentAnswerView view = service.ask("查项目 10 的定时任务", actorWith("system:scheduler:list"), METADATA);
        assertThat(view.degraded()).isNotNull();
        assertThat(view.degraded().reason()).isEqualTo("PLAN_INVALID");
        assertThat(view.answer()).contains("没有找到你有权限的项目");
        verify(invoker, never()).invoke(any(), any(), any());
    }

    /** 模型服务在规划或总结阶段失败时，统一返回结构化降级结果并写评估事件。 */
    @Test
    void providerFailureReturnsStructuredDegradedResult() {
        when(ai.chat(any(), anyString(), anyString(), anyInt())).thenThrow(new IllegalStateException("offline"));

        AgentAnswerView view = service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded()).isNotNull();
        assertThat(view.degraded().reason()).isEqualTo("PROVIDER_UNAVAILABLE");
        verify(invoker, never()).invoke(any(), any(), any());
    }

    /** 正常提问：一条请求父记录 + 每个能力一条子记录，correlationId 贯穿。 */
    @Test
    void successfulAskWritesOneParentAuditPlusOnePerCapability() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST,
                        "项目",
                        List.of(Map.of("id", "10", "projectCode", "demo")),
                        List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "共 1 个项目。");

        AgentAnswerView view = service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(view.correlationId()).isNotBlank();
        assertThat(view.usedCapabilities()).containsExactly(CapabilityCatalog.PROJECT_LIST);
        assertThat(view.degraded()).isNull();

        ArgumentCaptor<String> operations = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> details = ArgumentCaptor.forClass(String.class);
        verify(audit, times(2))
                .recordOperation(any(), eq("agent"), operations.capture(), anyString(), details.capture(), any());
        assertThat(operations.getAllValues()).containsExactly("CAPABILITY_CALLED", "ASK");
        assertThat(details.getAllValues()).allMatch(detail -> detail.contains(view.correlationId()));
    }

    /** 同一请求按各自用途调用模型；现有能力和权限复核仍参与执行。 */
    @Test
    void askUsesSeparatePlanningAndAnswerModels() {
        var plan = new AgentAiPort.RuntimeConfig("p", "https://example.org", "k", "small", BigDecimal.ONE, 30);
        var answer = new AgentAiPort.RuntimeConfig("p", "https://example.org", "k", "large", BigDecimal.ONE, 30);
        doReturn(Optional.of(new AgentAiPort.RoutedConfig("1", plan))).when(ai).effectiveFor("PLAN");
        doReturn(Optional.of(new AgentAiPort.RoutedConfig("2", answer)))
                .when(ai)
                .effectiveFor("ANSWER");
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(CapabilityCatalog.PROJECT_LIST, "项目", List.of(), List.of()));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "完成");
        assertThat(service.ask("有哪些项目", actorWith("system:project:list"), METADATA)
                        .degraded())
                .isNull();
        verify(ai).chat(argThat(config -> "small".equals(config.model())), anyString(), anyString(), eq(1000));
        verify(ai).chat(argThat(config -> "large".equals(config.model())), anyString(), anyString(), eq(2000));
    }

    @Test
    void approvedOutputViewIsReturnedButCannotOverrideSummaryOnlyIntent() {
        var remote = mock(RemoteCapabilitySource.class);
        var presentation = new OutputViewSpec(
                "配置详情", List.of(new OutputViewSpec.Field("id", "配置编号", OutputViewSpec.Format.TEXT, null)));
        var capability = new Capability(
                "sample",
                "sample.config.detail",
                "3",
                "读取配置",
                "config:config:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id"),
                Map.of(),
                true,
                true,
                true,
                null,
                presentation);
        when(remote.visibleTo(any())).thenReturn(List.of(capability));
        when(remote.findVisible(eq(capability.code()), any())).thenReturn(Optional.of(capability));
        catalog.remoteSource(remote);
        accessReChecker.remoteSource(remote);
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        capability.code(),
                        "响应标题",
                        List.of(Map.of("id", "1789248125900000001", "private", "hidden")),
                        List.of("123")));
        String plan = "{\"understood\":true,\"calls\":[{\"code\":\"sample.config.detail\",\"params\":{}}]}";
        modelReturns(plan, "查询成功");
        var answer = service.ask("读取示例配置", actorWith("system:agent:ask"), METADATA);
        assertThat(answer.cards()).singleElement().satisfies(card -> {
            assertThat(card.outputView().title()).isEqualTo("配置详情");
            assertThat(card.outputView().fields())
                    .extracting(field -> field.label())
                    .containsExactly("配置编号");
            assertThat(card.rows().getFirst()).doesNotContainKey("private");
        });
        modelReturns(plan, "返回1条");
        assertThat(service.ask("只回复条数，不展示记录详情", actorWith("system:agent:ask"), METADATA)
                        .cards())
                .isEmpty();
    }

    @Test
    void summaryOnlyQuestionDoesNotReturnDetailCards() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST,
                        "项目",
                        List.of(Map.of("id", "10", "projectName", "演示项目")),
                        List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "返回 1 条。");

        AgentAnswerView view = service.ask("统计项目数量，只回复条数，不展示记录详情或用户标识", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("返回 1 条。");
        assertThat(view.cards()).isEmpty();
        assertThat(view.usedCapabilities()).containsExactly(CapabilityCatalog.PROJECT_LIST);
    }

    @Test
    void decisionQuestionDoesNotExposeEvidenceCards() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST,
                        "项目",
                        List.of(Map.of("id", "10", "projectName", "演示项目", "ownerUserId", "42")),
                        List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "当前不能删除。");

        AgentAnswerView view =
                service.ask("检查项目 ID 10 能否删除；如果已有引用，请直接说明原因，不要执行删除或其他修改", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("当前不能删除。");
        assertThat(view.cards()).isEmpty();
        assertThat(view.usedCapabilities()).containsExactly(CapabilityCatalog.PROJECT_LIST);
    }

    @Test
    void listQuestionStillReturnsDetailCards() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST,
                        "项目",
                        List.of(Map.of("id", "10", "projectName", "演示项目")),
                        List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "项目如下。");

        AgentAnswerView view = service.ask("列出项目列表和详情", actorWith("system:project:list"), METADATA);

        assertThat(view.cards()).hasSize(1);
        assertThat(view.cards().getFirst().rows()).containsExactly(Map.of("id", "10", "projectName", "演示项目"));
    }

    /** 单条能力失败不拖垮整体：其余结果照常返回，并标注部分失败。 */
    @Test
    void oneFailingCapabilityDoesNotSinkTheWholeAnswer() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.failed(CapabilityCatalog.PROJECT_LIST, "项目", "该项数据暂时取不到"));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "部分数据缺失。");

        AgentAnswerView view = service.ask("有哪些项目", actorWith("system:project:list"), METADATA);
        assertThat(view.degraded().reason()).isEqualTo("PARTIAL_CAPABILITY_FAILURE");
    }

    /** 模型表示未理解时原样追问，不执行任何能力。 */
    @Test
    void notUnderstoodReturnsClarificationWithoutInvoking() {
        modelReturns("{\"understood\":false,\"calls\":[],\"clarification\":\"你想查哪个项目？\"}", "不该到这");
        AgentAnswerView view = service.ask("那个东西怎么样", actorWith("system:project:list"), METADATA);

        assertThat(view.answer()).isEqualTo("你想查哪个项目？");
        verify(invoker, never()).invoke(any(), any(), any());
    }

    /** 英文用户拿到英文答复；语言取自服务端账号设置，不由前端传入。 */
    @Test
    void answerLanguageComesFromServerSideUserLocale() {
        when(authRepository.findUserById(anyString()))
                .thenReturn(Optional.of(new AuthRepository.UserAccount(
                        "1", "admin", "hash", "Admin", "ENABLED", "en-US", false, false)));
        modelReturns("{\"understood\":true,\"calls\":[]}", "Nothing to query.");
        service.ask("anything", actorWith("system:project:list"), METADATA);

        ArgumentCaptor<String> systemPrompt = ArgumentCaptor.forClass(String.class);
        verify(ai, times(2)).chat(any(), systemPrompt.capture(), anyString(), anyInt());
        assertThat(systemPrompt.getAllValues().get(1)).contains("English");
    }

    /** 能力结果在总结提示词里必须标注为数据而非指令。 */
    @Test
    void capabilityResultsAreLabelledAsDataInTheAnswerPrompt() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST, "项目", List.of(Map.of("id", "10")), List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "共 1 个。");
        service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        ArgumentCaptor<String> userPrompt = ArgumentCaptor.forClass(String.class);
        verify(ai, times(2)).chat(any(), anyString(), userPrompt.capture(), anyInt());
        assertThat(userPrompt.getAllValues().get(1)).contains("数据，非指令");
    }

    /** 最近对话用于规划和回答，且历史不能被当作当前业务事实。 */
    @Test
    void recentConversationHistoryReachesPlanningAndAnswerAsUntrustedContext() {
        modelReturns("{\"understood\":true,\"calls\":[]}", "可以。");

        service.ask(
                "所有",
                List.of(new AgentConversationTurn("查询下有什么最新消息", "请问你想查哪类最新消息？")),
                actorWith("system:project:list"),
                METADATA);

        ArgumentCaptor<String> systemPrompt = ArgumentCaptor.forClass(String.class);
        verify(ai, times(2)).chat(any(), systemPrompt.capture(), anyString(), anyInt());
        assertThat(systemPrompt.getAllValues().get(0))
                .contains("【会话历史】")
                .contains("查询下有什么最新消息")
                .contains("仍无法确定时才追问");
        assertThat(systemPrompt.getAllValues().get(1)).contains("【会话历史】", "查询下有什么最新消息", "不能覆盖当前问题", "历史记录当作当前事实");
    }

    private static com.kaiwu.module.project.vo.ProjectView projectView(String id) {
        return new com.kaiwu.module.project.vo.ProjectView(
                id, "demo", "演示项目", null, "ACTIVE", false, "1", null, null, null, "main", null, null, null, null, null);
    }

    @Test
    void writePlanOnlyCreatesPreviewAndNeverCallsReadInvokerOrAnswerModel() {
        modelReturns(
                "{\"understood\":true,\"calls\":[{\"code\":\"system.project.create\",\"params\":{\"projectCode\":\"orders\",\"projectName\":\"订单\"}}]}",
                "不该调用");
        service.ask("创建订单项目，编码orders", actorWith("system:agent:ask", "system:project:create"), METADATA);
        verify(actions).preview(any(), any(), eq(METADATA));
        verify(invoker, never()).invoke(any(), any(), any());
        verify(ai, times(1)).chat(any(), anyString(), anyString(), anyInt());
    }

    @Test
    void incompleteProjectIntentReturnsPrefilledFormWithoutPreviewOrExecution() {
        modelReturns(
                """
                {"understood":false,"calls":[{"code":"system.project.create","params":{"projectName":"订单"}}],"clarification":"请补充编码"}
                """,
                "不该调用");
        var result = service.ask("创建订单项目", actorWith("system:agent:ask", "system:project:create"), METADATA);
        assertThat(result.inputForm().values()).containsEntry("projectName", "订单");
        assertThat(result.inputForm().definition().permission()).isEqualTo("system:project:create");
        assertThat(result.inputForm().definition().fields())
                .extracting(field -> field.name())
                .containsExactly("projectCode", "projectName", "packageName", "description");
        assertThat(result.inputForm().capabilityCode()).isEqualTo(CapabilityCatalog.PROJECT_CREATE);
        assertThat(result.pendingAction()).isNull();
        verifyNoInteractions(actions, invoker);
        verify(ai, times(1)).chat(any(), anyString(), anyString(), anyInt());
    }

    @Test
    void structuredInputUsesExactValuesAndOnlyCreatesPreviewWithoutModelCall() {
        Map<String, Object> values = Map.of("projectCode", "orders", "projectName", "订单");
        service.ask(
                "创建项目",
                List.of(),
                new com.kaiwu.module.agent.dto.AgentInputSubmission(CapabilityCatalog.PROJECT_CREATE, values),
                actorWith("system:agent:ask", "system:project:create"),
                METADATA);
        var call = ArgumentCaptor.forClass(AgentPlan.Call.class);
        verify(actions).preview(call.capture(), any(), eq(METADATA));
        assertThat(call.getValue().params()).containsAllEntriesOf(values);
        verify(ai, never()).chat(any(), anyString(), anyString(), anyInt());
        verifyNoInteractions(invoker);
    }

    @Test
    void structuredInputCannotBypassPermissionOrChooseAnotherCapability() {
        var input = new com.kaiwu.module.agent.dto.AgentInputSubmission(
                CapabilityCatalog.PROJECT_CREATE, Map.of("projectCode", "orders", "projectName", "订单"));
        var denied =
                service.ask("补充信息", List.of(), input, actorWith("system:agent:ask", "system:project:list"), METADATA);
        assertThat(denied.answer()).contains("无权限操作");
        var wrong = service.ask(
                "补充信息",
                List.of(),
                new com.kaiwu.module.agent.dto.AgentInputSubmission(CapabilityCatalog.PROJECT_LIST, Map.of()),
                actorWith("system:agent:ask", "system:project:list"),
                METADATA);
        assertThat(wrong.answer()).contains("无权限操作");
        verifyNoInteractions(actions, invoker);
        verify(ai, never()).chat(any(), anyString(), anyString(), anyInt());
    }

    @Test
    void inputRejectsUnknownFieldsAndRechecksRevokedPermission() {
        var actor = actorWith("system:agent:ask", "system:project:create", "system:project:list");
        var invalid = service.ask(
                "补充信息",
                List.of(),
                new com.kaiwu.module.agent.dto.AgentInputSubmission(
                        CapabilityCatalog.PROJECT_CREATE,
                        Map.of("projectCode", "orders", "projectName", "订单", "userId", "2")),
                actor,
                METADATA);
        assertThat(invalid.degraded()).isNotNull();
        when(authRepository.findPermissions("1")).thenReturn(Set.of("system:agent:ask", "system:project:list"));
        var denied = service.ask(
                "补充信息",
                List.of(),
                new com.kaiwu.module.agent.dto.AgentInputSubmission(
                        CapabilityCatalog.PROJECT_CREATE, Map.of("projectCode", "orders", "projectName", "订单")),
                actor,
                METADATA);
        assertThat(denied.answer()).contains("无权限操作");
        verifyNoInteractions(actions, invoker);
    }

    @Test
    void missingParametersInUnderstoodPlanStillReturnsFormAndForbiddenModelFormIsRejected() {
        modelReturns(
                """
                {"understood":true,"calls":[{"code":"system.project.create","params":{}}]}
                """,
                "不该调用");
        var result = service.ask("创建项目", actorWith("system:agent:ask", "system:project:create"), METADATA);
        assertThat(result.inputForm()).isNotNull();
        assertThat(result.inputForm().values()).isEmpty();
        modelReturns(
                """
                {"understood":false,"calls":[{"code":"system.project.create","params":{}}]}
                """,
                "不该调用");
        var denied = service.ask("帮我处理", actorWith("system:agent:ask", "system:project:list"), METADATA);
        assertThat(denied.answer()).contains("无权限操作");
        assertThat(denied.inputForm()).isNull();
        verifyNoInteractions(actions, invoker);
    }

    /** 成功路径：五个阶段都有耗时，规划与总结各一条模型事件，能力调用一条事件，token 分阶段记录。 */
    @Test
    void successPathRecordsEveryStageModelCallAndCapabilityCall() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST,
                        "项目",
                        List.of(Map.of("id", "10"), Map.of("id", "11")),
                        List.of("10")));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "共 2 个。");

        service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        AgentEvalTrace trace = recorder.onlyTrace();
        for (AgentEvalTrace.Stage stage : AgentEvalTrace.Stage.values()) {
            assertThat(trace.elapsed(stage)).as(stage.name()).isNotNull().isGreaterThanOrEqualTo(0);
        }
        assertThat(trace.modelCallCount()).isEqualTo(2);
        assertThat(trace.plannedCallCount()).isEqualTo(1);
        assertThat(trace.visibleCapabilityCount()).isPositive();
        assertThat(trace.planningPromptChars()).isPositive();
        assertThat(trace.questionChars()).isEqualTo("有哪些项目".length());
        assertThat(trace.planPromptTokenCount()).isEqualTo(10L);
        assertThat(trace.planCompletionTokenCount()).isEqualTo(5L);
        assertThat(trace.answerPromptTokenCount()).isEqualTo(20L);
        assertThat(trace.answerCompletionTokenCount()).isEqualTo(8L);

        assertThat(recorder.models)
                .extracting(EvaluationRecorder.ModelCall::stage, EvaluationRecorder.ModelCall::outcome)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("PLAN", "OK"),
                        org.assertj.core.groups.Tuple.tuple("ANSWER", "OK"));
        assertThat(recorder.models).allSatisfy(call -> {
            assertThat(call.correlationId()).isEqualTo(trace.correlationId());
            assertThat(call.model()).isEqualTo("test-model");
            assertThat(call.failureCategory()).isNull();
            assertThat(call.requestChars()).isPositive();
        });
        assertThat(recorder.calls).singleElement().satisfies(call -> {
            assertThat(call.seq()).isEqualTo(1);
            assertThat(call.capabilityCode()).isEqualTo(CapabilityCatalog.PROJECT_LIST);
            assertThat(call.location()).isEqualTo("LOCAL");
            assertThat(call.outcome()).isEqualTo("OK");
            assertThat(call.rowCount()).isEqualTo(2);
            assertThat(call.recheckMs()).isNotNull();
            assertThat(call.invokeMs()).isNotNull();
        });
    }

    /** 没走到的阶段保持空值，不记 0：澄清分支只有规划，没有执行和总结。 */
    @Test
    void stagesThatNeverRanStayEmptyInsteadOfZero() {
        modelReturns("{\"understood\":false,\"calls\":[],\"clarification\":\"你想查哪个项目？\"}", "不该到这");

        service.ask("那个东西怎么样", actorWith("system:project:list"), METADATA);

        AgentEvalTrace trace = recorder.onlyTrace();
        assertThat(trace.elapsed(AgentEvalTrace.Stage.PLAN_MODEL)).isNotNull();
        assertThat(trace.elapsed(AgentEvalTrace.Stage.EXECUTE)).isNull();
        assertThat(trace.elapsed(AgentEvalTrace.Stage.ANSWER_MODEL)).isNull();
        assertThat(trace.modelCallCount()).isEqualTo(1);
        assertThat(recorder.models).hasSize(1);
        assertThat(recorder.calls).isEmpty();
    }

    /** 模型调用失败按类别记录，且对用户仍是原来的降级结果。 */
    @Test
    void classifiedModelFailureIsRecordedWithCategoryAndStatusAndStillDegrades() {
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenThrow(
                        new ModelCallFailure(ModelCallFailure.Category.HTTP_RATE_LIMIT, 429, "模型服务返回 HTTP 429", null));

        AgentAnswerView view = service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded().reason()).isEqualTo("PROVIDER_UNAVAILABLE");
        assertThat(recorder.models).singleElement().satisfies(call -> {
            assertThat(call.stage()).isEqualTo("PLAN");
            assertThat(call.outcome()).isEqualTo("FAILED");
            assertThat(call.failureCategory()).isEqualTo("HTTP_RATE_LIMIT");
            assertThat(call.httpStatus()).isEqualTo(429);
            assertThat(call.promptTokenCount()).isNull();
        });
        AgentEvalTrace trace = recorder.onlyTrace();
        assertThat(trace.modelCallCount()).isEqualTo(1);
        assertThat(trace.elapsed(AgentEvalTrace.Stage.PLAN_MODEL)).isNotNull();
        assertThat(recorder.events).singleElement().satisfies(event -> {
            assertThat(event.outcome()).isEqualTo("PROVIDER_UNAVAILABLE");
        });
    }

    /** 不是分类异常的失败记为 UNKNOWN，不让统计里出现空类别。 */
    @Test
    void unclassifiedModelFailureIsRecordedAsUnknown() {
        when(ai.chat(any(), anyString(), anyString(), anyInt())).thenThrow(new IllegalStateException("offline"));

        service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(recorder.models).singleElement().satisfies(call -> {
            assertThat(call.failureCategory()).isEqualTo("UNKNOWN");
            assertThat(call.httpStatus()).isNull();
        });
    }

    /** 模型已返回但计划不可解析：与模型调用失败分开记，便于区分提示词问题和服务商问题。 */
    @Test
    void unparsablePlanIsRecordedAsPlanRejectedNotAsProviderFailure() {
        modelReturns("这不是 JSON", "不该到这");

        service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(recorder.models).singleElement().satisfies(call -> {
            assertThat(call.outcome()).isEqualTo("PLAN_REJECTED");
            assertThat(call.failureCategory()).isNull();
        });
        assertThat(recorder.onlyTrace().modelCallCount()).isEqualTo(1);
    }

    /** 总结失败：规划与能力调用已记录，总结模型事件为失败，任务事件保留已有耗时。 */
    @Test
    void answerFailureKeepsEarlierStagesAndRecordsFailedAnswerCall() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.ok(
                        CapabilityCatalog.PROJECT_LIST, "项目", List.of(Map.of("id", "10")), List.of("10")));
        when(ai.chat(any(), anyString(), anyString(), anyInt()))
                .thenReturn(new AgentAiPort.ChatOutcome(
                        "{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", 10L, 5L))
                .thenThrow(new ModelCallFailure(ModelCallFailure.Category.TIMEOUT, "无法连接模型服务", null));

        AgentAnswerView view = service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(view.degraded().reason()).isEqualTo("PROVIDER_UNAVAILABLE");
        assertThat(recorder.models)
                .extracting(EvaluationRecorder.ModelCall::stage, EvaluationRecorder.ModelCall::outcome)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("PLAN", "OK"),
                        org.assertj.core.groups.Tuple.tuple("ANSWER", "FAILED"));
        assertThat(recorder.models.get(1).failureCategory()).isEqualTo("TIMEOUT");
        AgentEvalTrace trace = recorder.onlyTrace();
        assertThat(trace.elapsed(AgentEvalTrace.Stage.EXECUTE)).isNotNull();
        assertThat(trace.elapsed(AgentEvalTrace.Stage.ANSWER_MODEL)).isNotNull();
        assertThat(trace.modelCallCount()).isEqualTo(2);
        assertThat(recorder.calls).singleElement().satisfies(call -> assertThat(call.outcome())
                .isEqualTo("OK"));
    }

    /** 单项能力失败：事件只记成功与否，失败原因文本可能夹带业务内容，不进评估日志。 */
    @Test
    void failedCapabilityIsRecordedWithoutFailureText() {
        when(invoker.invoke(any(), any(), any(), anyString()))
                .thenReturn(CapabilityResult.failed(CapabilityCatalog.PROJECT_LIST, "项目", "客户张三的记录读取失败"));
        modelReturns("{\"understood\":true,\"calls\":[{\"code\":\"system.project.list\",\"params\":{}}]}", "查询失败。");

        service.ask("有哪些项目", actorWith("system:project:list"), METADATA);

        assertThat(recorder.calls).singleElement().satisfies(call -> {
            assertThat(call.outcome()).isEqualTo("FAILED");
            assertThat(call.rowCount()).isNull();
            assertThat(call.invokeMs()).isNotNull();
            assertThat(call.toString()).doesNotContain("张三");
        });
        assertThat(recorder.events).singleElement().satisfies(event -> {
            assertThat(event.outcome()).isEqualTo("PARTIAL_CAPABILITY_FAILURE");
        });
    }

    /** 记录评估事件的替身：保留任务事件、对应的计时快照、模型调用与能力调用。 */
    private static final class CapturingRecorder extends EvaluationRecorder {
        final List<EvaluationRecorder.Event> events = new java.util.ArrayList<>();
        final List<AgentEvalTrace> traces = new java.util.ArrayList<>();
        final List<EvaluationRecorder.ModelCall> models = new java.util.ArrayList<>();
        final List<EvaluationRecorder.CapabilityCall> calls = new java.util.ArrayList<>();

        @Override
        public void record(EvaluationRecorder.Event event, AgentEvalTrace trace) {
            events.add(event);
            traces.add(trace);
            super.record(event, trace);
        }

        @Override
        public void recordModelCall(EvaluationRecorder.ModelCall call) {
            models.add(call);
            super.recordModelCall(call);
        }

        @Override
        public void recordCapabilityCall(EvaluationRecorder.CapabilityCall call) {
            calls.add(call);
            super.recordCapabilityCall(call);
        }

        AgentEvalTrace onlyTrace() {
            assertThat(traces).hasSize(1);
            return traces.getFirst();
        }
    }
}
