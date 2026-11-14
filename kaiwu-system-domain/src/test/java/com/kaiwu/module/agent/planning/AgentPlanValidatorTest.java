package com.kaiwu.module.agent.planning;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.protocol.ParamType;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * 校验器的安全行为。重点是权限反例与越界拒绝，而不是happy path。
 */
class AgentPlanValidatorTest {

    @Test
    void structuredEnumAndDateTimeRejectForgedValuesWithoutCoercion() {
        var capability = Capability.builder("system.example.filter")
                .description("筛选")
                .permission("system:example:list")
                .dataScope(DataScope.ALL)
                .params(Map.of(
                        "status", ParamSpec.optionalEnum(Set.of("ACTIVE")), "since", ParamSpec.optionalDateTime()))
                .inputForm(
                        "example.title",
                        List.of("status", "since"),
                        Set.of(),
                        Map.of(),
                        Map.of("status", "common.status"))
                .verifiedReadOnly()
                .build();
        var registry = mock(CapabilityCatalog.class);
        var actor = actorWith("system:example:list");
        when(registry.findVisible(capability.code(), actor)).thenReturn(java.util.Optional.of(capability));
        var validation = new AgentPlanValidator(registry);
        var values = Map.<String, Object>of("status", "ACTIVE", "since", "2026-09-27T08:30:00");
        assertThat(validation
                        .validateInput(planOf(capability.code(), values), actor, Set.of())
                        .calls()
                        .getFirst()
                        .params())
                .isEqualTo(values);
        for (var bad : List.of(
                Map.of("status", "ADMIN"),
                Map.of("status", " ACTIVE "),
                Map.of("status", 1),
                Map.of("since", "2026-02-30T08:30:00"),
                Map.of("since", "2026-09-27T08:30:00Z"),
                Map.of("since", 123))) {
            assertThatThrownBy(() -> validation.validateInput(
                            planOf(capability.code(), new java.util.HashMap<>(bad)), actor, Set.of()))
                    .isInstanceOf(PlanRejectedException.class);
        }
    }

    @Test
    void boundedStringListRequiresExactArrayShapeAndBounds() {
        var capability = Capability.builder("system.example.grant")
                .description("授权菜单")
                .permission("system:project:role")
                .dataScope(DataScope.ALL)
                .params(Map.of("menuIds", ParamSpec.stringList(true, 0, 3, 19)))
                .inputForm("example.title", List.of("menuIds"), Set.of(), Map.of())
                .build();
        var registry = mock(CapabilityCatalog.class);
        var actor = actorWith("system:project:role");
        when(registry.findVisible(capability.code(), actor)).thenReturn(java.util.Optional.of(capability));
        var validation = new AgentPlanValidator(registry);
        assertThat(validation
                        .validateInput(
                                planOf(capability.code(), Map.of("menuIds", List.of("11", "12"))), actor, Set.of())
                        .calls()
                        .getFirst()
                        .params())
                .containsEntry("menuIds", List.of("11", "12"));
        assertThat(validation
                        .validateInput(planOf(capability.code(), Map.of("menuIds", List.of())), actor, Set.of())
                        .calls()
                        .getFirst()
                        .params())
                .containsEntry("menuIds", List.of());
        for (Object bad : List.of(
                "11,12",
                List.of("11", "11"),
                List.of(""),
                List.of(" 11"),
                List.of("11", "12", "13", "14"),
                List.of("12345678901234567890"))) {
            assertThatThrownBy(() -> validation.validateInput(
                            planOf(capability.code(), Map.of("menuIds", bad)), actor, Set.of()))
                    .isInstanceOf(PlanRejectedException.class);
        }
    }

    private static final Set<String> VISIBLE_PROJECTS = Set.of("10", "11");

    private final CapabilityCatalog catalog = new CapabilityCatalog();
    private final AgentPlanValidator validator = new AgentPlanValidator(catalog);

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

