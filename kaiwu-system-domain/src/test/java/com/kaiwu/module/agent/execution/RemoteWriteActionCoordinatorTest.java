package com.kaiwu.module.agent.execution;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.ParamSpec;
import com.kaiwu.module.agent.service.AgentRemoteActionService;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class RemoteWriteActionCoordinatorTest {
    private final RemoteCapabilitySource source = mock(RemoteCapabilitySource.class);
    private final AgentRemoteActionService actions = mock(AgentRemoteActionService.class);
    private final RemoteWriteTransport transport = mock(RemoteWriteTransport.class);
    private final AuditPort audit = mock(AuditPort.class);
    private final KaiwuContext actor = com.kaiwu.testing.AgentTestFixtures.actor("user-1", "session-1");
    private final RequestMetadata metadata = new RequestMetadata("127.0.0.1", "test");
    private RemoteWriteActionCoordinator coordinator;

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
    private final ProjectAccessView access =
            new ProjectAccessView("123", "crm", List.of("record:record:update"), List.of("editor"));

    @BeforeEach
    void setup() {
        coordinator = new RemoteWriteActionCoordinator(source, actions, transport, audit);
    }

    @Test
    void previewFreezesOnlyTheActualHandlerResponse() {
        when(source.visibleWriteRevision(capability.code(), actor))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.REQUIRED));
        String business = "{\"displayFields\":{\"name\":\"新名称\"},\"affectedCount\":1,"
                + "\"preconditionsJson\":\"{\\\"revision\\\":1}\"}";
        when(transport.send(any())).thenReturn(business.getBytes(StandardCharsets.UTF_8));
        when(actions.prepare(
                        anyString(),
                        anyString(),
                        anyString(),
                        anyString(),
                        anyString(),
                        anyString(),
                        eq("corr-1"),
                        eq(actor)))
                .thenReturn(new AgentRemoteActionService.Pending(
                        "action-1",
                        "one-time-token",
                        "确认 12345678",
                        new AgentRemoteActionService.PreviewView(Map.of("name", "新名称"), 1),
                        Instant.now().plusSeconds(300)));
        var view = coordinator.preview(
                new AgentPlan.Call(capability.code(), Map.of("name", "新名称")), actor, metadata, "corr-1");
        assertThat(view.status()).isEqualTo("PENDING");
        assertThat(view.confirmationToken()).isEqualTo("one-time-token");
        ArgumentCaptor<RemoteWriteTransport.Request> request =
                ArgumentCaptor.forClass(RemoteWriteTransport.Request.class);
        verify(transport).send(request.capture());
        assertThat(request.getValue().operation()).isEqualTo("PREVIEW");
        assertThat(request.getValue().actionId()).isNull();
        verify(actions)
                .prepare(
                        eq(capability.code()),
                        eq("1"),
                        eq("a".repeat(64)),
                        anyString(),
                        eq("{\"revision\":1}"),
                        eq(business),
                        eq("corr-1"),
                        eq(actor));
    }

    @Test
    void uncertainConfirmationNeverRetriesExecute() {
        var claimed = new AgentRemoteActionService.Claimed(
                "9ff3e37c-a5bb-4b0e-8a3f-94f5ab9e894b",
                "123",
                "crm",
                capability.code(),
                "1",
                "a".repeat(64),
                "{\"name\":\"新名称\"}",
                "{\"revision\":1}",
                "b".repeat(64),
                Instant.now().plusSeconds(300).toEpochMilli(),
                "corr-1");
        when(actions.confirm(claimed.actionId(), "token", null, actor)).thenReturn(claimed);
        when(transport.send(any())).thenThrow(new IllegalStateException("connection lost"));
        when(actions.markUnknown(claimed, actor))
                .thenReturn(new AgentRemoteActionService.State(
                        claimed.actionId(),
                        "123",
                        "crm",
                        capability.code(),
                        "测试写能力",
                        "1",
                        "UNKNOWN",
                        "REQUIRED",
                        new AgentRemoteActionService.PreviewView(Map.of("name", "新名称"), 1),
                        Instant.now().plusSeconds(300),
                        "UNKNOWN_OUTCOME",
                        null));
        var view = coordinator.confirm(claimed.actionId(), "token", null, actor, metadata);
        assertThat(view.status()).isEqualTo("UNKNOWN");
        ArgumentCaptor<RemoteWriteTransport.Request> request =
                ArgumentCaptor.forClass(RemoteWriteTransport.Request.class);
        verify(transport, times(1)).send(request.capture());
        assertThat(request.getValue().operation()).isEqualTo("EXECUTE");
        verify(actions, times(1)).confirm(claimed.actionId(), "token", null, actor);
    }

    @Test
    void unknownStatusOnlyQueriesResultLedger() {
        var claimed = new AgentRemoteActionService.Claimed(
                "9ff3e37c-a5bb-4b0e-8a3f-94f5ab9e894b",
                "123",
                "crm",
                capability.code(),
                "1",
                "a".repeat(64),
                "{}",
                "{}",
                "b".repeat(64),
                Instant.now().minusSeconds(60).toEpochMilli(),
                "corr-1");
        var state = new AgentRemoteActionService.State(
                claimed.actionId(),
                "123",
                "crm",
                capability.code(),
                "测试写能力",
                "1",
                "UNKNOWN",
                "REQUIRED",
                new AgentRemoteActionService.PreviewView(Map.of(), 1),
                Instant.now().minusSeconds(60),
                "UNKNOWN_OUTCOME",
                null);
        when(actions.status(claimed.actionId(), actor)).thenReturn(state);
        when(actions.queryBinding(claimed.actionId(), actor)).thenReturn(claimed);
        when(transport.send(any())).thenReturn("{\"state\":\"UNKNOWN\"}".getBytes(StandardCharsets.UTF_8));
        when(actions.acceptResult(eq(claimed), any(), eq(actor))).thenReturn(state);
        assertThat(coordinator.status(claimed.actionId(), actor).status()).isEqualTo("UNKNOWN");
        ArgumentCaptor<RemoteWriteTransport.Request> request =
                ArgumentCaptor.forClass(RemoteWriteTransport.Request.class);
        verify(transport).send(request.capture());
        assertThat(request.getValue().operation()).isEqualTo("RESULT");
        verify(actions, never()).confirm(anyString(), anyString(), any(), any());
    }
}
