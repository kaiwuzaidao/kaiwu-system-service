package com.kaiwu.module.connector.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.kaiwu.module.connector.service.AiProviderService.RuntimeConfig;
import com.kaiwu.port.ModelCallFailure;
import com.kaiwu.port.ModelCallFailure.Category;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * 模型调用的失败分类。
 *
 * <p>出站策略强制走代理且只允许 DNS 主机名，所以测试里本地 HTTP 服务充当「代理」：
 * 客户端把 {@code http://provider.test/...} 发给它，由它按用例返回状态与内容。
 * 这样走的是真实的 {@code HttpClient}，不是 mock。</p>
 */
class OpenAiCompatibleClientTest {

    private static final String HOST = "provider.test";
    private static final String OK_BODY =
            "{\"choices\":[{\"message\":{\"content\":\"你好\"}}],\"usage\":{\"prompt_tokens\":7,\"completion_tokens\":3}}";

    private HttpServer server;
    private final AtomicReference<Reply> reply = new AtomicReference<>(new Reply(200, OK_BODY, 0));
    private OpenAiCompatibleClient client;

    /** 启动本地代理模拟模型服务。 */
    @BeforeEach
    void startFakeProvider() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            Reply current = reply.get();
            exchange.getRequestBody().readAllBytes();
            try {
                if (current.delayMillis() > 0) Thread.sleep(current.delayMillis());
                byte[] body = current.body().getBytes(StandardCharsets.UTF_8);
                exchange.sendResponseHeaders(current.status(), body.length);
                exchange.getResponseBody().write(body);
            } catch (InterruptedException | IOException ignored) {
                // 客户端超时后会断开，服务端写失败属于预期。
            } finally {
                exchange.close();
            }
        });
        server.start();
        client = new OpenAiCompatibleClient(
                new ObjectMapper(),
                new AiProviderNetworkPolicy(
                        HOST, "http://127.0.0.1:" + server.getAddress().getPort()));
    }

    /** 关闭模拟服务。 */
    @AfterEach
    void stopFakeProvider() {
        server.stop(0);
    }

    /** 构造测试专用的服务配置。 */
    private static RuntimeConfig config(int timeoutSeconds) {
        return new RuntimeConfig("p", "http://" + HOST + "/v1", "k", "m", BigDecimal.ONE, timeoutSeconds);
    }

    /** 取得并检查模型调用失败。 */
    private ModelCallFailure failure() {
        Throwable thrown =
                org.assertj.core.api.Assertions.catchThrowable(() -> client.chat(config(5), "system", "user", 100));
        assertThat(thrown).isInstanceOf(ModelCallFailure.class).isInstanceOf(IllegalStateException.class);
        return (ModelCallFailure) thrown;
    }

    /** 验证成功响应内容和用量。 */
    @Test
    void successfulCallReturnsContentAndUsage() {
        var result = client.chat(config(5), "system", "user", 100);

        assertThat(result.content()).isEqualTo("你好");
        assertThat(result.promptTokens()).isEqualTo(7L);
        assertThat(result.completionTokens()).isEqualTo(3L);
    }

    /** 验证状态码分类及原始提示文案。 */
    @Test
    void httpStatusesAreClassifiedAndKeepTheOriginalMessage() {
        /** 状态码与期望分类的测试对照。 */
        record Case(int status, Category category) {}
        for (Case item : new Case[] {
            new Case(401, Category.HTTP_AUTH),
            new Case(403, Category.HTTP_AUTH),
            new Case(404, Category.HTTP_NOT_FOUND),
            new Case(429, Category.HTTP_RATE_LIMIT),
            new Case(400, Category.HTTP_4XX),
            new Case(500, Category.HTTP_5XX),
            new Case(503, Category.HTTP_5XX),
            new Case(302, Category.HTTP_OTHER)
        }) {
            reply.set(new Reply(item.status(), "{\"error\":{\"message\":\"Incorrect API key\"}}", 0));

            ModelCallFailure failure = failure();

            assertThat(failure.category()).as("HTTP %d", item.status()).isEqualTo(item.category());
            assertThat(failure.httpStatus()).isEqualTo(item.status());
            // 连通性测试页直接回显这句话，文案不能因为加了分类而变。
            assertThat(failure.getMessage()).isEqualTo("模型服务返回 HTTP " + item.status() + "：Incorrect API key");
        }
    }

    /** 验证非法 JSON 与空内容的分类。 */
    @Test
    void invalidJsonAndEmptyContentAreDistinguished() {
        reply.set(new Reply(200, "<html>gateway</html>", 0));
        assertThat(failure().category()).isEqualTo(Category.INVALID_JSON);
        assertThat(failure().getMessage()).isEqualTo("模型服务响应不是有效 JSON");

        reply.set(new Reply(200, "{\"choices\":[]}", 0));
        assertThat(failure().category()).isEqualTo(Category.EMPTY_CONTENT);
        assertThat(failure().getMessage()).isEqualTo("模型服务未返回有效内容");
    }

    /** 验证超大响应的分类与提示。 */
    @Test
    void oversizedResponseIsClassifiedSeparatelyFromReadFailure() {
        reply.set(new Reply(200, "x".repeat(2 * 1024 * 1024 + 10), 0));

        ModelCallFailure failure = failure();

        assertThat(failure.category()).isEqualTo(Category.RESPONSE_TOO_LARGE);
        assertThat(failure.getMessage()).isEqualTo("模型服务响应读取失败");
    }

    /** 验证超时分类及提示。 */
    @Test
    void slowResponseIsATimeoutNotAConnectionFailure() {
        reply.set(new Reply(200, OK_BODY, 3_000));

        Throwable thrown =
                org.assertj.core.api.Assertions.catchThrowable(() -> client.chat(config(1), "system", "user", 100));

        assertThat(thrown).isInstanceOf(ModelCallFailure.class);
        assertThat(((ModelCallFailure) thrown).category()).isEqualTo(Category.TIMEOUT);
        // 用户可见文案与改动前一致：超时和连不上过去都是这一句。
        assertThat(thrown.getMessage()).isEqualTo("无法连接模型服务");
    }

    /** 验证无法连接代理的分类。 */
    @Test
    void unreachableProxyIsAConnectionFailure() {
        server.stop(0);

        ModelCallFailure failure = failure();

        assertThat(failure.category()).isEqualTo(Category.CONNECT);
        assertThat(failure.httpStatus()).isNull();
    }

    /** 验证网络策略拒绝的分类。 */
    @Test
    void networkPolicyRejectionIsClassified() {
        var strict = new OpenAiCompatibleClient(
                new ObjectMapper(), new AiProviderNetworkPolicy("other.test", "http://127.0.0.1:9"));

        assertThatThrownBy(() -> strict.chat(config(5), "system", "user", 100))
                .isInstanceOfSatisfying(ModelCallFailure.class, failure -> {
                    assertThat(failure.category()).isEqualTo(Category.NETWORK_POLICY);
                    assertThat(failure.getMessage()).startsWith("模型服务地址被网络安全策略拒绝：");
                });
    }

    /** 验证异常链分类与未知回退。 */
    @Test
    void categoryOfAnythingElseIsUnknown() {
        assertThat(ModelCallFailure.categoryOf(new IllegalStateException("x"))).isEqualTo(Category.UNKNOWN);
        assertThat(ModelCallFailure.statusOf(new IllegalStateException("x"))).isNull();
        assertThat(ModelCallFailure.categoryOf(
                        new RuntimeException("wrapper", new ModelCallFailure(Category.TIMEOUT, "t", null))))
                .isEqualTo(Category.TIMEOUT);
    }

    /** 模拟服务的响应内容与延迟。 */
    private record Reply(int status, String body, long delayMillis) {}
}
