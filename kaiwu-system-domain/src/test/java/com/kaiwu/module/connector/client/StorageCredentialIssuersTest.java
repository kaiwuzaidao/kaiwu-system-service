package com.kaiwu.module.connector.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import java.time.Instant;
import java.util.Map;
import java.util.TreeMap;
import org.junit.jupiter.api.Test;

/** 验证会话策略、阿里云签名编码、响应解析与出站白名单，不访问网络。 */
class StorageCredentialIssuersTest {

    /** 读写策略只给对象级权限，资源限定在项目前缀；只读策略只有 GetObject。 */
    @Test
    void sessionPoliciesAreScopedToTheProjectPrefix() {
        String write = StorageSessionPolicies.s3("files", "demo/", false);
        String read = StorageSessionPolicies.s3("files", "demo/", true);
        String aliyun = StorageSessionPolicies.aliyun("files", "demo/", false);

        assertThat(write).contains("arn:aws:s3:::files/demo/*", "s3:PutObject", "s3:DeleteObject");
        assertThat(write).doesNotContain("s3:ListBucket", "\"s3:*\"");
        assertThat(read).contains("s3:GetObject").doesNotContain("s3:PutObject", "s3:DeleteObject");
        assertThat(aliyun).contains("acs:oss:*:*:files/demo/*", "oss:PutObject").doesNotContain("\"oss:*\"");
    }

    /** 阿里云 POP 编码：空格为 %20、星号为 %2A、波浪号不编码。 */
    @Test
    void aliyunPercentEncodingFollowsPopRules() {
        assertThat(AliyunStsCredentialIssuer.percentEncode("a b*c~d/")).isEqualTo("a%20b%2Ac~d%2F");
    }

    /** 签名只取决于参数集合与 Secret，与参数插入顺序无关；换 Secret 签名随之改变。 */
    @Test
    void aliyunSignatureIsDeterministicAndOrderIndependent() {
        Map<String, String> params = new TreeMap<>(Map.of("Action", "AssumeRole", "Version", "2015-04-01"));
        Map<String, String> reversed = new java.util.LinkedHashMap<>();
        reversed.put("Version", "2015-04-01");
        reversed.put("Action", "AssumeRole");

        String signature = AliyunStsCredentialIssuer.sign("POST", params, "secret");

        assertThat(AliyunStsCredentialIssuer.sign("POST", reversed, "secret")).isEqualTo(signature);
        assertThat(AliyunStsCredentialIssuer.sign("POST", params, "other")).isNotEqualTo(signature);
    }

    /** 阿里云成功响应解析为临时凭证；失败只回显错误码，不回显完整响应。 */
    @Test
    void parsesAliyunResponses() {
        TemporaryCredential credential = AliyunStsCredentialIssuer.parse(
                200,
                """
                {"RequestId":"r","Credentials":{"AccessKeyId":"STS.id","AccessKeySecret":"s",
                 "SecurityToken":"t","Expiration":"2026-10-29T09:00:00Z"}}
                """);

        assertThat(credential.expiresAt()).isEqualTo(Instant.parse("2026-10-29T09:00:00Z"));
        assertThat(credential.toString()).doesNotContain("STS.id", "\"s\"", "t,");
        assertThatThrownBy(() -> AliyunStsCredentialIssuer.parse(
                        403, "{\"Code\":\"NoPermission\",\"Message\":\"internal detail\"}"))
                .hasMessageContaining("NoPermission")
                .hasMessageNotContaining("internal detail");
    }

    /** S3 兼容 STS 的 XML 响应解析，会话令牌不被截断。 */
    @Test
    void parsesS3CompatibleResponseWithoutTruncatingTheToken() {
        String token = "x".repeat(800);
        TemporaryCredential credential = S3CompatibleStsCredentialIssuer.parse(
                "<AssumeRoleResponse><AssumeRoleResult><Credentials><AccessKeyId>AK</AccessKeyId>"
                        + "<SecretAccessKey>SK</SecretAccessKey><SessionToken>" + token + "</SessionToken>"
                        + "<Expiration>2026-10-29T09:00:00Z</Expiration></Credentials></AssumeRoleResult>"
                        + "</AssumeRoleResponse>");

        assertThat(credential.securityToken()).hasSize(800);
        assertThatThrownBy(() -> S3CompatibleStsCredentialIssuer.parse("<Error/>"))
                .isInstanceOf(IllegalStateException.class);
    }

    /** 白名单为空时一律拒绝；IP 字面量即使在白名单里也拒绝。 */
    @Test
    void networkPolicyIsFailClosed() {
        assertThatThrownBy(() -> new StorageNetworkPolicy("", "").verify(URI.create("https://sts.example.com/")))
                .isInstanceOf(SecurityException.class);
        StorageNetworkPolicy policy = new StorageNetworkPolicy("sts.example.com,169.254.169.254", "");

        policy.verify(URI.create("https://STS.example.com/"));
        assertThatThrownBy(() -> policy.verify(URI.create("http://169.254.169.254/")))
                .isInstanceOf(SecurityException.class);
        assertThatThrownBy(() -> policy.verify(URI.create("ftp://sts.example.com/")))
                .isInstanceOf(SecurityException.class);
        assertThatThrownBy(() -> new StorageNetworkPolicy("a", "https://proxy:8080"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    /** 对象地址按访问风格拼接，virtual-hosted 时桶名进入主机名。 */
    @Test
    void buildsObjectUris() {
        URI endpoint = URI.create("https://oss-cn-hangzhou.aliyuncs.com");

        assertThat(StorageObjectProbe.objectUri(endpoint, "files", false, "demo/a"))
                .hasToString("https://files.oss-cn-hangzhou.aliyuncs.com/demo/a");
        assertThat(StorageObjectProbe.objectUri(URI.create("http://minio:9000"), "files", true, "demo/a"))
                .hasToString("http://minio:9000/files/demo/a");
    }
}
