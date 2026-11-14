package com.kaiwu.module.connector.mapper;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.module.connector.entity.ProjectStorageRow;
import com.kaiwu.module.connector.entity.StorageAccountRow;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.time.LocalDateTime;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.exceptions.PersistenceException;
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
 * 对象存储 Mapper 的真实 MySQL 契约（ADR 0018、ADR 0039）：record 按列顺序映射、
 * 生成列唯一键保证每个存储名至多一条生效绑定。
 */
class StorageMapperMySqlTest {

    private static final String USER_ID = "910000000000000001";
    private static final String PROJECT_ID = "910000000000000002";
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                            .asCompatibleSubstituteFor("mysql"))
            .withDatabaseName("kaiwu_storage")
            .withUsername("kaiwu_storage")
            .withPassword("kaiwu_storage");

    private static SqlSessionFactory sessionFactory;

    /**
     * 启动 MySQL、执行全部迁移并准备一个项目。
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
        configuration.setEnvironment(new Environment("storage", new JdbcTransactionFactory(), dataSource));
        configuration.addMapper(StorageAccountMapper.class);
        configuration.addMapper(ProjectStorageMapper.class);
        sessionFactory = new MybatisSqlSessionFactoryBuilder().build(configuration);
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement user = connection.prepareStatement(
                        """
                        INSERT INTO sys_user (id, username, password_hash, display_name, status, must_change_password,
                                              created_at, updated_at)
                        VALUES (?, 'storage-user', 'not-a-real-password', 'Storage', 'ENABLED', 0,
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """);
                PreparedStatement project = connection.prepareStatement(
                        """
                        INSERT INTO sys_project (id, project_code, project_name, status, built_in, created_by,
                                                 package_name, default_branch, created_at, updated_at)
                        VALUES (?, 'demo', 'Demo', 'ACTIVE', 0, ?, 'com.example.demo', 'main',
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """)) {
            user.setLong(1, Long.parseLong(USER_ID));
            user.executeUpdate();
            project.setLong(1, Long.parseLong(PROJECT_ID));
            project.setLong(2, Long.parseLong(USER_ID));
            project.executeUpdate();
        }
    }

    /** 停止容器。 */
    @AfterAll
    static void stop() {
        MYSQL.stop();
    }

    /** 账号写入后按列顺序映射回 record，测试结果与绑定数可读。 */
    @Test
    void accountRoundTripsThroughRecordMapping() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            StorageAccountMapper mapper = session.getMapper(StorageAccountMapper.class);
            mapper.insertAccount(account("920000000000000101", "minio-a"), USER_ID);
            mapper.recordTest("920000000000000101", "SUCCESS", "ok", LocalDateTime.of(2026, 10, 29, 10, 0));

            StorageAccountRow row = mapper.findAccount("920000000000000101");

            assertThat(row.accountCode()).isEqualTo("minio-a");
            assertThat(row.pathStyle()).isTrue();
            assertThat(row.credentialTtlSeconds()).isEqualTo(1800);
            assertThat(row.enabled()).isTrue();
            assertThat(row.lastTestStatus()).isEqualTo("SUCCESS");
            assertThat(row.bindingCount()).isZero();
            assertThat(mapper.findAccountByCode("minio-a").id()).isEqualTo("920000000000000101");
            assertThat(mapper.listAccounts()).extracting(StorageAccountRow::id).contains("920000000000000101");
        }
    }

    /** 同一存储名第二条 ACTIVE 被唯一键拒绝；旧绑定转只读后可以新建生效绑定。 */
    @Test
    void onlyOneActiveBindingPerStorageName() {
        try (SqlSession session = sessionFactory.openSession(true)) {
            StorageAccountMapper accounts = session.getMapper(StorageAccountMapper.class);
            ProjectStorageMapper bindings = session.getMapper(ProjectStorageMapper.class);
            accounts.insertAccount(account("920000000000000201", "minio-b"), USER_ID);
            accounts.insertAccount(account("920000000000000202", "minio-c"), USER_ID);
            bindings.insertBinding(
                    "920000000000000211", PROJECT_ID, "default", "920000000000000201", "ACTIVE", 1024, "image/png");

            assertThatThrownBy(() -> bindings.insertBinding(
                            "920000000000000212", PROJECT_ID, "default", "920000000000000202", "ACTIVE", 1024, null))
                    .isInstanceOf(PersistenceException.class)
                    .hasMessageContaining("uk_sys_project_storage_active");

            bindings.updateStatus("920000000000000211", "READ_ONLY");
            bindings.insertBinding(
                    "920000000000000212", PROJECT_ID, "default", "920000000000000202", "ACTIVE", 2048, null);

            ProjectStorageRow active = bindings.lockActive(PROJECT_ID, "default");
            assertThat(active.id()).isEqualTo("920000000000000212");
            assertThat(active.projectCode()).isEqualTo("demo");
            assertThat(active.maxObjectBytes()).isEqualTo(2048);
            assertThat(bindings.listIssuable(PROJECT_ID))
                    .extracting(ProjectStorageRow::status)
                    .containsExactlyInAnyOrder("ACTIVE", "READ_ONLY");
            assertThat(bindings.listBindings(null)).hasSizeGreaterThanOrEqualTo(2);
            assertThat(bindings.listBindings(PROJECT_ID)).allMatch(row -> PROJECT_ID.equals(row.projectId()));
            assertThat(bindings.findProjectCode(PROJECT_ID)).isEqualTo("demo");
            assertThat(accounts.findAccount("920000000000000201").bindingCount())
                    .isEqualTo(1);
        }
    }

    /**
     * 构造一个 MinIO 账号。
     *
     * @param id 账号 ID
     * @param code 账号编码
     * @return 账号行
     */
    private static StorageAccountRow account(String id, String code) {
        return new StorageAccountRow(
                id,
                code,
                "MinIO",
                "S3_COMPATIBLE_STS",
                "http://minio:9000",
                "us-east-1",
                "files",
                true,
                "http://minio:9000",
                null,
                "minio-user",
                "cipher",
                1800,
                "ENABLED",
                null,
                null,
                null,
                0);
    }

    /**
     * 向上查找迁移目录。
     *
     * @return sql/increment 目录
     */
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
