package com.kaiwu.module.agent.controller;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentRemoteWriteAuthorizationRequest;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.service.AgentRemoteActionService;
import com.kaiwu.module.project.config.GatewayAccessProperties;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.port.agent.protocol.ConfirmationMode;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import tools.jackson.databind.json.JsonMapper;

class InternalAgentWriteAuthorizationControllerTest {
    private final GatewayAccessProperties gateway = new GatewayAccessProperties();
    private final RemoteCapabilitySource source = mock(RemoteCapabilitySource.class);
    private final AgentRemoteActionService actions = mock(AgentRemoteActionService.class);
    private final ProjectAccessView access =
            new ProjectAccessView("123", "crm", List.of("record:update"), List.of("editor"));
    private final JsonMapper json = JsonMapper.builder().build();
    private InternalAgentWriteAuthorizationController controller;

    @BeforeEach
    void setup() {
        gateway.setInternalToken("internal-secret");
        controller = new InternalAgentWriteAuthorizationController(gateway, source, actions);
        when(source.user("session-1")).thenReturn("100");
    }

    private MockHttpServletRequest request(Object body, String token) {
        var http = new MockHttpServletRequest("POST", "/api/internal/gateway/agent-write-access");
        http.setContent(json.writeValueAsBytes(body));
        if (token != null) http.addHeader("X-Kaiwu-Internal-Token", token);
        return http;
    }

    private AgentRemoteWriteAuthorizationRequest preview() {
        return new AgentRemoteWriteAuthorizationRequest(
                "session-1",
                "PREVIEW",
                "crm.record.update",
                "1",
                "a".repeat(64),
                "b".repeat(64),
                null,
                null,
                null,
                null,
                "corr-1");
    }

    @Test
    void previewAuthorizesWriteManifestButNeverConfirms() throws Exception {
        var capability = mock(Capability.class);
        when(source.authorizeWrite("crm.record.update", "1", "a".repeat(64), "session-1"))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.REQUIRED));
        var view = controller.authorize(request(preview(), "internal-secret")).data();
        assertThat(view.confirmed()).isFalse();
        assertThat(view.operation()).isEqualTo("PREVIEW");
        assertThat(view.projectId()).isEqualTo("123");
        verifyNoInteractions(actions);
    }

    /** 项目快照带数据范围时 Agent 写授权原样带出，没有时不出现该键（docs/DATA_SCOPE.md §5）。 */
    @Test
    void previewCarriesDataScopeFromProjectAccessAndOmitsItWhenAbsent() throws Exception {
        var scope = new com.kaiwu.module.project.vo.DataScopeView(
                1,
                "101",
                List.of("101"),
                Map.of("crm:customer", com.kaiwu.module.project.vo.DataScopeRuleView.departments(List.of(0))),
                "0123456789abcdef");
        var scoped = new ProjectAccessView("123", "crm", List.of("record:update"), List.of("editor"), scope);
        var capability = mock(Capability.class);
        when(source.authorizeWrite("crm.record.update", "1", "a".repeat(64), "session-1"))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, scoped, ConfirmationMode.REQUIRED));
        var view = controller.authorize(request(preview(), "internal-secret")).data();
        assertThat(view.dataScope()).isSameAs(scope);
        assertThat(json.writeValueAsString(view)).contains("\"dataScope\":{\"v\":1");

        when(source.authorizeWrite("crm.record.update", "1", "a".repeat(64), "session-1"))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability, "a".repeat(64), 1000, access, ConfirmationMode.REQUIRED));
        var plain = controller.authorize(request(preview(), "internal-secret")).data();
        assertThat(json.writeValueAsString(plain)).doesNotContain("dataScope");
    }

    @Test
    void callerCannotForgeConfirmationOrUseReadAuthorization() {
        assertThatThrownBy(() -> controller.authorize(request(preview(), "wrong")))
                .isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> controller.authorize(request(
                        Map.of(
                                "sessionId",
                                "session-1",
                                "operation",
                                "PREVIEW",
                                "code",
                                "crm.record.update",
                                "version",
                                "1",
                                "manifestHash",
                                "a".repeat(64),
                                "paramsHash",
                                "b".repeat(64),
                                "correlationId",
                                "corr-1",
                                "confirmed",
                                true),
                        "internal-secret")))
                .isInstanceOf(RuntimeException.class);
        assertThatThrownBy(() -> controller.authorize(request(
                        new AgentRemoteWriteAuthorizationRequest(
                                "session-1",
                                "EXECUTE",
                                "crm.record.update",
                                "1",
                                "a".repeat(64),
                                "b".repeat(64),
                                "c".repeat(64),
                                "d".repeat(64),
                                "9ff3e37c-a5bb-4b0e-8a3f-94f5ab9e894b",
                                1000L,
                                "corr-1"),
                        "internal-secret")))
                .isInstanceOf(RuntimeException.class);
        verify(actions).authorizeDelegation(any(), eq("100"));
    }

    @Test
    void executeCanOnlyBeConfirmedByActionService() throws Exception {
        var write = new AgentRemoteWriteAuthorizationRequest(
                "session-1",
                "EXECUTE",
                "crm.record.update",
                "1",
                "a".repeat(64),
                "b".repeat(64),
                "c".repeat(64),
                "d".repeat(64),
                "9ff3e37c-a5bb-4b0e-8a3f-94f5ab9e894b",
                1000L,
                "corr-1");
        when(actions.authorizeDelegation(eq(write), eq("100")))
                .thenReturn(new AgentRemoteActionService.Delegation("100", access, 1000));
        var view = controller.authorize(request(write, "internal-secret")).data();
        assertThat(view.confirmed()).isTrue();
        assertThat(view.actionId()).isEqualTo(write.actionId());
        verify(actions).authorizeDelegation(write, "100");
    }
}
