package com.kaiwu.module.connector.client;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;

/**
 * S3 兼容 STS 签发器（MinIO 等，AWS STS AssumeRole 协议）。
 *
 * <p>MinIO 的 AssumeRole 以发起请求的账号为父身份，忽略 RoleArn；会话策略与父身份策略取交集，
 * 因此签发出的凭证不会超过管理员登记账号本身的权限。
 */
@Component
public class S3CompatibleStsCredentialIssuer implements StorageCredentialIssuer {

    /** 对应字典 {@code storage.provider.type} 的值。 */
    public static final String PROVIDER_TYPE = "S3_COMPATIBLE_STS";

    private static final String FORM = "application/x-www-form-urlencoded";
    private static final String PLACEHOLDER_ROLE_ARN = "arn:kaiwu:iam::storage:role/kaiwu";
    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

    private final StorageNetworkPolicy networkPolicy;
    private final Clock clock;

    /**
     * 创建签发器。
     *
     * @param networkPolicy 出站管控
     * @param clock 签名时间来源
     */
    public S3CompatibleStsCredentialIssuer(StorageNetworkPolicy networkPolicy, Clock clock) {
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
     * 以 SigV4 签名调用 AssumeRole，附带收窄到项目前缀的会话策略。
     *
     * @param account 已解密的账号参数
     * @param sessionName 会话名
     * @param prefix 对象前缀
     * @param readOnly 是否只读
     * @param ttlSeconds 有效期（秒）
     * @return 临时凭证
     */
    @Override
    public TemporaryCredential assumeRole(
            StorageAccountAccess account, String sessionName, String prefix, boolean readOnly, int ttlSeconds) {
        URI endpoint = rootOf(account.stsEndpoint());
        networkPolicy.verify(endpoint);
        Map<String, String> form = new LinkedHashMap<>();
        form.put("Action", "AssumeRole");
        form.put("Version", "2011-06-15");
        form.put("DurationSeconds", Integer.toString(ttlSeconds));
        form.put(
                "RoleArn",
                account.roleArn() == null || account.roleArn().isBlank() ? PLACEHOLDER_ROLE_ARN : account.roleArn());
        form.put("RoleSessionName", sessionName);
        form.put("Policy", StorageSessionPolicies.s3(account.bucket(), prefix, readOnly));
        byte[] body = form.entrySet().stream()
                .map(entry -> encode(entry.getKey()) + "=" + encode(entry.getValue()))
                .collect(Collectors.joining("&"))
                .getBytes(StandardCharsets.UTF_8);
        Map<String, String> headers = AwsSigV4Signer.sign(
                "POST",
                endpoint,
                FORM,
                body,
                account.region(),
                "sts",
                account.accessKeyId(),
                account.accessKeySecret(),
                null,
                Instant.now(clock));
        HttpRequest.Builder request = HttpRequest.newBuilder(endpoint)
                .timeout(REQUEST_TIMEOUT)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body));
        headers.forEach(request::header);
        HttpResponse<String> response = StorageHttp.send(networkPolicy.newClient(), request.build(), "STS");
        if (response.statusCode() != 200) {
            String code = StorageHttp.between(response.body(), "<Code>", "</Code>");
            throw new IllegalStateException(
                    "STS 签发失败（HTTP " + response.statusCode() + (code.isEmpty() ? "" : "，" + code) + "）");
        }
        return parse(response.body());
    }

    /**
     * 解析 AssumeRole 的 XML 响应。只做定位读取，不启用 XML 解析器，避免外部实体注入。
     *
     * @param body 响应体
     * @return 临时凭证
     */
    static TemporaryCredential parse(String body) {
        String accessKeyId = xmlValue(body, "AccessKeyId");
        String secret = xmlValue(body, "SecretAccessKey");
        String token = xmlValue(body, "SessionToken");
        String expiration = xmlValue(body, "Expiration");
        if (accessKeyId.isEmpty() || secret.isEmpty() || token.isEmpty() || expiration.isEmpty()) {
            throw new IllegalStateException("STS 响应缺少临时凭证字段");
        }
        try {
            return new TemporaryCredential(accessKeyId, secret, token, Instant.parse(expiration));
        } catch (DateTimeParseException exception) {
            throw new IllegalStateException("STS 响应的过期时间格式无法识别", exception);
        }
    }

    /**
     * 读取不截断的 XML 文本值；会话令牌可能很长，不能复用只取错误码的截断逻辑。
     *
     * @param body 响应体
     * @param tag 标签名
     * @return 标签内的文本，找不到时为空字符串
     */
    private static String xmlValue(String body, String tag) {
        String open = "<" + tag + ">";
        int start = body.indexOf(open);
        int end = start < 0 ? -1 : body.indexOf("</" + tag + ">", start);
        return start < 0 || end < 0
                ? ""
                : body.substring(start + open.length(), end).trim();
    }

    /**
     * 规范化 STS 地址为根路径。
     *
     * @param value 管理员登记的 STS 地址
     * @return 以 {@code /} 为路径的地址
     */
    private static URI rootOf(String value) {
        URI uri = URI.create(value);
        return URI.create(uri.getScheme() + "://" + uri.getRawAuthority() + "/");
    }

    /**
     * 表单编码，空格编码为 {@code %20} 以满足 SigV4 对请求体的一致性要求。
     *
     * @param value 原值
     * @return 编码后的值
     */
    private static String encode(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
