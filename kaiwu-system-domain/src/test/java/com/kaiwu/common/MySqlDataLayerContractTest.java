package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.annotation.DbType;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.entity.AgentMessageEntity;
import com.kaiwu.module.agent.mapper.*;
import com.kaiwu.module.agent.store.AgentConversationStore;
import com.kaiwu.module.identity.entity.UserEntity;
import com.kaiwu.module.identity.mapper.AuthMapper;
import com.kaiwu.module.identity.mapper.DepartmentMapper;
import com.kaiwu.module.identity.mapper.DeviceAuthorizationMapper;
import com.kaiwu.module.identity.mapper.UserMapper;
import com.kaiwu.module.identity.repository.UserRepository;
import com.kaiwu.module.operation.entity.LoginLogEntity;
import com.kaiwu.module.operation.entity.OperationLogEntity;
import com.kaiwu.module.operation.mapper.LoginLogMapper;
import com.kaiwu.module.operation.mapper.OnlineSessionQueryMapper;
import com.kaiwu.module.operation.mapper.OperationLogMapper;
import com.kaiwu.module.operation.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.project.entity.ProjectMemberCandidateRow;
import com.kaiwu.module.project.mapper.ProjectBackendServiceMapper;
import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.mapper.ProjectMemberQueryMapper;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
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
import org.testcontainers.utility.DockerImageName;

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

    /** CI runner 使用可达的镜像镜像源；本地默认仍使用官方标签。 */
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                            .asCompatibleSubstituteFor("mysql"))
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

    /** 选人候选：只返回启用且尚未加入本项目的用户，按关键字匹配登录名与显示名，带上限。 */
    @Test
    void projectMemberCandidatesExcludeMembersDisabledUsersAndHonourTheLimit() throws Exception {
        long projectId = 900000000000000071L;
        try (Connection connection = MYSQL.createConnection("")) {
            insertCandidateUser(connection, 900000000000000072L, "cand-alice", "Alice Candidate", "ENABLED");
            insertCandidateUser(connection, 900000000000000073L, "cand-alan", "Alan Member", "ENABLED");
            insertCandidateUser(connection, 900000000000000074L, "cand-albert", "Albert Disabled", "DISABLED");
            insertCandidateUser(connection, 900000000000000075L, "cand-amy", "Amy Candidate", "ENABLED");
            try (PreparedStatement project = connection.prepareStatement(
                    """
                    INSERT INTO sys_project
                        (id, project_code, project_name, status, built_in, created_by,
                         package_name, default_branch, created_at, updated_at)
                    VALUES (?, 'candidate-contract', 'Candidate Contract', 'ACTIVE', 0, ?,
                            'com.kaiwu.candidate', 'main', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """)) {
                project.setLong(1, projectId);
                project.setLong(2, 900000000000000073L);
                project.executeUpdate();
            }
            try (PreparedStatement member = connection.prepareStatement(
                    """
                    INSERT INTO sys_project_member (project_id, user_id, status, created_at, updated_at)
                    VALUES (?, ?, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    """)) {
                member.setLong(1, projectId);
                member.setLong(2, 900000000000000073L);
                member.executeUpdate();
            }
        }
        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectMapper projects = session.getMapper(ProjectMapper.class);
            assertThat(projects.findMemberCandidates(Long.toString(projectId), "cand-a", 20))
                    .extracting(ProjectMemberCandidateRow::getUsername)
                    .containsExactly("cand-alice", "cand-amy");
            assertThat(projects.findMemberCandidates(Long.toString(projectId), "Candidate", 1))
                    .hasSize(1);
        }
    }

    private static void insertCandidateUser(
            Connection connection, long id, String username, String displayName, String status) throws Exception {
        try (PreparedStatement statement = connection.prepareStatement(
                """
                INSERT INTO sys_user
                    (id, username, password_hash, display_name, status, created_at, updated_at)
                VALUES (?, ?, 'not-a-real-password', ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """)) {
            statement.setLong(1, id);
            statement.setString(2, username);
            statement.setString(3, displayName);
            statement.setString(4, status);
            statement.executeUpdate();
        }
    }

    @Test
    void userDepartmentLockSelectsTheTargetUserAndRejectsUnknownIds() throws Exception {
        long userId = 900000000000000008L;
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(
                        """
                        INSERT INTO sys_user
                            (id, username, password_hash, display_name, status, created_at, updated_at)
                        VALUES (?, 'department-lock-user', 'not-a-real-password', 'Department Lock User',
                                'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            statement.setLong(1, userId);
            statement.executeUpdate();
        }
        try (SqlSession session = sessionFactory.openSession(false)) {
            DepartmentMapper departments = session.getMapper(DepartmentMapper.class);
            assertThat(departments.lockUser(userId)).isEqualTo(userId);
            assertThat(departments.lockUser(userId + 100)).isNull();
            session.rollback();
        }
    }

    @Test
    void userProfileLockMapsEditableFieldsWithoutPasswordHash() throws Exception {
        long userId = 900000000000000009L;
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(
                        """
                        INSERT INTO sys_user
                            (id, username, password_hash, display_name, email, status, created_at, updated_at)
                        VALUES (?, 'profile-lock-user', 'never-return-this-hash', 'Profile Lock User',
                                'profile@example.test', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            statement.setLong(1, userId);
            statement.executeUpdate();
        }
        try (SqlSession session = sessionFactory.openSession(false)) {
            UserMapper mapper = session.getMapper(UserMapper.class);
            UserRepository users = new UserRepository(mapper, Clock.systemUTC());
            var locked = users.findViewForUpdate(String.valueOf(userId)).orElseThrow();
            assertThat(locked.displayName()).isEqualTo("Profile Lock User");
            assertThat(locked.email()).isEqualTo("profile@example.test");
            assertThat(users.findViewForUpdate(String.valueOf(userId + 100))).isEmpty();
            session.rollback();
        }
    }

    @Test
    void agentAutoOpenDefaultsOffAndRoundTripsThroughAuthQueries() throws Exception {
        long userId = 900000000000000007L;
        // 不写 agent_auto_open：存量用户与旧应用创建的用户都必须落到默认值 0。
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement user = connection.prepareStatement(
                        """
                        INSERT INTO sys_user
                            (id, username, password_hash, display_name, status, created_at, updated_at)
                        VALUES (?, 'agent-auto-open-user', 'not-a-real-password', 'Agent Auto Open User',
                                'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            user.setLong(1, userId);
            user.executeUpdate();
        }

        try (SqlSession session = sessionFactory.openSession(true)) {
            AuthMapper auth = session.getMapper(AuthMapper.class);
            assertThat(auth.findUserById(String.valueOf(userId)).getAgentAutoOpen())
                    .isFalse();

            assertThat(auth.updateAgentAutoOpen(String.valueOf(userId), true)).isEqualTo(1);

            assertThat(auth.findUserById(String.valueOf(userId)).getAgentAutoOpen())
                    .isTrue();
            assertThat(auth.findUserByUsername("agent-auto-open-user").getAgentAutoOpen())
                    .isTrue();
        }
    }

    /** 设备授权的条件更新只允许一次决定、一次兑换；CLI 会话带来源并能被会话列表读出（ADR 0035）。 */
    @Test
    void deviceAuthorizationTransitionsOnceAndCliSessionCarriesSource() throws Exception {
        long userId = 900000000000000041L;
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement user = connection.prepareStatement(
                        """
                        INSERT INTO sys_user
                            (id, username, password_hash, display_name, status, created_at, updated_at)
                        VALUES (?, 'device-auth-user', 'not-a-real-password', 'Device Auth User',
                                'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            user.setLong(1, userId);
            user.executeUpdate();
        }
        LocalDateTime now = LocalDateTime.of(2026, 10, 28, 8, 0);

        try (SqlSession session = sessionFactory.openSession(true)) {
            DeviceAuthorizationMapper device = session.getMapper(DeviceAuthorizationMapper.class);
            assertThat(device.insert(
                            "req-contract", "digest-1", "WDJB-MJHT", "Trae", "10.0.0.8", now.plusMinutes(10), now))
                    .isEqualTo(1);
            assertThat(device.findPendingByUserCode("WDJB-MJHT", now).getClientName())
                    .isEqualTo("Trae");
            assertThat(device.findPendingByUserCode("WDJB-MJHT", now.plusMinutes(11)))
                    .isNull();

            assertThat(device.decide("req-contract", "APPROVED", String.valueOf(userId), now))
                    .isEqualTo(1);
            assertThat(device.decide("req-contract", "DENIED", String.valueOf(userId), now))
                    .isZero();
            assertThat(device.findByDeviceCodeHash("digest-1").getUserId()).isEqualTo(String.valueOf(userId));

            assertThat(device.consume("req-contract", now)).isEqualTo(1);
            assertThat(device.consume("req-contract", now)).isZero();
            assertThat(device.findByDeviceCodeHash("digest-1").getAuthStatus()).isEqualTo("CONSUMED");

            assertThat(device.deleteExpiredBefore(now.plusDays(1))).isEqualTo(1);

            AuthMapper auth = session.getMapper(AuthMapper.class);
            auth.createSession(
                    "00000000-0000-0000-0000-00000000c111",
                    String.valueOf(userId),
                    "hash",
                    "CLI",
                    "Trae",
                    now.plusDays(7));
            auth.createSession(
                    "00000000-0000-0000-0000-00000000c112",
                    String.valueOf(userId),
                    "hash",
                    "WEB",
                    null,
                    now.plusDays(7));
            OnlineSessionQueryMapper sessions = session.getMapper(OnlineSessionQueryMapper.class);
            assertThat(sessions.findById("00000000-0000-0000-0000-00000000c111").getSessionSource())
                    .isEqualTo("CLI");
            assertThat(sessions.findById("00000000-0000-0000-0000-00000000c111").getClientName())
                    .isEqualTo("Trae");
            assertThat(sessions.findById("00000000-0000-0000-0000-00000000c112").getSessionSource())
                    .isEqualTo("WEB");
        }
    }

    /** 国际化资源在作用域内唯一：不同项目、项目与平台可以用同一个 key，同一作用域内不能重复（ADR 0037）。 */
    @Test
    void i18nMessageKeyIsUniqueWithinScopeOnly() throws Exception {
        String insert =
                """
                INSERT INTO sys_i18n_message
                    (id, scope_id, message_key, default_text, module_code, public_visible, required_resource,
                     status, version, created_at, updated_at)
                VALUES (?, ?, 'dict.contract.scope.SAME', '文本', 'project', 0, 0, 'ENABLED', 1,
                        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                """;
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(insert)) {
            statement.setLong(1, 900000000000000051L);
            statement.setLong(2, 0L);
            statement.executeUpdate();
            statement.setLong(1, 900000000000000052L);
            statement.setLong(2, 900000000000000053L);
            statement.executeUpdate();
            statement.setLong(1, 900000000000000054L);
            statement.setLong(2, 900000000000000055L);
            statement.executeUpdate();

            statement.setLong(1, 900000000000000056L);
            statement.setLong(2, 900000000000000053L);
            assertThatThrownBy(statement::executeUpdate).hasMessageContaining("Duplicate entry");
        }
    }

    /**
     * 平台连接串带 connectionTimeZone 与 forceConnectionTimeZoneToSession 后，数据库写入的时间
     * 与 Java 写入的时间落在同一个时区；少了任何一个参数，两者会相差整数小时。
     */
    @Test
    void databaseAndJavaTimestampsShareTheConfiguredZone() throws Exception {
        String zone = "Asia/Shanghai";
        String base = MYSQL.getJdbcUrl();
        String url = base + (base.contains("?") ? "&" : "?") + "connectionTimeZone=" + zone
                + "&forceConnectionTimeZoneToSession=true";
        try (Connection connection = DriverManager.getConnection(url, MYSQL.getUsername(), MYSQL.getPassword());
                PreparedStatement statement = connection.prepareStatement("SELECT CURRENT_TIMESTAMP")) {
            try (ResultSet result = statement.executeQuery()) {
                assertThat(result.next()).isTrue();
                LocalDateTime database = result.getObject(1, LocalDateTime.class);
                LocalDateTime java = LocalDateTime.now(ZoneId.of(zone));
                assertThat(Duration.between(database, java).abs()).isLessThan(Duration.ofMinutes(1));
            }
        }
    }

    @Test
    void bootstrapAdminMustChangePasswordAndStartsInAgentMode() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            AuthMapper auth = session.getMapper(AuthMapper.class);
            assertThat(auth.insertBootstrapAdmin("bootstrap-hash")).isEqualTo(1);

            var admin = auth.findUserByUsername("admin");
            assertThat(admin.getMustChangePassword()).isTrue();
            assertThat(admin.getAgentAutoOpen()).isTrue();
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

    /** 服务凭据到期时间按UTC冻结，MySQL会话时区变化不得提前拒绝或延后失效。 */
    @Test
    void serviceCredentialExpiryIsIndependentOfDatabaseSessionTimezone() throws Exception {
        seedProject();
        try (SqlSession session = sessionFactory.openSession(true)) {
            var mapper = session.getMapper(ProjectSchedulerMapper.class);
            var expiry = LocalDateTime.now(ZoneOffset.UTC).plusHours(1);
            mapper.insertScopedCredential("900000000000000088", PROJECT_ID, "test-hash", "tztest", expiry);
            try (var statement = session.getConnection().createStatement()) {
                statement.execute("SET time_zone='+09:00'");
            }
            assertThat(mapper.findCredential("900000000000000088")).isNotNull();
            try (var statement = session.getConnection().createStatement()) {
                statement.execute("SET time_zone='-09:00'");
                statement.execute(
                        "UPDATE sys_scheduler_credential SET expires_at='2000-01-01 00:00:00' WHERE id=900000000000000088");
            }
            session.clearCache();
            assertThat(mapper.findCredential("900000000000000088")).isNull();
        }
    }

    /** 旧轮换只影响 default，且过期服务凭据不能认证。 */
    @Test
    void oldRotationRevokesOnlyDefaultAndExpiredCredentialsAreRejected() throws Exception {
        seedProject();
        try (Connection connection =
                        DriverManager.getConnection(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
                PreparedStatement insert = connection.prepareStatement(
                        """
                        INSERT INTO sys_scheduler_credential(id, project_id, token_hash, status, service_code, expires_at, created_at, updated_at)
                        VALUES (?, ?, 'test-hash', 'ACTIVE', ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            for (int index = 0; index < 3; index++) {
                insert.setLong(1, 900000000000000050L + index);
                insert.setString(2, PROJECT_ID);
                insert.setString(3, index == 0 ? "default" : "workflow");
                insert.setObject(4, index == 2 ? LocalDateTime.of(2000, 1, 1, 0, 0) : null);
                insert.executeUpdate();
            }
            try (PreparedStatement scope = connection.prepareStatement(
                    "INSERT INTO sys_service_credential_scope (credential_id,scope_code) VALUES (?,?)")) {
                scope.setLong(1, 900000000000000051L);
                scope.setString(2, "member:read");
                scope.executeUpdate();
            }
        }
        try (SqlSession session = sessionFactory.openSession(true)) {
            ProjectSchedulerMapper mapper = session.getMapper(ProjectSchedulerMapper.class);
            assertThat(mapper.findCredential("900000000000000050").getServiceCode())
                    .isEqualTo("default");
            assertThat(mapper.findCredential("900000000000000052")).isNull();
            assertThat(mapper.credentialScopes("900000000000000051")).containsExactly("member:read");
            LocalDateTime now = LocalDateTime.now().withNano(0);
            assertThat(mapper.touchCredential("900000000000000051", now, now.minusMinutes(1)))
                    .isEqualTo(1);
            assertThat(mapper.touchCredential("900000000000000051", now.plusSeconds(30), now.minusSeconds(30)))
                    .isZero();
            assertThat(mapper.touchCredential("900000000000000051", now.plusMinutes(2), now.plusMinutes(1)))
                    .isEqualTo(1);
            assertThat(mapper.revokeCredentials(PROJECT_ID)).isEqualTo(1);
            assertThat(mapper.findCredential("900000000000000050")).isNull();
            assertThat(mapper.findCredential("900000000000000051").getServiceCode())
                    .isEqualTo("workflow");
        }
    }

    /** 同一项目并发签发须串行，不能超过两份有效凭据。 */
    @Test
    void concurrentServiceCredentialIssuanceHonorsProjectLock() throws Exception {
        seedProject();
        var pool = Executors.newFixedThreadPool(3);
        var ready = new CountDownLatch(3);
        var go = new CountDownLatch(1);
        try {
            var futures = new ArrayList<Future<Boolean>>();
            for (int i = 0; i < 3; i++) {
                final String id = Long.toString(900000000000000080L + i);
                futures.add(pool.submit(() -> {
                    ready.countDown();
                    if (!go.await(10, TimeUnit.SECONDS)) throw new IllegalStateException("start timeout");
                    try (SqlSession session = sessionFactory.openSession(false)) {
                        var mapper = session.getMapper(ProjectSchedulerMapper.class);
                        if (mapper.lockActiveCredentialProject(PROJECT_ID) == null)
                            throw new IllegalStateException("missing project");
                        if (mapper.activeServiceCredentials(PROJECT_ID, "race").size() >= 2) {
                            session.rollback();
                            return false;
                        }
                        mapper.insertScopedCredential(
                                id,
                                PROJECT_ID,
                                "hash",
                                "race",
                                LocalDateTime.now().plusHours(1));
                        mapper.insertCredentialScope(id, "member:read");
                        session.commit();
                        return true;
                    }
                }));
            }
            assertThat(ready.await(10, TimeUnit.SECONDS)).isTrue();
            go.countDown();
            int successes = 0;
            for (var future : futures) if (future.get(30, TimeUnit.SECONDS)) successes++;
            assertThat(successes).isEqualTo(2);
        } finally {
            pool.shutdownNow();
        }
    }

    /** 真实 SQL 排除停用用户、失效成员和其他项目，并支持限额探测。 */
    @Test
    void candidateQueriesUseActiveProjectUserMembershipAndRole() throws Exception {
        seedProject();
        try (Connection c = MYSQL.createConnection("");
                var stmt = c.createStatement()) {
            stmt.executeUpdate(
                    "INSERT INTO sys_user (id,username,password_hash,display_name,status,created_at,updated_at) VALUES "
                            + "(900000000000000101,'c3-active','x','active','ENABLED',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),"
                            + "(900000000000000102,'c3-disabled','x','disabled','DISABLED',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
            stmt.executeUpdate(
                    "INSERT INTO sys_project_member (project_id,user_id,status,created_at,updated_at) VALUES "
                            + "(" + PROJECT_ID + ",900000000000000101,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),"
                            + "(" + PROJECT_ID + ",900000000000000102,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
            stmt.executeUpdate(
                    "INSERT INTO sys_project_role (id,project_id,role_code,role_name,status,built_in,created_at,updated_at) VALUES "
                            + "(900000000000000103," + PROJECT_ID
                            + ",'c3-approver','approver','ACTIVE',0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
            stmt.executeUpdate("INSERT INTO sys_project_member_role (project_id,user_id,role_id,created_at) VALUES "
                    + "(" + PROJECT_ID + ",900000000000000101,900000000000000103,CURRENT_TIMESTAMP),"
                    + "(" + PROJECT_ID + ",900000000000000102,900000000000000103,CURRENT_TIMESTAMP)");
        }
        try (SqlSession session = sessionFactory.openSession(true)) {
            var mapper = session.getMapper(ProjectMemberQueryMapper.class);
            assertThat(mapper.matchesProject(PROJECT_ID, "mapper-contract")).isEqualTo(1);
            assertThat(mapper.matchesProject(PROJECT_ID, "other")).isZero();
            assertThat(mapper.activeRole(PROJECT_ID, "c3-approver")).isEqualTo(1);
            assertThat(mapper.membersByRole(PROJECT_ID, "c3-approver", 2)).containsExactly("900000000000000101");
            assertThat(mapper.eligibleMembers(
                            PROJECT_ID, java.util.List.of("900000000000000101", "900000000000000102"), null))
                    .containsExactly("900000000000000101");
            assertThat(mapper.eligibleMembers(PROJECT_ID, java.util.List.of("900000000000000101"), "not-this-role"))
                    .isEmpty();
            try (Connection c = MYSQL.createConnection("");
                    var user = c.prepareStatement(
                            "INSERT INTO sys_user(id,username,password_hash,display_name,status,created_at,updated_at) VALUES (?,?,'x','test','ENABLED',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                    var member = c.prepareStatement(
                            "INSERT INTO sys_project_member(project_id,user_id,status,created_at,updated_at) VALUES (?,?,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                    var role = c.prepareStatement(
                            "INSERT INTO sys_project_member_role(project_id,user_id,role_id,created_at) VALUES (?,?,900000000000000103,CURRENT_TIMESTAMP)")) {
                for (int i = 0; i < 200; i++) {
                    long id = 900000000000001000L + i;
                    user.setLong(1, id);
                    user.setString(2, "c3-bulk-" + i);
                    user.addBatch();
                    member.setString(1, PROJECT_ID);
                    member.setLong(2, id);
                    member.addBatch();
                    role.setString(1, PROJECT_ID);
                    role.setLong(2, id);
                    role.addBatch();
                }
                user.executeBatch();
                member.executeBatch();
                role.executeBatch();
            }
            assertThat(mapper.membersByRole(PROJECT_ID, "c3-approver", 201)).hasSize(201);
            var repository = new com.kaiwu.module.project.repository.ProjectMemberQueryRepository(mapper);
            var credentials =
                    org.mockito.Mockito.mock(com.kaiwu.module.project.service.ProjectServiceCredentials.class);
            org.mockito.Mockito.when(credentials.authenticateScopeBearer("Bearer test", "member:read"))
                    .thenReturn(
                            new com.kaiwu.module.project.model.ProjectServiceCredential("1", PROJECT_ID, "workflow"));
            var service = new com.kaiwu.module.project.service.impl.ProjectMemberQueryServiceImpl(
                    credentials, repository, 200);
            try (Connection c = MYSQL.createConnection("");
                    var stmt = c.createStatement()) {
                stmt.executeUpdate("DELETE FROM sys_project_member_role WHERE project_id=" + PROJECT_ID
                        + " AND user_id=900000000000001199 AND role_id=900000000000000103");
            }
            session.clearCache();
            assertThat(service.byRole("Bearer test", "mapper-contract", "c3-approver")
                            .userIds())
                    .hasSize(200);
            try (Connection c = MYSQL.createConnection("");
                    var stmt = c.createStatement()) {
                stmt.executeUpdate("INSERT INTO sys_project_member_role(project_id,user_id,role_id,created_at) VALUES ("
                        + PROJECT_ID + ",900000000000001199,900000000000000103,CURRENT_TIMESTAMP)");
            }
            session.clearCache();
            assertThatThrownBy(() -> service.byRole("Bearer test", "mapper-contract", "c3-approver"))
                    .isInstanceOfSatisfying(
                            ApiException.class,
                            ex -> assertThat(ex.getStatus().value()).isEqualTo(422));
        }
    }

    /** 旧项目服务地址清空或更新时，default 登记与项目字段保持事务一致。 */
    @Test
    void defaultBackendAddressTracksLegacyProjectField() throws Exception {
        seedProject();
        try (Connection c = MYSQL.createConnection("");
                var stmt = c.createStatement()) {
            stmt.executeUpdate("UPDATE sys_project SET service_url='http://example.test:8080' WHERE id=" + PROJECT_ID);
        }
        try (SqlSession session = sessionFactory.openSession(true)) {
            var mapper = session.getMapper(ProjectMapper.class);
            mapper.syncDefaultBackendService(PROJECT_ID);
            try (Connection c = MYSQL.createConnection("");
                    var q = c.prepareStatement(
                            "SELECT service_url,status FROM sys_project_backend_service WHERE project_id=? AND service_code='default'")) {
                q.setString(1, PROJECT_ID);
                try (var r = q.executeQuery()) {
                    assertThat(r.next()).isTrue();
                    assertThat(r.getString(1)).isEqualTo("http://example.test:8080");
                    assertThat(r.getString(2)).isEqualTo("ENABLED");
                }
                try (var clear = c.createStatement()) {
                    clear.executeUpdate("UPDATE sys_project SET service_url=NULL WHERE id=" + PROJECT_ID);
                }
                mapper.syncDefaultBackendService(PROJECT_ID);
                try (var r = q.executeQuery()) {
                    assertThat(r.next()).isTrue();
                    assertThat(r.getString(1)).isNull();
                }
            }
        }
    }

    /** 登记服务使用项目复合唯一键，地址和状态只能修改本项目。 */
    @Test
    void backendServiceRegistryUsesProjectScopedKeys() throws Exception {
        seedProject();
        try (SqlSession session = sessionFactory.openSession(true)) {
            var mapper = session.getMapper(ProjectBackendServiceMapper.class);
            assertThat(mapper.insert(PROJECT_ID, "wfreg", "http://localhost:8091"))
                    .isEqualTo(1);
            assertThat(mapper.find(PROJECT_ID, "wfreg").getServiceUrl()).isEqualTo("http://localhost:8091");
            assertThatThrownBy(() -> mapper.insert(PROJECT_ID, "wfreg", "http://localhost:8092"))
                    .isInstanceOf(RuntimeException.class);
            assertThat(mapper.updateStatus(PROJECT_ID, "wfreg", "DISABLED")).isEqualTo(1);
            assertThat(mapper.updateUrl(PROJECT_ID, "wfreg", "http://localhost:8093"))
                    .isEqualTo(1);
            assertThat(mapper.find(PROJECT_ID, "wfreg").getStatus()).isEqualTo("DISABLED");
            assertThat(mapper.find(PROJECT_ID, "wfreg").getServiceUrl()).isEqualTo("http://localhost:8093");
            assertThat(mapper.find("900000000000000999", "wfreg")).isNull();
        }
    }

    @Test
    void personalAgentDataIsOwnedPaginatedAndNeverReplaysDuplicateTurns() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            var store = new AgentConversationStore(
                    session.getMapper(AgentConversationMapper.class),
                    session.getMapper(AgentMessageMapper.class),
                    session.getMapper(AgentMemoryMapper.class));
            var conversation = store.create("900000000000000020", new AgentConversationRequest("历史记录", true));
            assertThat(store.list("900000000000000020", 1).total()).isEqualTo(1);
            assertThat(store.list("900000000000000021", 1).records()).isEmpty();
            assertThatThrownBy(() -> store.messages("900000000000000021", conversation.id(), 1))
                    .isInstanceOf(ApiException.class);
            assertThatThrownBy(() -> store.update(
                            "900000000000000021", conversation.id(), new AgentConversationRequest("越权", false)))
                    .isInstanceOf(ApiException.class);
            assertThatThrownBy(() -> store.delete("900000000000000021", conversation.id()))
                    .isInstanceOf(ApiException.class);
            for (int i = 0; i < 32; i++) {
                var request = new AgentMessageRequest("问题" + i, "request-identifier-" + i, null);
                var messageId = store.begin("900000000000000020", conversation.id(), request);
                assertThatThrownBy(() -> store.begin(
                                "900000000000000020",
                                conversation.id(),
                                new AgentMessageRequest("重复并发", "another-request-identifier", null)))
                        .isInstanceOf(ApiException.class);
                assertThatThrownBy(() -> store.delete("900000000000000020", conversation.id()))
                        .isInstanceOf(ApiException.class);
                assertThat(store.finish("900000000000000021", conversation.id(), messageId, "越权", true))
                        .isFalse();
                assertThat(store.finish("900000000000000020", conversation.id(), "999", "旧结果", true))
                        .isFalse();
                assertThat(store.finish("900000000000000020", conversation.id(), messageId, "答复" + i, true))
                        .isTrue();
                assertThatThrownBy(() -> store.begin("900000000000000020", conversation.id(), request))
                        .isInstanceOf(ApiException.class);
            }
            assertThat(store.messages("900000000000000020", conversation.id(), 1)
                            .records())
                    .hasSize(30);
            assertThat(store.messages("900000000000000020", conversation.id(), 2)
                            .records())
                    .hasSize(2);
            assertThat(store.messages("900000000000000020", conversation.id(), 1)
                            .total())
                    .isEqualTo(32);
            assertThat(store.history("900000000000000020", conversation.id()))
                    .hasSize(4)
                    .extracting(AgentConversationTurn::answer)
                    .containsExactly("答复28", "答复29", "答复30", "答复31");
            assertThat(store.owned("900000000000000020", conversation.id()).getRunId())
                    .isNull();
            var updated =
                    store.update("900000000000000020", conversation.id(), new AgentConversationRequest("修改", false));
            assertThat(updated.useMemory()).isFalse();
            store.delete("900000000000000020", conversation.id());
            assertThat(session.getMapper(AgentMessageMapper.class)
                            .selectCount(
                                    new QueryWrapper<AgentMessageEntity>().eq("conversation_id", conversation.id())))
                    .isZero();
        }
    }

    @Test
    void personalMemoryOwnershipToggleLimitsAndDeletion() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            var store = new AgentConversationStore(
                    session.getMapper(AgentConversationMapper.class),
                    session.getMapper(AgentMessageMapper.class),
                    session.getMapper(AgentMemoryMapper.class));
            var memory = store.saveMemory("900000000000000030", null, new AgentMemoryRequest("使用简短中文", true));
            assertThat(store.memories("900000000000000031")).isEmpty();
            assertThatThrownBy(() ->
                            store.saveMemory("900000000000000031", memory.id(), new AgentMemoryRequest("越权", true)))
                    .isInstanceOf(ApiException.class);
            assertThatThrownBy(() -> store.deleteMemory("900000000000000031", memory.id()))
                    .isInstanceOf(ApiException.class);
            assertThat(store.saveMemory("900000000000000030", memory.id(), new AgentMemoryRequest("按周汇总", false))
                            .enabled())
                    .isFalse();
            for (int i = 1; i < 20; i++)
                store.saveMemory("900000000000000030", null, new AgentMemoryRequest("偏好" + i, true));
            assertThatThrownBy(() -> store.saveMemory("900000000000000030", null, new AgentMemoryRequest("超限", true)))
                    .isInstanceOf(ApiException.class);
            store.deleteMemory("900000000000000030", memory.id());
            assertThat(store.memories("900000000000000030")).hasSize(19);
        }
    }

    private static MybatisConfiguration mybatisConfiguration() {
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        MybatisConfiguration configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setEnvironment(new Environment("contract", new JdbcTransactionFactory(), dataSource));
        var pagination = new MybatisPlusInterceptor();
        pagination.addInnerInterceptor(new PaginationInnerInterceptor(DbType.MYSQL));
        configuration.addInterceptor(pagination);
        configuration.addMapper(AgentConversationMapper.class);
        configuration.addMapper(AgentMessageMapper.class);
        configuration.addMapper(AgentMemoryMapper.class);
        configuration.addMapper(UserMapper.class);
        configuration.addMapper(ProjectMapper.class);
        configuration.addMapper(ProjectBackendServiceMapper.class);
        configuration.addMapper(ProjectMemberQueryMapper.class);
        configuration.addMapper(AuthMapper.class);
        configuration.addMapper(DeviceAuthorizationMapper.class);
        configuration.addMapper(OnlineSessionQueryMapper.class);
        configuration.addMapper(DepartmentMapper.class);
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
                     INSERT IGNORE INTO sys_project
                         (id, project_code, project_name, status, built_in, created_by,
                          package_name, default_branch, created_at, updated_at)
                     VALUES (?, 'mapper-contract', 'Mapper Contract', 'ACTIVE', 0, ?,
                             'com.kaiwu.contract', 'main', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                     """)) {
            try (PreparedStatement user = connection.prepareStatement(
                    """
                    INSERT IGNORE INTO sys_user
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
