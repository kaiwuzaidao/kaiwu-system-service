package com.kaiwu.module.connector.client;

import java.net.URI;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;

/**
 * 用临时凭证写入并删除一个探测对象，验证数据面地址、区域、桶与会话策略都可用。
 *
 * <p>会话策略只授予对象级权限，HeadBucket 一类桶级操作会被拒绝，因此探测走的是业务项目真实会用到的
 * PutObject 与 DeleteObject，且使用与 starter 相同的 S3 协议与 SigV4 签名。探测对象位于保留前缀
 * {@link #PROBE_PREFIX}，不会落入任何项目前缀。
 */
@Component
public class StorageObjectProbe {

    /** 探测对象使用的保留前缀；项目编码不允许以下划线开头，不会与项目前缀冲突。 */
    public static final String PROBE_PREFIX = "_kaiwu-probe/";

    private static final Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);
    private static final byte[] PROBE_BODY = "kaiwu storage probe".getBytes(StandardCharsets.UTF_8);

    private final StorageNetworkPolicy networkPolicy;
    private final Clock clock;

    /**
     * 创建探测器。
     *
     * @param networkPolicy 出站管控
     * @param clock 签名时间来源
     */
    public StorageObjectProbe(StorageNetworkPolicy networkPolicy, Clock clock) {
        this.networkPolicy = networkPolicy;
        this.clock = clock;
    }

    /**
     * 写入并删除一个探测对象。
     *
     * @param account 账号参数，提供地址、区域、桶与访问风格
     * @param credential 针对 {@link #PROBE_PREFIX} 签发的读写临时凭证
     * @throws IllegalStateException 任一步失败时抛出，消息可直接展示
     */
    public void writeAndDelete(StorageAccountAccess account, TemporaryCredential credential) {
        URI endpoint = URI.create(account.endpoint());
        networkPolicy.verify(endpoint);
        URI object = objectUri(endpoint, account.bucket(), account.pathStyle(), PROBE_PREFIX + UUID.randomUUID());
        send("PUT", object, PROBE_BODY, account, credential);
        send("DELETE", object, new byte[0], account, credential);
    }

    /**
     * 拼接对象地址：path-style 为 {@code endpoint/bucket/key}，否则为 {@code bucket.host/key}。
     *
     * @param endpoint 数据面地址
     * @param bucket 桶名
     * @param pathStyle 是否 path-style
     * @param key 对象 key，只含安全字符
     * @return 对象地址
     */
    static URI objectUri(URI endpoint, String bucket, boolean pathStyle, String key) {
        String port = endpoint.getPort() == -1 ? "" : ":" + endpoint.getPort();
        if (pathStyle) {
            return URI.create(endpoint.getScheme() + "://" + endpoint.getHost() + port + "/" + bucket + "/" + key);
        }
        return URI.create(endpoint.getScheme() + "://" + bucket + "." + endpoint.getHost() + port + "/" + key);
    }

    /**
     * 发送一次已签名的对象请求。
     *
     * @param method HTTP 方法
     * @param object 对象地址
     * @param body 请求体
     * @param account 账号参数
     * @param credential 临时凭证
     */
    private void send(
            String method, URI object, byte[] body, StorageAccountAccess account, TemporaryCredential credential) {
        Map<String, String> headers = AwsSigV4Signer.sign(
                method,
                object,
                null,
                body,
                account.region(),
                "s3",
                credential.accessKeyId(),
                credential.accessKeySecret(),
                credential.securityToken(),
                Instant.now(clock));
        HttpRequest.Builder request = HttpRequest.newBuilder(object)
                .timeout(REQUEST_TIMEOUT)
                .method(method, HttpRequest.BodyPublishers.ofByteArray(body));
        headers.forEach(request::header);
        HttpResponse<String> response = StorageHttp.send(networkPolicy.newClient(), request.build(), "对象存储");
        if (response.statusCode() / 100 != 2) {
            String code = StorageHttp.between(response.body(), "<Code>", "</Code>");
            String action = "PUT".equals(method) ? "写入" : "删除";
            throw new IllegalStateException(
                    "探测对象" + action + "失败（HTTP " + response.statusCode() + (code.isEmpty() ? "" : "，" + code) + "）");
        }
    }
}
