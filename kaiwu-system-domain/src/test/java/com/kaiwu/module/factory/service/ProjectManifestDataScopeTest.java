package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.factory.convert.ProjectManifestParser;
import com.kaiwu.module.factory.dto.ProjectManifestRequest;
import com.kaiwu.module.factory.service.impl.ProjectHandoverRecorder;
import com.kaiwu.module.factory.service.impl.ProjectManifestServiceImpl;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.service.ProjectAccessGuard;
import com.kaiwu.module.project.service.ProjectDataScopeService;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectDataResourceView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.json.JsonMapper;

/** 受控数据资源在清单同步里的计划与执行语义（ADR 0044）：只声明资源，不产生授权，不自动下线。 */
class ProjectManifestDataScopeTest {

    private static final String PROJECT = "100";
    private static final Set<String> ALL = Set.of("system:dict:save", "system:config:save", "system:project:menu");
    private static final RequestMetadata METADATA = new RequestMetadata("10.0.0.8", "trace-1");
    private static final String YAML =
            """
            resources:
              - { code: 'crm:customer', name: 客户, table: crm_customer, allowedScopes: [ALL, SELF] }
            """;

    private ProjectDataScopeService dataScopes;
    private ProjectService projectService;
    private ProjectAccessGuard guard;
    private ProjectManifestService service;

    /** 用被模拟的平台服务搭建清单同步服务，项目管理员校验直接通过。 */
    @BeforeEach
    void setUp() {
        dataScopes = mock(ProjectDataScopeService.class);
        projectService = mock(ProjectService.class);
        guard = mock(ProjectAccessGuard.class);
        ProjectGenerationProjectPort projects = mock(ProjectGenerationProjectPort.class);
        when(projects.requireProjectAdmin(eq(PROJECT), anyString())).thenReturn(project());
        when(projectService.menus(PROJECT)).thenReturn(List.of());
        service = new ProjectManifestServiceImpl(
                new ProjectManifestParser(),
                projects,
                projectService,
                mock(MetadataService.class),
                mock(I18nService.class),
                mock(AuditPort.class),
                JsonMapper.builder().build(),
                guard,
                mock(ProjectHandoverRecorder.class),
                mock(ProjectSchedulerService.class),
                dataScopes);
    }

    /** 只带 data-scopes.yml 的同步请求。 */
    private static ProjectManifestRequest request(String yaml, String hash) {
        return new ProjectManifestRequest(Map.of("data-scopes.yml", yaml), "abc1234", hash);
    }

    /** 计划里受控资源变化的「资源码:动作」摘要。 */
    private static List<String> summary(ProjectManifestPlanView plan) {
        return plan.changes().stream()
                .filter(change -> "DATA_SCOPE".equals(change.resource()))
                .map(change -> change.key() + ":" + change.action())
                .toList();
    }

    /** 新资源在计划阶段只读不写，作为普通变更执行，不属于授权类别。 */
    @Test
    void aNewResourceIsPlannedWithoutWritingAndAppliedAsAnOrdinaryChange() {
        ProjectManifestPlanView plan = service.plan(PROJECT, request(YAML, null), actor());

        assertThat(summary(plan)).containsExactly("crm:customer:CREATE");
        assertThat(plan.changes().get(0).category()).isNotEqualTo("ACCESS");
        verify(dataScopes, never()).saveResource(any(), any(), any(), any());

        service.apply(PROJECT, request(YAML, plan.planHash()), actor(), METADATA);

        verify(dataScopes).saveResource(PROJECT, "crm:customer", "客户", List.of("ALL", "SELF"));
    }

    /** 与平台一致的资源不产生变更，也不写入。 */
    @Test
    void anUnchangedResourceProducesNoChangeAndNoWrite() {
        when(dataScopes.resources(PROJECT))
                .thenReturn(
                        List.of(new ProjectDataResourceView("crm:customer", "客户", List.of("ALL", "SELF"), "ENABLED")));

        ProjectManifestPlanView plan = service.plan(PROJECT, request(YAML, null), actor());

        assertThat(summary(plan)).isEmpty();
    }

