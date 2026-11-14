package com.kaiwu.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.baomidou.mybatisplus.extension.plugins.MybatisPlusInterceptor;
import com.baomidou.mybatisplus.extension.plugins.inner.PaginationInnerInterceptor;
import com.kaiwu.module.operation.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Set;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 在一次性 MySQL 的 V127 基线上验证旧凭据轮换与服务范围认证。 */
class ServiceCredentialUpgradeMySqlTest {
    /** 老版本写入只使用原列；新旧default可以交替轮换，新scope互不借权且撤销/到期生效。 */
    @Test
    void upgradesLegacyRowsAndKeepsLegacyRotationSeparateFromScopedCredentials() throws Exception {
        try (var mysql = new MySQLContainer<>(
                DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                        .asCompatibleSubstituteFor("mysql"))) {
            mysql.start();
            Path migrations = Path.of("../sql/increment").toAbsolutePath();
            var latest = Flyway.configure()
                    .dataSource(mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())
                    .locations("filesystem:" + migrations)
                    .load();
            assertThat(latest.migrate().migrationsExecuted).isPositive();
            var encoder = new BCryptPasswordEncoder(4);
            String oldToken = "zsch_10_old-test-secret", newToken = "zsch_11_new-test-secret";
            try (var connection = mysql.createConnection("");
                    var statement = connection.createStatement()) {
                statement.executeUpdate(
                        "INSERT INTO sys_user(id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES(1,'c5-legacy','test-only','Legacy','ENABLED',0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                statement.executeUpdate(
                        "INSERT INTO sys_project(id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES(2,'c5legacy','Legacy','ACTIVE',0,1,'com.example.legacy','main',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                try (var insert = connection.prepareStatement(
                        "INSERT INTO sys_scheduler_credential(id,project_id,token_hash,status,created_at,updated_at) VALUES(10,2,?,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)")) {
                    insert.setString(1, encoder.encode(oldToken));
                    insert.executeUpdate();
                }
            }
            assertThat(latest.migrate().migrationsExecuted).isZero();
            try (var connection = mysql.createConnection("");
                    var statement = connection.createStatement();
                    var rows = statement.executeQuery(
                            "SELECT service_code,expires_at,last_used_at FROM sys_scheduler_credential WHERE id=10")) {
                assertThat(rows.next()).isTrue();
                assertThat(rows.getString(1)).isEqualTo("default");
                assertThat(rows.getObject(2)).isNull();
                assertThat(rows.getObject(3)).isNull();
            }
            var configuration = new MybatisConfiguration();
            configuration.setMapUnderscoreToCamelCase(true);
            configuration.setEnvironment(new Environment(
                    "c5-upgrade",
                    new JdbcTransactionFactory(),
                    new UnpooledDataSource(
                            "com.mysql.cj.jdbc.Driver", mysql.getJdbcUrl(), mysql.getUsername(), mysql.getPassword())));
            var pagination = new MybatisPlusInterceptor();
            pagination.addInnerInterceptor(new PaginationInnerInterceptor());
            configuration.addInterceptor(pagination);
            configuration.addMapper(ProjectSchedulerMapper.class);
            var factory = new MybatisSqlSessionFactoryBuilder().build(configuration);
            try (var session = factory.openSession(true)) {
                var mapper = session.getMapper(ProjectSchedulerMapper.class);
                var repository = new ProjectSchedulerRepository(mapper);
                var auth = new ProjectServiceCredentials(repository, encoder);
                assertThat(auth.authenticateBearer("Bearer " + oldToken).projectId())
                        .isEqualTo("2");
                assertThatThrownBy(() -> auth.authenticateScoped(oldToken, "2", "member:read"))
                        .isInstanceOf(ApiException.class);
                // 旧二进制在开关关闭期间仍执行原UPDATE/INSERT，仅有default行，不依赖新增列。
                try (var connection = mysql.createConnection("");
                        var revoke = connection.prepareStatement(
                                "UPDATE sys_scheduler_credential SET status='REVOKED',updated_at=CURRENT_TIMESTAMP WHERE project_id=? AND status='ACTIVE'")) {
                    revoke.setString(1, "2");
                    assertThat(revoke.executeUpdate()).isEqualTo(1);
                    try (var insert = connection.prepareStatement(
                            "INSERT INTO sys_scheduler_credential(id,project_id,token_hash,status,created_at,updated_at) VALUES(11,2,?,'ACTIVE',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)")) {
                        insert.setString(1, encoder.encode(newToken));
                        insert.executeUpdate();
                    }
                }
                session.clearCache();
                assertThatThrownBy(() -> auth.authenticate(oldToken)).isInstanceOf(ApiException.class);
                assertThat(auth.authenticate(newToken).serviceCode()).isEqualTo("default");
                // 新版本原default轮换同样即时撤销旧default，不触及后续非default凭据。
                repository.replaceCredential("12", "2", encoder.encode("zsch_12_next-test-secret"));
                assertThatThrownBy(() -> auth.authenticate(newToken)).isInstanceOf(ApiException.class);
                assertThat(auth.authenticate("zsch_12_next-test-secret").projectId())
                        .isEqualTo("2");
                repository.insertScopedCredential(
                        "20",
                        "2",
                        encoder.encode("zsch_20_scope-test-secret"),
                        "workflow",
                        LocalDateTime.now(ZoneOffset.UTC).plusHours(1),
                        Set.of("member:read"));
                repository.insertScopedCredential(
                        "21",
                        "2",
                        encoder.encode("zsch_21_other-test-secret"),
                        "purchase",
                        LocalDateTime.now(ZoneOffset.UTC).plusHours(1),
                        Set.of("todo:managed"));
                assertThat(auth.authenticateScopedBearer("Bearer zsch_20_scope-test-secret", "2", "member:read")
                                .serviceCode())
                        .isEqualTo("workflow");
                assertThatThrownBy(() -> auth.authenticate("zsch_20_scope-test-secret"))
                        .isInstanceOf(ApiException.class);
                assertThatThrownBy(() -> auth.authenticateScoped("zsch_20_scope-test-secret", "3", "member:read"))
                        .isInstanceOf(ApiException.class);
                assertThatThrownBy(() -> auth.authenticateScoped("zsch_20_scope-test-secret", "2", "todo:managed"))
                        .isInstanceOf(ApiException.class);
                repository.replaceCredential("13", "2", encoder.encode("zsch_13_last-test-secret"));
                assertThat(auth.authenticateScoped("zsch_20_scope-test-secret", "2", "member:read")
                                .id())
                        .isEqualTo("20");
                assertThat(repository.listScopedCredentials("2", 1, 100).records())
                        .hasSize(2);
                assertThat(repository
                                .listScopedCredentials("2", 1, 100)
                                .records()
                                .toString())
                        .doesNotContain("test-secret", encoder.encode(oldToken));
                assertThat(repository.revokeScopedCredential("3", "21")).isFalse();
                assertThat(repository.revokeScopedCredential("2", "21")).isTrue();
                assertThatThrownBy(() -> auth.authenticateScoped("zsch_21_other-test-secret", "2", "todo:managed"))
                        .isInstanceOf(ApiException.class);
                repository.shortenCredential("20", LocalDateTime.of(2000, 1, 1, 0, 0));
                assertThatThrownBy(() -> auth.authenticateScoped("zsch_20_scope-test-secret", "2", "member:read"))
                        .isInstanceOf(ApiException.class);
                assertThat(repository.revokeScopedCredential("2", "13")).isFalse();
                try (var connection = mysql.createConnection("");
                        var statement = connection.createStatement();
                        var rows = statement.executeQuery(
                                "SELECT token_hash,status FROM sys_scheduler_credential WHERE id=20")) {
                    assertThat(rows.next()).isTrue();
                    assertThat(rows.getString(2)).isEqualTo("ACTIVE"); // 到期不是删除或状态覆盖。
                    assertThat(encoder.matches("zsch_20_scope-test-secret", rows.getString(1)))
                            .isTrue();
                }
            }
        }
    }
}
