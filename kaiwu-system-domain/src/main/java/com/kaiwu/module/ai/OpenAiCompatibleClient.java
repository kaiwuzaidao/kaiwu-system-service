package com.kaiwu.module.ai;

import com.kaiwu.module.ai.AiProviderService.RuntimeConfig;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Small HTTP adapter for the OpenAI-compatible chat-completions protocol.
 */
@Component
public final class OpenAiCompatibleClient {

    private static final int MAX_RESPONSE_BYTES = 2 * 1024 * 1024;
    private static final int MAX_ERROR_DETAIL_CHARS = 200;

    private final ObjectMapper objectMapper;
    private final AiProviderNetworkPolicy networkPolicy;

    public OpenAiCompatibleClient(ObjectMapper objectMapper) {
        this(objectMapper, new AiProviderNetworkPolicy("", ""));
    }

    @Autowired
    public OpenAiCompatibleClient(ObjectMapper objectMapper, AiProviderNetworkPolicy networkPolicy) {
        this.objectMapper = objectMapper;
        this.networkPolicy = networkPolicy;
    }

    /**
     * 调用 OpenAI 兼容的对话接口。
     *
     * <p>出站前先过 {@code AiProviderNetworkPolicy} 的白名单校验，并强制走配置的代理。</p>
     */
    public ChatResult chat(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens) {
        URI endpoint = URI.create(config.baseUrl() + "/chat/completions");
        try {
            networkPolicy.verify(endpoint);
        } catch (SecurityException exception) {
            // 策略有四条独立规则（代理未配置/协议不符/必须 DNS 主机名/不在白名单），
            // 原因必须带出来，否则配置页只能看到"被拒绝"而无法判断要改什么。
            // 这些文案是本类与 policy 自己构造的固定中文，不含任何凭据。
            throw new IllegalStateException("模型服务地址被网络安全策略拒绝：" + exception.getMessage(), exception);
        }

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(Math.min(10, config.timeoutSeconds())))
                .followRedirects(HttpClient.Redirect.NEVER)
                .proxy(networkPolicy.proxySelector())
                .build();

        String requestBody = serializeRequest(config, systemPrompt, userPrompt, maxTokens);
        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(endpoint)
                .timeout(Duration.ofSeconds(config.timeoutSeconds()))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestBody));
        if (config.apiKey() != null && !config.apiKey().isBlank()) {
            requestBuilder.header("Authorization", "Bearer " + config.apiKey().trim());
        }

        final HttpResponse<InputStream> response;
        try {
            response = client.send(requestBuilder.build(), HttpResponse.BodyHandlers.ofInputStream());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("模型服务请求已中断", exception);
        } catch (IOException | IllegalArgumentException exception) {
            throw new IllegalStateException("无法连接模型服务", exception);
        }

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("模型服务返回 HTTP " + response.statusCode() + describeError(response.body()));
        }
        try (InputStream body = response.body()) {
            return parseResponse(readBounded(body));
        } catch (IOException exception) {
            throw new IllegalStateException("模型服务响应读取失败", exception);
        }
    }

    private String serializeRequest(RuntimeConfig config, String systemPrompt, String userPrompt, int maxTokens) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", config.model());
        body.put("temperature", config.temperature());
        body.put("max_tokens", maxTokens);
        body.put(
                "messages",
                List.of(
                        Map.of("role", "system", "content", systemPrompt),
                        Map.of("role", "user", "content", userPrompt)));
        try {
            return objectMapper.writeValueAsString(body);
        } catch (Exception exception) {
            throw new IllegalStateException("无法生成模型服务请求", exception);
        }
    }

    private ChatResult parseResponse(String responseBody) {
        final JsonNode root;
        try {
            root = objectMapper.readTree(responseBody);
        } catch (Exception exception) {
            // 与"返回了 JSON 但没有内容"区分开：前者多半是地址指错（少了 /v1 或打到了网关）。
            throw new IllegalStateException("模型服务响应不是有效 JSON", exception);
        }
        if (root == null) {
            throw new IllegalStateException("模型服务未返回有效内容");
        }

        JsonNode contentNode = root.path("choices").path(0).path("message").path("content");
        if (!contentNode.isTextual() || contentNode.asText().isBlank()) {
            throw new IllegalStateException("模型服务未返回有效内容");
        }

        JsonNode usage = root.path("usage");
        return new ChatResult(
                contentNode.asText(),
                nullableLong(usage.path("prompt_tokens")),
                nullableLong(usage.path("completion_tokens")));
    }

    private static String readBounded(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8_192];
        int total = 0;
        int read;
        while ((read = input.read(buffer)) >= 0) {
            total += read;
            if (total > MAX_RESPONSE_BYTES) {
                throw new IOException("模型服务响应超过大小限制");
            }
            output.write(buffer, 0, read);
        }
        return output.toString(java.nio.charset.StandardCharsets.UTF_8);
    }

    /**
     * 读取错误响应体，提炼出可诊断的原因后缀。
     *
     * <p>"API Key 无效 / 模型名不存在 / 余额不足 / 缺少 v1 路径"这几类问题在 OpenAI 兼容协议里
     * 都只体现在响应体的 {@code error.message}；只回 HTTP 状态码会让配置页无法定位问题。
     * 读取仍受 {@link #MAX_RESPONSE_BYTES} 约束，输出再按 {@code MAX_ERROR_DETAIL_CHARS} 截断，
     * 任何解析失败都退化为空串，不影响主错误信息。
     *
     * @param body 错误响应体流，本方法负责关闭
     * @return 形如 {@code "：Incorrect API key provided"} 的后缀；无可用信息时为空串
     */
    private String describeError(InputStream body) {
        final String raw;
        try (InputStream input = body) {
            raw = readBounded(input);
        } catch (IOException exception) {
            return "";
        }
        String detail = collapse(extractErrorMessage(raw));
        return detail.isEmpty() ? "" : "：" + detail;
    }

    /**
     * 优先取 OpenAI 兼容协议的 {@code error.message}，其次取顶层 {@code message}；
     * 响应体不是 JSON（例如网关返回 HTML 错误页）时退化为原文，由调用方截断。
     */
    private String extractErrorMessage(String raw) {
        if (raw.isBlank()) {
            return "";
        }
        try {
            JsonNode root = objectMapper.readTree(raw);
            if (root != null) {
                JsonNode nested = root.path("error").path("message");
                if (nested.isTextual() && !nested.asText().isBlank()) {
                    return nested.asText();
                }
                JsonNode flat = root.path("message");
                if (flat.isTextual() && !flat.asText().isBlank()) {
                    return flat.asText();
                }
            }
        } catch (Exception ignored) {
            // 非 JSON 响应没有结构可取，退化为原文。
        }
        return raw;
    }

    /**
     * 折叠连续空白并截断，避免 HTML 错误页或多行堆栈把测试结果撑成一团乱码。
     */
    private static String collapse(String value) {
        String single = value.replaceAll("\\s+", " ").trim();
        if (single.length() <= MAX_ERROR_DETAIL_CHARS) {
            return single;
        }
        return single.substring(0, MAX_ERROR_DETAIL_CHARS) + "…";
    }

    private static Long nullableLong(JsonNode node) {
        return node.isIntegralNumber() ? node.longValue() : null;
    }

    public record ChatResult(String content, Long promptTokens, Long completionTokens) {}
}
