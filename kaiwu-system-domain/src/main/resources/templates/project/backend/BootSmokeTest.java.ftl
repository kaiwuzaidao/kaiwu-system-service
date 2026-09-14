package ${basePackage};

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MySQLContainer;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 启动冒烟：把服务真的拉起来，跑一次 Flyway，再打一次健康检查。
 *
 * <p>为什么单独要这一条：其余测试全部是切片或纯单测（Controller 用 standalone MockMvc
 * 配 mock，Service 测逻辑），没有任何一个会加载完整 Spring 上下文。
 * "编译通过"和"能启动"是两件事——缺 Bean、配置写错、Mapper XML 找不到、迁移脚本有语法
 * 错，这些只有真的 run 一次才会暴露。</p>
 *
 * <p>数据库用 Testcontainers 的一次性 MySQL，绝不读开发库或共享库的配置。</p>
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class BootSmokeTest {

    private static final MySQLContainer<?> MYSQL =
            new MySQLContainer<>("mysql:8.4").withDatabaseName("kaiwu_${normalizedProjectCode}");

    static {
        MYSQL.start();
    }

    @LocalServerPort
    private int port;

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("spring.flyway.default-schema", MYSQL::getDatabaseName);
        // Context 公钥是公开值，不是 Secret；这里当场生成一把，只为让校验器能完成装配。
        // 冒烟不验证令牌校验逻辑本身，那由 Gateway 与 Starter 各自的测试覆盖。
        registry.add("kaiwu.starter.context-public-key", BootSmokeTest::generatePublicKey);
        // 参数配置客户端会去连 Kaiwu System；冒烟阶段平台不在，关掉以免拖慢启动。
        registry.add("kaiwu.starter.config.enabled", () -> "false");
        registry.add("kaiwu.starter.scheduler.enabled", () -> "false");
    }

    private static String generatePublicKey() {
        try {
            KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
            generator.initialize(2048);
            KeyPair keyPair = generator.generateKeyPair();
            return Base64.getEncoder().encodeToString(keyPair.getPublic().getEncoded());
        } catch (Exception exception) {
            throw new IllegalStateException("生成冒烟用 RSA 公钥失败", exception);
        }
    }

    @Test
    void startsAndReportsHealthy() throws Exception {
        // 用 JDK 自带的 HttpClient，不依赖任何被自动装配的 Web 客户端 Bean——
        // 这条测试要验证的是"应用能起来"，不该因为客户端 Bean 缺失而失败。
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "/actuator/health"))
                .GET()
                .build();
        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("\"status\":\"UP\"");
    }
}
