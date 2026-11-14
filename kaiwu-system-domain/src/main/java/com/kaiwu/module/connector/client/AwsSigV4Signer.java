package com.kaiwu.module.connector.client;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Map;
import java.util.TreeMap;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * AWS Signature Version 4 签名（用于 S3 兼容 STS 与对象读写探测）。
 *
 * <p>只覆盖 System 实际发出的请求形态：无查询参数、请求体已知。签名结果只放在请求头里，
 * 调用方不得记录返回的请求头。
 */
public final class AwsSigV4Signer {

    private static final DateTimeFormatter AMZ_DATE =
            DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss'Z'", Locale.ROOT).withZone(ZoneOffset.UTC);
    private static final DateTimeFormatter DATE =
            DateTimeFormatter.ofPattern("yyyyMMdd", Locale.ROOT).withZone(ZoneOffset.UTC);
    private static final HexFormat HEX = HexFormat.of();

    /** 工具类不实例化。 */
    private AwsSigV4Signer() {}

    /**
     * 计算需要附加到请求上的签名头。
     *
     * @param method HTTP 方法
     * @param uri 请求地址，不含查询参数
     * @param contentType 请求体类型，可空
     * @param body 请求体，没有时传空数组
     * @param region 签名区域
     * @param service 服务名，如 {@code sts}、{@code s3}
     * @param accessKeyId AccessKey ID
     * @param secretAccessKey AccessKey Secret
     * @param sessionToken 会话令牌，长期密钥时为 {@code null}
     * @param now 签名时间
     * @return 需要设置的请求头（不含 Host，Host 由 HTTP 客户端按同样规则生成）
     */
    public static Map<String, String> sign(
            String method,
            URI uri,
            String contentType,
            byte[] body,
            String region,
            String service,
            String accessKeyId,
            String secretAccessKey,
            String sessionToken,
            Instant now) {
        String amzDate = AMZ_DATE.format(now);
        String date = DATE.format(now);
        String payloadHash = HEX.formatHex(sha256(body));
        TreeMap<String, String> canonicalHeaders = new TreeMap<>();
        canonicalHeaders.put("host", hostHeader(uri));
        canonicalHeaders.put("x-amz-date", amzDate);
        canonicalHeaders.put("x-amz-content-sha256", payloadHash);
        if (contentType != null) {
            canonicalHeaders.put("content-type", contentType);
        }
        if (sessionToken != null) {
            canonicalHeaders.put("x-amz-security-token", sessionToken);
        }
        StringBuilder headerBlock = new StringBuilder();
        canonicalHeaders.forEach((name, value) ->
                headerBlock.append(name).append(':').append(value.trim()).append('\n'));
        String signedHeaders = String.join(";", canonicalHeaders.keySet());
        String canonicalRequest =
                method + "\n" + canonicalPath(uri) + "\n\n" + headerBlock + "\n" + signedHeaders + "\n" + payloadHash;
        String scope = date + "/" + region + "/" + service + "/aws4_request";
        String stringToSign = "AWS4-HMAC-SHA256\n" + amzDate + "\n" + scope + "\n"
                + HEX.formatHex(sha256(canonicalRequest.getBytes(StandardCharsets.UTF_8)));
        byte[] key = hmac(("AWS4" + secretAccessKey).getBytes(StandardCharsets.UTF_8), date);
        key = hmac(key, region);
        key = hmac(key, service);
        key = hmac(key, "aws4_request");
        String signature = HEX.formatHex(hmac(key, stringToSign));

        Map<String, String> headers = new TreeMap<>(canonicalHeaders);
        headers.remove("host");
        headers.put(
                "authorization",
                "AWS4-HMAC-SHA256 Credential=" + accessKeyId + "/" + scope + ", SignedHeaders=" + signedHeaders
                        + ", Signature=" + signature);
        return headers;
    }

    /**
     * 生成与 Java HTTP 客户端一致的 Host 头：显式端口时带端口。
     *
     * @param uri 请求地址
     * @return Host 头的值
     */
    static String hostHeader(URI uri) {
        String host = uri.getHost().toLowerCase(Locale.ROOT);
        return uri.getPort() == -1 ? host : host + ":" + uri.getPort();
    }

    /**
     * 取规范路径。直接使用 URI 的原始（已编码）路径：S3 规范要求只编码一次，
     * 而 System 发出的路径只含桶名与安全字符组成的 key。
     *
     * @param uri 请求地址
     * @return 规范路径
     */
    private static String canonicalPath(URI uri) {
        String path = uri.getRawPath();
        if (path == null || path.isEmpty()) {
            return "/";
        }
        return path;
    }

    /**
     * 计算 SHA-256 摘要。
     *
     * @param value 输入
     * @return 摘要
     */
    private static byte[] sha256(byte[] value) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(value);
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("JDK 缺少 SHA-256", exception);
        }
    }

    /**
     * 计算 HMAC-SHA256。
     *
     * @param key 密钥
     * @param value 待签名文本
     * @return 签名
     */
    private static byte[] hmac(byte[] key, String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException exception) {
            throw new IllegalStateException("JDK 缺少 HmacSHA256", exception);
        }
    }
}
