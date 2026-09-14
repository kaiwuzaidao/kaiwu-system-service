package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.module.audit.entity.LoginLogEntity;
import com.kaiwu.module.audit.entity.OperationLogEntity;
import com.kaiwu.module.audit.mapper.LoginLogMapper;
import com.kaiwu.module.audit.mapper.OperationLogMapper;
import com.kaiwu.module.scheduler.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.user.entity.UserEntity;
import com.kaiwu.module.user.mapper.UserMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.LocalDateTime;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.output.MigrateResult;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;

/**
 * 平台数据层的真实 MySQL 契约。
 *
 * <p>该测试只连接 Testcontainers 创建的一次性实例，禁止读取任何开发或共享数据库配置。</p>
 */
class MySqlDataLayerContractTest {

    private static final long USER_ID = 900000000000000001L;
    private static final String PROJECT_ID = "900000000000000002";
    private static final String JOB_ID = "900000000000000003";
    private static final String EXECUTION_ID = "900000000000000004";
    private static final long SCHEDULER_USER_ID = 900000000000000006L;

    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
            .withDatabaseName("kaiwu_contract")
            .withUsername("kaiwu_contract")
            .withPassword("kaiwu_contract");

    private static Flyway flyway;
    private static SqlSessionFactory sessionFactory;

