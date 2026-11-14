package com.kaiwu.module.agent.service;

import static com.kaiwu.testing.AgentTestFixtures.actor;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.execution.AgentActionAccess;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.service.impl.AgentActionServiceImpl;
import com.kaiwu.module.agent.store.AgentActionRecord;
import com.kaiwu.module.agent.store.AgentActionStore;
import com.kaiwu.module.agent.vo.AgentActionView;
import com.kaiwu.module.configuration.agent.ConfigCreateAgentWriteHandler;
import com.kaiwu.module.configuration.agent.ConfigDeleteAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictItemCreateAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictItemDeleteAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictItemRenameAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictTypeCreateAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictTypeDeleteAgentWriteHandler;
import com.kaiwu.module.configuration.agent.DictTypeRenameAgentWriteHandler;
import com.kaiwu.module.configuration.service.MetadataService;
import com.kaiwu.module.configuration.service.MetadataService.ConfigDeleteSnapshot;
import com.kaiwu.module.configuration.service.MetadataService.DictItemDeleteSnapshot;
import com.kaiwu.module.configuration.service.MetadataService.DictItemRenameExpectation;
import com.kaiwu.module.configuration.service.MetadataService.DictTypeDeleteSnapshot;
import com.kaiwu.module.configuration.service.MetadataService.DictTypeRenameExpectation;
import com.kaiwu.module.identity.agent.DepartmentCreateAgentWriteHandler;
import com.kaiwu.module.identity.agent.DepartmentDeleteAgentWriteHandler;
import com.kaiwu.module.identity.agent.DepartmentRenameAgentWriteHandler;
import com.kaiwu.module.identity.agent.DepartmentStatusUpdateAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserCreateAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserDepartmentAssignAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserDisplayNameUpdateAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserPasswordResetAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserProfileUpdateAgentWriteHandler;
import com.kaiwu.module.identity.agent.UserStatusUpdateAgentWriteHandler;
import com.kaiwu.module.identity.repository.AuthRepository;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.identity.service.OrgService;
import com.kaiwu.module.identity.service.OrgService.DepartmentRenameExpectation;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.metadata.dto.ConfigSaveRequest;
import com.kaiwu.module.metadata.dto.DictItemSaveRequest;
import com.kaiwu.module.metadata.vo.ConfigView;
import com.kaiwu.module.metadata.vo.DictItemView;
import com.kaiwu.module.metadata.vo.DictTypeView;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.module.project.agent.ProjectMemberDeleteAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectMemberSaveAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectMenuCreateAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectMenuDeleteAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectMenuStatusAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectMenuUpdateAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRenameAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRoleCreateAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRoleDeleteAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRoleMenuGrantAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRoleStatusAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectRoleUpdateAgentWriteHandler;
import com.kaiwu.module.project.agent.ProjectStatusUpdateAgentWriteHandler;
import com.kaiwu.module.project.dto.ProjectRoleCreateRequest;
import com.kaiwu.module.project.dto.ProjectRoleUpdateRequest;
import com.kaiwu.module.project.service.ProjectService;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.module.user.dto.UserCreateRequest;
import com.kaiwu.module.user.vo.UserView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import jakarta.validation.Validation;
import jakarta.validation.ValidatorFactory;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.DockerImageName;
import tools.jackson.databind.json.JsonMapper;

/** 真 Redis 验证 Lua 原子互斥、跨请求状态及失败关闭，不操作共享环境。 */
class AgentActionServiceTest {
    static final GenericContainer<?> REDIS = new GenericContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_REDIS_IMAGE", "redis:7.4-alpine")))
            .withExposedPorts(6379);
    static LettuceConnectionFactory connections;
    static StringRedisTemplate redis;
    static ValidatorFactory validation;
    static final RequestMetadata METADATA = new RequestMetadata("127.0.0.1", "action-test");
    AuthRepository auth;
    ProjectService projects;
    AuditPort audit;
    AgentActionStore store;
    AgentActionServiceImpl service;
    CapabilityCatalog catalog;

