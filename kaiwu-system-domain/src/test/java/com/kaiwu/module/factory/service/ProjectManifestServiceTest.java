package com.kaiwu.module.factory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.configuration.service.I18nService;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.factory.convert.ProjectManifestParser;
import com.kaiwu.module.factory.dto.ProjectManifestRequest;
import com.kaiwu.module.factory.entity.ProjectHandoverRow;
import com.kaiwu.module.factory.service.impl.ProjectHandoverRecorder;
import com.kaiwu.module.factory.service.impl.ProjectManifestServiceImpl;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import com.kaiwu.module.i18n.dto.I18nMessageSaveRequest;
import com.kaiwu.module.i18n.vo.I18nMessageView;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.operation.dto.request.SchedulerJobSaveRequest;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import com.kaiwu.module.project.dto.ProjectMenuRequest;
import com.kaiwu.module.project.dto.ProjectRoleCreateRequest;
import com.kaiwu.module.project.service.ProjectAccessGuard;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.ProjectGenerationProjectPort;
import com.kaiwu.starter.KaiwuContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.json.JsonMapper;

/**
 * 平台资源清单同步的计划与执行语义（ADR 0036）。
 */
class ProjectManifestServiceTest {

    private static final String PROJECT = "100";
    private static final Set<String> ALL = Set.of("system:dict:save", "system:config:save", "system:project:menu");
    private static final RequestMetadata METADATA = new RequestMetadata("10.0.0.8", "trace-1");

    private MetadataService metadata;
    private I18nService i18n;
    private ProjectService projectService;
    private AuditPort audit;
    private ProjectAccessGuard guard;
    private ProjectHandoverRecorder recorder;
    private ProjectSchedulerService scheduler;
    private ProjectManifestService service;

    /** 平台初始为空，项目管理员校验直接通过。 */
    @BeforeEach
    void setUp() {
        metadata = mock(MetadataService.class);
        i18n = mock(I18nService.class);
        projectService = mock(ProjectService.class);
        audit = mock(AuditPort.class);
        guard = mock(ProjectAccessGuard.class);
        recorder = mock(ProjectHandoverRecorder.class);
        scheduler = mock(ProjectSchedulerService.class);
        ProjectGenerationProjectPort projects = mock(ProjectGenerationProjectPort.class);
        when(projects.requireProjectAdmin(eq(PROJECT), anyString())).thenReturn(project());
        when(projectService.menus(PROJECT)).thenReturn(List.of());
        service = new ProjectManifestServiceImpl(
                new ProjectManifestParser(),
                projects,
                projectService,
                metadata,
                i18n,
                audit,
                JsonMapper.builder().build(),
                guard,
                recorder,
                scheduler,
                mock(com.kaiwu.module.project.service.ProjectDataScopeService.class));
    }

    /** 清单里有、平台上没有的条目列为新增；平台多出的配置只报漂移。 */
    @Test
    void planListsCreatesAndDriftWithoutWriting() {
        when(metadata.configs(PROJECT)).thenReturn(List.of(config("legacy.flag", "true", "BOOLEAN", "旧开关")));

        ProjectManifestPlanView plan = service.plan(PROJECT, request(null), actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.resource() + ":" + change.key() + ":" + change.action())
                .contains(
                        "DICT:order.order_status:CREATE",
                        "DICT_ITEM:order.order_status:PAID:CREATE",
                        "I18N:dictType.order.order_status:CREATE",
                        "CONFIG:order.max_items:CREATE",
                        "CONFIG:legacy.flag:DRIFT");
        assertThat(plan.missingPermissions()).isEmpty();
        verify(metadata, never()).saveConfig(any(), any(), any(), any());
        verify(i18n, never()).createProjectMessage(any(), any(), any(), any());
    }

    /** 已存在的配置只更新类型与说明，当前值保持平台运营设置的值。 */
    @Test
    void applyKeepsOperatorOwnedConfigValue() {
        when(metadata.configs(PROJECT)).thenReturn(List.of(config("order.max_items", "80", "STRING", "旧说明")));
        when(metadata.dictTypes(PROJECT)).thenReturn(List.of());
        when(metadata.saveDictType(eq(PROJECT), any(), any(), any())).thenReturn(dictType("type-1"));
        String hash = service.plan(PROJECT, request(null), actor(ALL)).planHash();

        service.apply(PROJECT, request(hash), actor(ALL), METADATA);

        ArgumentCaptor<ConfigSaveRequest> saved = ArgumentCaptor.forClass(ConfigSaveRequest.class);
        verify(metadata).saveConfig(eq(PROJECT), saved.capture(), any(), eq(METADATA));
        assertThat(saved.getValue().configValue()).isEqualTo("80");
        assertThat(saved.getValue().valueType()).isEqualTo("NUMBER");
        verify(audit).recordOperation(any(), eq("SYNC_PROJECT_MANIFEST"), anyString(), anyString(), eq(METADATA));
    }

