package com.kaiwu.module.agent.execution;

import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.config.AgentRemoteProperties;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.presentation.CardProjection;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.Capability;
import com.kaiwu.module.agent.protocol.CapabilityResult;
import com.kaiwu.module.identity.config.AuthProperties;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.client.*;
import io.jsonwebtoken.Jwts;
import jakarta.annotation.PreDestroy;
import java.io.ByteArrayOutputStream;
import java.net.URI;
import java.net.http.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import org.springframework.stereotype.Component;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

/** 只向运维配置的 Gateway 委托，固定内部路径，无 URL 参数、重定向或自动重试。 */
@Component
public class RemoteCapabilityInvoker {
    private static final int MAX_BYTES = 262144;
    private static final JsonMapper JSON = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();
    private final AgentRemoteProperties properties;
    private final RemoteCapabilitySource source;
    private final AuthProperties auth;
    private final ServiceAddressResolver resolver;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .followRedirects(HttpClient.Redirect.NEVER)
            .build();

    public RemoteCapabilityInvoker(
            AgentRemoteProperties properties,
            RemoteCapabilitySource source,
            AuthProperties auth,
            ServiceAddressResolver resolver) {
        this.properties = properties;
        this.source = source;
        this.auth = auth;
        this.resolver = resolver;
        if (properties.isEnabled()) target();
    }

    public CapabilityResult invoke(Capability capability, Map<String, Object> parameters, KaiwuContext actor) {
        return invoke(capability, parameters, actor, UUID.randomUUID().toString());
    }

    public CapabilityResult invoke(
            Capability capability, Map<String, Object> parameters, KaiwuContext actor, String correlationId) {
        String paramsJson = JSON.writeValueAsString(parameters);
        if (paramsJson.getBytes(StandardCharsets.UTF_8).length > 16384) throw new PlanRejectedException(6, "参数过长");
        var latest = source.findVisible(capability.code(), actor)
                .filter(capability::equals)
                .orElseThrow(() -> new PlanRejectedException(3, "无权限操作"));
        // 从审核清单重新取得摘要；不使用模型传入的版本/摘要。
        var approved = source.visibleRevision(latest.code(), actor);
        if (!latest.equals(approved.capability())) throw new PlanRejectedException(3, "该能力已更新，请重新查询");
        byte[] body = JSON.writeValueAsBytes(Map.of(
                "sessionId",
                actor.sessionId(),
                "code",
                latest.code(),
                "version",
                latest.version(),
                "manifestHash",
                approved.manifestHash(),
                "paramsJson",
                paramsJson,
                "correlationId",
                correlationId));
        var request = HttpRequest.newBuilder(target())
                .timeout(Duration.ofSeconds(15))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + assertion(body))
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .build();
        CompletableFuture<HttpResponse<byte[]>> future = http.sendAsync(request, info -> new BoundedBody());
        try {
            var response = future.get(15, TimeUnit.SECONDS);
            if (response.statusCode() == 403) {
                throw new PlanRejectedException(3, "无权限操作");
            }
            if (response.statusCode() != 200) throw new IllegalStateException("Agent invocation unavailable");
            var tree = JSON.readTree(response.body());
            var rows = tree.path("rows");
            if (!tree.isObject() || tree.size() != 1 || !rows.isArray() || rows.size() > 100)
                throw new IllegalStateException("Invalid Agent response");
            List<Map<String, Object>> result = new ArrayList<>();
            for (var row : rows) {
                if (!row.isObject()) throw new IllegalStateException("Invalid Agent row");
                var safe = new LinkedHashMap<String, Object>();
                for (String field : latest.outboundFields()) {
                    var value = row.get(field);
                    if (value == null) continue;
                    if (value.isContainer()
                            || (value.isString() && value.asString().length() > 8000))
                        throw new IllegalStateException("Invalid Agent field");
                    safe.put(field, JSON.convertValue(value, Object.class));
                }
                safe.put(CardProjection.SOURCE_PROJECT_ID, approved.access().projectId());
                result.add(safe);
            }
            return CapabilityResult.ok(
                    latest.code(),
                    latest.description(),
                    result,
                    List.of(approved.access().projectId()));
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Agent invocation interrupted");
        } catch (ExecutionException | TimeoutException failure) {
            throw new IllegalStateException("Agent invocation unavailable");
        } finally {
            if (!future.isDone()) future.cancel(true);
        }
    }

    private URI target() {
        if (!properties.isEnabled()) throw new IllegalStateException("Remote Agent disabled");
        ServiceAddress address = ServiceAddress.parse(properties.getGatewayBaseUrl());
        requireBase(URI.create(address.url()));
        URI resolved = URI.create(resolver.resolve(address));
        requireBase(resolved);
        if (!Set.of("http", "https").contains(resolved.getScheme()))
            throw new IllegalStateException("Invalid Gateway address");
        return resolved.resolve("/api/internal/agent/delegate");
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
                    .type("kaiwu-agent-delegation+jwt")
                    .and()
                    .issuer("kaiwu-system-service")
                    .subject("kaiwu-system-service")
                    .audience()
                    .add("kaiwu-gateway-agent")
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
                if (buffer.remaining() > MAX_BYTES - bytes.size()) {
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