    /** 收窄允许范围时，计划写明有多少角色配置会因此按仅本人生效。 */
    @Test
    void narrowingTheAllowedScopesTellsHowManyRoleConfigurationsFallBackToSelf() {
        when(dataScopes.resources(PROJECT))
                .thenReturn(List.of(
                        new ProjectDataResourceView("crm:customer", "客户", List.of("ALL", "DEPT", "SELF"), "ENABLED")));
        when(dataScopes.configsOutside(PROJECT, "crm:customer", List.of("ALL", "SELF")))
                .thenReturn(3L);

        ProjectManifestPlanView plan = service.plan(PROJECT, request(YAML, null), actor());

        assertThat(summary(plan)).containsExactly("crm:customer:UPDATE");
        assertThat(plan.changes().get(0).detail()).contains("3 个角色配置").contains("仅本人");
    }

    /** 已下线的资源被清单重新声明时重新启用。 */
    @Test
    void aDisabledResourceThatIsDeclaredAgainIsReenabled() {
        when(dataScopes.resources(PROJECT))
                .thenReturn(
                        List.of(new ProjectDataResourceView("crm:customer", "客户", List.of("ALL", "SELF"), "DISABLED")));

        ProjectManifestPlanView plan = service.plan(PROJECT, request(YAML, null), actor());
        assertThat(summary(plan)).containsExactly("crm:customer:REENABLE");

        service.apply(PROJECT, request(YAML, plan.planHash()), actor(), METADATA);
        verify(dataScopes).saveResource(PROJECT, "crm:customer", "客户", List.of("ALL", "SELF"));
    }

    /** 清单里消失的资源只报漂移，不会被自动下线。 */
    @Test
    void aResourceMissingFromTheManifestIsOnlyReportedAsDriftAndNeverDisabled() {
        when(dataScopes.resources(PROJECT))
                .thenReturn(List.of(new ProjectDataResourceView("crm:legacy", "旧资源", List.of("SELF"), "ENABLED")));

        ProjectManifestPlanView plan = service.plan(PROJECT, request(YAML, null), actor());
        assertThat(summary(plan)).containsExactlyInAnyOrder("crm:customer:CREATE", "crm:legacy:DRIFT");

        service.apply(PROJECT, request(YAML, plan.planHash()), actor(), METADATA);
        verify(dataScopes, never()).saveResource(eq(PROJECT), eq("crm:legacy"), any(), any());
    }

    /** 计划之后资源被改动，哈希对不上，执行被拒绝并返回冲突。 */
    @Test
    void applyIsRejectedWhenTheResourceChangedAfterThePlan() {
        when(dataScopes.resources(PROJECT))
                .thenReturn(List.of(new ProjectDataResourceView("crm:customer", "客户", List.of("SELF"), "ENABLED")))
                .thenReturn(
                        List.of(new ProjectDataResourceView("crm:customer", "客户", List.of("ALL", "SELF"), "ENABLED")));
        String hash = service.plan(PROJECT, request(YAML, null), actor()).planHash();

        assertThatThrownBy(() -> service.apply(PROJECT, request(YAML, hash), actor(), METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.CONFLICT));
        verify(dataScopes, never()).saveResource(any(), any(), any(), any());
    }

    // ---- 角色数据范围（随授权组） ----

    private static final String ROLE_YAML =
            """
            - roleCode: sales-manager
              name: 销售经理
              dataScopes:
                - { resource: 'crm:customer', scope: DEPT_AND_CHILD }
                - { resource: 'crm:contract', scope: CUSTOM_DEPT, depts: [SALES-EAST, SALES-NORTH], includeChild: true }
            """;

    /** 同时带资源声明与角色清单的同步请求。 */
    private static ProjectManifestRequest roleRequest(String hash, boolean applyAccess) {
        return new ProjectManifestRequest(
                Map.of("data-scopes.yml", ROLE_RESOURCES, "roles.yml", ROLE_YAML),
                "abc1234",
                hash,
                applyAccess,
                List.of(),
                null,
                null,
                null,
                null);
    }

    private static final String ROLE_RESOURCES =
            """
            resources:
              - { code: 'crm:customer', name: 客户, table: crm_customer, allowedScopes: [DEPT_AND_CHILD, SELF] }
              - { code: 'crm:contract', name: 合同, table: crm_contract, allowedScopes: [CUSTOM_DEPT, SELF] }
            """;

