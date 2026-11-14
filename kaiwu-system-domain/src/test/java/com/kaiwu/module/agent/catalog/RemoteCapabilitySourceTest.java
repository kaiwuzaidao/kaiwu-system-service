package com.kaiwu.module.agent.catalog;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.entity.AgentCapabilityEntity;
import com.kaiwu.module.agent.execution.AccessReChecker;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.planning.AgentPlanValidator;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.presentation.ResultProjector;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityManifest;
import com.kaiwu.module.agent.protocol.CapabilityManifestValidator;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.repository.AgentRegistryRepository;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.port.ProjectAgentAccessPort;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;

class RemoteCapabilitySourceTest {
    final Clock clock = Clock.fixed(Instant.parse("2026-09-23T00:00:00Z"), ZoneOffset.UTC);
    final AgentManifestCodec codec = new AgentManifestCodec();
    final AgentRemoteProperties config = new AgentRemoteProperties();
    final AgentRegistryRepository registry = mock(AgentRegistryRepository.class);
    final AuthRepository auth = mock(AuthRepository.class);
    final ProjectAgentAccessPort projects = mock(ProjectAgentAccessPort.class);
    RemoteCapabilitySource source;
    AgentCapabilityEntity row;
    KaiwuContext actor;

    @BeforeEach
    void setup() {
        config.setEnabled(true);
        actor = new KaiwuContext(
                "user-1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask"),
                Set.of(),
                null,
                "kaiwu-system-service",
                clock.instant(),
                clock.instant().plusSeconds(60),
                "context-1");
        when(auth.findSession("session-1"))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        "session-1",
                        "user-1",
                        "hash",
                        "ONLINE",
                        "WEB",
                        clock.instant().plusSeconds(600))));
        when(auth.findUserById("user-1"))
                .thenReturn(Optional.of(new AuthRepository.UserAccount(
                        "user-1", "user", "hash", "User", "ENABLED", "zh-CN", false, false)));
        when(auth.findPermissions("user-1")).thenReturn(Set.of("system:agent:ask"));
        var manifest = com.kaiwu.testing.AgentTestFixtures.manifest("1");
        row = new AgentCapabilityEntity();
        row.setProjectId("123");
        row.setCapabilityCode(manifest.code());
        row.setVersion("1");
        row.setManifestJson(codec.canonical(manifest));
        row.setManifestHash(AgentManifestCodec.digest(row.getManifestJson()));
        row.setStatus("APPROVED");
        row.setLastSeenAt(LocalDateTime.now(clock));
        when(registry.visibleCandidates(eq("user-1"), any())).thenReturn(List.of(row));
        when(registry.byCode(manifest.code())).thenReturn(row);
        when(registry.permissions("123")).thenReturn(Set.of("record:record:list"));
        when(projects.resolve("crm", "user-1"))
                .thenReturn(Optional.of(
                        new ProjectAccessView("123", "crm", List.of("record:record:list"), List.of("reader"))));
        source = new RemoteCapabilitySource(
                config, registry, codec, new CapabilityManifestValidator(), projects, auth, clock);
    }

    @Test
    void formControlsUseReviewedCandidatesAndDictionaryWithoutChangingValues() throws Exception {
        CapabilityManifest manifest;
        try (var input = getClass().getResourceAsStream("/agent-registration-form-controls.json")) {
            manifest = codec.decode(input.readAllBytes());
        }
        row.setCapabilityCode(manifest.code());
        row.setVersion("2");
        row.setManifestJson(codec.canonical(manifest));
        row.setManifestHash(AgentManifestCodec.digest(row.getManifestJson()));
        var fields = source.visibleTo(actor).getFirst().inputForm().fields();
        assertThat(fields.getFirst().dictCode()).isEqualTo("common.status");
        assertThat(fields.getFirst().values()).containsExactly("ACTIVE", "DISABLED");
        assertThat(fields.get(1).type()).isEqualTo("DATETIME");
        row.setManifestJson(row.getManifestJson().replace("common.status", "common.other"));
        assertThat(source.visibleTo(actor)).isEmpty();
    }

    @Test
    void outputMetadataOnlyComesFromApprovedManifestAndDoesNotExpandProjection() throws Exception {
        CapabilityManifest manifest;
        try (var input = getClass().getResourceAsStream("/agent-registration-output-v3.json")) {
            manifest = codec.decode(input.readAllBytes());
        }
        row.setCapabilityCode(manifest.code());
        row.setVersion("3");
        row.setManifestJson(codec.canonical(manifest));
        row.setManifestHash(AgentManifestCodec.digest(row.getManifestJson()));
        var capability = source.visibleTo(actor).getFirst();
        assertThat(capability.outputView()).isEqualTo(manifest.outputView());
        var card = new ResultProjector()
                .toCard(
                        capability,
                        "Untrusted response title",
                        List.of(Map.of("id", "1789248125900000001", "title", "示例", "secret", "excluded")),
                        List.of("123"));
        assertThat(card.rows().getFirst()).doesNotContainKey("secret").containsEntry("id", "1789248125900000001");
        row.setManifestJson(row.getManifestJson().replace("编号", "未经审核"));
        assertThat(source.visibleTo(actor)).isEmpty();
        row.setManifestJson(codec.canonical(manifest));
        when(projects.resolve("crm", "user-1")).thenReturn(Optional.empty());
        assertThat(source.visibleTo(actor)).isEmpty();
    }

    @Test
    void reviewedOnlineCapabilityEntersCatalogUsingProjectPermissions() {
        var catalog = new CapabilityCatalog();
        catalog.remoteSource(source);
        var visible = catalog.visibleTo(actor);
        assertThat(visible).extracting(Capability::code).containsExactly(row.getCapabilityCode());
        assertThat(visible.getFirst().canSkipConfirmation()).isTrue();
        // actor 中没有任何项目权限；权限必须来自项目事实，而非平台管理员快照。
        assertThat(catalog.findVisible(row.getCapabilityCode(), actor)).isPresent();
        var checker = new AccessReChecker(mock(com.kaiwu.port.ProjectMembershipPort.class), auth, clock);
        checker.remoteSource(source);
        checker.check(visible.getFirst(), Map.of(), actor);
    }

    @Test
    void removesOfflinePendingRevokedAndMismatchedVersions() {
        for (String status : List.of("PENDING", "REVOKED")) {
            row.setStatus(status);
            assertThat(source.visibleTo(actor)).isEmpty();
        }
        row.setStatus("APPROVED");
        row.setLastSeenAt(LocalDateTime.now(clock).minusSeconds(180));
        assertThat(source.visibleTo(actor)).isEmpty();
        row.setLastSeenAt(LocalDateTime.now(clock));
        row.setVersion("2");
        assertThat(source.visibleTo(actor)).isEmpty();
    }

    @Test
    void membershipPermissionProjectAndHashChangesFailClosed() {
        when(projects.resolve("crm", "user-1")).thenReturn(Optional.empty());
        assertThat(source.visibleTo(actor)).isEmpty();
        when(projects.resolve("crm", "user-1"))
                .thenReturn(Optional.of(new ProjectAccessView("123", "crm", List.of(), List.of())));
        assertThat(source.visibleTo(actor)).isEmpty();
        when(projects.resolve("crm", "user-1"))
                .thenReturn(Optional.of(new ProjectAccessView("999", "crm", List.of("record:record:list"), List.of())));
        assertThat(source.visibleTo(actor)).isEmpty();
        row.setManifestHash("0".repeat(64));
        assertThat(source.visibleTo(actor)).isEmpty();
    }

    @Test
    void sessionRevocationPasswordResetAndAskPermissionChangeReject() {
        when(auth.findPermissions("user-1")).thenReturn(Set.of());
        assertThatThrownBy(() -> source.visibleTo(actor)).isInstanceOf(PlanRejectedException.class);
        when(auth.findPermissions("user-1")).thenReturn(Set.of("system:agent:ask"));
        when(auth.findUserById("user-1"))
                .thenReturn(Optional.of(new AuthRepository.UserAccount(
                        "user-1", "user", "hash", "User", "ENABLED", "zh-CN", true, false)));
        assertThatThrownBy(() -> source.visibleTo(actor)).isInstanceOf(PlanRejectedException.class);
        when(auth.findSession("session-1")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> source.visibleTo(actor)).isInstanceOf(PlanRejectedException.class);
    }

    @Test
    void approvalDigestAndVersionAreBoundAndRechecked() {
        assertThat(source.authorize(row.getCapabilityCode(), "1", row.getManifestHash(), "session-1")
                        .access()
                        .projectId())
                .isEqualTo("123");
        assertThatThrownBy(() -> source.authorize(row.getCapabilityCode(), "2", row.getManifestHash(), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
        assertThatThrownBy(() -> source.authorize(row.getCapabilityCode(), "1", "0".repeat(64), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
        row.setStatus("REVOKED");
        assertThatThrownBy(() -> source.authorize(row.getCapabilityCode(), "1", row.getManifestHash(), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
    }

    @Test
    void removingButtonPermissionRemovesCapability() {
        when(registry.permissions("123")).thenReturn(Set.of());
        assertThat(source.visibleTo(actor)).isEmpty();
    }

    @Test
    void disabledFeatureDoesNotQueryIdentityOrMetadata() {
        config.setEnabled(false);
        clearInvocations(auth, registry, projects);
        assertThat(source.visibleTo(actor)).isEmpty();
        assertThat(source.findVisible(row.getCapabilityCode(), actor)).isEmpty();
        verifyNoInteractions(auth, registry, projects);
    }

    @Test
    void writeRevisionRequiresSeparateFlagAndNeverEntersReadCatalog() {
        var manifest = new CapabilityManifest(
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
                true,
                ConfirmationMode.REQUIRED,
                1000);
        row.setCapabilityCode(manifest.code());
        row.setManifestJson(codec.canonical(manifest));
        row.setManifestHash(AgentManifestCodec.digest(row.getManifestJson()));
        when(registry.byCode(manifest.code())).thenReturn(row);
        when(registry.permissions("123")).thenReturn(Set.of(manifest.permission()));
        when(projects.resolve("crm", "user-1"))
                .thenReturn(Optional.of(
                        new ProjectAccessView("123", "crm", List.of(manifest.permission()), List.of("editor"))));

        assertThat(source.visibleTo(actor)).isEmpty();
        assertThat(source.visibleWritesTo(actor)).isEmpty();
        assertThat(source.findVisible(manifest.code(), actor)).isEmpty();
        assertThatThrownBy(() -> source.authorizeWrite(manifest.code(), "1", row.getManifestHash(), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
        config.setWriteEnabled(true);
        var approved = source.authorizeWrite(manifest.code(), "1", row.getManifestHash(), "session-1");
        assertThat(source.visibleWritesTo(actor)).extracting(Capability::code).containsExactly(manifest.code());
        assertThat(source.findVisibleWrite(manifest.code(), actor)).isPresent();
        assertThat(source.visibleWriteRevision(manifest.code(), actor).manifestHash())
                .isEqualTo(row.getManifestHash());
        assertThat(approved.capability().readOnly()).isFalse();
        assertThat(approved.capability().canSkipConfirmation()).isFalse();
        assertThat(approved.confirmation()).isEqualTo(ConfirmationMode.REQUIRED);
        assertThat(approved.access().projectId()).isEqualTo("123");
        assertThatThrownBy(() -> source.authorizeWrite(manifest.code(), "2", row.getManifestHash(), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
        assertThatThrownBy(() -> source.authorizeWrite(manifest.code(), "1", "0".repeat(64), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
        row.setStatus("REVOKED");
        assertThatThrownBy(() -> source.authorizeWrite(manifest.code(), "1", row.getManifestHash(), "session-1"))
                .isInstanceOf(PlanRejectedException.class);
    }

    @Test
    void reviewedFormUsesProjectPermissionsAndDisappearsAfterRevocation() throws Exception {
        try (var input = getClass().getResourceAsStream("/agent-registration-form-v2.json")) {
            var manifest = codec.decode(input.readAllBytes());
            row.setVersion("2");
            row.setCapabilityCode(manifest.code());
            when(registry.byCode(manifest.code())).thenReturn(row);
            row.setManifestJson(codec.canonical(manifest));
            row.setManifestHash(AgentManifestCodec.digest(row.getManifestJson()));
            var form = source.visibleTo(actor).getFirst().inputForm();
            assertThat(form.projectCode()).isEqualTo("crm");
            assertThat(form.title()).isEqualTo("查询跟进记录");
            assertThat(form.fields()).extracting(field -> field.type()).containsExactly("STRING", "BOOL", "INT");
            var catalog = new CapabilityCatalog();
            catalog.remoteSource(source);
            var validator = new AgentPlanValidator(catalog);
            var plan = new AgentPlan(true, List.of(new AgentPlan.Call(manifest.code(), Map.of())), null);
            assertThat(validator.validate(plan, actor, Set.of()).understood()).isFalse();
            var values = Map.<String, Object>of("keyword", "测试", "enabled", false, "pageSize", 20);
            var complete = new AgentPlan(true, List.of(new AgentPlan.Call(manifest.code(), values)), null);
            assertThat(validator
                            .validateInput(complete, actor, Set.of())
                            .calls()
                            .getFirst()
                            .params())
                    .isEqualTo(values);
            for (Object invalid : List.of("20", 0, 1.5, 101)) {
                var invalidValues = new HashMap<>(values);
                invalidValues.put("pageSize", invalid);
                assertThatThrownBy(() -> validator.validateInput(
                                new AgentPlan(true, List.of(new AgentPlan.Call(manifest.code(), invalidValues)), null),
                                actor,
                                Set.of()))
                        .isInstanceOf(PlanRejectedException.class);
            }
            when(projects.resolve("crm", "user-1"))
                    .thenReturn(Optional.of(new ProjectAccessView("123", "crm", List.of(), List.of())));
            assertThat(source.visibleTo(actor)).isEmpty();
            assertThatThrownBy(() -> validator.validateInput(complete, actor, Set.of()))
                    .isInstanceOf(PlanRejectedException.class);
        }
    }
}
