package ${basePackage};

import io.jsonwebtoken.Jwts;
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
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 接口冒烟：真 HTTP、真鉴权、真数据库，一次走通 Controller → Service → Mapper → MySQL。
 *
 * <p>与 {@link BootSmokeTest} 的分工：那条只证明"应用能起来"，这条证明"接口真的能用"。
 * 切片测试用 mock 替掉了 Service 和拦截器，因此下面这些问题它们一个都发现不了：
 * 路由前缀写错、鉴权拦截器没装上、权限码对不上、Mapper XML 没被扫描到、
 * 返回信封结构与前端约定不一致。</p>
 *
 * <p>Context 令牌在测试内用同一把私钥当场签发，格式必须与 Gateway 完全一致
 * （RS256、typ=kaiwu-context+jwt、60 秒有效期、audience 绑定本服务）——
 * 这等于把 Starter 的校验规则也一并测到了。</p>
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApiSmokeTest {

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
        registry.add("kaiwu.starter.context-public-key", SmokeKeys::publicKeyBase64);
        registry.add("kaiwu.starter.config.enabled", () -> "false");
        registry.add("kaiwu.starter.scheduler.enabled", () -> "false");
    }

    @Test
    void startsAndReportsHealthy() throws Exception {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "/actuator/health"))
                .GET()
                .build();
        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("\"status\":\"UP\"");
    }

    @Test
    void listReturnsEnvelopeWithValidContext() throws Exception {
        HttpResponse<String> response = call(context(List.of("${smokePermission}")));

        // 把响应体带进失败信息：接口挂了的时候，只有一个状态码很难定位。
        assertThat(response.statusCode())
                .withFailMessage("列表接口返回 %s，响应体：%s", response.statusCode(), response.body())
                .isEqualTo(200);
        // 前端 request.ts 按 {code, message, data} 解包，data 分页按 {records, total}。
        // 这三个字段名是前后端的硬约定，改了要两边一起改。
        assertThat(response.body())
                .contains("\"code\":")
                .contains("\"records\":")
                .contains("\"total\":");
    }

    @Test
    void rejectsRequestWithoutContext() throws Exception {
        HttpResponse<String> response = call(null);

        // 没有 Context 就必须被拦住。这条断言守的是"拦截器真的装上了"——
        // 切片测试里拦截器是被绕过的，只有真 HTTP 才能验证。
        assertThat(response.statusCode()).isEqualTo(401);
    }

    @Test
    void rejectsRequestMissingRequiredPermission() throws Exception {
        HttpResponse<String> response = call(context(List.of("${projectCode}:nothing:granted")));

        assertThat(response.statusCode()).isEqualTo(403);
    }

    private HttpResponse<String> call(String contextToken) throws Exception {
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create("http://localhost:" + port + "${smokeListPath}?page=1&size=10"))
                .GET();
        if (contextToken != null) {
            builder.header("X-Kaiwu-Context", contextToken);
        }
        return HttpClient.newHttpClient()
                .send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    /** 按 Gateway 的签发规则当场造一个 Context；任何一项不符都会被 Starter 拒掉。 */
    private static String context(List<String> permissions) {
        Instant now = Instant.now();
        return Jwts.builder()
                .header().type("kaiwu-context+jwt").and()
                .issuer("kaiwu-gateway-service")
                .audience().add("kaiwu-${projectCode}-service").and()
                .subject("9000000000000000001")
                .id(UUID.randomUUID().toString())
                .claim("sid", UUID.randomUUID().toString())
                .claim("projectCode", "${projectCode}")
                .claim("projectId", "${projectId}")
                .claim("permissions", permissions)
                .claim("projectRoleCodes", List.of("admin"))
                .claim("authzVersion", "1")
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(60)))
                .signWith(SmokeKeys.privateKey())
                .compact();
    }

    /** 冒烟用的一次性密钥对。公钥不是 Secret；私钥只存在于本次测试进程内。 */
    static final class SmokeKeys {
        private static final java.security.KeyPair PAIR = generate();

        private static java.security.KeyPair generate() {
            try {
                java.security.KeyPairGenerator generator =
                        java.security.KeyPairGenerator.getInstance("RSA");
                generator.initialize(2048);
                return generator.generateKeyPair();
            } catch (Exception exception) {
                throw new IllegalStateException("生成冒烟用 RSA 密钥失败", exception);
            }
        }

        static java.security.PrivateKey privateKey() {
            return PAIR.getPrivate();
        }

        static String publicKeyBase64() {
            return java.util.Base64.getEncoder().encodeToString(PAIR.getPublic().getEncoded());
        }

        private SmokeKeys() {
        }
    }

}
