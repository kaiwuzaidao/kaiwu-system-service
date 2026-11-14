package com.kaiwu.module.agent.execution;

import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.identity.config.AuthProperties;
import com.kaiwu.starter.client.ServiceAddress;
import com.kaiwu.starter.client.ServiceAddressResolver;
import io.jsonwebtoken.Jwts;
import jakarta.annotation.PreDestroy;
import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Flow;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/** System 到 Gateway 的固定写调用传输；每次只发送一次，调用方负责 UNKNOWN 对账。 */
@Component
public class RemoteWriteTransport {
    private static final int MAX_RESPONSE_BYTES = 65_536;
    private static final JsonMapper JSON = JsonMapper.builder().build();

    public record Request(
            String sessionId,
            String operation,
            String code,
            String version,
            String manifestHash,
            String paramsJson,
            String preconditionsJson,
            String previewHash,
            String actionId,
            Long actionExpiresAt,
            String correlationId) {
        @Override
        public String toString() {
            return "RemoteWriteTransport.Request[redacted]";
        }
    }

    private final AgentRemoteProperties properties;
    private final AuthProperties auth;
    private final ServiceAddressResolver resolver;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();

    public RemoteWriteTransport(
            AgentRemoteProperties properties, AuthProperties auth, ServiceAddressResolver resolver) {
        this.properties = properties;
        this.auth = auth;
        this.resolver = resolver;
        if (properties.isWriteEnabled()) target();
    }

    /** 原样返回业务 Handler 的受限 JSON；非 200、断线和超时都不推测业务写是否已提交。 */
    public byte[] send(Request invocation) {
        byte[] body = JSON.writeValueAsBytes(invocation);
        if (body.length > 65_536) throw new IllegalArgumentException("Agent write request too large");
        var request = HttpRequest.newBuilder(target())
                .timeout(Duration.ofSeconds(15))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + assertion(body))
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .build();
        CompletableFuture<HttpResponse<byte[]>> future = http.sendAsync(request, info -> new BoundedBody());
        try {
            var response = future.get(15, TimeUnit.SECONDS);
            if (response.statusCode() != 200) throw new IllegalStateException("Agent write outcome unavailable");
            return response.body();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Agent write interrupted");
        } catch (ExecutionException | TimeoutException failure) {
            throw new IllegalStateException("Agent write outcome unavailable");
        } finally {
            if (!future.isDone()) future.cancel(true);
        }
    }

    private URI target() {
        ServiceAddress address = ServiceAddress.parse(properties.getGatewayBaseUrl());
        requireBase(URI.create(address.url()));
        URI resolved = URI.create(resolver.resolve(address));
        requireBase(resolved);
        if (!Set.of("http", "https").contains(resolved.getScheme()))
            throw new IllegalStateException("Invalid Gateway address");
        return resolved.resolve("/api/internal/agent/write-delegate");
    }

    private static void requireBase(URI uri) {
        if (uri.getHost() == null
                || uri.getUserInfo() != null
                || uri.getQuery() != null
                || uri.getFragment() != null
                || !(uri.getPath().isEmpty() || uri.getPath().equals("/")))
            throw new IllegalStateException("Invalid Gateway address");
    }

    private String assertion(byte[] body) {
        try {
            String pem = auth.getAccessPrivateKey()
                    .replace("\\n", "\n")
                    .replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");
            var key = KeyFactory.getInstance("RSA")
                    .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
            Instant now = Instant.now();
            return Jwts.builder()
                    .header()
                    .type("kaiwu-agent-write-delegation+jwt")
                    .and()
                    .issuer("kaiwu-system-service")
                    .subject("kaiwu-system-service")
                    .audience()
                    .add("kaiwu-gateway-agent-write")
                    .and()
                    .id(UUID.randomUUID().toString())
                    .issuedAt(Date.from(now))
                    .expiration(Date.from(now.plusSeconds(30)))
                    .claim("bodyHash", AgentManifestCodec.digest(new String(body, StandardCharsets.UTF_8)))
                    .signWith(key, Jwts.SIG.RS256)
                    .compact();
        } catch (GeneralSecurityException failure) {
            throw new IllegalStateException("Agent signing unavailable");
        }
    }

    @PreDestroy
    public void close() {
        http.shutdownNow();
    }

    private static final class BoundedBody implements HttpResponse.BodySubscriber<byte[]> {
        private final CompletableFuture<byte[]> result = new CompletableFuture<>();
        private final ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        private Flow.Subscription subscription;

        public CompletionStage<byte[]> getBody() {
            return result;
        }

        public void onSubscribe(Flow.Subscription value) {
            subscription = value;
            value.request(1);
        }

        public void onNext(List<ByteBuffer> buffers) {
            for (var buffer : buffers) {
                if (buffer.remaining() > MAX_RESPONSE_BYTES - bytes.size()) {
                    subscription.cancel();
                    result.completeExceptionally(new IllegalStateException("Agent response too large"));
                    return;
                }
                byte[] chunk = new byte[buffer.remaining()];
                buffer.get(chunk);
                bytes.writeBytes(chunk);
            }
            subscription.request(1);
        }

        public void onError(Throwable error) {
            result.completeExceptionally(new IllegalStateException("Agent response unavailable"));
        }

        public void onComplete() {
            result.complete(bytes.toByteArray());
        }
    }
}
