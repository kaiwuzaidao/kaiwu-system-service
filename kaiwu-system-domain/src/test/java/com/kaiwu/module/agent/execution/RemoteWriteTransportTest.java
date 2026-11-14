package com.kaiwu.module.agent.execution;

import static org.assertj.core.api.Assertions.*;

import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.identity.config.AuthProperties;
import com.kaiwu.starter.client.ServiceAddressResolver;
import com.sun.net.httpserver.HttpServer;
import io.jsonwebtoken.Jwts;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class RemoteWriteTransportTest {
    static KeyPair keys;
    private static final JsonMapper JSON = JsonMapper.builder().build();
    HttpServer gateway;
    RemoteWriteTransport transport;
    AtomicInteger calls = new AtomicInteger();
    AtomicInteger status = new AtomicInteger(200);
    AtomicReference<String> response = new AtomicReference<>("{\"state\":\"UNKNOWN\"}");

    @BeforeAll
    static void key() throws Exception {
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        keys = generator.generateKeyPair();
    }

    @BeforeEach
    void setup() throws Exception {
        gateway = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        gateway.createContext("/api/internal/agent/write-delegate", exchange -> {
            calls.incrementAndGet();
            byte[] body = exchange.getRequestBody().readAllBytes();
            var jwt = Jwts.parser()
                    .verifyWith(keys.getPublic())
                    .build()
                    .parseSignedClaims(exchange.getRequestHeaders()
                            .getFirst("Authorization")
                            .substring(7));
            assertThat(jwt.getHeader().getType()).isEqualTo("kaiwu-agent-write-delegation+jwt");
            assertThat(jwt.getPayload().getAudience()).containsExactly("kaiwu-gateway-agent-write");
            assertThat(jwt.getPayload().get("bodyHash"))
                    .isEqualTo(AgentManifestCodec.digest(new String(body, StandardCharsets.UTF_8)));
            var request = JSON.readTree(body);
            assertThat(request.path("operation").asString()).isEqualTo("PREVIEW");
            assertThat(request.has("userId")).isFalse();
            assertThat(request.has("targetUrl")).isFalse();
            byte[] bytes = response.get().getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status.get(), bytes.length);
            try (var output = exchange.getResponseBody()) {
                output.write(bytes);
            }
        });
        gateway.start();
        var props = new AgentRemoteProperties();
        props.setWriteEnabled(true);
        props.setGatewayBaseUrl("http://127.0.0.1:" + gateway.getAddress().getPort());
        var auth = new AuthProperties();
        auth.setAccessPrivateKey(
                Base64.getEncoder().encodeToString(keys.getPrivate().getEncoded()));
        transport = new RemoteWriteTransport(props, auth, ServiceAddressResolver.direct());
    }

    @AfterEach
    void stop() {
        transport.close();
        gateway.stop(0);
    }

    private RemoteWriteTransport.Request request() {
        return new RemoteWriteTransport.Request(
                "session-1",
                "PREVIEW",
                "crm.record.update",
                "1",
                "a".repeat(64),
                "{\"name\":\"新名称\"}",
                null,
                null,
                null,
                null,
                "corr-1");
    }

    @Test
    void signsExactBodyAndSendsOnlyOnce() {
        assertThat(new String(transport.send(request()), StandardCharsets.UTF_8))
                .isEqualTo("{\"state\":\"UNKNOWN\"}");
        assertThat(calls).hasValue(1);
    }

    @Test
    void nonSuccessNeverRedirectsOrRetries() {
        status.set(503);
        assertThatThrownBy(() -> transport.send(request())).isInstanceOf(IllegalStateException.class);
        assertThat(calls).hasValue(1);
    }

    @Test
    void responseBodyIsBounded() {
        response.set("x".repeat(70_000));
        assertThatThrownBy(() -> transport.send(request())).isInstanceOf(IllegalStateException.class);
        assertThat(calls).hasValue(1);
    }
}