    private static AgentPlan planOf(String code, Map<String, Object> params) {
        return new AgentPlan(true, List.of(new AgentPlan.Call(code, params)), null);
    }

    @Test
    void declaredFormOnAnotherCapabilityValidatesPartialValuesWithoutProjectSpecialCase() {
        var local = Capability.builder("system.example.detail")
                .description("测试详情")
                .permission("system:example:list")
                .dataScope(DataScope.ALL)
                .params(Map.of("reference", new ParamSpec(ParamType.STRING, true, null, null, 64, null, null, null)))
                .inputForm("example.title", List.of("reference"), Set.of(), Map.of())
                .verifiedReadOnly()
                .build();
        var registry = mock(CapabilityCatalog.class);
        var actor = actorWith("system:example:list");
        when(registry.findVisible(local.code(), actor)).thenReturn(java.util.Optional.of(local));
        var validation = new AgentPlanValidator(registry);
        assertThat(validation
                        .validate(planOf(local.code(), Map.of()), actor, Set.of())
                        .understood())
                .isFalse();
        assertThat(validation
                        .validate(planOf(local.code(), Map.of("reference", "  ")), actor, Set.of())
                        .calls()
                        .getFirst()
                        .params())
                .isEmpty();
        assertThat(validation
                        .validate(planOf(local.code(), Map.of("reference", "123")), actor, Set.of())
                        .understood())
                .isTrue();
        assertThatThrownBy(() -> validation.validate(planOf(local.code(), Map.of("actor", "2")), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessageContaining("不接受参数");
        when(registry.findVisible(local.code(), actor)).thenReturn(java.util.Optional.empty());
        assertThatThrownBy(() -> validation.validate(planOf(local.code(), Map.of()), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessageContaining("无权限操作");
    }

    @Test
    void formMetadataRejectsUnknownFieldsAndDerivesIntegerType() {
        assertThatThrownBy(() -> Capability.builder("system.example.detail")
                        .description("测试")
                        .permission("system:example:list")
                        .dataScope(DataScope.ALL)
                        .inputForm("example.title", List.of("actor"), Set.of(), Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat(Capability.builder("system.example.detail")
                        .description("测试")
                        .permission("system:example:list")
                        .dataScope(DataScope.ALL)
                        .params(Map.of("pageSize", ParamSpec.pageSize(50, 20)))
                        .inputForm("example.title", List.of("pageSize"), Set.of(), Map.of())
                        .build()
                        .inputForm()
                        .fields()
                        .getFirst()
                        .type())
                .isEqualTo("INT");
    }

    /** 无权限时目录为空；能力可见性完全由权限决定。 */
    @Test
    void catalogIsFilteredByPermissionAndEmptyWithoutAny() {
        assertThat(catalog.visibleTo(actorWith())).isEmpty();
        assertThat(catalog.visibleTo(actorWith("system:project:list")))
                .extracting(Capability::code)
                .containsExactlyInAnyOrder(CapabilityCatalog.PROJECT_LIST, CapabilityCatalog.PROJECT_DETAIL);
    }

    /** 规则 3：调用未获授权的能力被拒绝。 */
    @Test
    void rule3RejectsCapabilityTheCallerCannotUse() {
        KaiwuContext actor = actorWith("system:project:list");
        assertThatThrownBy(
                        () -> validator.validate(planOf(CapabilityCatalog.SCHEDULER_LIST, Map.of()), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessageContaining("无权限操作");
    }

    /** 规则 3：不存在的能力与越权能力得到同一种拒绝，不泄露能力是否存在。 */
    @Test
    void rule3TreatsUnknownAndUnauthorizedAlike() {
        KaiwuContext actor = actorWith("system:project:list");
        assertThatThrownBy(() -> validator.validate(planOf("system.nonexistent", Map.of()), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(3));
    }

    /** 规则 2：单次计划的能力数超过上限即拒绝。 */
    @Test
    void rule2RejectsTooManyCalls() {
        KaiwuContext actor = actorWith("system:project:list");
        List<AgentPlan.Call> calls = List.of(
                new AgentPlan.Call(CapabilityCatalog.PROJECT_LIST, Map.of()),
                new AgentPlan.Call(CapabilityCatalog.PROJECT_LIST, Map.of()),
                new AgentPlan.Call(CapabilityCatalog.PROJECT_LIST, Map.of()),
                new AgentPlan.Call(CapabilityCatalog.PROJECT_LIST, Map.of()));
        assertThatThrownBy(() -> validator.validate(new AgentPlan(true, calls, null), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(2));
    }

    @Test
    void rule4RejectsSelfReportedReadOnlyCapability() {
        KaiwuContext actor = actorWith("crm:record:list");
        Capability remote = new Capability(
                "crm",
                "crm.record.search",
                "1",
                "查询记录",
                "crm:record:list",
                DataScope.MEMBER_PROJECTS,
                Map.of(),
                Set.of("id"),
                Map.of(),
                true,
                false,
                true);
        CapabilityCatalog remoteCatalog = mock(CapabilityCatalog.class);
        when(remoteCatalog.findVisible(remote.code(), actor)).thenReturn(java.util.Optional.of(remote));
        AgentPlanValidator remoteValidator = new AgentPlanValidator(remoteCatalog);
        assertThatThrownBy(() -> remoteValidator.validate(planOf(remote.code(), Map.of()), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(4));
    }

    /** 规则 5：schema 之外的参数被拒绝；身份类字段因为不允许声明，必然落进这一条。 */
    @Test
    void rule5RejectsParameterOutsideSchema() {
        KaiwuContext actor = actorWith("system:project:list");
        assertThatThrownBy(() -> validator.validate(
                        planOf(CapabilityCatalog.PROJECT_LIST, Map.of("userId", "999")), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(5));
    }

    /** 规则 6：枚举取值非法即拒绝——那说明模型没理解意图。 */
    @Test
    void rule6RejectsInvalidEnumValue() {
        KaiwuContext actor = actorWith("system:project:list");
        assertThatThrownBy(() -> validator.validate(
                        planOf(CapabilityCatalog.PROJECT_LIST, Map.of("status", "WHATEVER")), actor, Set.of()))
                .isInstanceOf(PlanRejectedException.class)
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(6));
    }

    /** 规则 6b：数值越界钳制到边界。模型把 20 写成 200 是常见抖动，为此让用户重问不合理。 */
    @Test
    void rule6bClampsOutOfRangeNumberInsteadOfRejecting() {
        KaiwuContext actor = actorWith("system:project:list");
        AgentPlan result =
                validator.validate(planOf(CapabilityCatalog.PROJECT_LIST, Map.of("pageSize", 500)), actor, Set.of());
        assertThat(result.calls().get(0).params()).containsEntry("pageSize", 50);
    }

    /** 规则 6：未提供的可选参数补上默认值。 */
    @Test
    void rule6FillsDefaultForOmittedParameter() {
        KaiwuContext actor = actorWith("system:project:list");
        AgentPlan result = validator.validate(planOf(CapabilityCatalog.PROJECT_LIST, Map.of()), actor, Set.of());
        assertThat(result.calls().get(0).params()).containsEntry("pageSize", 20);
    }

    /** 规则 7：超长字符串截断而非拒绝。 */
    @Test
    void rule7TruncatesOverlongStringInsteadOfRejecting() {
        KaiwuContext actor = actorWith("system:project:list");
        AgentPlan result = validator.validate(
                planOf(CapabilityCatalog.PROJECT_LIST, Map.of("keyword", "x".repeat(200))), actor, Set.of());
        assertThat((String) result.calls().get(0).params().get("keyword")).hasSize(64);
    }

    /** 规则 9：指定无权限的项目被拒绝，且话术不确认该项目是否存在。 */
    @Test
    void rule9RejectsProjectOutsideVisibleSet() {
        KaiwuContext actor = actorWith("system:scheduler:list");
        assertThatThrownBy(() -> validator.validate(
                        planOf(CapabilityCatalog.SCHEDULER_LIST, Map.of("projectId", "99")), actor, VISIBLE_PROJECTS))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessageContaining("没有找到你有权限的项目")
                .satisfies(thrown ->
                        assertThat(((PlanRejectedException) thrown).rule()).isEqualTo(9));
    }

    /** 规则 9：可见项目正常通过。 */
    @Test
    void rule9AcceptsVisibleProject() {
        KaiwuContext actor = actorWith("system:scheduler:list");
        AgentPlan result = validator.validate(
                planOf(CapabilityCatalog.SCHEDULER_LIST, Map.of("projectId", "10")), actor, VISIBLE_PROJECTS);
        assertThat(result.calls().get(0).params()).containsEntry("projectId", "10");
    }

    /** 模型表示未理解时原样返回，不猜参数、不空跑能力。 */
    @Test
    void unresolvedQuestionIsReturnedWithoutExecutingAnything() {
        AgentPlan plan = new AgentPlan(false, List.of(), "你想查哪个项目？");
        AgentPlan result = validator.validate(plan, actorWith("system:project:list"), Set.of());
        assertThat(result.understood()).isFalse();
        assertThat(result.calls()).isEmpty();
    }

    /** 能力契约缺必填字段时构造即失败，不会带着半个契约进入目录。 */
    @Test
    void capabilityWithMissingContractFieldFailsToConstruct() {
        assertThatThrownBy(() -> Capability.builder("x.y")
                        .description("d")
                        .permission("p")
                        .build())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("dataScope");
    }

    /** 能力不得声明身份类参数，该值只能由服务端从 Context 注入。 */
    @Test
    void capabilityCannotDeclareIdentityParameter() {
        assertThatThrownBy(() -> Capability.builder("x.y")
                        .description("d")
                        .permission("p")
                        .dataScope(DataScope.SELF)
                        .params(Map.of("userId", ParamSpec.optionalString(10)))
                        .build())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("身份类参数");
    }

    /** 调度执行记录同样标记为已验证只读，否则会与「只读无需逐次确认」冲突。 */
    @Test
    void builtInCapabilitiesAreAllVerifiedReadOnly() {
        KaiwuContext admin = actorWith("system:project:list", "system:project-factory:list", "system:scheduler:list");
        assertThat(catalog.visibleTo(admin)).extracting(Capability::code).contains(CapabilityCatalog.GENERATION_DETAIL);
        assertThat(catalog.visibleTo(admin)).allSatisfy(capability -> assertThat(capability.canSkipConfirmation())
                .isTrue());
    }

    @Test
    void projectCreationRequiresOneStandaloneWriteAndStrictStrings() {
        KaiwuContext actor = actorWith("system:project:create", "system:project:list");
        var params = Map.<String, Object>of("projectCode", "orders", "projectName", "订单");
        assertThat(validator
                        .validate(planOf(CapabilityCatalog.PROJECT_CREATE, params), actor, Set.of())
                        .calls())
                .hasSize(1);
        var mixed = new AgentPlan(
                true,
                List.of(
                        new AgentPlan.Call(CapabilityCatalog.PROJECT_CREATE, params),
                        new AgentPlan.Call(CapabilityCatalog.PROJECT_LIST, Map.of())),
                null);
        assertThatThrownBy(() -> validator.validate(mixed, actor, Set.of())).isInstanceOf(PlanRejectedException.class);
        for (Object value : List.of(123, "x".repeat(101), List.of("orders")))
            assertThatThrownBy(() -> validator.validate(
                            planOf(
                                    CapabilityCatalog.PROJECT_CREATE,
                                    Map.of("projectCode", "orders", "projectName", value)),
                            actor,
                            Set.of()))
                    .isInstanceOf(PlanRejectedException.class);
        assertThat(catalog.findVisible(CapabilityCatalog.PROJECT_CREATE, actor)
                        .orElseThrow()
                        .canSkipConfirmation())
                .isFalse();
    }
}
