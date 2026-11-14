package com.kaiwu;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.github.dockerjava.api.model.ExposedPort;
import com.kaiwu.config.MybatisPlusConfig;
import com.kaiwu.database.DmMigrationMain;
import com.kaiwu.module.configuration.mapper.I18nMapper;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import com.kaiwu.module.connector.mapper.ProjectStorageMapper;
import com.kaiwu.module.connector.mapper.StorageAccountMapper;
import com.kaiwu.module.identity.entity.UserEntity;
import com.kaiwu.module.identity.mapper.AuthMapper;
import com.kaiwu.module.identity.mapper.DepartmentMapper;
import com.kaiwu.module.identity.mapper.DeviceAuthorizationMapper;
import com.kaiwu.module.identity.mapper.UserMapper;
import com.kaiwu.module.operation.entity.LoginLogEntity;
import com.kaiwu.module.operation.entity.TodoEntity;
import com.kaiwu.module.operation.mapper.AuditWriteMapper;
import com.kaiwu.module.operation.mapper.LoginLogMapper;
import com.kaiwu.module.operation.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.operation.mapper.TodoMapper;
import com.kaiwu.module.project.lifecycle.SystemProjectBootstrap;
import com.kaiwu.module.project.mapper.SystemBootstrapMapper;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.time.Duration;
import java.time.LocalDateTime;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.testcontainers.DockerClientFactory;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;

/**
 * 真实 DM8 数据契约；只连接测试自行创建的一次性容器。
 *
 * <p>官方镜像需按达梦许可自行下载并 docker load；设置 KAIWU_TEST_DM_IMAGE 后启用本组，
 * 此时 Docker 或数据库不可用会失败。测试不读取开发库地址。</p>
 */
@EnabledIfEnvironmentVariable(named = "KAIWU_TEST_DM_IMAGE", matches = ".+")
class DmDataLayerContractTest {
    private static final String PASSWORD = "KaiwuContractOnly2026";
    private static final String SCHEMA = "KAIWU_CONTRACT";
    private static GenericContainer<?> database;
    private static String url;
    private static SqlSessionFactory sessions;
    private static Flyway flyway;

    /** 创建独立实例，设置兼容参数，迁移空库并装配真实 Mapper。 */
    @BeforeAll
    static void initialize() throws Exception {
        database = new GenericContainer<>(DockerImageName.parse(System.getenv("KAIWU_TEST_DM_IMAGE")))
                .withExposedPorts(5236)
                .withEnv("SYSDBA_PWD", PASSWORD)
                .withEnv("PAGE_SIZE", "16")
                .withEnv("CASE_SENSITIVE", "0")
                .withEnv("UNICODE_FLAG", "1")
                .withEnv("BUFFER", "128")
                .waitingFor(Wait.forLogMessage(".*SYSTEM IS READY.*\\n", 1))
                .withStartupTimeout(Duration.ofMinutes(3));
        database.start();
        url = "jdbc:dm://" + database.getHost() + ":" + database.getMappedPort(5236);
        try (Connection connection = DriverManager.getConnection(url, "SYSDBA", PASSWORD);
                var statement = connection.createStatement()) {
            assertThatThrownBy(() -> DmMigrationMain.validateInstance(connection))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("COMPATIBLE_MODE");
            statement.execute("SP_SET_PARA_VALUE(2, 'COMPATIBLE_MODE', 4)");
            statement.execute("CREATE USER " + SCHEMA + " IDENTIFIED BY \"" + PASSWORD + "\"");
            statement.execute("GRANT RESOURCE TO " + SCHEMA);
            statement.execute("GRANT SELECT ON SYS.V$PARAMETER TO " + SCHEMA);
        }
        DockerClientFactory.instance()
                .client()
                .restartContainerCmd(database.getContainerId())
                .exec();
        // Docker 随机发布的端口在重启时可能重新分配，必须读取新映射。
        String restartedPort = DockerClientFactory.instance()
                .client()
                .inspectContainerCmd(database.getContainerId())
                .exec()
                .getNetworkSettings()
                .getPorts()
                .getBindings()
                .get(new ExposedPort(5236))[0]
                .getHostPortSpec();
        url = "jdbc:dm://" + database.getHost() + ":" + restartedPort;
        awaitRestart();
        try (Connection connection = DriverManager.getConnection(url + "?schema=" + SCHEMA, SCHEMA, PASSWORD)) {
            // 以普通迁移用户验证权限；预检应当先于任何平台 DDL。
            DmMigrationMain.validateInstance(connection);
        }
        flyway = Flyway.configure()
                .dataSource(url + "?schema=" + SCHEMA, SCHEMA, PASSWORD)
                .locations("filesystem:" + Path.of("..", "sql", "dm").toAbsolutePath())
                .defaultSchema(SCHEMA)
                .schemas(SCHEMA)
                .createSchemas(false)
                .cleanDisabled(true)
                .baselineOnMigrate(false)
                .ignoreMigrationPatterns(new String[0])
                .load();
        flyway.migrate();
        var dataSource = new UnpooledDataSource("dm.jdbc.driver.DmDriver", url + "?schema=" + SCHEMA, SCHEMA, PASSWORD);
        var configuration = new MybatisConfiguration();
        configuration.setEnvironment(new Environment("dm-contract", new JdbcTransactionFactory(), dataSource));
        configuration.setMapUnderscoreToCamelCase(true);
        var plugins = new MybatisPlusConfig();
        configuration.setDatabaseId(plugins.databaseIdProvider().getDatabaseId(dataSource));
        configuration.addInterceptor(plugins.mybatisPlusInterceptor());
        configuration.addMappers("com.kaiwu.module");
        sessions = new MybatisSqlSessionFactoryBuilder().build(configuration);
        try (var session = sessions.openSession(true)) {
            session.getMapper(AuthMapper.class).insertBootstrapAdmin("contract-placeholder-hash");
            new SystemProjectBootstrap(session.getMapper(SystemBootstrapMapper.class)).run(null);
        }
    }