    @BeforeAll
    static void startMysqlAndMigrate() {
        MYSQL.start();
        flyway = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + migrationDirectory())
                .load();
        flyway.migrate();
        sessionFactory = new MybatisSqlSessionFactoryBuilder().build(mybatisConfiguration());
    }

    @AfterAll
    static void stopMysql() {
        MYSQL.stop();
    }

    @Test
    void migratesEveryIncrementAndSecondRunIsNoop() throws Exception {
        MigrateResult secondRun = flyway.migrate();

        assertThat(secondRun.migrationsExecuted).isZero();
        try (var paths = Files.list(migrationDirectory())) {
            long migrationCount = paths.filter(
                            path -> path.getFileName().toString().startsWith("V"))
                    .count();
            assertThat(flyway.info().applied()).hasSize((int) migrationCount);
        }
    }

    @Test
    void newProjectAndRepositoryDefaultsUseNeutralMainBranch() throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(
                        """
                     SELECT table_name, column_default
                     FROM information_schema.columns
                     WHERE table_schema = DATABASE()
                       AND table_name IN ('sys_project', 'sys_project_repository')
                       AND column_name = 'default_branch'
                     ORDER BY table_name
                     """);
                ResultSet rows = statement.executeQuery()) {
            assertThat(rows.next()).isTrue();
            assertThat(rows.getString("column_default")).isEqualTo("main");
            assertThat(rows.next()).isTrue();
            assertThat(rows.getString("column_default")).isEqualTo("main");
            assertThat(rows.next()).isFalse();
        }
    }

    @Test
    void userMapperMapsColumnsButNeverSelectsPasswordHashByDefault() {
        LocalDateTime createdAt = LocalDateTime.of(2026, 8, 10, 12, 0, 0);
        UserEntity user = new UserEntity();
        user.setId(USER_ID);
        user.setUsername("mapper-contract-user");
        user.setPasswordHash("never-return-this-hash");
        user.setDisplayName("Mapper Contract User");
        user.setEmail("contract@example.test");
        user.setStatus("ENABLED");
        user.setLocale("ja-JP");
        user.setMustChangePassword(true);
        user.setCreatedAt(createdAt);
        user.setUpdatedAt(createdAt);

        try (SqlSession session = sessionFactory.openSession(true)) {
            UserMapper users = session.getMapper(UserMapper.class);
            assertThat(users.insert(user)).isEqualTo(1);

            UserEntity found = users.selectById(USER_ID);
            assertThat(found.getUsername()).isEqualTo("mapper-contract-user");
            assertThat(found.getLocale()).isEqualTo("ja-JP");
            assertThat(found.getMustChangePassword()).isTrue();
            assertThat(found.getCreatedAt()).isEqualTo(createdAt);
            assertThat(found.getPasswordHash()).isNull();
        }
    }

    @Test
    void auditMappersUseDatabaseGeneratedIds() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            LoginLogEntity login = new LoginLogEntity();
            login.setUsername("mapper-contract-user");
            login.setUserId(USER_ID);
            login.setLoginStatus("SUCCESS");
            login.setMessage("contract");
            login.setClientIp("127.0.0.1");
            login.setTraceId("trace-contract-login");
            login.setCreatedAt(LocalDateTime.of(2026, 8, 10, 12, 1));
            assertThat(session.getMapper(LoginLogMapper.class).insert(login)).isEqualTo(1);
            assertThat(login.getId()).isPositive();

            OperationLogEntity operation = new OperationLogEntity();
            operation.setUserId(USER_ID);
            operation.setUsername("mapper-contract-user");
            operation.setModule("contract");
            operation.setOperation("verify");
            operation.setRequestMethod("POST");
            operation.setRequestPath("/contract");
            operation.setResponseStatus(200);
            operation.setClientIp("127.0.0.1");
            operation.setTraceId("trace-contract-operation");
            operation.setCreatedAt(LocalDateTime.of(2026, 8, 10, 12, 1));
            assertThat(session.getMapper(OperationLogMapper.class).insert(operation))
                    .isEqualTo(1);
            assertThat(operation.getId()).isPositive();
        }
    }

    @Test
    void schedulerMapperPreservesMillisecondScheduleAndRejectsDuplicateClaim() throws Exception {
        seedProject();
        LocalDateTime scheduledAt = LocalDateTime.of(2026, 8, 10, 12, 2, 3, 456_000_000);

        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectSchedulerMapper scheduler = session.getMapper(ProjectSchedulerMapper.class);
            assertThat(scheduler.insertJob(
                            JOB_ID,
                            PROJECT_ID,
                            "contract-job",
                            "contract-task",
                            "0 * * * * *",
                            "Asia/Seoul",
                            "{}",
                            true))
                    .isEqualTo(1);
            assertThat(scheduler.insertExecution(EXECUTION_ID, JOB_ID, PROJECT_ID, 1, scheduledAt, "contract-instance"))
                    .isEqualTo(1);
            assertThat(scheduler.findExecutionId(JOB_ID, scheduledAt)).isEqualTo(EXECUTION_ID);
            assertThatThrownBy(() -> scheduler.insertExecution(
                            "900000000000000005", JOB_ID, PROJECT_ID, 1, scheduledAt, "other-instance"))
                    .isInstanceOf(RuntimeException.class);
        }
    }

    private static MybatisConfiguration mybatisConfiguration() {
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        MybatisConfiguration configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setEnvironment(new Environment("contract", new JdbcTransactionFactory(), dataSource));
        configuration.addMapper(UserMapper.class);
        configuration.addMapper(LoginLogMapper.class);
        configuration.addMapper(OperationLogMapper.class);
        configuration.addMapper(ProjectSchedulerMapper.class);
        return configuration;
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

    private static void seedProject() throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(
                        """
                     INSERT INTO sys_project
                         (id, project_code, project_name, status, built_in, created_by,
                          package_name, default_branch, created_at, updated_at)
                     VALUES (?, 'mapper-contract', 'Mapper Contract', 'ACTIVE', 0, ?,
                             'com.kaiwu.contract', 'main', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                     """)) {
            try (PreparedStatement user = connection.prepareStatement(
                    """
                    INSERT INTO sys_user
                        (id, username, password_hash, display_name, status, must_change_password,
                         created_at, updated_at)
                    VALUES (?, 'scheduler-contract-user', 'not-a-real-password', 'Scheduler Contract User',
                            'ENABLED', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """)) {
                user.setLong(1, SCHEDULER_USER_ID);
                user.executeUpdate();
            }
            statement.setLong(1, Long.parseLong(PROJECT_ID));
            statement.setLong(2, SCHEDULER_USER_ID);
            statement.executeUpdate();
        }
    }
}
