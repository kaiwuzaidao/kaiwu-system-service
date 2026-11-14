package com.kaiwu.module.agent.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentRemoteWriteAuthorizationRequest;
import com.kaiwu.module.agent.entity.AgentRemoteActionEntity;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.repository.AgentRemoteActionRepository;
import com.kaiwu.module.agent.service.impl.AgentRemoteActionServiceImpl;
import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.port.ProjectAgentAccessPort;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.time.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class AgentRemoteActionServiceTest {
    private final Clock clock = Clock.fixed(Instant.parse("2026-09-23T00:00:00Z"), ZoneOffset.UTC);
    private final AgentRemoteActionRepository repository = mock(AgentRemoteActionRepository.class);
    private final RemoteCapabilitySource source = mock(RemoteCapabilitySource.class);
    private final ProjectAgentAccessPort projects = mock(ProjectAgentAccessPort.class);
    private final ConfigEncryptionService encryption =
            new ConfigEncryptionService(Base64.getEncoder().encodeToString(new byte[32]));
    private final Map<String, AgentRemoteActionEntity> rows = new ConcurrentHashMap<>();
    private final ProjectAccessView access =
            new ProjectAccessView("123", "crm", List.of("record:record:update"), List.of("editor"));
    private final Capability capability = new Capability(
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
    private final KaiwuContext actor = new KaiwuContext(
            "100",
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
    private AgentRemoteActionService service;
    private String previewJson;

    @BeforeEach
    void setup() {
        service = new AgentRemoteActionServiceImpl(repository, source, projects, encryption, clock);
        previewJson = JsonMapper.builder()
                .build()
                .writeValueAsString(Map.of(
                        "displayFields",
                        Map.of("name", "新名称"),
                        "displayLabels",
                        Map.of("name", "客户单名称"),
                        "affectedCount",
                        1,
                        "preconditionsJson",
                        "{\"revision\":1}"));
        when(source.user("session-1")).thenReturn("100");
        when(source.authorizeWrite(eq(capability.code()), eq("1"), eq("a".repeat(64)), eq("session-1")))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.REQUIRED));
        when(projects.resolve("crm", "100")).thenReturn(Optional.of(access));
        doAnswer(call -> {
                    AgentRemoteActionEntity row = call.getArgument(0);
                    rows.put(row.getActionId(), row);
                    return null;
                })
                .when(repository)
                .create(any());
        when(repository.owned(anyString(), eq("100"), eq("session-1")))
                .thenAnswer(call -> Optional.ofNullable(rows.get(call.getArgument(0))));
        when(repository.claim(any(), any())).thenAnswer(call -> {
            AgentRemoteActionEntity row = call.getArgument(0);
            if (!"PENDING".equals(row.getStatus())) return false;
            row.setStatus("EXECUTING");
            row.setRevision(row.getRevision() + 1);
            return true;
        });
        when(repository.closePending(any(), anyString(), nullable(String.class), any()))
                .thenAnswer(call -> {
                    AgentRemoteActionEntity row = call.getArgument(0);
                    if (!"PENDING".equals(row.getStatus())) return false;
                    row.setStatus(call.getArgument(1));
                    return true;
                });
        when(repository.complete(any(), anyString(), nullable(String.class), nullable(String.class), any()))
                .thenAnswer(call -> {
                    AgentRemoteActionEntity row = call.getArgument(0);
                    row.setStatus(call.getArgument(1));
                    row.setResultCiphertext(call.getArgument(2));
                    row.setReasonCode(call.getArgument(3));
                    return true;
                });
        when(repository.markUnknown(any(), any(), any())).thenAnswer(call -> {
            AgentRemoteActionEntity row = call.getArgument(0);
            if (!"EXECUTING".equals(row.getStatus())) return false;
            row.setStatus("UNKNOWN");
            row.setRevision(row.getRevision() + 1);
            return true;
        });
        when(repository.reconcile(any(), eq("SUCCEEDED"), anyString(), nullable(String.class), any()))
                .thenAnswer(call -> {
                    AgentRemoteActionEntity row = call.getArgument(0);
                    if (!"UNKNOWN".equals(row.getStatus())) return false;
                    row.setStatus("SUCCEEDED");
                    row.setResultCiphertext(call.getArgument(2));
                    return true;
                });
    }

    private AgentRemoteActionService.Pending pending() {
        return service.prepare(
                capability.code(),
                "1",
                "a".repeat(64),
                "{\"name\":\"新名称\"}",
                "{\"revision\":1}",
                previewJson,
                "corr-1",
                actor);
    }

    @Test
    void freezesEncryptedPreviewAndClaimsOnlyOnce() {
        var pending = pending();
        AgentRemoteActionEntity row = rows.get(pending.actionId());
        assertThat(row.getFrozenCiphertext()).startsWith("v1:").doesNotContain("新名称");
        assertThat(row.getTokenHash()).doesNotContain(pending.confirmationToken());
        assertThat(pending.preview().displayFields()).containsEntry("name", "新名称");
        assertThat(pending.preview().displayLabels()).containsEntry("name", "客户单名称");
        assertThat(pending.preview().toString()).doesNotContain("revision");
        assertThat(JsonMapper.builder().build().writeValueAsString(pending))
                .doesNotContain("preconditionsJson", "revision");
        assertThat(service.status(pending.actionId(), actor).status()).isEqualTo("PENDING");
        assertThatThrownBy(() -> service.confirm(pending.actionId(), "bad", null, actor))
                .isInstanceOf(RuntimeException.class);
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        assertThat(claimed.actionId()).isEqualTo(pending.actionId());
        assertThat(claimed.paramsJson()).isEqualTo("{\"name\":\"新名称\"}");
        assertThat(claimed.correlationId()).isEqualTo("corr-1");
        assertThat(service.status(pending.actionId(), actor).status()).isEqualTo("EXECUTING");
        assertThat(service.status(pending.actionId(), actor).preview().toString())
                .doesNotContain("revision");
        assertThatThrownBy(() -> service.confirm(pending.actionId(), pending.confirmationToken(), null, actor))
                .isInstanceOf(RuntimeException.class);
        verify(repository, times(1)).claim(any(), any());
    }

    @Test
    void cancelWinsOverConfirmAndCrossSessionCannotObserve() {
        var pending = pending();
        assertThat(service.cancel(pending.actionId(), actor).status()).isEqualTo("CANCELLED");
        assertThatThrownBy(() -> service.confirm(pending.actionId(), pending.confirmationToken(), null, actor))
                .isInstanceOf(RuntimeException.class);
        verify(repository, never()).claim(any(), any());
        var other = new KaiwuContext(
                "100",
                "other-session",
                null,
                null,
                Set.of(),
                Set.of(),
                null,
                "kaiwu-system-service",
                clock.instant(),
                clock.instant().plusSeconds(60),
                "context-2");
        assertThatThrownBy(() -> service.status(pending.actionId(), other)).isInstanceOf(RuntimeException.class);
    }

    @Test
    void swappedCiphertextAndChangedPermissionFailClosed() {
        var first = pending();
        var second = pending();
        rows.get(first.actionId())
                .setFrozenCiphertext(rows.get(second.actionId()).getFrozenCiphertext());
        assertThatThrownBy(() -> service.status(first.actionId(), actor)).isInstanceOf(IllegalStateException.class);
        rows.get(first.actionId())
                .setFrozenCiphertext(rows.get(second.actionId()).getFrozenCiphertext());
        when(projects.resolve("crm", "100"))
                .thenReturn(Optional.of(new ProjectAccessView("123", "crm", List.of(), List.of())));
        assertThatThrownBy(() -> service.status(second.actionId(), actor)).isInstanceOf(RuntimeException.class);
    }

    @Test
    void revocationAfterClaimPreventsDispatch() {
        var pending = pending();
        when(source.authorizeWrite(eq(capability.code()), eq("1"), eq("a".repeat(64)), eq("session-1")))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.REQUIRED))
                .thenThrow(new PlanRejectedException(3, "revoked"));
        assertThatThrownBy(() -> service.confirm(pending.actionId(), pending.confirmationToken(), null, actor))
                .isInstanceOf(RuntimeException.class);
        assertThat(rows.get(pending.actionId()).getStatus()).isEqualTo("FAILED");
        verify(repository).complete(any(), eq("FAILED"), isNull(), eq("ACCESS_CHANGED_BEFORE_DISPATCH"), any());
    }

    @Test
    void rejectsForgedParametersAndUnsafePreviewBeforeCreatingAction() {
        assertThatThrownBy(() -> service.prepare(
                        capability.code(),
                        "1",
                        "a".repeat(64),
                        "{\"userId\":\"other\"}",
                        "{\"revision\":1}",
                        previewJson,
                        "corr-1",
                        actor))
                .isInstanceOf(RuntimeException.class);
        String unsafe = JsonMapper.builder()
                .build()
                .writeValueAsString(Map.of(
                        "displayFields",
                        Map.of("name", "<script>"),
                        "affectedCount",
                        1,
                        "preconditionsJson",
                        "{\"revision\":1}"));
        assertThatThrownBy(() -> service.prepare(
                        capability.code(),
                        "1",
                        "a".repeat(64),
                        "{\"name\":\"新名称\"}",
                        "{\"revision\":1}",
                        unsafe,
                        "corr-1",
                        actor))
                .isInstanceOf(RuntimeException.class);
        assertThat(rows).isEmpty();
    }

    @Test
    void strongConfirmationRequiresManualPhraseBoundToPreview() {
        when(source.authorizeWrite(eq(capability.code()), eq("1"), eq("a".repeat(64)), eq("session-1")))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.STRONG));
        var pending = pending();
        assertThatThrownBy(() -> service.confirm(pending.actionId(), pending.confirmationToken(), "确认", actor))
                .isInstanceOf(RuntimeException.class);
        assertThat(service.confirm(pending.actionId(), pending.confirmationToken(), pending.confirmationPhrase(), actor)
                        .actionId())
                .isEqualTo(pending.actionId());
    }

    private AgentRemoteWriteAuthorizationRequest delegation(
            String operation, AgentRemoteActionService.Claimed claimed) {
        AgentRemoteActionEntity row = rows.get(claimed.actionId());
        return new AgentRemoteWriteAuthorizationRequest(
                "session-1",
                operation,
                claimed.capabilityCode(),
                claimed.version(),
                claimed.manifestHash(),
                row.getParamsHash(),
                row.getPreconditionsHash(),
                claimed.previewHash(),
                claimed.actionId(),
                claimed.expiresAtMillis(),
                claimed.correlationId());
    }

    @Test
    void gatewayExecuteRequiresClaimAndEveryFrozenBinding() {
        var pending = pending();
        var row = rows.get(pending.actionId());
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        var request = delegation("EXECUTE", claimed);
        assertThat(service.authorizeDelegation(request, "100").access()).isEqualTo(access);

        assertThatThrownBy(() -> service.authorizeDelegation(request, "other")).isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> service.authorizeDelegation(
                        new AgentRemoteWriteAuthorizationRequest(
                                "other-session",
                                "EXECUTE",
                                request.code(),
                                request.version(),
                                request.manifestHash(),
                                request.paramsHash(),
                                request.preconditionsHash(),
                                request.previewHash(),
                                request.actionId(),
                                request.actionExpiresAt(),
                                request.correlationId()),
                        "100"))
                .isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> service.authorizeDelegation(
                        new AgentRemoteWriteAuthorizationRequest(
                                request.sessionId(),
                                "EXECUTE",
                                request.code(),
                                request.version(),
                                request.manifestHash(),
                                "f".repeat(64),
                                request.preconditionsHash(),
                                request.previewHash(),
                                request.actionId(),
                                request.actionExpiresAt(),
                                request.correlationId()),
                        "100"))
                .isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> service.authorizeDelegation(
                        new AgentRemoteWriteAuthorizationRequest(
                                request.sessionId(),
                                "EXECUTE",
                                request.code(),
                                request.version(),
                                request.manifestHash(),
                                request.paramsHash(),
                                request.preconditionsHash(),
                                request.previewHash(),
                                request.actionId(),
                                request.actionExpiresAt(),
                                "forged"),
                        "100"))
                .isInstanceOf(RuntimeException.class);
        row.setStatus("UNKNOWN");
        assertThatThrownBy(() -> service.authorizeDelegation(request, "100")).isInstanceOf(RuntimeException.class);
    }

    @Test
    void resultQueryRemainsAvailableAfterWriteFlagOffButNeedsCurrentMembership() {
        var pending = pending();
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        rows.get(pending.actionId()).setStatus("UNKNOWN");
        var request = delegation("RESULT", claimed);
        when(source.authorizeWrite(anyString(), anyString(), anyString(), anyString()))
                .thenThrow(new PlanRejectedException(3, "disabled"));
        assertThat(service.authorizeDelegation(request, "100").access()).isEqualTo(access);
        when(projects.resolve("crm", "100")).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.authorizeDelegation(request, "100")).isInstanceOf(RuntimeException.class);
    }

    @Test
    void persistedSuccessIsBoundToActionAndOnlyApprovedFields() {
        var pending = pending();
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        byte[] response = "{\"state\":\"SUCCEEDED\",\"result\":{\"name\":\"新名称\"}}"
                .getBytes(java.nio.charset.StandardCharsets.UTF_8);
        var state = service.acceptResult(claimed, response, actor);
        assertThat(state.status()).isEqualTo("SUCCEEDED");
        assertThat(state.result()).containsEntry("name", "新名称");
        assertThat(rows.get(pending.actionId()).getResultCiphertext())
                .startsWith("v1:")
                .doesNotContain("新名称");
        var second = pending();
        rows.get(second.actionId()).setStatus("SUCCEEDED");
        rows.get(second.actionId())
                .setResultCiphertext(rows.get(pending.actionId()).getResultCiphertext());
        assertThatThrownBy(() -> service.status(second.actionId(), actor)).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void uncertainExecutionOnlyQueriesLedgerAndCanReconcile() {
        var pending = pending();
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        assertThat(service.markUnknown(claimed, actor).status()).isEqualTo("UNKNOWN");
        assertThat(service.queryBinding(pending.actionId(), actor)).isEqualTo(claimed);
        assertThat(service.acceptResult(claimed, "{\"state\":\"UNKNOWN\"}".getBytes(), actor)
                        .status())
                .isEqualTo("UNKNOWN");
        assertThat(service.acceptResult(
                                claimed, "{\"state\":\"SUCCEEDED\",\"result\":{\"name\":\"核实成功\"}}".getBytes(), actor)
                        .status())
                .isEqualTo("SUCCEEDED");
        verify(repository, never()).claim(argThat(row -> "UNKNOWN".equals(row.getStatus())), any());
    }

    @Test
    void unsafeBusinessResultCannotBecomeSuccess() {
        var pending = pending();
        var claimed = service.confirm(pending.actionId(), pending.confirmationToken(), null, actor);
        assertThatThrownBy(() -> service.acceptResult(
                        claimed, "{\"state\":\"SUCCEEDED\",\"result\":{\"secret\":\"x\"}}".getBytes(), actor))
                .isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> service.acceptResult(
                        claimed, "{\"state\":\"SUCCEEDED\",\"result\":{\"name\":\"<script>\"}}".getBytes(), actor))
                .isInstanceOf(RuntimeException.class);
        assertThat(rows.get(pending.actionId()).getStatus()).isEqualTo("EXECUTING");
    }
}