    /** 重启后等待新连接可用；有界等待避免永久挂起。 */
    private static void awaitRestart() throws Exception {
        Exception last = null;
        for (int attempt = 0; attempt < 120; attempt++) {
            try (Connection ignored = DriverManager.getConnection(url, SCHEMA, PASSWORD)) {
                return;
            } catch (Exception failure) {
                last = failure;
                Thread.sleep(1000);
            }
        }
        throw new IllegalStateException("一次性达梦实例重启失败", last);
    }

    /** 只删除本测试建立的容器，不访问其它部署与数据卷。 */
    @AfterAll
    static void stop() {
        if (database != null) {
            database.stop();
        }
    }

    /** 首次迁移必须建立完整平台，重复迁移不能重放种子。 */
    @Test
    void migrationAndBootstrapAreRepeatable() {
        assertThat(flyway.migrate().migrationsExecuted).isZero();
        flyway.validate();
        try (var session = sessions.openSession(true)) {
            var auth = session.getMapper(AuthMapper.class);
            var admin = auth.findUserByUsername("admin");
            var permissions = auth.findPermissions(String.valueOf(admin.getId()));
            assertThat(permissions).contains("system:user:list");
            new SystemProjectBootstrap(session.getMapper(SystemBootstrapMapper.class)).run(null);
            assertThat(auth.findPermissions(String.valueOf(admin.getId())))
                    .containsExactlyInAnyOrderElementsOf(permissions);
            assertThat(admin.getMustChangePassword()).isTrue();
        }
    }

    /** 验证达梦分页及实体字段映射，同时确保普通查询不带密码哈希。 */
    @Test
    void paginationPreservesUserMappingAndPasswordBoundary() {
        try (var session = sessions.openSession(true)) {
            UserEntity user = new UserEntity();
            user.setId(101L);
            user.setUsername("dm-contract-user");
            user.setDisplayName("数据库中文用户");
            user.setPasswordHash("private-hash");
            user.setStatus("ENABLED");
            user.setLocale("zh-CN");
            user.setCreatedAt(LocalDateTime.now());
            user.setUpdatedAt(LocalDateTime.now());
            var users = session.getMapper(UserMapper.class);
            users.insert(user);
            var page = users.selectPage(new Page<>(1, 1), null);
            assertThat(page.getRecords()).hasSize(1);
            assertThat(page.getTotal()).isGreaterThanOrEqualTo(2);
            assertThat(users.selectById(101L).getPasswordHash()).isNull();
            assertThat(users.selectById(101L).getDisplayName()).isEqualTo("数据库中文用户");
        }
    }

