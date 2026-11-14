package com.kaiwu;

import static org.assertj.core.api.Assertions.assertThat;

import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.service.AgentService;
import com.kaiwu.module.identity.service.UserService;
import com.kaiwu.module.project.service.ProjectService;
import java.security.KeyPairGenerator;
import java.util.Base64;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mysql.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** Full component scan, transaction proxies and mapper XML against isolated disposable databases. */
@Testcontainers
@SpringBootTest(
        properties = {
            "spring.profiles.active=package-test",
            "spring.config.import=",
            "spring.cloud.nacos.config.enabled=false",
            "spring.cloud.nacos.discovery.enabled=false",
            "kaiwu.starter.enabled=true",
            "kaiwu.starter.audience=kaiwu-system-service",
            "kaiwu.agent.remote.enabled=false",
            "kaiwu.agent.remote.write-enabled=false"
        })
class PackageWiringTest {
    @Container
    static final MySQLContainer MYSQL = new MySQLContainer(
            DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                    .asCompatibleSubstituteFor("mysql"));

    @Container
    static final GenericContainer<?> REDIS = new GenericContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_REDIS_IMAGE", "redis:7.4-alpine")))
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void configure(DynamicPropertyRegistry registry) throws Exception {
        Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:"
                        + java.nio.file.Path.of("../sql/increment").toAbsolutePath())
                .load()
                .migrate();
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
        var generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        var key = generator.generateKeyPair();
        registry.add("kaiwu.starter.context-public-key", () -> Base64.getEncoder()
                .encodeToString(key.getPublic().getEncoded()));
        registry.add("kaiwu.auth.access-private-key", () -> Base64.getEncoder()
                .encodeToString(key.getPrivate().getEncoded()));
        // Ephemeral bootstrap applies only to this test container, never a local or production database.
        String password = java.util.UUID.randomUUID().toString();
        registry.add("kaiwu.auth.bootstrap-admin-password", () -> password);
        registry.add("kaiwu.metadata.encryption-key", () -> Base64.getEncoder().encodeToString(new byte[32]));
        registry.add("kaiwu.codegen.artifact-root", () -> "target/package-test-artifacts");
    }

    @Autowired
    ApplicationContext context;

    @Test
    void scansMovedComponentsAndQueriesThroughTheRealMappers() {
        var projects = context.getBean(ProjectService.class);
        assertThat(context.getBean("projectService")).isSameAs(projects);
        assertThat(org.springframework.aop.support.AopUtils.isAopProxy(projects))
                .isTrue();
        assertThat(context.getBean(UserService.class).page(null, 1, 10).total()).isPositive();
        assertThat(context.getBean(AgentService.class)).isNotNull();
        assertThat(context.getBean(CapabilityCatalog.class).size()).isPositive();
        assertThat(context.getBean(com.kaiwu.module.agent.mapper.AgentCapabilityMapper.class)
                        .selectList(null))
                .isEmpty();
        // Exercise the relocated XML namespace as well as MyBatis-Plus generated statements.
        assertThat(context.getBean(com.kaiwu.module.agent.mapper.AgentCapabilityMapper.class)
                        .countProjectAdmin("missing-project", "missing-user"))
                .isZero();
    }
}
