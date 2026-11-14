package com.kaiwu.module.factory.mapper;

import static org.assertj.core.api.Assertions.assertThat;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.module.factory.entity.ProjectHandoverRow;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.time.LocalDateTime;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 项目配置移交记录 Mapper 的真实 MySQL 契约（ADR 0018、ADR 0042）：record 按列顺序映射、
 * 基线只取最近一次成功记录、失败记录不参与基线、按项目隔离。
 */
class ProjectHandoverMapperMySqlTest {

    private static final String USER_ID = "930000000000000001";
    private static final String PROJECT_ID = "930000000000000002";
    private static final String OTHER_PROJECT_ID = "930000000000000003";
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                            .asCompatibleSubstituteFor("mysql"))
            .withDatabaseName("kaiwu_handover")
            .withUsername("kaiwu_handover")
            .withPassword("kaiwu_handover");

    private static SqlSessionFactory sessionFactory;

    /**
     * 启动 MySQL、执行全部迁移并准备两个项目。
     *
     * @throws Exception 初始化失败时抛出
     */
    @BeforeAll
    static void start() throws Exception {
        MYSQL.start();
        Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + migrationDirectory())
                .load()
                .migrate();
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        MybatisConfiguration configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setEnvironment(new Environment("handover", new JdbcTransactionFactory(), dataSource));
        configuration.addMapper(ProjectHandoverMapper.class);
        sessionFactory = new MybatisSqlSessionFactoryBuilder().build(configuration);
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement user = connection.prepareStatement(
                        """
                        INSERT INTO sys_user (id, username, password_hash, display_name, status, must_change_password,
                                              created_at, updated_at)
                        VALUES (?, 'handover-user', 'not-a-real-password', 'Handover', 'ENABLED', 0,
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """);
                PreparedStatement project = connection.prepareStatement(
                        """
                        INSERT INTO sys_project (id, project_code, project_name, status, built_in, created_by,
                                                 package_name, default_branch, created_at, updated_at)
                        VALUES (?, ?, 'Demo', 'ACTIVE', 0, ?, 'com.example.demo', 'main',
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            user.setLong(1, Long.parseLong(USER_ID));
            user.executeUpdate();
            for (String[] entry : new String[][] {{PROJECT_ID, "demo-a"}, {OTHER_PROJECT_ID, "demo-b"}}) {
                project.setLong(1, Long.parseLong(entry[0]));
                project.setString(2, entry[1]);
                project.setLong(3, Long.parseLong(USER_ID));
                project.executeUpdate();
            }
        }
    }

    /** 停止容器。 */
    @AfterAll
    static void stop() {
        MYSQL.stop();
    }

    /** 记录摘要按列顺序映射回 record，明细 JSON 单独读取。 */
    @Test
    void recordRoundTripsThroughMapping() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectHandoverMapper mapper = session.getMapper(ProjectHandoverMapper.class);
            mapper.insert(
                    row("930000000000000101", PROJECT_ID, "SUCCESS", "digest-a", true, 7, 2, null),
                    "[{\"resource\":\"DICT\"}]",
                    "[\"DICT|a.b\"]");

            ProjectHandoverRow found = mapper.find(PROJECT_ID, "930000000000000101");

            assertThat(found.status()).isEqualTo("SUCCESS");
            assertThat(found.packageDigest()).isEqualTo("digest-a");
            assertThat(found.sourceHost()).isEqualTo("test.example.com");
            assertThat(found.appliedAccess()).isTrue();
            assertThat(found.changeCount()).isEqualTo(7);
            assertThat(found.deleteCount()).isEqualTo(2);
            assertThat(found.operatorId()).isEqualTo(USER_ID);
            assertThat(found.createdAt()).isNotNull();
            assertThat(mapper.changesJson(PROJECT_ID, "930000000000000101")).contains("DICT");
        }
    }

    /** 基线只取最近一次成功记录；失败记录没有业务键，不能当基线。 */
    @Test
    void baselineIsLatestSuccessfulRecordOnly() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectHandoverMapper mapper = session.getMapper(ProjectHandoverMapper.class);
            mapper.insert(
                    row("930000000000000201", OTHER_PROJECT_ID, "SUCCESS", "d1", false, 1, 0, null),
                    "[]",
                    "[\"CONFIG|old\"]");
            mapper.insert(
                    row("930000000000000202", OTHER_PROJECT_ID, "SUCCESS", "d2", false, 1, 0, null),
                    "[]",
                    "[\"CONFIG|new\"]");
            mapper.insert(
                    row("930000000000000203", OTHER_PROJECT_ID, "FAILED", "d3", false, 0, 0, "db down"), "[]", null);

            assertThat(mapper.latestSuccessKeysJson(OTHER_PROJECT_ID)).isEqualTo("[\"CONFIG|new\"]");
            assertThat(mapper.latestSuccessByDigest(OTHER_PROJECT_ID, "d2").id())
                    .isEqualTo("930000000000000202");
            assertThat(mapper.latestSuccessByDigest(OTHER_PROJECT_ID, "d3")).isNull();
            assertThat(mapper.list(OTHER_PROJECT_ID, 10))
                    .extracting(ProjectHandoverRow::status)
                    .contains("FAILED", "SUCCESS");
        }
    }

    /** 记录按项目隔离：用另一个项目的 ID 读不到。 */
    @Test
    void recordsAreIsolatedByProject() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectHandoverMapper mapper = session.getMapper(ProjectHandoverMapper.class);
            mapper.insert(row("930000000000000301", PROJECT_ID, "SUCCESS", "iso", false, 1, 0, null), "[]", "[]");

            assertThat(mapper.find(OTHER_PROJECT_ID, "930000000000000301")).isNull();
            assertThat(mapper.changesJson(OTHER_PROJECT_ID, "930000000000000301"))
                    .isNull();
            assertThat(mapper.latestSuccessByDigest(OTHER_PROJECT_ID, "iso")).isNull();
        }
    }

    /** 构造一条记录摘要。 */
    private static ProjectHandoverRow row(
            String id,
            String projectId,
            String status,
            String digest,
            boolean access,
            int changes,
            int deletes,
            String reason) {
        return new ProjectHandoverRow(
                id,
                projectId,
                status,
                digest,
                "test.example.com",
                "7",
                "2026-10-30T00:00:00Z",
                "plan-hash",
                null,
                access,
                changes,
                deletes,
                reason,
                USER_ID,
                LocalDateTime.now());
    }

    private static Path migrationDirectory() {
        Path current = Path.of("").toAbsolutePath();
        while (current != null) {
            Path candidate = current.resolve("sql/increment");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            current = current.getParent();
        }
        throw new IllegalStateException("未找到 sql/increment 迁移目录");
    }
}