    /** 唯一键列可被更新，重复写入保持原行 ID。 */
    @Test
    void departmentMergeUpdatesUniqueCode() {
        try (var session = sessions.openSession(true)) {
            var departments = session.getMapper(DepartmentMapper.class);
            departments.upsert(201L, null, "测试部门", "dm-test", 1, "ENABLED");
            departments.upsert(201L, null, "测试部门修改", "dm-test-updated", 2, "ENABLED");
            assertThat(departments.selectById(201L).getDeptCode()).isEqualTo("dm-test-updated");
        }
    }

    /** JSON 更新只覆盖目标语言，保留已有的其它译文。 */
    @Test
    void translationUpdatePreservesOtherLocales() throws Exception {
        try (var session = sessions.openSession(true)) {
            var messages = session.getMapper(I18nMapper.class);
            try (var statement = session.getConnection().createStatement()) {
                statement.executeUpdate(
                        """
                        INSERT INTO sys_i18n_message
                            (id, scope_id, message_key, default_text, translations_json, module_code,
                             public_visible, required_resource, status, version, created_at, updated_at)
                        VALUES (301, 42, 'menu.system.users', '业务项目用户', '{"en-US":"Project users"}',
                                'test', 0, 1, 'ENABLED', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """);
            }
            assertThat(messages.upsertMenuTranslation("/users", "en-US", "DM Users"))
                    .isPositive();
            assertThat(messages.upsertMenuTranslation("/users", "ko-KR", "사용자")).isPositive();
            try (var statement = session.getConnection().createStatement();
                    var result = statement.executeQuery(
                            "SELECT JSON_UNQUOTE(JSON_EXTRACT(translations_json, '$.\"en-US\"')) FROM sys_i18n_message WHERE scope_id=0 AND message_key='menu.system.users'")) {
                assertThat(result.next()).isTrue();
                assertThat(result.getString(1)).isEqualTo("DM Users");
            }
            try (var statement = session.getConnection().createStatement();
                    var result = statement.executeQuery("SELECT version FROM sys_i18n_message WHERE id=301")) {
                assertThat(result.next()).isTrue();
                assertThat(result.getLong(1)).isEqualTo(1);
            }
        }
    }

    /** CLI 授权状态守卫在达梦上仍保证一次确认、一次兑换。 */
    @Test
    void deviceAuthorizationCanOnlyBeConsumedOnce() {
        try (var session = sessions.openSession(true)) {
            var devices = session.getMapper(DeviceAuthorizationMapper.class);
            var now = LocalDateTime.now();
            devices.insert("dm-device", "dm-device-hash", "DM-TEST", "contract", "127.0.0.1", now.plusMinutes(5), now);
            assertThat(devices.findPendingByUserCode("DM-TEST", now)).isNotNull();
            String adminId = String.valueOf(session.getMapper(AuthMapper.class)
                    .findUserByUsername("admin")
                    .getId());
            assertThat(devices.decide("dm-device", "APPROVED", adminId, now)).isEqualTo(1);
            assertThat(devices.decide("dm-device", "DENIED", adminId, now)).isZero();
            assertThat(devices.consume("dm-device", now)).isEqualTo(1);
            assertThat(devices.consume("dm-device", now)).isZero();
        }
    }