    /** 计划之后平台被改动，哈希对不上，整体拒绝执行。 */
    @Test
    void applyRejectsStalePlan() {
        assertThatThrownBy(() -> service.apply(PROJECT, request("stale"), actor(ALL), METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.CONFLICT));
        verify(metadata, never()).saveDictType(any(), any(), any(), any());
    }

    /** 计划之后平台上被清单涉及的条目改了（哪怕变化说明的文字没变），执行也要拒绝。 */
    @Test
    void applyRejectsPlanWhenTouchedPlatformEntryChangedAfterwards() {
        when(metadata.configs(PROJECT))
                .thenReturn(List.of(config("order.max_items", "80", "STRING", "旧说明")))
                .thenReturn(List.of(config("order.max_items", "80", "JSON", "旧说明")));
        String hash = service.plan(PROJECT, request(null), actor(ALL)).planHash();

        assertThatThrownBy(() -> service.apply(PROJECT, request(hash), actor(ALL), METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.CONFLICT));
        verify(metadata, never()).saveConfig(any(), any(), any(), any());
    }

    /** 运营只改了配置的当前值，不影响计划，执行照常并保留新值。 */
    @Test
    void operatorValueChangeDoesNotInvalidatePlan() {
        when(metadata.configs(PROJECT))
                .thenReturn(List.of(config("order.max_items", "80", "STRING", "旧说明")))
                .thenReturn(List.of(config("order.max_items", "90", "STRING", "旧说明")));
        when(metadata.saveDictType(eq(PROJECT), any(), any(), any())).thenReturn(dictType("type-1"));
        String hash = service.plan(PROJECT, request(null), actor(ALL)).planHash();

        service.apply(PROJECT, request(hash), actor(ALL), METADATA);

        ArgumentCaptor<ConfigSaveRequest> saved = ArgumentCaptor.forClass(ConfigSaveRequest.class);
        verify(metadata).saveConfig(eq(PROJECT), saved.capture(), any(), eq(METADATA));
        assertThat(saved.getValue().configValue()).isEqualTo("90");
    }

    /** 权限不全时计划照常给出并列出缺失项，执行整体拒绝，不做部分同步。 */
    @Test
    void missingPermissionIsReportedAndBlocksApply() {
        Set<String> partial = Set.of("system:dict:save");
        ProjectManifestPlanView plan = service.plan(PROJECT, request(null), actor(partial));

        assertThat(plan.missingPermissions()).contains("system:config:save", "system:project:menu");
        assertThatThrownBy(() -> service.apply(PROJECT, request(plan.planHash()), actor(partial), METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.FORBIDDEN));
    }

    /** 新建菜单交给平台服务完成，平台会自动授予内置项目管理员；同步本身不改任何角色授权。 */
    @Test
    void applyCreatesMenusWithoutTouchingRoleGrants() {
        when(projectService.createMenu(eq(PROJECT), any(), any(), any()))
                .thenReturn(menu("new-menu"))
                .thenReturn(menu("new-button"));
        ProjectManifestRequest menus = new ProjectManifestRequest(
                Map.of(
                        "menus.yml",
                        """
                        - type: MENU
                          name: 订单管理
                          path: /order
                          children:
                            - { type: BUTTON, permission: "order:order:list" }
                        """),
                null,
                null);
        String hash = service.plan(PROJECT, menus, actor(ALL)).planHash();

        service.apply(PROJECT, new ProjectManifestRequest(menus.files(), null, hash), actor(ALL), METADATA);

        ArgumentCaptor<ProjectMenuRequest> created = ArgumentCaptor.forClass(ProjectMenuRequest.class);
        verify(projectService, org.mockito.Mockito.times(2)).createMenu(eq(PROJECT), created.capture(), any(), any());
        assertThat(created.getAllValues().get(1).parentId()).isEqualTo("new-menu");
        verify(projectService, never()).grantRoleMenus(any(), any(), any(), any(), any());
    }

