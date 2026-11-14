package com.kaiwu.module.connector.client;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 在 LocalStack 上跑通 STS AssumeRole 与对象写删的完整协议流程。
 *
 * <p>LocalStack 不校验签名、也不执行会话策略，所以本测试证明的是请求格式、响应解析与探测流程；
 * 签名正确性由 {@link AwsSigV4SignerTest} 对照 AWS 官方签名器保证。内网 CI 拉不到镜像，
 * 只有设置 {@code KAIWU_TEST_LOCALSTACK_IMAGE} 时才运行。
 */
@EnabledIfEnvironmentVariable(named = "KAIWU_TEST_LOCALSTACK_IMAGE", matches = ".+")
class StorageLocalStackIntegrationTest {

    private static final String BUCKET = "kaiwu-files";
    private static final GenericContainer<?> LOCALSTACK = new GenericContainer<>(
                    DockerImageName.parse(System.getenv("KAIWU_TEST_LOCALSTACK_IMAGE")))
            .withEnv("SERVICES", "s3,sts")
            .withExposedPorts(4566);

    private static String endpoint;

    /**
     * 启动 LocalStack 并用长期密钥创建测试桶。
     *
     * @throws Exception 创建桶失败时抛出
     */
    @BeforeAll
    static void start() throws Exception {
        LOCALSTACK.start();
        endpoint = "http://localhost:" + LOCALSTACK.getMappedPort(4566);
        URI bucket = URI.create(endpoint + "/" + BUCKET);
        Map<String, String> headers = AwsSigV4Signer.sign(
                "PUT", bucket, null, new byte[0], "us-east-1", "s3", "test", "test", null, Instant.now());
        HttpRequest.Builder request = HttpRequest.newBuilder(bucket).PUT(HttpRequest.BodyPublishers.noBody());
        headers.forEach(request::header);
        HttpResponse<String> response = HttpClient.newBuilder()
                .proxy(HttpClient.Builder.NO_PROXY)
                .build()
                .send(request.build(), HttpResponse.BodyHandlers.ofString());
        assertThat(response.statusCode()).isEqualTo(200);
    }

    /** 停止容器。 */
    @AfterAll
    static void stop() {
        LOCALSTACK.stop();
    }

    /** 签发项目前缀凭证，并用签出的凭证在探测前缀下写入、删除对象。 */
    @Test
    void assumesRoleAndWritesThenDeletesProbeObject() {
        StorageNetworkPolicy policy = new StorageNetworkPolicy("localhost", "");
        S3CompatibleStsCredentialIssuer issuer = new S3CompatibleStsCredentialIssuer(policy, Clock.systemUTC());
        StorageAccountAccess account = new StorageAccountAccess(
                S3CompatibleStsCredentialIssuer.PROVIDER_TYPE,
                endpoint,
                "us-east-1",
                BUCKET,
                true,
                endpoint,
                "arn:aws:iam::000000000000:role/kaiwu",
                "test",
                "test");

        TemporaryCredential credential =
                issuer.assumeRole(account, "kaiwu-probe", StorageObjectProbe.PROBE_PREFIX, false, 900);
        new StorageObjectProbe(policy, Clock.systemUTC()).writeAndDelete(account, credential);

        assertThat(credential.accessKeyId()).isNotBlank();
        assertThat(credential.securityToken()).isNotBlank();
        assertThat(credential.expiresAt()).isAfter(Instant.now());
    }
}