    /** 对象存储同名绑定只能有一个 ACTIVE，历史 READ_ONLY 绑定可共存。 */
    @Test
    void storageBindingEnforcesSingleActiveAccount() {
        try (var session = sessions.openSession(true)) {
            var accounts = session.getMapper(StorageAccountMapper.class);
            var bindings = session.getMapper(ProjectStorageMapper.class);
            accounts.insertAccount(
                    new StorageAccountRow(
                            "401",
                            "dm-storage",
                            "达梦存储测试",
                            "S3_COMPATIBLE_STS",
                            "https://storage.invalid",
                            "test",
                            "test-bucket",
                            true,
                            "https://sts.invalid",
                            null,
                            "contract-key",
                            "contract-ciphertext",
                            1800,
                            "ENABLED",
                            null,
                            null,
                            null,
                            0),
                    null);
            String projectId = "9000000000000000001";
            bindings.insertBinding("402", projectId, "files", "401", "ACTIVE", 1024, null);
            assertThatThrownBy(() -> bindings.insertBinding("403", projectId, "files", "401", "ACTIVE", 1024, null))
                    .hasMessageContaining("uk_sys_project_storage_active");
            bindings.updateStatus("402", "READ_ONLY");
            bindings.insertBinding("404", projectId, "files", "401", "READ_ONLY", 1024, null);
            bindings.insertBinding("405", projectId, "files", "401", "ACTIVE", 1024, null);
            assertThat(bindings.lockActive(projectId, "files").id()).isEqualTo("405");
            assertThat(accounts.findAccount("401").bindingCount()).isEqualTo(3);
        }
    }

    /** 心跳冲突更新后仍只有一个活跃处理器，并能按达梦时间表达式查询。 */
    @Test
    void schedulerHandlerMergeAndTimeWindow() {
        try (var session = sessions.openSession(true)) {
            var scheduler = session.getMapper(ProjectSchedulerMapper.class);
            scheduler.upsertHandler("9000000000000000001", "dm-task", "测试任务", "one");
            scheduler.upsertHandler("9000000000000000001", "dm-task", "测试任务修改", "two");
            assertThat(scheduler.countActiveHandler("9000000000000000001", "dm-task"))
                    .isEqualTo(1);
        }
    }

    /** 执行唯一键与租约谓词必须共同阻止重复抢占，过期后允许其它实例接管。 */
    @Test
    void schedulerExecutionCannotBeTakenOverBeforeLeaseExpiry() throws Exception {
        try (var session = sessions.openSession(true)) {
            var scheduler = session.getMapper(ProjectSchedulerMapper.class);
            String project = "9000000000000000001";
            var scheduledAt = LocalDateTime.of(2026, 1, 1, 0, 0);
            scheduler.insertJob("401", project, "达梦调度测试", "dm-task", "0 * * * * *", "Asia/Shanghai", "{}", true);
            assertThat(scheduler.insertExecution("402", "401", project, 1, scheduledAt, "first"))
                    .isEqualTo(1);
            assertThatThrownBy(() -> scheduler.insertExecution("403", "401", project, 1, scheduledAt, "second"))
                    .isInstanceOf(RuntimeException.class);
            assertThat(scheduler.takeOverExpiredExecution("401", scheduledAt, "second", 1))
                    .isZero();
            try (var statement = session.getConnection().createStatement()) {
                statement.executeUpdate(
                        "UPDATE sys_scheduler_execution SET lease_until=CURRENT_TIMESTAMP - INTERVAL '1' MINUTE WHERE id=402");
            }
            assertThat(scheduler.takeOverExpiredExecution("401", scheduledAt, "second", 1))
                    .isEqualTo(1);
            assertThat(scheduler.takeOverExpiredExecution("401", scheduledAt, "third", 1))
                    .isZero();
        }
    }