    /** 显式 i18nKey 带译文：沿用该 key 创建资源，不再按规则生成。 */
    @Test
    void planUsesExplicitI18nKeyForNewResource() {
        ProjectManifestRequest explicit = new ProjectManifestRequest(
                Map.of(
                        "dicts.yml",
                        """
                        - dictCode: order.order_status
                          name: { i18nKey: custom.order.status, zh-CN: 订单状态, en-US: Order status }
                          items:
                            - { value: PAID, label: 已支付 }
                        """),
                null,
                null);

        ProjectManifestPlanView plan = service.plan(PROJECT, explicit, actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.resource() + ":" + change.key() + ":" + change.action())
                .contains("I18N:custom.order.status:CREATE")
                .doesNotContain("I18N:dictType.order.order_status:CREATE");
    }

    /** 只带 key 不带译文：引用的资源不存在时拒绝，存在时不产生资源变更。 */
    @Test
    void keyOnlyTextMustReferToExistingResource() {
        ProjectManifestRequest keyOnly = new ProjectManifestRequest(
                Map.of(
                        "dicts.yml",
                        """
                        - dictCode: order.order_status
                          name: { i18nKey: common.status, zh-CN: 订单状态 }
                          items:
                            - { value: PAID, label: 已支付 }
                        """),
                null,
                null);

        assertThatThrownBy(() -> service.plan(PROJECT, keyOnly, actor(ALL)))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.BAD_REQUEST));

        when(i18n.messageKeyExists(PROJECT, "common.status")).thenReturn(true);
        ProjectManifestPlanView plan = service.plan(PROJECT, keyOnly, actor(ALL));
        assertThat(plan.changes()).noneMatch(change -> "I18N".equals(change.resource()));
    }

    /** 角色及授权归入「授权」类：未勾选时不执行，勾选后才创建角色并追加授权。 */
    @Test
    void rolesAreAccessCategoryAndOnlyAppliedWhenSelected() {
        when(projectService.menus(PROJECT)).thenReturn(List.of(button("b1", "order:order:list")));
        when(projectService.roles(PROJECT))
                .thenReturn(List.of(), List.of(), List.of(), List.of(), List.of(role("r1", "finance", Set.of())));
        ProjectManifestRequest roles = rolesRequest(
                """
                - { roleCode: finance, name: 财务, permissions: ["order:order:list"] }
                """,
                null,
                false);

        ProjectManifestPlanView plan = service.plan(PROJECT, roles, actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.resource() + ":" + change.key() + ":" + change.category())
                .contains("ROLE:finance:ACCESS", "ROLE_GRANT:finance/perm:order:order:list:ACCESS");
        service.apply(
                PROJECT, rolesRequest(roles.files().get("roles.yml"), plan.planHash(), false), actor(ALL), METADATA);
        verify(projectService, never()).createRole(any(), any(), any(), any());

        ProjectManifestPlanView second = service.plan(PROJECT, roles, actor(ALL));
        service.apply(
                PROJECT, rolesRequest(roles.files().get("roles.yml"), second.planHash(), true), actor(ALL), METADATA);
        ArgumentCaptor<ProjectRoleCreateRequest> created = ArgumentCaptor.forClass(ProjectRoleCreateRequest.class);
        verify(projectService).createRole(eq(PROJECT), created.capture(), any(), any());
        assertThat(created.getValue().roleCode()).isEqualTo("finance");
        ArgumentCaptor<Set<String>> menuIds = ArgumentCaptor.forClass(Set.class);
        verify(projectService).grantRoleMenus(eq(PROJECT), eq("r1"), menuIds.capture(), any(), any());
        assertThat(menuIds.getValue()).containsExactly("b1");
        verify(guard, org.mockito.Mockito.atLeastOnce()).require(eq(PROJECT), any(), eq("access:role:grant"));
    }

    /** 授权引用了目标项目没有、清单也不会创建的菜单：整体拒绝，不给出半份计划。 */
    @Test
    void roleGrantToUnknownMenuIsRejected() {
        ProjectManifestRequest roles = rolesRequest(
                """
                - { roleCode: finance, name: 财务, permissions: ["no:such:code"] }
                """,
                null,
                false);

        assertThatThrownBy(() -> service.plan(PROJECT, roles, actor(ALL)))
                .isInstanceOfSatisfying(ApiException.class, error -> {
                    assertThat(error.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(error.getMessage()).contains("no:such:code");
                });
    }

    /** 目标已有角色只追加授权，目标多出的授权只报告漂移，不撤销。 */
    @Test
    void existingRoleOnlyGetsAdditiveGrants() {
        when(projectService.menus(PROJECT))
                .thenReturn(List.of(button("b1", "order:order:list"), button("b2", "order:order:edit")));
        when(projectService.roles(PROJECT)).thenReturn(List.of(role("r1", "finance", Set.of("b2"))));
        ProjectManifestRequest roles = rolesRequest(
                """
                - { roleCode: finance, name: 财务, permissions: ["order:order:list"] }
                """,
                null,
                false);

        ProjectManifestPlanView plan = service.plan(PROJECT, roles, actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.resource() + ":" + change.key() + ":" + change.action())
                .contains(
                        "ROLE_GRANT:finance/perm:order:order:list:CREATE",
                        "ROLE_GRANT:finance/perm:order:order:edit:DRIFT")
                .doesNotContain("ROLE:finance:CREATE");
    }

    /** 上次移交过而本次包里没有的条目是「源环境已删除」；目标自己加的只是漂移。 */
    @Test
    void baselineSeparatesRemovedAtSourceFromTargetOnlyDrift() {
        when(recorder.baselineKeys(PROJECT)).thenReturn(Optional.of(Set.of("DICT_ITEM|order.order_status:OLD")));
        stubDictWithItems("PAID", "OLD", "MINE");

        ProjectManifestPlanView plan = service.plan(PROJECT, plainDictRequest(null, List.of()), actor(ALL));

        assertThat(plan.hasBaseline()).isTrue();
        assertThat(plan.changes())
                .extracting(change -> change.key() + ":" + change.action() + ":" + change.category())
                .contains("order.order_status:OLD:REMOVED_AT_SOURCE:DELETE", "order.order_status:MINE:DRIFT:NORMAL");
    }

    /** 没有基线时，目标多出的条目一律只报告漂移，不给删除建议。 */
    @Test
    void withoutBaselineNothingIsOfferedForDeletion() {
        stubDictWithItems("PAID", "OLD");

        ProjectManifestPlanView plan = service.plan(PROJECT, plainDictRequest(null, List.of()), actor(ALL));

        assertThat(plan.hasBaseline()).isFalse();
        assertThat(plan.changes()).noneMatch(change -> "DELETE".equals(change.category()));
    }

    /** 只删除勾选的条目；没勾选的「源环境已删除」条目保持不动。 */
    @Test
    void applyDeletesOnlySelectedItems() {
        when(recorder.baselineKeys(PROJECT))
                .thenReturn(
                        Optional.of(Set.of("DICT_ITEM|order.order_status:OLD", "DICT_ITEM|order.order_status:OLD2")));
        stubDictWithItems("PAID", "OLD", "OLD2");
        String hash = service.plan(PROJECT, plainDictRequest(null, List.of()), actor(ALL))
                .planHash();
        Set<String> withDelete =
                Set.of("system:dict:save", "system:config:save", "system:project:menu", "system:dict:delete");

        service.apply(
                PROJECT,
                plainDictRequest(hash, List.of("DICT_ITEM|order.order_status:OLD")),
                actor(withDelete),
                METADATA);

        verify(metadata, times(1)).deleteDictItem(eq(PROJECT), eq("type-1"), eq("i-OLD"), any(), any());
        verify(metadata, never()).deleteDictItem(eq(PROJECT), eq("type-1"), eq("i-OLD2"), any(), any());
    }

    /** 勾选了计划里没有的删除项：拒绝，且不执行任何写入。 */
    @Test
    void applyRejectsDeleteKeysOutsideThePlan() {
        stubDictWithItems("PAID", "MINE");
        String hash = service.plan(PROJECT, plainDictRequest(null, List.of()), actor(ALL))
                .planHash();

        assertThatThrownBy(() -> service.apply(
                        PROJECT,
                        plainDictRequest(hash, List.of("DICT_ITEM|order.order_status:MINE")),
                        actor(ALL),
                        METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.BAD_REQUEST));
        verify(metadata, never()).deleteDictItem(any(), any(), any(), any(), any());
    }

    /** 删除需要平台删除权限，缺少时整体拒绝。 */
    @Test
    void deleteRequiresDeletePermission() {
        when(recorder.baselineKeys(PROJECT)).thenReturn(Optional.of(Set.of("DICT_ITEM|order.order_status:OLD")));
        stubDictWithItems("PAID", "OLD");
        String hash = service.plan(PROJECT, plainDictRequest(null, List.of()), actor(ALL))
                .planHash();

        assertThatThrownBy(() -> service.apply(
                        PROJECT,
                        plainDictRequest(hash, List.of("DICT_ITEM|order.order_status:OLD")),
                        actor(ALL),
                        METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> {
                    assertThat(error.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(error.getMessage()).contains("system:dict:delete");
                });
    }

    /** 成功执行写移交记录，带上移交包来源与实际条数；失败时回滚并另记失败记录。 */
    @Test
    void applyRecordsSuccessAndFailure() {
        when(metadata.saveDictType(eq(PROJECT), any(), any(), any())).thenReturn(dictType("type-1"));
        String hash = service.plan(PROJECT, request(null), actor(ALL)).planHash();
        ProjectManifestRequest withMeta = new ProjectManifestRequest(
                request(null).files(),
                "abc1234",
                hash,
                false,
                List.of(),
                "digest-1",
                "test.example.com",
                "7",
                "2026-10-30T00:00:00Z");

        service.apply(PROJECT, withMeta, actor(ALL), METADATA);

        ArgumentCaptor<ProjectHandoverRow> success = ArgumentCaptor.forClass(ProjectHandoverRow.class);
        verify(recorder).recordSuccess(success.capture(), any(), any());
        assertThat(success.getValue().packageDigest()).isEqualTo("digest-1");
        assertThat(success.getValue().sourceHost()).isEqualTo("test.example.com");
        assertThat(success.getValue().status()).isEqualTo("SUCCESS");

        when(metadata.saveConfig(eq(PROJECT), any(), any(), any())).thenThrow(new IllegalStateException("db down"));
        String hash2 = service.plan(PROJECT, request(null), actor(ALL)).planHash();
        assertThatThrownBy(() -> service.apply(PROJECT, request(hash2), actor(ALL), METADATA))
                .isInstanceOf(IllegalStateException.class);
        ArgumentCaptor<ProjectHandoverRow> failure = ArgumentCaptor.forClass(ProjectHandoverRow.class);
        verify(recorder).recordFailure(failure.capture(), any());
        assertThat(failure.getValue().status()).isEqualTo("FAILED");
    }

    /** 同一移交包摘要已导入过时，计划里带上上次记录。 */
    @Test
    void planReportsPackageAlreadyApplied() {
        ProjectHandoverRow previous = new ProjectHandoverRow(
                "h1",
                PROJECT,
                "SUCCESS",
                "digest-1",
                null,
                null,
                null,
                "p",
                null,
                false,
                3,
                0,
                null,
                "7",
                LocalDateTime.now());
        when(recorder.findAppliedByDigest(PROJECT, "digest-1")).thenReturn(Optional.of(previous));
        ProjectManifestRequest withDigest = new ProjectManifestRequest(
                request(null).files(), null, null, false, List.of(), "digest-1", null, null, null);

        ProjectManifestPlanView plan = service.plan(PROJECT, withDigest, actor(ALL));

        assertThat(plan.alreadyApplied()).isNotNull();
        assertThat(plan.alreadyApplied().handoverId()).isEqualTo("h1");
    }

    /** 建项目时种入的成员管理菜单不参与比对：即使清单没有也不算漂移。 */
    @Test
    void seededAccessMenusAreNotReportedAsDrift() {
        ProjectMenuView seeded = new ProjectMenuView(
                "s1",
                PROJECT,
                null,
                "成员管理",
                null,
                "MENU",
                "/project-members",
                "ProjectMembers",
                null,
                null,
                900,
                true,
                "ENABLED",
                LocalDateTime.now(),
                LocalDateTime.now(),
                List.of());
        when(projectService.menus(PROJECT)).thenReturn(List.of(seeded));
        ProjectManifestRequest menus =
                new ProjectManifestRequest(Map.of("menus.yml", "- { type: MENU, name: 订单, path: /order }"), null, null);

        ProjectManifestPlanView plan = service.plan(PROJECT, menus, actor(ALL));

        assertThat(plan.changes()).noneMatch(change -> "DRIFT".equals(change.action()));
    }

    /** 国际化资源：目标没有的新增，文案不同的按移交包更新，相同的不动。 */
    @Test
    void messagesAreCreatedUpdatedAndLeftAlone() {
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(
                        message("m1", "order.same", "相同", "{\"en-US\":\"Same\"}"),
                        message("m2", "order.diff", "旧文案", "{\"en-US\":\"Old\"}")));
        ProjectManifestRequest request = new ProjectManifestRequest(
                Map.of(
                        "i18n.yml",
                        """
                        - { messageKey: order.same, zh-CN: 相同, en-US: Same }
                        - { messageKey: order.diff, zh-CN: 新文案, en-US: New }
                        - { messageKey: order.fresh, zh-CN: 新增 }
                        """),
                null,
                null);

        ProjectManifestPlanView plan = service.plan(PROJECT, request, actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.resource() + ":" + change.key() + ":" + change.action())
                .containsExactlyInAnyOrder("I18N:order.diff:UPDATE", "I18N:order.fresh:CREATE");
    }

    /** 执行国际化更新：沿用已有资源的 ID、版本与模块，不改可见性。 */
    @Test
    void applyUpdatesMessageWithExistingVersion() {
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(message("m2", "order.diff", "旧文案", "{\"en-US\":\"Old\"}")));
        ProjectManifestRequest request = new ProjectManifestRequest(
                Map.of("i18n.yml", "- { messageKey: order.diff, zh-CN: 新文案, en-US: New }"), null, null);
        String hash = service.plan(PROJECT, request, actor(ALL)).planHash();

        service.apply(PROJECT, new ProjectManifestRequest(request.files(), null, hash), actor(ALL), METADATA);

        ArgumentCaptor<I18nMessageSaveRequest> saved = ArgumentCaptor.forClass(I18nMessageSaveRequest.class);
        verify(i18n).saveProjectMessage(eq(PROJECT), saved.capture(), any(), any());
        assertThat(saved.getValue().id()).isEqualTo("m2");
        assertThat(saved.getValue().defaultText()).isEqualTo("新文案");
        assertThat(saved.getValue().version()).isEqualTo(3L);
        assertThat(saved.getValue().translationsJson()).contains("New");
    }

    /** 被字典引用的 key 不算「目标多出」；源环境已删除的资源才给出可删除项。 */
    @Test
    void messageDriftHonoursReferencesAndBaseline() {
        when(recorder.baselineKeys(PROJECT)).thenReturn(Optional.of(Set.of("I18N|order.gone")));
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(
                        message("m1", "order.keep", "保留", "{}"),
                        message("m2", "order.gone", "已删", "{}"),
                        message("m3", "order.mine", "自加", "{}")));
        ProjectManifestRequest request =
                new ProjectManifestRequest(Map.of("i18n.yml", "- { messageKey: order.keep, zh-CN: 保留 }"), null, null);

        ProjectManifestPlanView plan = service.plan(PROJECT, request, actor(ALL));

        assertThat(plan.changes())
                .extracting(change -> change.key() + ":" + change.action() + ":" + change.category())
                .contains("order.gone:REMOVED_AT_SOURCE:DELETE", "order.mine:DRIFT:NORMAL")
                .noneMatch(entry -> entry.startsWith("order.keep:"));
    }

    /** 勾选后才删除国际化资源，带上资源版本。 */
    @Test
    void applyDeletesSelectedMessage() {
        when(recorder.baselineKeys(PROJECT)).thenReturn(Optional.of(Set.of("I18N|order.gone")));
        when(i18n.projectMessages(PROJECT))
                .thenReturn(List.of(message("m1", "order.keep", "保留", "{}"), message("m2", "order.gone", "已删", "{}")));
        ProjectManifestRequest request =
                new ProjectManifestRequest(Map.of("i18n.yml", "- { messageKey: order.keep, zh-CN: 保留 }"), null, null);
        String hash = service.plan(PROJECT, request, actor(ALL)).planHash();

        service.apply(
                PROJECT,
                new ProjectManifestRequest(
                        request.files(), null, hash, false, List.of("I18N|order.gone"), null, null, null, null),
                actor(ALL),
                METADATA);

        verify(i18n).deleteProjectMessage(eq(PROJECT), eq("m2"), eq(3L), any(), any());
    }

    /** 新建定时任务一律停用，要求目标项目有在线 Handler。 */
    @Test
    void newJobIsCreatedDisabledAndNeedsAnActiveHandler() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(1, 100, 0, List.of()));
        ProjectManifestRequest request = jobsRequest(
                "- { jobName: 日结, taskType: daily.settle, cron: '0 0 2 * * *', zoneId: Asia/Shanghai, enabled: true }",
                null);

        assertThatThrownBy(() -> service.plan(PROJECT, request, actor(jobAll())))
                .isInstanceOfSatisfying(ApiException.class, error -> {
                    assertThat(error.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(error.getMessage()).contains("daily.settle");
                });

        when(scheduler.handlerActive(PROJECT, "daily.settle")).thenReturn(true);
        String hash = service.plan(PROJECT, request, actor(jobAll())).planHash();
        service.apply(PROJECT, jobsRequest(request.files().get("jobs.yml"), hash), actor(jobAll()), METADATA);

        ArgumentCaptor<SchedulerJobSaveRequest> saved = ArgumentCaptor.forClass(SchedulerJobSaveRequest.class);
        verify(scheduler).saveJob(eq(null), saved.capture(), any(), any());
        assertThat(saved.getValue().enabled()).isFalse();
        assertThat(saved.getValue().payload()).isEqualTo("{}");
    }

    /** 已有任务只更新 cron 等配置，保留启用状态；没变化的不列出。 */
    @Test
    void existingJobKeepsEnabledStateAndSkipsUnchanged() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(
                        1,
                        100,
                        2,
                        List.of(
                                job("j1", "日结", "daily.settle", "0 0 1 * * *", true),
                                job("j2", "周报", "weekly.report", "0 0 3 * * 1", true))));
        ProjectManifestRequest request = jobsRequest(
                """
                - { jobName: 日结, taskType: daily.settle, cron: '0 0 2 * * *', zoneId: Asia/Shanghai }
                - { jobName: 周报, taskType: weekly.report, cron: '0 0 3 * * 1', zoneId: Asia/Shanghai }
                """,
                null);

        ProjectManifestPlanView plan = service.plan(PROJECT, request, actor(jobAll()));
        service.apply(
                PROJECT, jobsRequest(request.files().get("jobs.yml"), plan.planHash()), actor(jobAll()), METADATA);

        assertThat(plan.changes())
                .extracting(change -> change.key() + ":" + change.action())
                .containsExactly("日结:UPDATE");
        ArgumentCaptor<SchedulerJobSaveRequest> saved = ArgumentCaptor.forClass(SchedulerJobSaveRequest.class);
        verify(scheduler).saveJob(eq("j1"), saved.capture(), any(), any());
        assertThat(saved.getValue().enabled()).isTrue();
        assertThat(saved.getValue().cronExpression()).isEqualTo("0 0 2 * * *");
    }

    /** 目标有多个同名任务时业务键有歧义，整体拒绝。 */
    @Test
    void duplicateTargetJobNamesAreRejected() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(
                        1,
                        100,
                        2,
                        List.of(
                                job("j1", "日结", "daily.settle", "0 0 1 * * *", false),
                                job("j2", "日结", "daily.settle", "0 0 1 * * *", false))));
        ProjectManifestRequest request = jobsRequest(
                "- { jobName: 日结, taskType: daily.settle, cron: '0 0 1 * * *', zoneId: Asia/Shanghai }", null);

        assertThatThrownBy(() -> service.plan(PROJECT, request, actor(jobAll())))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getMessage())
                        .contains("同名"));
    }

    /** 源环境已删除的定时任务勾选后逻辑删除；需要定时任务保存权限。 */
    @Test
    void removedJobIsDeletedOnlyWhenSelected() {
        when(recorder.baselineKeys(PROJECT)).thenReturn(Optional.of(Set.of("JOB|旧任务")));
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(
                        1,
                        100,
                        2,
                        List.of(
                                job("j1", "日结", "daily.settle", "0 0 1 * * *", false),
                                job("j9", "旧任务", "old.task", "0 0 1 * * *", false))));
        ProjectManifestRequest request = jobsRequest(
                "- { jobName: 日结, taskType: daily.settle, cron: '0 0 1 * * *', zoneId: Asia/Shanghai }", null);
        String hash = service.plan(PROJECT, request, actor(jobAll())).planHash();

        service.apply(
                PROJECT,
                new ProjectManifestRequest(
                        request.files(), null, hash, false, List.of("JOB|旧任务"), null, null, null, null),
                actor(jobAll()),
                METADATA);

        verify(scheduler).deleteJob(eq("j9"), any(), any());
    }

    /** 清单带定时任务时，缺少定时任务保存权限会在计划里报告。 */
    @Test
    void jobsRequireSchedulerPermission() {
        when(scheduler.jobs(eq(PROJECT), anyLong(), anyLong(), any()))
                .thenReturn(new PageResult<>(1, 100, 0, List.of()));
        when(scheduler.handlerActive(PROJECT, "daily.settle")).thenReturn(true);
        ProjectManifestRequest request = jobsRequest(
                "- { jobName: 日结, taskType: daily.settle, cron: '0 0 2 * * *', zoneId: Asia/Shanghai }", null);

        ProjectManifestPlanView plan = service.plan(PROJECT, request, actor(ALL));

        assertThat(plan.missingPermissions()).contains("system:scheduler:save");
    }

    /** 测试用清单：一个带多语言名称的字典与一个配置。 */
    private static ProjectManifestRequest request(String hash) {
        return new ProjectManifestRequest(
                Map.of(
                        "dicts.yml",
                        """
                        - dictCode: order.order_status
                          name: { zh-CN: 订单状态, en-US: Order status }
                          items:
                            - { value: PAID, label: 已支付 }
                        """,
                        "configs.yml",
                        "- { key: order.max_items, type: NUMBER, default: 50, description: 单笔上限 }"),
                "abc1234",
                hash);
    }

    /** 构造带指定权限的调用者。 */
    private static KaiwuContext actor(Set<String> permissions) {
        return new KaiwuContext(
                "7",
                "session-1",
                null,
                null,
                permissions,
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "context-1");
    }

    /** 测试项目。 */
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

    /** 本项目范围的配置。 */
    private static ConfigView config(String key, String value, String type, String description) {
        return new ConfigView(
                "cfg-" + key,
                PROJECT,
                key,
                value,
                null,
                type,
                false,
                "ENABLED",
                description,
                0,
                LocalDateTime.now(),
                LocalDateTime.now());
    }

    /** 新建字典类型的返回值。 */
    private static DictTypeView dictType(String id) {
        return new DictTypeView(
                id, PROJECT, "order.order_status", "订单状态", null, false, 0, "ENABLED", null, LocalDateTime.now());
    }

    /** 新建菜单的返回值。 */
    private static ProjectMenuView menu(String id) {
        return new ProjectMenuView(
                id,
                PROJECT,
                null,
                "x",
                null,
                "MENU",
                null,
                null,
                null,
                null,
                0,
                true,
                "ENABLED",
                LocalDateTime.now(),
                LocalDateTime.now(),
                List.of());
    }

    /** 平台上已有 PAID 等字典项的订单状态字典，名称不带国际化引用。 */
    private void stubDictWithItems(String... values) {
        when(metadata.dictTypes(PROJECT)).thenReturn(List.of(dictType("type-1")));
        List<DictItemView> items = new java.util.ArrayList<>();
        for (String value : values) {
            items.add(new DictItemView("i-" + value, "已支付", value, 10, false, null, null, null, "ENABLED"));
        }
        when(metadata.dictItems(PROJECT, "type-1")).thenReturn(items);
    }

    /** 只含 PAID 一项的纯文本字典清单。 */
    private static ProjectManifestRequest plainDictRequest(String hash, List<String> deleteKeys) {
        return new ProjectManifestRequest(
                Map.of(
                        "dicts.yml",
                        """
                        - dictCode: order.order_status
                          name: 订单状态
                          items:
                            - { value: PAID, label: 已支付, sort: 10 }
                        """),
                null,
                hash,
                false,
                deleteKeys,
                null,
                null,
                null,
                null);
    }

    /** 只含角色清单的请求。 */
    private static ProjectManifestRequest rolesRequest(String yaml, String hash, boolean applyAccess) {
        return new ProjectManifestRequest(
                Map.of("roles.yml", yaml), null, hash, applyAccess, List.of(), null, null, null, null);
    }

    /** 带权限码的按钮节点。 */
    private static ProjectMenuView button(String id, String permission) {
        return new ProjectMenuView(
                id,
                PROJECT,
                null,
                permission,
                null,
                "BUTTON",
                null,
                null,
                permission,
                null,
                10,
                true,
                "ENABLED",
                LocalDateTime.now(),
                LocalDateTime.now(),
                List.of());
    }

    /** 自定义角色。 */
    private static ProjectRoleView role(String id, String code, Set<String> menuIds) {
        return new ProjectRoleView(
                id, PROJECT, code, "财务", null, "ENABLED", false, menuIds, LocalDateTime.now(), LocalDateTime.now());
    }

    /** 含定时任务保存权限的权限集。 */
    private static Set<String> jobAll() {
        Set<String> all = new java.util.HashSet<>(ALL);
        all.add("system:scheduler:save");
        return all;
    }

    /** 只含 jobs.yml 的请求。 */
    private static ProjectManifestRequest jobsRequest(String yaml, String hash) {
        return new ProjectManifestRequest(Map.of("jobs.yml", yaml), null, hash);
    }

    /** 项目国际化资源，版本固定为 3。 */
    private static I18nMessageView message(String id, String key, String text, String translations) {
        return new I18nMessageView(
                id, key, text, translations, "project", false, false, "ENABLED", null, 3L, LocalDateTime.now());
    }

    /** 定时任务视图。 */
    private static SchedulerJobView job(String id, String name, String type, String cron, boolean enabled) {
        return new SchedulerJobView(
                id,
                PROJECT,
                "订单中心",
                name,
                type,
                cron,
                "Asia/Shanghai",
                "{}",
                enabled,
                1L,
                null,
                null,
                LocalDateTime.now(),
                LocalDateTime.now());
    }
}
