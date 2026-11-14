package com.kaiwu.module.connector.client;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import java.util.UUID;
import java.util.stream.Collectors;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * 阿里云 STS 签发器（AssumeRole，RPC 风格 API 与 HMAC-SHA1 签名）。
 *
 * <p>管理员需要为 System 准备一个只允许 {@code sts:AssumeRole} 的 RAM 用户，以及一个对目标桶有
 * 读写权限的 RAM 角色。会话策略与角色策略取交集，签发出的凭证只能访问项目前缀。
 */
@Component
public class AliyunStsCredentialIssuer implements StorageCredentialIssuer {

    /** 对应字典 {@code storage.provider.type} 的值。 */
    public static final String PROVIDER_TYPE = "ALIYUN_OSS";

    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final DateTimeFormatter TIMESTAMP =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.ROOT).withZone(ZoneOffset.UTC);
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final StorageNetworkPolicy networkPolicy;
    private final Clock clock;

    /**
     * 创建签发器。
     *
     * @param networkPolicy 出站管控
     * @param clock 签名时间来源
     */
    public AliyunStsCredentialIssuer(StorageNetworkPolicy networkPolicy, Clock clock) {
        this.networkPolicy = networkPolicy;
        this.clock = clock;
    }

    /**
     * 返回本签发器负责的存储类型。
     *
     * @return {@link #PROVIDER_TYPE}
     */
    @Override
    public String providerType() {
        return PROVIDER_TYPE;
    }

    /**
     * 调用阿里云 STS AssumeRole，附带收窄到项目前缀的会话策略。
     *
     * @param account 已解密的账号参数，{@code roleArn} 必填
     * @param sessionName 会话名
     * @param prefix 对象前缀
     * @param readOnly 是否只读
     * @param ttlSeconds 有效期（秒），阿里云要求不少于 900
     * @return 临时凭证
     */
    @Override
    public TemporaryCredential assumeRole(
            StorageAccountAccess account, String sessionName, String prefix, boolean readOnly, int ttlSeconds) {
        if (account.roleArn() == null || account.roleArn().isBlank()) {
            throw new IllegalStateException("阿里云存储账号必须配置角色 ARN");
        }
        URI uri = URI.create(account.stsEndpoint());
        URI endpoint = URI.create(uri.getScheme() + "://" + uri.getRawAuthority() + "/");
        networkPolicy.verify(endpoint);
        Map<String, String> params = new TreeMap<>();
        params.put("Action", "AssumeRole");
        params.put("Version", "2015-04-01");
        params.put("Format", "JSON");
        params.put("AccessKeyId", account.accessKeyId());
        params.put("SignatureMethod", "HMAC-SHA1");
        params.put("SignatureVersion", "1.0");
        params.put("SignatureNonce", UUID.randomUUID().toString());
        params.put("Timestamp", TIMESTAMP.format(Instant.now(clock)));
        params.put("RoleArn", account.roleArn());
        params.put("RoleSessionName", sessionName);
        params.put("DurationSeconds", Integer.toString(ttlSeconds));
        params.put("Policy", StorageSessionPolicies.aliyun(account.bucket(), prefix, readOnly));
        params.put("Signature", sign("POST", params, account.accessKeySecret()));
        String body = params.entrySet().stream()
                .map(entry -> percentEncode(entry.getKey()) + "=" + percentEncode(entry.getValue()))
                .collect(Collectors.joining("&"));
        HttpRequest request = HttpRequest.newBuilder(endpoint)
                .timeout(REQUEST_TIMEOUT)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                .build();
        HttpResponse<String> response = StorageHttp.send(networkPolicy.newClient(), request, "阿里云 STS");
        return parse(response.statusCode(), response.body());
    }

    /**
     * 计算 RPC 风格签名：参数按键排序后编码，再对 {@code METHOD&%2F&编码串} 做 HMAC-SHA1。
     *
     * @param method HTTP 方法
     * @param params 不含 Signature 的全部参数，已按键排序
     * @param accessKeySecret 签发用 Secret
     * @return Base64 签名
     */
    static String sign(String method, Map<String, String> params, String accessKeySecret) {
        String canonical = new TreeMap<>(params)
                .entrySet().stream()
                        .map(entry -> percentEncode(entry.getKey()) + "=" + percentEncode(entry.getValue()))
                        .collect(Collectors.joining("&"));
        String stringToSign = method + "&" + percentEncode("/") + "&" + percentEncode(canonical);
        try {
            Mac mac = Mac.getInstance("HmacSHA1");
            mac.init(new SecretKeySpec((accessKeySecret + "&").getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
            return Base64.getEncoder().encodeToString(mac.doFinal(stringToSign.getBytes(StandardCharsets.UTF_8)));
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("JDK 缺少 HmacSHA1", exception);
        }
    }

    /**
     * 解析 STS 的 JSON 响应；失败时只回显阿里云的错误码。
     *
     * @param status HTTP 状态码
     * @param body 响应体
     * @return 临时凭证
     */
    static TemporaryCredential parse(int status, String body) {
        JsonNode root;
        try {
            root = JSON.readTree(body);
        } catch (RuntimeException exception) {
            throw new IllegalStateException("阿里云 STS 返回了无法解析的响应（HTTP " + status + "）", exception);
        }
        if (status != 200) {
            String code = root.path("Code").asString("");
            throw new IllegalStateException("阿里云 STS 签发失败（HTTP " + status + (code.isEmpty() ? "" : "，" + code) + "）");
        }
        JsonNode credentials = root.path("Credentials");
        String accessKeyId = credentials.path("AccessKeyId").asString("");
        String secret = credentials.path("AccessKeySecret").asString("");
        String token = credentials.path("SecurityToken").asString("");
        String expiration = credentials.path("Expiration").asString("");
        if (accessKeyId.isEmpty() || secret.isEmpty() || token.isEmpty() || expiration.isEmpty()) {
            throw new IllegalStateException("阿里云 STS 响应缺少临时凭证字段");
        }
        try {
            return new TemporaryCredential(accessKeyId, secret, token, Instant.parse(expiration));
        } catch (DateTimeParseException exception) {
            throw new IllegalStateException("阿里云 STS 响应的过期时间格式无法识别", exception);
        }
    }

    /**
     * 阿里云 POP 规范的百分号编码：在 URL 编码基础上把 {@code +}、{@code *}、{@code %7E} 修正为
     * {@code %20}、{@code %2A}、{@code ~}。
     *
     * @param value 原值
     * @return 编码后的值
     */
    static String percentEncode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8)
                .replace("+", "%20")
                .replace("*", "%2A")
                .replace("%7E", "~");
    }
}