    /** 待办重复投递保留打开时间；重开时刷新，业务幂等键保持唯一。 */
    @Test
    void todoMergePreservesOpenTimeAndReopensClosedRow() {
        try (var session = sessions.openSession(true)) {
            var todos = session.getMapper(TodoMapper.class);
            TodoEntity todo = new TodoEntity();
            todo.setId(301L);
            todo.setProjectId(9000000000000000001L);
            todo.setProjectCode("system");
            todo.setBizKey("dm-contract");
            todo.setRecipientUserId(Long.valueOf(session.getMapper(AuthMapper.class)
                    .findUserByUsername("admin")
                    .getId()));
            todo.setTitle("待办测试");
            todo.setOpenedAt(LocalDateTime.of(2026, 1, 1, 0, 0));
            todo.setCreatedAt(todo.getOpenedAt());
            todo.setUpdatedAt(todo.getOpenedAt());
            todos.upsertOpen(todo);
            todo.setOpenedAt(LocalDateTime.of(2026, 1, 2, 0, 0));
            todos.upsertOpen(todo);
            assertThat(todos.selectById(301L).getOpenedAt()).isEqualTo(todo.getCreatedAt());
            todos.update(
                    null,
                    new com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper<TodoEntity>()
                            .eq(TodoEntity::getId, 301L)
                            .set(TodoEntity::getStatus, "DONE"));
            todos.upsertOpen(todo);
            assertThat(todos.selectById(301L).getOpenedAt()).isEqualTo(todo.getOpenedAt());
            assertThat(todos.countOpenByKey("system", "dm-contract", todo.getRecipientUserId()))
                    .isEqualTo(1);
        }
    }

    /** 达梦自增列必须回填审计实体主键。 */
    @Test
    void auditIdentityIsReturned() {
        try (var session = sessions.openSession(true)) {
            LoginLogEntity log = new LoginLogEntity();
            log.setUsername("dm-test");
            log.setLoginStatus("SUCCESS");
            log.setCreatedAt(LocalDateTime.now());
            session.getMapper(LoginLogMapper.class).insert(log);
            assertThat(log.getId()).isPositive();
        }
    }

    /** 后台清理必须遵守单批上限，避免一次取消或删除全部历史数据。 */
    @Test
    void cleanupJobsRespectBatchLimits() throws Exception {
        var before = LocalDateTime.of(2021, 1, 1, 0, 0);
        try (var session = sessions.openSession(true)) {
            var audit = session.getMapper(AuditWriteMapper.class);
            for (int i = 0; i < 3; i++) {
                LoginLogEntity log = new LoginLogEntity();
                log.setUsername("cleanup-test");
                log.setLoginStatus("SUCCESS");
                log.setCreatedAt(LocalDateTime.of(2020, 1, 1, 0, 0));
                session.getMapper(LoginLogMapper.class).insert(log);
            }
            assertThat(audit.deleteLoginLogsBefore(before, 1)).isEqualTo(1);
            assertThat(audit.deleteLoginLogsBefore(before, 1)).isEqualTo(1);
            try (var statement = session.getConnection().createStatement()) {
                statement.executeUpdate(
                        "INSERT INTO sys_oper_log(module,operation,request_method,request_path,response_status,created_at) VALUES ('test','cleanup','WRITE','/test',200,DATE '2020-01-01')");
                statement.executeUpdate(
                        "INSERT INTO sys_oper_log(module,operation,request_method,request_path,response_status,created_at) VALUES ('test','cleanup','WRITE','/test',200,DATE '2020-01-01')");
                statement.executeUpdate(
                        "INSERT INTO sys_todo(id,project_id,project_code,biz_key,recipient_user_id,title,status,opened_at,created_at,updated_at) VALUES (501,9000000000000000001,'system','cleanup-a',1,'test','OPEN',DATE '2020-01-01',DATE '2020-01-01',DATE '2020-01-01')");
                statement.executeUpdate(
                        "INSERT INTO sys_todo(id,project_id,project_code,biz_key,recipient_user_id,title,status,opened_at,created_at,updated_at) VALUES (502,9000000000000000001,'system','cleanup-b',1,'test','OPEN',DATE '2020-01-01',DATE '2020-01-01',DATE '2020-01-01')");
            }
            assertThat(audit.deleteOperationLogsBefore(before, 1)).isEqualTo(1);
            var todos = session.getMapper(TodoMapper.class);
            assertThat(todos.cancelStaleBefore(before, LocalDateTime.of(2020, 2, 1, 0, 0), 1))
                    .isEqualTo(1);
            assertThat(todos.deleteClosedBefore(before, 1)).isEqualTo(1);
            assertThat(todos.selectById(501L) == null || todos.selectById(502L) == null)
                    .isTrue();
        }
    }
}