    static final KaiwuContext ACTOR = actor("1", "session-1");
    static final KaiwuContext DICT_ACTOR = new KaiwuContext(
            "1",
            "session-1",
            null,
            null,
            Set.of("system:agent:ask", "system:dict:save"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "dict-jti");
    static final KaiwuContext CONFIG_ACTOR = new KaiwuContext(
            "1",
            "session-1",
            null,
            null,
            Set.of("system:agent:ask", "system:config:save"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "config-jti");
    static final KaiwuContext USER_ACTOR = new KaiwuContext(
            "1",
            "session-1",
            null,
            null,
            Set.of("system:agent:ask", "system:user:update"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "user-jti");
    static final KaiwuContext USER_CREATE_ACTOR = new KaiwuContext(
            "1",
            "session-1",
            null,
            null,
            Set.of("system:agent:ask", "system:user:create"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "user-create-jti");
    static final KaiwuContext ORG_ACTOR = new KaiwuContext(
            "1",
            "session-1",
            null,
            null,
            Set.of("system:agent:ask", "system:org:save"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            Instant.now(),
            Instant.now().plusSeconds(60),
            "org-jti");

    @BeforeAll
    static void start() {
        REDIS.start();
        connections = new LettuceConnectionFactory(REDIS.getHost(), REDIS.getMappedPort(6379));
        connections.afterPropertiesSet();
        connections.start();
        redis = new StringRedisTemplate(connections);
        validation = Validation.buildDefaultValidatorFactory();
    }

    @AfterAll
    static void stop() {
        if (connections != null) connections.destroy();
        if (validation != null) validation.close();
        REDIS.stop();
    }

    @BeforeEach
    void setup() {
        auth = mock(AuthRepository.class);
        projects = mock(ProjectService.class);
        audit = mock(AuditPort.class);
        var json = JsonMapper.builder().build();
        store = spy(new AgentActionStore(redis, json));
        catalog = spy(new CapabilityCatalog());
        service = new AgentActionServiceImpl(
                store, new AgentActionAccess(auth), catalog, projects, validation.getValidator(), json, audit);
        allow(ACTOR);
        when(projects.create(any(), any(), any()))
                .thenReturn(new ProjectView(
                        "1789248125900000001",
                        "orders",
                        "订单",
                        null,
                        "ACTIVE",
                        false,
                        "1",
                        "com.kaiwu.business.orders",
                        null,
                        null,
                        "main",
                        null,
                        null,
                        null,
                        null,
                        null));
    }

    void allow(KaiwuContext actor) {
        when(auth.findSession(actor.sessionId()))
                .thenReturn(Optional.of(new AuthRepository.OnlineSession(
                        actor.sessionId(),
                        actor.userId(),
                        "hash",
                        "ONLINE",
                        "WEB",
                        Instant.now().plusSeconds(600))));
        when(auth.findUserById(actor.userId()))
                .thenReturn(Optional.of(new AuthRepository.UserAccount(
                        actor.userId(), "user", "hash", "User", "ENABLED", "zh-CN", false, false)));
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:create"));
    }

    AgentActionView preview() {
        return service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_CREATE, Map.of("projectCode", "orders", "projectName", "订单")),
                ACTOR,
                METADATA);
    }

    @Test
    void dictionaryCreationUsesPreviewRealtimePermissionAndSingleConfirmation() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictTypeCreateAgentWriteHandler(metadata)));
        allow(DICT_ACTOR);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:save"));
        when(metadata.saveDictType(eq("0"), any(), eq(DICT_ACTOR), eq(METADATA)))
                .thenReturn(new DictTypeView(
                        "721",
                        "0",
                        "agent_example",
                        "示例",
                        null,
                        false,
                        10,
                        "ENABLED",
                        null,
                        java.time.LocalDateTime.now()));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DICT_TYPE_CREATE, Map.of("dictCode", "agent_example", "dictName", "示例")),
                DICT_ACTOR,
                METADATA);
        assertThat(preview.project()).isNull();
        assertThat(preview.permission()).isEqualTo("system:dict:save");
        assertThat(preview.previewFields()).containsEntry("dictCode", "agent_example");
        verifyNoInteractions(metadata);
        assertThat(redis.opsForValue().get("agent:action:" + preview.actionId()))
                .doesNotContain(preview.confirmationToken());

        var done = service.confirm(preview.actionId(), preview.confirmationToken(), DICT_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        assertThat(done.projectId()).isEqualTo("721");
        service.confirm(preview.actionId(), preview.confirmationToken(), DICT_ACTOR, METADATA);
        verify(metadata, times(1)).saveDictType(eq("0"), any(), eq(DICT_ACTOR), eq(METADATA));

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DICT_TYPE_CREATE, Map.of("dictCode", "agent_second", "dictName", "第二项")),
                DICT_ACTOR,
                METADATA);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), DICT_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(metadata, times(1)).saveDictType(eq("0"), any(), eq(DICT_ACTOR), eq(METADATA));
    }

    @Test
    void dictionaryRenameUsesServerFrozenStateAndLivePermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictTypeRenameAgentWriteHandler(metadata)));
        allow(DICT_ACTOR);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:save"));
        when(metadata.dictTypes("0"))
                .thenReturn(List.of(
                        new DictTypeView("721", "0", "agent_example", "原名称", null, false, 10, "ENABLED", null, null)));

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.DICT_TYPE_RENAME, Map.of("typeId", "721", "dictName", "新名称")),
                DICT_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("currentName", "原名称").containsEntry("dictName", "新名称");
        verify(metadata, never()).renameGlobalDictType(any(), any(), any(), any(), any());

        var done = service.confirm(preview.actionId(), preview.confirmationToken(), DICT_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata)
                .renameGlobalDictType(
                        "721",
                        "新名称",
                        new DictTypeRenameExpectation("agent_example", "原名称", "ENABLED", ""),
                        DICT_ACTOR,
                        METADATA);

        var revoked = service.preview(
                new AgentPlan.Call(CapabilityCatalog.DICT_TYPE_RENAME, Map.of("typeId", "721", "dictName", "另一名称")),
                DICT_ACTOR,
                METADATA);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), DICT_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(metadata, times(1)).renameGlobalDictType(any(), any(), any(), any(), any());
    }

    @Test
    void dictionaryItemRenameUsesServerFrozenStateAndLivePermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictItemRenameAgentWriteHandler(metadata)));
        allow(DICT_ACTOR);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:save"));
        when(metadata.dictItems("0", "721"))
                .thenReturn(List.of(new DictItemView("722", "原标签", "stable", 0, false, null, null, null, "ENABLED")));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DICT_ITEM_RENAME,
                        Map.of("typeId", "721", "itemId", "722", "itemLabel", "新标签")),
                DICT_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("currentLabel", "原标签").containsEntry("itemValue", "stable");
        verify(metadata, never()).renameGlobalDictItem(any(), any(), any(), any(), any(), any());

        var done = service.confirm(preview.actionId(), preview.confirmationToken(), DICT_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata)
                .renameGlobalDictItem(
                        "721",
                        "722",
                        "新标签",
                        new DictItemRenameExpectation("原标签", "stable", "ENABLED"),
                        DICT_ACTOR,
                        METADATA);

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DICT_ITEM_RENAME,
                        Map.of("typeId", "721", "itemId", "722", "itemLabel", "另一标签")),
                DICT_ACTOR,
                METADATA);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), DICT_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(metadata, times(1)).renameGlobalDictItem(any(), any(), any(), any(), any(), any());
    }

    @Test
    void dictionaryItemDeletionRequiresStrongConfirmationAndLiveDeletePermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictItemDeleteAgentWriteHandler(metadata)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:dict:delete"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "dict-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:delete"));
        var snapshot = new DictItemDeleteSnapshot("旧标签", "stable", "ENABLED");
        when(metadata.previewGlobalDictItemDeletion("721", "722")).thenReturn(snapshot);

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.DICT_ITEM_DELETE, Map.of("typeId", "721", "itemId", "722")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("删除字典项 722 stable");
        verify(metadata, never()).deleteGlobalDictItemForAgent(any(), any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "删除字典项 722 stable", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:delete"));
        var done =
                service.confirm(preview.actionId(), preview.confirmationToken(), "删除字典项 722 stable", actor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata).deleteGlobalDictItemForAgent("721", "722", snapshot, actor, METADATA);
    }

    @Test
    void dictionaryTypeDeletionShowsAffectedCountAndRequiresLivePermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictTypeDeleteAgentWriteHandler(metadata)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:dict:delete"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "dict-type-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:delete"));
        var snapshot = new DictTypeDeleteSnapshot("status", "状态", "ENABLED", 3, "digest");
        when(metadata.previewGlobalDictTypeDeletion("721")).thenReturn(snapshot);

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.DICT_TYPE_DELETE, Map.of("typeId", "721")), actor, METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("删除字典 721 status");
        assertThat(preview.previewFields()).containsEntry("itemCount", "3").doesNotContainKey("_fingerprint");
        verify(metadata, never()).deleteGlobalDictTypeForAgent(any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "删除字典 721 status", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:delete"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), "删除字典 721 status", actor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata).deleteGlobalDictTypeForAgent("721", snapshot, actor, METADATA);
    }

    @Test
    void secretConfigurationDeletionHidesSnapshotAndRechecksPermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new ConfigDeleteAgentWriteHandler(metadata)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:config:delete"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "config-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:config:delete"));
        var snapshot = new ConfigDeleteSnapshot("api.secret", "STRING", true, "ENABLED", "opaque-snapshot");
        when(metadata.previewGlobalConfigDeletion("31")).thenReturn(snapshot);

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.CONFIG_DELETE, Map.of("configId", "31")), actor, METADATA);
        assertThat(preview.previewFields())
                .containsEntry("configKey", "api.secret")
                .doesNotContainKey("_fingerprint");
        assertThat(preview.confirmationPhrase()).isEqualTo("删除配置 api.secret");
        verify(metadata, never()).deleteGlobalConfigForAgent(any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "删除配置 api.secret", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:config:delete"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), "删除配置 api.secret", actor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata).deleteGlobalConfigForAgent("31", snapshot, actor, METADATA);
    }

    @Test
    void nonSecretConfigurationCreationRequiresPreviewAndLivePermission() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new ConfigCreateAgentWriteHandler(metadata)));
        allow(CONFIG_ACTOR);
        when(auth.findPermissions(CONFIG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:config:save"));
        when(metadata.saveConfig(eq("0"), any(), eq(CONFIG_ACTOR), eq(METADATA)))
                .thenReturn(new ConfigView(
                        "731", "0", "notice.enabled", "true", null, "BOOLEAN", false, "ENABLED", null, 0, null, null));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.CONFIG_CREATE,
                        Map.of("configKey", "notice.enabled", "configValue", "true", "valueType", "BOOLEAN")),
                CONFIG_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("configValue", "true");
        verifyNoInteractions(metadata);
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), CONFIG_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata)
                .saveConfig(
                        eq("0"),
                        eq(new ConfigSaveRequest(
                                null, "notice.enabled", "true", null, "BOOLEAN", false, "ENABLED", null, 0)),
                        eq(CONFIG_ACTOR),
                        eq(METADATA));

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.CONFIG_CREATE, Map.of("configKey", "notice.other", "configValue", "on")),
                CONFIG_ACTOR,
                METADATA);
        when(auth.findPermissions(CONFIG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(
                        () -> service.confirm(revoked.actionId(), revoked.confirmationToken(), CONFIG_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(metadata, times(1)).saveConfig(any(), any(), any(), any());
    }

    @Test
    void configurationCreationRejectsSecretAndUnknownFields() {
        var handler = new ConfigCreateAgentWriteHandler(mock(MetadataService.class));
        assertThatThrownBy(() ->
                        handler.normalize(Map.of("configKey", "mail.token", "configValue", "secret", "secret", true)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> handler.normalize(Map.of("configKey", "bad key", "configValue", "x")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void invalidDictionaryCodeIsRejectedBeforeActionIsStored() {
        service.localWriteHandlers(List.of(new DictTypeCreateAgentWriteHandler(mock(MetadataService.class))));
        when(auth.findPermissions(ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:save"));
        assertThatThrownBy(() -> service.preview(
                        new AgentPlan.Call(
                                CapabilityCatalog.DICT_TYPE_CREATE,
                                Map.of("dictCode", "invalid code", "dictName", "示例")),
                        DICT_ACTOR,
                        METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void dictionaryItemCreationUsesExistingTypeAndServiceDefaults() {
        MetadataService metadata = mock(MetadataService.class);
        service.localWriteHandlers(List.of(new DictItemCreateAgentWriteHandler(metadata)));
        allow(DICT_ACTOR);
        when(auth.findPermissions(DICT_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:dict:save"));
        when(metadata.dictTypes("0"))
                .thenReturn(List.of(
                        new DictTypeView("721", "0", "agent_example", "示例字典", null, false, 10, "ENABLED", null, null)));
        when(metadata.saveDictItem(eq("0"), eq("721"), any(), eq(DICT_ACTOR), eq(METADATA)))
                .thenReturn(new DictItemView("722", "示例项", "sample", 0, false, null, null, null, "ENABLED"));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DICT_ITEM_CREATE,
                        Map.of("typeId", "721", "itemLabel", "示例项", "itemValue", "sample")),
                DICT_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("dictName", "示例字典");
        verify(metadata, never()).saveDictItem(any(), any(), any(), any(), any());
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), DICT_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(metadata)
                .saveDictItem(
                        eq("0"),
                        eq("721"),
                        eq(new DictItemSaveRequest(null, "示例项", "sample", 0, false, null, null, null, "ENABLED")),
                        eq(DICT_ACTOR),
                        eq(METADATA));
        assertThat(done.oneTimeSecret()).isNull();
    }

    @Test
    void departmentCreationReusesOrgServiceAndDoesNotMutateDuringPreview() {
        OrgService org = mock(OrgService.class);
        service.localWriteHandlers(List.of(new DepartmentCreateAgentWriteHandler(org, validation.getValidator())));
        allow(ORG_ACTOR);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:org:save"));
        when(org.saveDepartment(any(), eq(ORG_ACTOR), eq(METADATA)))
                .thenReturn(new DepartmentView("91", null, "技术部", "tech", 0, "ENABLED", null, null, List.of()));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DEPARTMENT_CREATE, Map.of("departmentName", "技术部", "departmentCode", "tech")),
                ORG_ACTOR,
                METADATA);
        assertThat(preview.previewFields())
                .containsEntry("departmentName", "技术部")
                .containsEntry("parentDepartmentId", "-");
        verifyNoInteractions(org);
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), ORG_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(org)
                .saveDepartment(
                        eq(new DepartmentSaveRequest(null, null, "技术部", "tech", 0, "ENABLED")),
                        eq(ORG_ACTOR),
                        eq(METADATA));
    }

    @Test
    void departmentRenameUsesFrozenPreviewAndLivePermission() {
        OrgService org = mock(OrgService.class);
        service.localWriteHandlers(List.of(new DepartmentRenameAgentWriteHandler(org)));
        allow(ORG_ACTOR);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:org:save"));
        when(org.department("91"))
                .thenReturn(new DepartmentView("91", null, "研发部", "rd", 10, "ENABLED", null, null, List.of()));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DEPARTMENT_RENAME, Map.of("departmentId", "91", "departmentName", "新研发部")),
                ORG_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("currentName", "研发部").containsEntry("departmentCode", "rd");
        verify(org, never()).renameDepartment(any(), any(), any(), any(), any());

        var done = service.confirm(preview.actionId(), preview.confirmationToken(), ORG_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(org)
                .renameDepartment(
                        "91", "新研发部", new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"), ORG_ACTOR, METADATA);

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DEPARTMENT_RENAME, Map.of("departmentId", "91", "departmentName", "另一名称")),
                ORG_ACTOR,
                METADATA);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), ORG_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(org, times(1)).renameDepartment(any(), any(), any(), any(), any());
    }

    @Test
    void departmentDisableRequiresStrongPhraseAndLivePermission() {
        OrgService org = mock(OrgService.class);
        service.localWriteHandlers(List.of(new DepartmentStatusUpdateAgentWriteHandler(org)));
        allow(ORG_ACTOR);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:org:save"));
        when(org.department("91"))
                .thenReturn(new DepartmentView("91", null, "研发部", "rd", 10, "ENABLED", null, null, List.of()));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.DEPARTMENT_STATUS_UPDATE, Map.of("departmentId", "91", "status", "DISABLED")),
                ORG_ACTOR,
                METADATA);
        assertThat(preview.previewFields())
                .containsEntry("currentStatus", "ENABLED")
                .containsEntry("departmentCode", "rd");
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("停用部门 rd");
        verify(org, never()).updateDepartmentStatus(any(), any(), any(), any(), any());

        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), ORG_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "停用部门 rd", ORG_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(ORG_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:org:save"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), "停用部门 rd", ORG_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(org)
                .updateDepartmentStatus(
                        "91",
                        "DISABLED",
                        new DepartmentRenameExpectation("研发部", "rd", "", "ENABLED"),
                        ORG_ACTOR,
                        METADATA);
    }

    @Test
    void departmentDeleteNeedsStrongPhraseAndLiveDeletePermission() {
        OrgService org = mock(OrgService.class);
        service.localWriteHandlers(List.of(new DepartmentDeleteAgentWriteHandler(org)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:org:delete"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "department-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:org:delete"));
        when(org.previewDepartmentDeletion("91"))
                .thenReturn(new DepartmentView("91", null, "研发部", "rd", 10, "ENABLED", null, null, List.of()));
        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.DEPARTMENT_DELETE, Map.of("departmentId", "91")), actor, METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() ->
                        service.confirm(preview.actionId(), preview.confirmationToken(), "删除部门 rd", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:org:delete"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "删除部门 rd", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(org)
                .deleteDepartmentForAgent(
                        "91",
                        new OrgService.DepartmentDeleteExpectation("研发部", "rd", null, 10, "ENABLED"),
                        actor,
                        METADATA);
    }

    @Test
    void userDepartmentAssignmentChecksOrderAndLivePermission() {
        OrgService org = mock(OrgService.class);
        service.localWriteHandlers(List.of(new UserDepartmentAssignAgentWriteHandler(org)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:org:assign"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "user-dept-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:org:assign"));
        when(org.previewUserDepartmentAssignment("91", List.of("12", "11"))).thenReturn(List.of("10"));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_DEPARTMENT_ASSIGN,
                        Map.of("targetUserId", "91", "departmentIds", List.of("12", "11"))),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.previewFields()).containsEntry("departmentIds", "12,11");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() ->
                        service.confirm(preview.actionId(), preview.confirmationToken(), "设置用户部门 91", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:org:assign"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "设置用户部门 91", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(org).assignDepartmentsForAgent("91", List.of("12", "11"), List.of("10"), actor, METADATA);
    }

    @Test
    void projectStatusUpdateRequiresFrozenTargetAndStrongConfirmation() {
        service.localWriteHandlers(List.of(new ProjectStatusUpdateAgentWriteHandler(projects)));
        var statusActor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:status"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-status-jti");
        allow(statusActor);
        when(auth.findPermissions(statusActor.userId()))
                .thenReturn(Set.of("system:agent:ask", "system:project:status"));
        when(projects.project("91"))
                .thenReturn(new ProjectView(
                        "91", "demo", "演示项目", null, "ACTIVE", false, "1", null, null, null, "main", null, null, null,
                        null, null));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_STATUS_UPDATE, Map.of("projectId", "91", "status", "DISABLED")),
                statusActor,
                METADATA);
        assertThat(preview.previewFields())
                .containsEntry("projectCode", "demo")
                .containsEntry("currentStatus", "ACTIVE");
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("停用项目 demo");
        verify(projects, never()).updateStatusForAgent(any(), any(), any(), any(), any());

        assertThatThrownBy(
                        () -> service.confirm(preview.actionId(), preview.confirmationToken(), statusActor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
        when(auth.findPermissions(statusActor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "停用项目 demo", statusActor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(statusActor.userId()))
                .thenReturn(Set.of("system:agent:ask", "system:project:status"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), "停用项目 demo", statusActor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(projects)
                .updateStatusForAgent(
                        "91",
                        "DISABLED",
                        new ProjectService.ProjectStatusExpectation("demo", "演示项目", "ACTIVE"),
                        statusActor,
                        METADATA);
    }

    @Test
    void projectRenameRequiresFrozenTargetAndLiveUpdatePermission() {
        service.localWriteHandlers(List.of(new ProjectRenameAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:update"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-rename-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:update"));
        when(projects.project("91"))
                .thenReturn(new ProjectView(
                        "91", "demo", "旧项目名", null, "ACTIVE", false, "1", null, null, null, "main", null, null, null,
                        null, null));

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.PROJECT_RENAME, Map.of("projectId", "91", "projectName", "新项目名")),
                actor,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("currentName", "旧项目名").containsEntry("projectCode", "demo");
        verify(projects, never()).renameProjectForAgent(any(), any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:update"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(projects)
                .renameProjectForAgent(
                        "91",
                        "新项目名",
                        new ProjectService.ProjectRenameExpectation("demo", "旧项目名", "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectRoleCreationUsesPageServiceAndLiveRolePermission() {
        service.localWriteHandlers(
                List.of(new ProjectRoleCreateAgentWriteHandler(projects, validation.getValidator())));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:role"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-role-create-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        when(projects.project("91"))
                .thenReturn(new ProjectView(
                        "91", "demo", "演示项目", null, "ACTIVE", false, "1", null, null, null, "main", null, null, null,
                        null, null));
        when(projects.createRole(eq("91"), any(), eq(actor), eq(METADATA)))
                .thenReturn(new ProjectRoleView(
                        "92", "91", "reviewer", "审核员", null, "ENABLED", false, Set.of(), null, null));

        var call = new AgentPlan.Call(
                CapabilityCatalog.PROJECT_ROLE_CREATE,
                Map.of("projectId", "91", "newRoleCode", "reviewer", "roleName", "审核员"));
        var preview = service.preview(call, actor, METADATA);
        assertThat(preview.previewFields()).containsEntry("projectCode", "demo").containsEntry("roleCode", "reviewer");
        verify(projects, never()).createRole(any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(projects).createRole("91", new ProjectRoleCreateRequest("reviewer", "审核员", null), actor, METADATA);
    }

    @Test
    void projectRoleUpdatePreservesUnspecifiedDescriptionAndRechecksPermission() {
        service.localWriteHandlers(
                List.of(new ProjectRoleUpdateAgentWriteHandler(projects, validation.getValidator())));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:role"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-role-update-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        when(projects.editableRole("91", "92"))
                .thenReturn(new ProjectRoleView(
                        "92", "91", "reviewer", "旧名称", "保留描述", "ACTIVE", false, Set.of(), null, null));
        var call = new AgentPlan.Call(
                CapabilityCatalog.PROJECT_ROLE_UPDATE,
                Map.of("projectId", "91", "targetRoleId", "92", "roleName", "新名称"));
        var preview = service.preview(call, actor, METADATA);
        assertThat(preview.previewFields())
                .containsEntry("currentName", "旧名称")
                .containsEntry("roleName", "新名称")
                .containsEntry("description", "保留描述");
        verify(projects, never()).updateRoleForAgent(any(), any(), any(), any(), any(), any());

        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .updateRoleForAgent(
                        "91",
                        "92",
                        new ProjectRoleUpdateRequest("新名称", "保留描述"),
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "旧名称", "保留描述", "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectRoleDeleteRequiresStrongConfirmationAndLivePermission() {
        service.localWriteHandlers(List.of(new ProjectRoleDeleteAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:role"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-role-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        when(projects.previewRoleDeletion("91", "92"))
                .thenReturn(new ProjectRoleView(
                        "92", "91", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_ROLE_DELETE, Map.of("projectId", "91", "targetRoleId", "92")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("删除角色 92 reviewer");
        verify(projects, never()).deleteRoleForAgent(any(), any(), any(), any(), any());
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "删除角色 92 reviewer", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "删除角色 92 reviewer", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .deleteRoleForAgent(
                        "91",
                        "92",
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "审核员", null, "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectRoleDisableRequiresStrongPhraseAndLivePermission() {
        service.localWriteHandlers(List.of(new ProjectRoleStatusAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:role"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "project-role-status-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        when(projects.editableRole("91", "92"))
                .thenReturn(new ProjectRoleView(
                        "92", "91", "reviewer", "审核员", null, "ACTIVE", false, Set.of(), null, null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_ROLE_STATUS_UPDATE,
                        Map.of("projectId", "91", "targetRoleId", "92", "status", "DISABLED")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("停用角色 reviewer");
        verify(projects, never()).updateRoleStatusForAgent(any(), any(), any(), any(), any(), any());
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "停用角色 reviewer", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "停用角色 reviewer", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .updateRoleStatusForAgent(
                        "91",
                        "92",
                        "DISABLED",
                        new ProjectService.ProjectRoleEditExpectation("reviewer", "审核员", null, "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectRoleMenuGrantChecksStrongConfirmationAndLiveRolePermission() {
        service.localWriteHandlers(List.of(new ProjectRoleMenuGrantAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:role"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "role-menu-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        when(projects.previewRoleMenuGrant("91", "92", Set.of("32")))
                .thenReturn(new ProjectRoleView(
                        "92", "91", "reviewer", "审核员", null, "ACTIVE", false, Set.of("31"), null, null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_ROLE_MENU_GRANT,
                        Map.of("projectId", "91", "targetRoleId", "92", "menuIds", List.of("32"))),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("重设角色菜单 92 reviewer");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "重设角色菜单 92 reviewer", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:role"));
        assertThat(service.confirm(
                                preview.actionId(), preview.confirmationToken(), "重设角色菜单 92 reviewer", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .grantRoleMenusForAgent(
                        "91",
                        "92",
                        Set.of("32"),
                        new ProjectService.ProjectRoleMenuExpectation("reviewer", "审核员", null, "ACTIVE", Set.of("31")),
                        actor,
                        METADATA);
    }

    @Test
    void projectMemberSaveChecksStrongConfirmationAndLiveMemberPermission() {
        service.localWriteHandlers(List.of(new ProjectMemberSaveAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:member"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "member-save-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:member"));
        when(projects.previewMemberSave(
                        "91", "94", new com.kaiwu.module.project.dto.ProjectMemberRequest(Set.of("92"), "ACTIVE")))
                .thenReturn(Optional.empty());
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MEMBER_SAVE,
                        Map.of("projectId", "91", "targetUserId", "94", "roleIds", List.of("92"), "status", "ACTIVE")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() ->
                        service.confirm(preview.actionId(), preview.confirmationToken(), "设置项目成员 94", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:member"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "设置项目成员 94", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .saveMemberForAgent(
                        "91",
                        "94",
                        new com.kaiwu.module.project.dto.ProjectMemberRequest(Set.of("92"), "ACTIVE"),
                        new ProjectService.ProjectMemberExpectation(false, "", "", Set.of()),
                        actor,
                        METADATA);
    }

    @Test
    void projectMemberDeleteChecksStrongConfirmationAndLiveMemberPermission() {
        service.localWriteHandlers(List.of(new ProjectMemberDeleteAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:member"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "member-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:member"));
        when(projects.previewMemberDeletion("91", "94", actor))
                .thenReturn(new com.kaiwu.module.project.vo.ProjectMemberView(
                        "94", "alice", "Alice", "ACTIVE", Set.of("92"), null, null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MEMBER_DELETE, Map.of("projectId", "91", "targetUserId", "94")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "移除项目成员 94 alice", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:member"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "移除项目成员 94 alice", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .deleteMemberForAgent(
                        "91",
                        "94",
                        new ProjectService.ProjectMemberExpectation(true, "alice", "ACTIVE", Set.of("92")),
                        actor,
                        METADATA);
    }

    @Test
    void projectMenuDisableNeedsStrongPhraseAndLivePermission() {
        service.localWriteHandlers(List.of(new ProjectMenuStatusAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:menu"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "menu-status-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        when(projects.menuForAgent("91", "93"))
                .thenReturn(new ProjectMenuView(
                        "93",
                        "91",
                        null,
                        "审核按钮",
                        null,
                        "BUTTON",
                        null,
                        null,
                        "demo:review",
                        null,
                        1,
                        true,
                        "ACTIVE",
                        null,
                        null,
                        null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MENU_STATUS_UPDATE,
                        Map.of("projectId", "91", "targetMenuId", "93", "status", "DISABLED")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("停用菜单 93 审核按钮");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "停用菜单 93 审核按钮", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "停用菜单 93 审核按钮", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .updateMenuStatusForAgent(
                        "91",
                        "93",
                        "DISABLED",
                        new ProjectService.ProjectMenuEditExpectation(null, "审核按钮", "BUTTON", "demo:review", "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectMenuDeletionNeedsStrongPhraseAndLivePermission() {
        service.localWriteHandlers(List.of(new ProjectMenuDeleteAgentWriteHandler(projects)));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:menu"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "menu-delete-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        when(projects.previewMenuDeletion("91", "93"))
                .thenReturn(new ProjectMenuView(
                        "93",
                        "91",
                        null,
                        "审核按钮",
                        null,
                        "BUTTON",
                        null,
                        null,
                        "demo:review",
                        null,
                        1,
                        true,
                        "ACTIVE",
                        null,
                        null,
                        null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MENU_DELETE, Map.of("projectId", "91", "targetMenuId", "93")),
                actor,
                METADATA);
        assertThat(preview.confirmationPhrase()).isEqualTo("删除菜单 93 审核按钮");
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "删除菜单 93 审核按钮", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(projects)
                .deleteMenuForAgent(
                        "91",
                        "93",
                        new ProjectService.ProjectMenuEditExpectation(null, "审核按钮", "BUTTON", "demo:review", "ACTIVE"),
                        actor,
                        METADATA);
    }

    @Test
    void projectMenuCreateUsesFullFormAndLivePermission() {
        service.localWriteHandlers(
                List.of(new ProjectMenuCreateAgentWriteHandler(projects, validation.getValidator())));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:menu"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "menu-create-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        var request = new com.kaiwu.module.project.dto.ProjectMenuRequest(
                null, "审核菜单", null, "DIR", null, null, null, null, 0, true);
        when(projects.previewMenuCreation("91", request))
                .thenReturn(new ProjectView(
                        "91", "demo", "演示项目", null, "ACTIVE", false, "1", null, null, null, "main", null, null, null,
                        null, null));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MENU_CREATE,
                        Map.of("projectId", "91", "menuName", "审核菜单", "menuType", "DIR")),
                actor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "创建项目菜单 审核菜单", actor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        when(projects.createMenuForAgent(
                        eq("91"),
                        eq(request),
                        eq(new ProjectService.ProjectRenameExpectation("demo", "演示项目", "ACTIVE")),
                        eq(actor),
                        eq(METADATA)))
                .thenReturn(new ProjectMenuView(
                        "93", "91", null, "审核菜单", null, "DIR", null, null, null, null, 0, true, "ACTIVE", null, null,
                        null));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "创建项目菜单 审核菜单", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
    }

    @Test
    void projectMenuUpdateKeepsFrozenFullSnapshot() {
        service.localWriteHandlers(
                List.of(new ProjectMenuUpdateAgentWriteHandler(projects, validation.getValidator())));
        var actor = new KaiwuContext(
                "1",
                "session-1",
                null,
                null,
                Set.of("system:agent:ask", "system:project:menu"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "menu-update-jti");
        allow(actor);
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:menu"));
        var request = new com.kaiwu.module.project.dto.ProjectMenuRequest(
                null, "新审核菜单", null, "DIR", null, null, null, null, 0, true);
        var old = new ProjectMenuView(
                "93", "91", null, "旧审核菜单", null, "DIR", null, null, null, null, 0, true, "ACTIVE", null, null, null);
        when(projects.previewMenuUpdate("91", "93", request)).thenReturn(old);
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.PROJECT_MENU_UPDATE,
                        Map.of("projectId", "91", "targetMenuId", "93", "menuName", "新审核菜单", "menuType", "DIR")),
                actor,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("currentMenuName", "旧审核菜单");
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        when(projects.updateMenuForAgent(
                        eq("91"),
                        eq("93"),
                        eq(request),
                        eq(new ProjectService.ProjectMenuFullExpectation(
                                null, "旧审核菜单", null, "DIR", null, null, null, null, 0, true, "ACTIVE")),
                        eq(actor),
                        eq(METADATA)))
                .thenReturn(new ProjectMenuView(
                        "93", "91", null, "新审核菜单", null, "DIR", null, null, null, null, 0, true, "ACTIVE", null, null,
                        null));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), "编辑项目菜单 93 旧审核菜单", actor, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
    }

    @Test
    void userDisplayNameUpdatePreservesEmailAndChecksRealtimePermission() {
        UserRepository users = mock(UserRepository.class);
        UserService userService = mock(UserService.class);
        service.localWriteHandlers(List.of(new UserDisplayNameUpdateAgentWriteHandler(userService, users)));
        allow(USER_ACTOR);
        when(auth.findPermissions(USER_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:user:update"));
        when(users.findView("35"))
                .thenReturn(
                        Optional.of(new UserView("35", "alice", "旧名称", "alice@example.com", "ENABLED", null, null)));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_DISPLAY_NAME_UPDATE, Map.of("targetUserId", "35", "displayName", "新名称")),
                USER_ACTOR,
                METADATA);
        assertThat(preview.previewFields()).containsEntry("username", "alice").containsEntry("displayName", "新名称");
        verifyNoInteractions(userService);
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), USER_ACTOR, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(userService).updateDisplayNameForAgent("35", "新名称", "旧名称", USER_ACTOR, METADATA);

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_DISPLAY_NAME_UPDATE,
                        Map.of("targetUserId", "35", "displayName", "另一名称")),
                USER_ACTOR,
                METADATA);
        when(auth.findPermissions(USER_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), USER_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(userService, times(1)).updateDisplayNameForAgent(anyString(), anyString(), anyString(), any(), any());
    }

    @Test
    void userProfileUpdateConfirmsFullFieldsAndChecksRealtimePermission() {
        UserRepository users = mock(UserRepository.class);
        UserService userService = mock(UserService.class);
        service.localWriteHandlers(
                List.of(new UserProfileUpdateAgentWriteHandler(users, userService, validation.getValidator())));
        allow(USER_ACTOR);
        when(auth.findPermissions(USER_ACTOR.userId())).thenReturn(Set.of("system:agent:ask", "system:user:update"));
        when(users.findView("35"))
                .thenReturn(Optional.of(new UserView("35", "alice", "旧名称", "old@example.com", "ENABLED", null, null)));
        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_PROFILE_UPDATE,
                        Map.of("targetUserId", "35", "displayName", "新名称", "email", "")),
                USER_ACTOR,
                METADATA);
        assertThat(preview.previewFields())
                .containsEntry("currentEmail", "old@example.com")
                .containsEntry("email", "");
        verifyNoInteractions(userService);
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), USER_ACTOR, METADATA)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(userService)
                .updateProfileForAgent(
                        "35",
                        new com.kaiwu.module.user.dto.UserUpdateRequest("新名称", ""),
                        new UserService.UserProfileExpectation("alice", "旧名称", "old@example.com", "ENABLED"),
                        USER_ACTOR,
                        METADATA);

        var revoked = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_PROFILE_UPDATE,
                        Map.of("targetUserId", "35", "displayName", "另一个名称", "email", "")),
                USER_ACTOR,
                METADATA);
        when(auth.findPermissions(USER_ACTOR.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(revoked.actionId(), revoked.confirmationToken(), USER_ACTOR, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verify(userService, times(1)).updateProfileForAgent(anyString(), any(), any(), any(), any());
    }

    @Test
    void userStatusUpdatePreviewsTargetAndRequiresCurrentStatusPermission() {
        UserRepository users = mock(UserRepository.class);
        UserService userService = mock(UserService.class);
        service.localWriteHandlers(List.of(new UserStatusUpdateAgentWriteHandler(userService, users)));
        KaiwuContext statusActor = new KaiwuContext(
                "2",
                "status-session",
                null,
                null,
                Set.of("system:agent:ask", "system:user:status"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "status-jti");
        allow(statusActor);
        when(auth.findPermissions(statusActor.userId())).thenReturn(Set.of("system:agent:ask", "system:user:status"));
        when(users.findView("35"))
                .thenReturn(Optional.of(new UserView("35", "alice", "Alice", null, "ENABLED", null, null)));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_STATUS_UPDATE, Map.of("targetUserId", "35", "status", "DISABLED")),
                statusActor,
                METADATA);
        assertThat(preview.previewFields())
                .containsEntry("username", "alice")
                .containsEntry("currentStatus", "ENABLED")
                .containsEntry("status", "DISABLED");
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("停用 alice");
        verifyNoInteractions(userService);

        assertThatThrownBy(
                        () -> service.confirm(preview.actionId(), preview.confirmationToken(), statusActor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.BAD_REQUEST);
        verifyNoInteractions(userService);

        when(auth.findPermissions(statusActor.userId())).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(
                        preview.actionId(), preview.confirmationToken(), "停用 alice", statusActor, METADATA))
                .isInstanceOf(ApiException.class)
                .extracting("status")
                .isEqualTo(HttpStatus.FORBIDDEN);
        verifyNoInteractions(userService);

        when(auth.findPermissions(statusActor.userId())).thenReturn(Set.of("system:agent:ask", "system:user:status"));
        var done = service.confirm(preview.actionId(), preview.confirmationToken(), "停用 alice", statusActor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        verify(userService).updateStatus("35", "DISABLED", statusActor, METADATA);

        var enable = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_STATUS_UPDATE, Map.of("targetUserId", "35", "status", "ENABLED")),
                statusActor,
                METADATA);
        assertThat(enable.confirmationMode()).isEqualTo("REQUIRED");
        assertThat(enable.confirmationPhrase()).isNull();
        service.confirm(enable.actionId(), enable.confirmationToken(), statusActor, METADATA);
        verify(userService).updateStatus("35", "ENABLED", statusActor, METADATA);
    }

    @Test
    void userCreationReturnsPasswordOnlyOnceAndNeverStoresItInAction() {
        UserService users = mock(UserService.class);
        service.localWriteHandlers(List.of(new UserCreateAgentWriteHandler(users, validation.getValidator())));
        allow(USER_CREATE_ACTOR);
        when(auth.findPermissions(USER_CREATE_ACTOR.userId()))
                .thenReturn(Set.of("system:agent:ask", "system:user:create"));
        when(users.create(any(), eq(USER_CREATE_ACTOR), eq(METADATA)))
                .thenReturn(new UserView("77", "new.user", "新用户", "new@example.com", "ENABLED", null, null));

        var preview = service.preview(
                new AgentPlan.Call(
                        CapabilityCatalog.USER_CREATE,
                        Map.of("username", "new.user", "displayName", "新用户", "email", "new@example.com")),
                USER_CREATE_ACTOR,
                METADATA);
        assertThat(preview.oneTimeSecret()).isNull();
        assertThat(preview.previewFields()).containsEntry("username", "new.user");
        verifyNoInteractions(users);

        var confirmed = service.confirm(preview.actionId(), preview.confirmationToken(), USER_CREATE_ACTOR, METADATA);
        assertThat(confirmed.status()).isEqualTo("SUCCEEDED");
        assertThat(confirmed.oneTimeSecret()).hasSize(32);
        assertThat(redis.opsForValue().get("agent:action:" + preview.actionId()))
                .doesNotContain(confirmed.oneTimeSecret());
        assertThat(service.status(preview.actionId(), USER_CREATE_ACTOR).oneTimeSecret())
                .isNull();
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), USER_CREATE_ACTOR, METADATA)
                        .oneTimeSecret())
                .isNull();
        var request = org.mockito.ArgumentCaptor.forClass(UserCreateRequest.class);
        verify(users).create(request.capture(), eq(USER_CREATE_ACTOR), eq(METADATA));
        assertThat(request.getValue().password()).isEqualTo(confirmed.oneTimeSecret());
    }

    @Test
    void userPasswordResetRequiresStrongConfirmationAndReturnsSecretOnlyOnce() {
        UserRepository users = mock(UserRepository.class);
        UserService userService = mock(UserService.class);
        service.localWriteHandlers(List.of(new UserPasswordResetAgentWriteHandler(users, userService)));
        KaiwuContext resetActor = new KaiwuContext(
                "1",
                "reset-session",
                null,
                null,
                Set.of("system:agent:ask", "system:user:reset-password"),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                Instant.now(),
                Instant.now().plusSeconds(60),
                "reset-jti");
        allow(resetActor);
        when(auth.findPermissions(resetActor.userId()))
                .thenReturn(Set.of("system:agent:ask", "system:user:reset-password"));
        when(users.findView("35"))
                .thenReturn(
                        Optional.of(new UserView("35", "alice", "Alice", "alice@example.com", "ENABLED", null, null)));

        var preview = service.preview(
                new AgentPlan.Call(CapabilityCatalog.USER_PASSWORD_RESET, Map.of("targetUserId", "35")),
                resetActor,
                METADATA);
        assertThat(preview.confirmationMode()).isEqualTo("STRONG");
        assertThat(preview.confirmationPhrase()).isEqualTo("重置用户密码 alice");
        assertThat(preview.previewFields()).doesNotContainKey("email");
        verifyNoInteractions(userService);
        var done =
                service.confirm(preview.actionId(), preview.confirmationToken(), "重置用户密码 alice", resetActor, METADATA);
        assertThat(done.status()).isEqualTo("SUCCEEDED");
        assertThat(done.oneTimeSecret()).hasSize(32);
        assertThat(redis.opsForValue().get("agent:action:" + preview.actionId()))
                .doesNotContain(done.oneTimeSecret());
        assertThat(service.status(preview.actionId(), resetActor).oneTimeSecret())
                .isNull();
        var request = org.mockito.ArgumentCaptor.forClass(com.kaiwu.module.user.dto.ResetPasswordRequest.class);
        verify(userService)
                .resetPasswordForAgent(
                        eq("35"),
                        request.capture(),
                        eq(new UserService.UserResetExpectation("alice", "Alice", "ENABLED")),
                        eq(resetActor),
                        eq(METADATA));
        assertThat(request.getValue().newPassword()).isEqualTo(done.oneTimeSecret());
    }

    @Test
    void previewDoesNotCreateAndStoresOnlyDigestThenConfirmationReturnsProject() {
        var preview = preview();
        verifyNoInteractions(projects);
        assertThat(preview.project().packageName()).isEqualTo("com.kaiwu.business.orders");
        assertThat(preview.confirmationToken()).hasSize(43);
        String stored = redis.opsForValue().get("agent:action:" + preview.actionId());
        assertThat(stored).doesNotContain(preview.confirmationToken());
        assertThat(service.status(preview.actionId(), ACTOR).confirmationToken())
                .isNull();
        var result = service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA);
        assertThat(result.status()).isEqualTo("SUCCEEDED");
        assertThat(result.projectId()).isEqualTo("1789248125900000001");
        assertThat(result.confirmationToken()).isNull();
        service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA);
        verify(projects, times(1)).create(eq(preview.project()), eq(ACTOR), eq(METADATA));
        verify(audit)
                .recordOperation(
                        eq(ACTOR),
                        eq("agent"),
                        eq("ACTION_SUCCEEDED"),
                        anyString(),
                        contains(preview.actionId()),
                        eq(METADATA));
    }

    @Test
    void parallelConfirmationsCreateOnlyOnce() throws Exception {
        var preview = preview();
        try (var pool = Executors.newFixedThreadPool(8)) {
            var start = new CountDownLatch(1);
            List<Future<AgentActionView>> results = new ArrayList<>();
            for (int i = 0; i < 16; i++)
                results.add(pool.submit(() -> {
                    start.await();
                    return service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA);
                }));
            start.countDown();
            for (var result : results)
                assertThat(result.get(10, TimeUnit.SECONDS).status()).isIn("EXECUTING", "SUCCEEDED");
        }
        verify(projects, times(1)).create(any(), any(), any());
        assertThat(service.status(preview.actionId(), ACTOR).status()).isEqualTo("SUCCEEDED");
    }

    @Test
    void cancelAndConfirmRaceHasOnlyOneWinner() throws Exception {
        var preview = preview();
        try (var pool = Executors.newFixedThreadPool(2)) {
            var start = new CountDownLatch(1);
            var confirm = pool.submit(() -> {
                start.await();
                return service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA);
            });
            var cancel = pool.submit(() -> {
                start.await();
                return service.cancel(preview.actionId(), ACTOR, METADATA);
            });
            start.countDown();
            confirm.get(10, TimeUnit.SECONDS);
            cancel.get(10, TimeUnit.SECONDS);
        }
        String status = service.status(preview.actionId(), ACTOR).status();
        assertThat(status).isIn("CANCELLED", "SUCCEEDED");
        verify(projects, times(status.equals("SUCCEEDED") ? 1 : 0)).create(any(), any(), any());
    }

    @Test
    void wrongTokenUserOrSessionCannotConsumeAction() {
        var preview = preview();
        assertThatThrownBy(() -> service.confirm(preview.actionId(), "b".repeat(43), ACTOR, METADATA))
                .isInstanceOf(ApiException.class);
        var other = actor("2", "session-2");
        allow(other);
        assertThatThrownBy(() -> service.status(preview.actionId(), other)).isInstanceOf(ApiException.class);
        var relogin = actor("1", "session-new");
        allow(relogin);
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), relogin, METADATA))
                .isInstanceOf(ApiException.class);
        assertThat(service.status(preview.actionId(), ACTOR).status()).isEqualTo("PENDING");
        verifyNoInteractions(projects);
    }

    @Test
    void revokedPermissionOrSessionStopsBeforeCreation() {
        var preview = preview();
        when(auth.findPermissions("1")).thenReturn(Set.of("system:agent:ask"));
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA))
                .isInstanceOf(ApiException.class);
        allow(ACTOR);
        when(auth.findSession("session-1")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA))
                .isInstanceOf(ApiException.class);
        verifyNoInteractions(projects);
    }

    @Test
    void permissionRevokedAfterClaimStillStopsBeforeServiceCall() {
        var preview = preview();
        when(auth.findPermissions("1"))
                .thenReturn(Set.of("system:agent:ask", "system:project:create"), Set.of("system:agent:ask"));
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("FAILED");
        verifyNoInteractions(projects);
    }

    @Test
    void cancellationExpiryAndVersionChangeNeverExecute() {
        var cancelled = preview();
        service.cancel(cancelled.actionId(), ACTOR, METADATA);
        assertThat(service.confirm(cancelled.actionId(), cancelled.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("CANCELLED");
        var expired = preview();
        var old = store.get(expired.actionId());
        var past = new AgentActionRecord(
                old.actionId(),
                old.userId(),
                old.sessionId(),
                old.capabilityCode(),
                old.version(),
                old.planHash(),
                old.tokenHash(),
                old.project(),
                System.currentTimeMillis() - 1,
                0,
                "PENDING",
                null,
                null);
        assertThat(store.replace(old, past)).isTrue();
        assertThat(service.confirm(expired.actionId(), expired.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("EXPIRED");
        var changed = preview();
        doReturn(Optional.empty()).when(catalog).findVisible(CapabilityCatalog.PROJECT_CREATE, ACTOR);
        assertThat(service.confirm(changed.actionId(), changed.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("REJECTED");
        verifyNoInteractions(projects);
    }

    @Test
    void uncertainOutcomeAndKnownConflictCannotBeReplayed() {
        var unknown = preview();
        when(projects.create(any(), any(), any())).thenThrow(new IllegalStateException("internal secret"));
        assertThat(service.confirm(unknown.actionId(), unknown.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("UNKNOWN");
        service.confirm(unknown.actionId(), unknown.confirmationToken(), ACTOR, METADATA);
        verify(projects, times(1)).create(any(), any(), any());
        var conflict = preview();
        doThrow(new ApiException(HttpStatus.CONFLICT, "private", "api.common.conflict"))
                .when(projects)
                .create(any(), any(), any());
        var result = service.confirm(conflict.actionId(), conflict.confirmationToken(), ACTOR, METADATA);
        assertThat(result.status()).isEqualTo("FAILED");
        assertThat(result.reason()).isEqualTo("PROJECT_CONFLICT");
    }

    @Test
    void missingRedisStateNeverReconstructsOrCreatesProject() {
        var preview = preview();
        redis.delete("agent:action:" + preview.actionId());
        assertThatThrownBy(() -> service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA))
                .isInstanceOf(ApiException.class);
        verifyNoInteractions(projects);
    }

    @Test
    void invalidParametersNeverProducePreview() {
        for (var params : List.of(
                Map.<String, Object>of("projectCode", "system", "projectName", "Bad"),
                Map.<String, Object>of("projectCode", "orders", "projectName", 123),
                Map.<String, Object>of("projectCode", "bad code", "projectName", "Bad"),
                Map.<String, Object>of("projectCode", "orders", "projectName", "Bad", "userId", "2"))) {
            assertThatThrownBy(() -> service.preview(
                            new AgentPlan.Call(CapabilityCatalog.PROJECT_CREATE, params), ACTOR, METADATA))
                    .isInstanceOf(ApiException.class);
        }
        verifyNoInteractions(projects);
    }

    @Test
    void outcomePersistenceFailureDoesNotEnableAnotherCreation() {
        var preview = preview();
        doAnswer(invocation -> {
                    AgentActionRecord next = invocation.getArgument(1);
                    if ("SUCCEEDED".equals(next.status())) throw new IllegalStateException("Redis unavailable");
                    return invocation.callRealMethod();
                })
                .when(store)
                .replace(any(), any());
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("UNKNOWN");
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("EXECUTING");
        verify(projects, times(1)).create(any(), any(), any());
    }

    @Test
    void confirmationAuditFailureStopsCreationWithoutReplay() {
        var preview = preview();
        doThrow(new IllegalStateException("audit unavailable"))
                .when(audit)
                .recordOperation(any(), eq("agent"), eq("ACTION_CONFIRM"), anyString(), anyString(), any());
        assertThat(service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA)
                        .status())
                .isEqualTo("UNKNOWN");
        service.confirm(preview.actionId(), preview.confirmationToken(), ACTOR, METADATA);
        verifyNoInteractions(projects);
    }

    @Test
    void redisFailureFailsClosedBeforeExecutionAndDoesNotLeakDetails() {
        var broken = mock(StringRedisTemplate.class);
        when(broken.opsForValue()).thenThrow(new IllegalStateException("private redis endpoint"));
        var failing = new AgentActionStore(broken, JsonMapper.builder().build());
        assertThatThrownBy(() -> failing.get(UUID.randomUUID().toString()))
                .isInstanceOf(ApiException.class)
                .hasMessageNotContaining("private");
    }
}
