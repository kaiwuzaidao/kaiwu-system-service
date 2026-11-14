package com.kaiwu.module.connector.client;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HexFormat;
import java.util.Map;
import org.junit.jupiter.api.Test;
import software.amazon.awssdk.http.ContentStreamProvider;
import software.amazon.awssdk.http.SdkHttpMethod;
import software.amazon.awssdk.http.SdkHttpRequest;
import software.amazon.awssdk.http.auth.aws.signer.AwsV4FamilyHttpSigner;
import software.amazon.awssdk.http.auth.aws.signer.AwsV4HttpSigner;
import software.amazon.awssdk.http.auth.spi.signer.HttpSigner;
import software.amazon.awssdk.http.auth.spi.signer.SignedRequest;
import software.amazon.awssdk.identity.spi.AwsCredentialsIdentity;
import software.amazon.awssdk.identity.spi.AwsSessionCredentialsIdentity;

/**
 * 用 AWS 官方签名器交叉验证手写 SigV4：同一请求、同一时间、同一密钥，两边的 Authorization 必须完全一致。
 * 本机拿不到能校验签名的 S3/STS 服务时，这是签名正确性的主要证据。
 */
class AwsSigV4SignerTest {

    private static final Instant NOW = Instant.parse("2026-10-29T08:30:00Z");
    private static final String KEY_ID = "AKIDEXAMPLE";
    private static final String KEY = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";

    /** STS 表单请求：长期密钥、带 Content-Type、无会话令牌。 */
    @Test
    void stsFormRequestMatchesAwsSdk() throws Exception {
        URI uri = URI.create("http://localhost:9000/");
        byte[] body = "Action=AssumeRole&Version=2011-06-15&DurationSeconds=900".getBytes(StandardCharsets.UTF_8);
        String form = "application/x-www-form-urlencoded";

        Map<String, String> ours =
                AwsSigV4Signer.sign("POST", uri, form, body, "us-east-1", "sts", KEY_ID, KEY, null, NOW);
        String expected = sdkAuthorization(
                SdkHttpMethod.POST, uri, form, body, "us-east-1", "sts", AwsCredentialsIdentity.create(KEY_ID, KEY));

        assertThat(ours.get("authorization")).isEqualTo(expected);
    }

    /** S3 对象写入：临时凭证、带会话令牌、virtual-hosted 地址。 */
    @Test
    void s3PutWithSessionTokenMatchesAwsSdk() throws Exception {
        URI uri = URI.create("https://bucket.oss-cn-hangzhou.aliyuncs.com/demo/invoice/2026/10/a.pdf");
        byte[] body = "probe".getBytes(StandardCharsets.UTF_8);

        Map<String, String> ours =
                AwsSigV4Signer.sign("PUT", uri, null, body, "cn-hangzhou", "s3", KEY_ID, KEY, "session-token", NOW);
        String expected = sdkAuthorization(
                SdkHttpMethod.PUT,
                uri,
                null,
                body,
                "cn-hangzhou",
                "s3",
                AwsSessionCredentialsIdentity.create(KEY_ID, KEY, "session-token"));

        assertThat(ours.get("authorization")).isEqualTo(expected);
        assertThat(ours).containsEntry("x-amz-security-token", "session-token");
    }

    /** Host 头与 Java HTTP 客户端一致：显式端口时带端口。 */
    @Test
    void hostHeaderKeepsExplicitPort() {
        assertThat(AwsSigV4Signer.hostHeader(URI.create("http://LocalHost:9000/")))
                .isEqualTo("localhost:9000");
        assertThat(AwsSigV4Signer.hostHeader(URI.create("https://sts.example.com/")))
                .isEqualTo("sts.example.com");
    }

    /**
     * 用 AWS SDK 签名同一个请求。预先放入 x-amz-content-sha256，使 SDK 与本实现签名相同的头集合。
     *
     * @param method HTTP 方法
     * @param uri 请求地址
     * @param contentType 请求体类型，可空
     * @param body 请求体
     * @param region 区域
     * @param service 服务名
     * @param identity 签名身份
     * @return SDK 生成的 Authorization 头
     * @throws Exception 摘要算法不可用时抛出
     */
    private static String sdkAuthorization(
            SdkHttpMethod method,
            URI uri,
            String contentType,
            byte[] body,
            String region,
            String service,
            AwsCredentialsIdentity identity)
            throws Exception {
        SdkHttpRequest.Builder request = SdkHttpRequest.builder()
                .method(method)
                .uri(uri)
                .putHeader(
                        "x-amz-content-sha256",
                        HexFormat.of()
                                .formatHex(MessageDigest.getInstance("SHA-256").digest(body)));
        if (contentType != null) {
            request.putHeader("Content-Type", contentType);
        }
        SignedRequest signed = AwsV4HttpSigner.create().sign(r -> r.identity(identity)
                .request(request.build())
                .payload(ContentStreamProvider.fromByteArray(body))
                .putProperty(AwsV4FamilyHttpSigner.SERVICE_SIGNING_NAME, service)
                .putProperty(AwsV4HttpSigner.REGION_NAME, region)
                .putProperty(AwsV4FamilyHttpSigner.DOUBLE_URL_ENCODE, false)
                .putProperty(AwsV4FamilyHttpSigner.NORMALIZE_PATH, false)
                .putProperty(HttpSigner.SIGNING_CLOCK, Clock.fixed(NOW, ZoneOffset.UTC)));
        return signed.request().firstMatchingHeader("Authorization").orElseThrow();
    }
}
