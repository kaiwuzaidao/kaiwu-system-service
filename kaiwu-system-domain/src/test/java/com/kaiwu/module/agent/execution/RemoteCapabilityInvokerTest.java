package com.kaiwu.module.agent.execution;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.presentation.CardProjection;
import com.kaiwu.module.agent.presentation.ResultProjector;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.DataScope;
import com.kaiwu.module.agent.protocol.RedactRule;
import com.kaiwu.module.identity.config.AuthProperties;
import com.kaiwu.module.project.vo.ProjectAccessView;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.client.ServiceAddressResolver;
import com.sun.net.httpserver.HttpServer;
import io.jsonwebtoken.Jwts;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.*;
import tools.jackson.databind.json.JsonMapper;

class RemoteCapabilityInvokerTest {
    static KeyPair keys;
    static final JsonMapper JSON = JsonMapper.builder().build();
    HttpServer gateway;
    RemoteCapabilityInvoker client;
    RemoteCapabilitySource source;
    Capability capability;
    KaiwuContext actor = com.kaiwu.testing.AgentTestFixtures.actor("user-1", "session-1");
    AtomicInteger calls = new AtomicInteger(), status = new AtomicInteger(200);
    AtomicReference<String> response =
            new AtomicReference<>("{\"rows\":[{\"title\":\"安全输出\",\"id\":\"123\",\"secret\":\"must-not-leak\"}]}");

    @BeforeAll
    static void key() throws Exception {
        var g = KeyPairGenerator.getInstance("RSA");
        g.initialize(2048);
        keys = g.generateKeyPair();
    }

    @BeforeEach
    void setup() throws Exception {
        var m = com.kaiwu.testing.AgentTestFixtures.manifest("1");
        capability = new Capability(
                m.projectCode(),
                m.code(),
                m.version(),
                m.description(),
                m.permission(),
                m.dataScope(),
                m.params(),
                m.outboundFields(),
                m.redact(),
                true,
                true,
                true);
        source = mock(RemoteCapabilitySource.class);
        when(source.findVisible(capability.code(), actor)).thenReturn(Optional.of(capability));
        when(source.visibleRevision(capability.code(), actor))
                .thenReturn(new RemoteCapabilitySource.Approved(
                        capability,
                        "a".repeat(64),
                        1000,
                        new ProjectAccessView("123", "crm", List.of(m.permission()), List.of("reader"))));
        gateway = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        gateway.createContext("/api/internal/agent/delegate", exchange -> {
            calls.incrementAndGet();
            byte[] body = exchange.getRequestBody().readAllBytes();
            var claims = Jwts.parser()
                    .verifyWith(keys.getPublic())
                    .build()
                    .parseSignedClaims(exchange.getRequestHeaders()
                            .getFirst("Authorization")
                            .substring(7));
            assertThat(claims.getHeader().getType()).isEqualTo("kaiwu-agent-delegation+jwt");
            assertThat(claims.getPayload().getAudience()).containsExactly("kaiwu-gateway-agent");
            assertThat(claims.getPayload().getSubject()).isEqualTo("kaiwu-system-service");
            assertThat(claims.getPayload().get("bodyHash"))
                    .isEqualTo(AgentManifestCodec.digest(new String(body, StandardCharsets.UTF_8)));
            var request = JSON.readTree(body);
            assertThat(request.path("sessionId").asString()).isEqualTo("session-1");
            assertThat(request.has("userId")).isFalse();
            assertThat(request.has("targetUrl")).isFalse();
            byte[] bytes = response.get().getBytes(StandardCharsets.UTF_8);
            if (status.get() == 302)
                exchange.getResponseHeaders()
                        .add(
                                "Location",
                                "http://127.0.0.1:" + gateway.getAddress().getPort() + "/redirect");
            exchange.sendResponseHeaders(status.get(), bytes.length);
            try (var out = exchange.getResponseBody()) {
                out.write(bytes);
            }
        });
        gateway.start();
        var props = new AgentRemoteProperties();
        props.setEnabled(true);
        props.setGatewayBaseUrl("http://127.0.0.1:" + gateway.getAddress().getPort());
        var auth = new AuthProperties();
        auth.setAccessPrivateKey(
                Base64.getEncoder().encodeToString(keys.getPrivate().getEncoded()));
        client = new RemoteCapabilityInvoker(props, source, auth, ServiceAddressResolver.direct());
    }

    @AfterEach
    void stop() {
        client.close();
        gateway.stop(0);
    }

    @Test
    void signsBoundServiceRequestAndWhitelistsResponse() {
        var result = client.invoke(capability, Map.of("pageSize", 20), actor);
        assertThat(result.succeeded()).isTrue();
        assertThat(result.rows().getFirst()).containsEntry("title", "安全输出").doesNotContainKey("secret");
        assertThat(result.sourceProjects()).containsExactly("123");
        assertThat(calls).hasValue(1);
    }

    @Test
    void neverCallsAfterPermissionRemovalOrVersionChange() {
        when(source.findVisible(capability.code(), actor)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor)).isInstanceOf(PlanRejectedException.class);
        assertThat(calls).hasValue(0);
    }

    @Test
    void redirectsAreNotFollowedAndErrorsAreNotReturnedAsData() {
        status.set(302);
        assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor)).isInstanceOf(IllegalStateException.class);
        assertThat(calls).hasValue(1);
        status.set(500);
        response.set("{\"stack\":\"sensitive\"}");
        assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor)).hasMessageNotContaining("sensitive");
    }

    @Test
    void gatewayPermissionDenialIsReturnedAsDenialWithoutResponseBody() {
        status.set(403);
        response.set("{\"secret\":\"must-not-leak\"}");

        assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor))
                .isInstanceOf(PlanRejectedException.class)
                .hasMessage("无权限操作");
        assertThat(calls).hasValue(1);
    }

    @Test
    void gatewayAuthenticationFailureIsNotMisreportedAsMissingPermission() {
        status.set(401);

        assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageNotContaining("无权限操作");
    }

    @Test
    void refusesOversizedNestedDuplicateAndUnexpectedResponses() {
        for (String invalid : List.of(
                "{\"rows\":[],\"secret\":1}",
                "{\"rows\":[{\"title\":{\"sql\":\"bad\"}}]}",
                "{\"rows\":[],\"rows\":[]}",
                "{\"rows\":[{\"title\":\"" + "x".repeat(300000) + "\"}]}")) {
            response.set(invalid);
            assertThatThrownBy(() -> client.invoke(capability, Map.of(), actor)).isInstanceOf(RuntimeException.class);
        }
    }

    @Test
    void browserProjectionAlsoWhitelistsAndRedactsRemoteRows() {
        var masked = new Capability(
                capability.projectCode(),
                capability.code(),
                "1",
                "records",
                capability.permission(),
                DataScope.SELF,
                Map.of(),
                Set.of("title"),
                Map.of("title", RedactRule.MASK),
                true,
                true,
                true);
        var card = new ResultProjector()
                .toCard(masked, "records", List.of(Map.of("title", "private", "secret", "hidden")), List.of("123"));
        assertThat(card.rows().getFirst())
                .containsExactlyInAnyOrderEntriesOf(Map.of("title", "***", CardProjection.SOURCE_PROJECT_ID, "123"));
    }
}