    /** 目标环境里已存在的自定义角色。 */
    private static ProjectRoleView existingRole() {
        return new ProjectRoleView(
                "r-1",
                PROJECT,
                "sales-manager",
                "销售经理",
                null,
                "ACTIVE",
                false,
                Set.of(),
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 目标环境里角色在某资源上已显式配置的范围。 */
    private static ProjectRoleDataScopeView.Item held(
            String resource, String scope, boolean includeChild, List<String> deptIds) {
        return new ProjectRoleDataScopeView.Item(
                resource, resource, List.of("SELF"), scope, true, includeChild, deptIds);
    }

    /** 让目标环境具备清单引用的两个部门编码。 */
    private void departmentsExist() {
        when(dataScopes.departmentIdsByCode(any())).thenReturn(Map.of("SALES-EAST", "9001", "SALES-NORTH", "9002"));
    }

    /** 计划里角色数据范围变化的「键:动作:类别」摘要。 */
    private static List<String> roleScopeSummary(ProjectManifestPlanView plan) {
        return plan.changes().stream()
                .filter(change -> "ROLE_DATA_SCOPE".equals(change.resource()))
                .map(change -> change.key() + ":" + change.action() + ":" + change.category())
                .toList();
    }

    /** 新角色的数据范围归入授权类别，执行时晚于角色创建，且部门编码已换成目标环境的部门 ID。 */
    @Test
    void aNewRolesDataScopesArePlannedAsAccessAndAppliedAfterTheRoleIsCreated() {
        departmentsExist();
        ProjectManifestPlanView plan = service.plan(PROJECT, roleRequest(null, true), actor());

        assertThat(roleScopeSummary(plan))
                .containsExactly(
                        "sales-manager/crm:customer:CREATE:ACCESS", "sales-manager/crm:contract:CREATE:ACCESS");

        ProjectRoleView created = existingRole();
        when(projectService.roles(PROJECT)).thenReturn(List.of(), List.of(created));
        when(dataScopes.roleScopes(PROJECT, "r-1"))
                .thenReturn(new ProjectRoleDataScopeView("r-1", "sales-manager", false, List.of()));
        service.apply(PROJECT, roleRequest(plan.planHash(), true), actor(), METADATA);

        org.mockito.ArgumentCaptor<ProjectRoleDataScopeRequest> saved =
                org.mockito.ArgumentCaptor.forClass(ProjectRoleDataScopeRequest.class);
        verify(dataScopes).saveRoleScopes(eq(PROJECT), eq("r-1"), saved.capture(), any(), eq(METADATA));
        assertThat(saved.getValue().items())
                .extracting(item ->
                        item.resourceCode() + ":" + item.scope() + ":" + item.includeChild() + ":" + item.deptIds())
                .containsExactly("crm:customer:DEPT_AND_CHILD:false:[]", "crm:contract:CUSTOM_DEPT:true:[9001, 9002]");
    }

    /** 不勾选导入授权时，数据范围只列在计划里，不会写入。 */
    @Test
    void withoutImportingAccessNothingIsWrittenEvenThoughTheChangesAreListed() {
        departmentsExist();
        ProjectManifestPlanView plan = service.plan(PROJECT, roleRequest(null, false), actor());

        service.apply(PROJECT, roleRequest(plan.planHash(), false), actor(), METADATA);

        verify(dataScopes, never()).saveRoleScopes(any(), any(), any(), any(), any());
    }

    /** 导入数据范围与角色授权同一道门禁，要求调用者具备项目内角色授权权限。 */
    @Test
    void importingAccessRequiresTheProjectRoleGrantPermission() {
        departmentsExist();
        ProjectManifestPlanView plan = service.plan(PROJECT, roleRequest(null, true), actor());
        when(projectService.roles(PROJECT)).thenReturn(List.of(), List.of(existingRole()));
        when(dataScopes.roleScopes(PROJECT, "r-1"))
                .thenReturn(new ProjectRoleDataScopeView("r-1", "sales-manager", false, List.of()));

        service.apply(PROJECT, roleRequest(plan.planHash(), true), actor(), METADATA);

        verify(guard)
                .require(eq(PROJECT), any(), eq(com.kaiwu.module.project.model.ProjectAccessPermissions.ROLE_GRANT));
    }

    /** 已有角色只报告确有差异的资源，目标环境多出的配置只报漂移、不撤销。 */
    @Test
    void anExistingRoleOnlyReportsWhatActuallyDiffersAndKeepsTargetOnlyConfigurationAsDrift() {
        departmentsExist();
        when(projectService.roles(PROJECT)).thenReturn(List.of(existingRole()));
        when(dataScopes.roleScopes(PROJECT, "r-1"))
                .thenReturn(new ProjectRoleDataScopeView(
                        "r-1",
                        "sales-manager",
                        false,
                        List.of(
                                held("crm:customer", "DEPT_AND_CHILD", false, List.of()),
                                held("crm:contract", "CUSTOM_DEPT", true, List.of("9001")),
                                held("crm:followup", "DEPT", false, List.of()))));

        ProjectManifestPlanView plan = service.plan(PROJECT, roleRequest(null, true), actor());

        assertThat(roleScopeSummary(plan))
                .as("customer 已一致，不出现；contract 的部门不同，更新；followup 只在目标环境有，仅报漂移")
                .containsExactly("sales-manager/crm:contract:UPDATE:ACCESS", "sales-manager/crm:followup:DRIFT:NORMAL");
    }

    /** 执行时只覆盖清单提到的资源，角色在其它资源上的配置原样保留。 */
    @Test
    void applyingKeepsTheConfigurationOfResourcesTheManifestDoesNotMention() {
        departmentsExist();
        ProjectRoleView role = existingRole();
        when(projectService.roles(PROJECT)).thenReturn(List.of(role));
        ProjectRoleDataScopeView current = new ProjectRoleDataScopeView(
                "r-1",
                "sales-manager",
                false,
                List.of(
                        held("crm:customer", "DEPT_AND_CHILD", false, List.of()),
                        held("crm:contract", "CUSTOM_DEPT", true, List.of("9001")),
                        held("crm:followup", "DEPT", false, List.of())));
        when(dataScopes.roleScopes(PROJECT, "r-1")).thenReturn(current);
        String hash = service.plan(PROJECT, roleRequest(null, true), actor()).planHash();

        service.apply(PROJECT, roleRequest(hash, true), actor(), METADATA);

        org.mockito.ArgumentCaptor<ProjectRoleDataScopeRequest> saved =
                org.mockito.ArgumentCaptor.forClass(ProjectRoleDataScopeRequest.class);
        verify(dataScopes).saveRoleScopes(eq(PROJECT), eq("r-1"), saved.capture(), any(), any());
        assertThat(saved.getValue().items())
                .extracting(ProjectRoleDataScopeRequest.Item::resourceCode)
                .containsExactlyInAnyOrder("crm:followup", "crm:customer", "crm:contract");
    }

    /** 引用了不存在的资源、部门或不允许的范围时，一次列出全部问题并整份拒绝。 */
    @Test
    void everyUnresolvableReferenceIsListedAndTheWholePlanIsRejected() {
        when(dataScopes.departmentIdsByCode(any())).thenReturn(Map.of("SALES-EAST", "9001"));
        String yaml =
                """
                - roleCode: sales-manager
                  name: 销售经理
                  dataScopes:
                    - { resource: 'crm:ghost', scope: SELF }
                    - { resource: 'crm:customer', scope: CUSTOM_DEPT, depts: [SALES-EAST, SALES-MARS] }
                """;
        ProjectManifestRequest request = new ProjectManifestRequest(
                Map.of("data-scopes.yml", ROLE_RESOURCES, "roles.yml", yaml), "abc1234", null);

        assertThatThrownBy(() -> service.plan(PROJECT, request, actor()))
                .isInstanceOfSatisfying(ApiException.class, error -> {
                    assertThat(error.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(error.getMessage())
                            .contains("crm:ghost")
                            .contains("SALES-MARS")
                            .contains("不允许范围 CUSTOM_DEPT");
                });
    }

    /** 角色可以引用同一个包里刚声明、平台上尚不存在的资源。 */
    @Test
    void aResourceDeclaredInTheSamePackageCanBeReferencedBeforeItExistsOnThePlatform() {
        departmentsExist();
        // 平台上还没有任何资源：ROLE_YAML 引用的资源来自同一个包的 data-scopes.yml。
        when(dataScopes.resources(PROJECT)).thenReturn(List.of());

        ProjectManifestPlanView plan = service.plan(PROJECT, roleRequest(null, true), actor());

        assertThat(summary(plan)).containsExactly("crm:customer:CREATE", "crm:contract:CREATE");
        assertThat(roleScopeSummary(plan)).hasSize(2);
    }

    /** 具备同步所需平台权限的调用者上下文。 */
    private static KaiwuContext actor() {
        return new KaiwuContext(
                "7",
                "session-1",
                null,
                null,
                ALL,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    /** 被同步的测试项目。 */
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
}
