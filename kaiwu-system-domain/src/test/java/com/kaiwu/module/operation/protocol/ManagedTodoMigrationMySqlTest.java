package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 在一次性 MySQL 中验证 V127 基线上的既有待办与共享额度。 */
class ManagedTodoMigrationMySqlTest {
    /** 按业务写入顺序建立存量待办，验证共享额度、关闭和清理。 */
    @Test
    void preservesExistingLegacyRowsAndGuards() throws Exception {
        try (var db = new MySQLContainer<>(DockerImageName.parse("mysql:8.4").asCompatibleSubstituteFor("mysql"))) {
            db.start();
            String migrations =
                    "filesystem:" + Path.of("../sql/increment").toAbsolutePath().normalize();
            var flyway = Flyway.configure()
                    .dataSource(db.getJdbcUrl(), db.getUsername(), db.getPassword())
                    .locations(migrations)
                    .load();
            assertThat(flyway.migrate().migrationsExecuted).isPositive();
            assertThat(flyway.migrate().migrationsExecuted).isZero();
            var configuration = new MybatisConfiguration();
            configuration.setEnvironment(new Environment(
                    "test",
                    new org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory(),
                    new UnpooledDataSource(
                            "com.mysql.cj.jdbc.Driver", db.getJdbcUrl(), db.getUsername(), db.getPassword())));
            configuration.addMapper(ManagedTodoLockMapper.class);
            var factory = new MybatisSqlSessionFactoryBuilder().build(configuration);
            try (var seed = factory.openSession(false);
                    var insert = seed.getConnection()
                            .prepareStatement(
                                    """
                    INSERT INTO sys_todo(id,project_id,project_code,biz_key,recipient_user_id,title,status,opened_at,created_at,updated_at)
                    VALUES (?,1,'sample',?,?,?, ?,NOW(),NOW(),NOW())
                    """)) {
                var guard = new com.kaiwu.module.operation.service.LegacyTodoOpenGuard(
                        seed.getMapper(ManagedTodoLockMapper.class));
                /** 验证开放和已关闭待办对业务键与共享配额的不同影响。 */
                record Todo(int id, String key, int recipient, String status) {}
                for (var row : java.util.List.of(
                        new Todo(1, "a", 501, "OPEN"),
                        new Todo(2, "b", 501, "OPEN"),
                        new Todo(3, "c", 501, "DONE"),
                        new Todo(4, "a", 502, "OPEN"))) {
                    var reservation = guard.prepare("sample", row.key(), row.recipient(), 10);
                    insert.setInt(1, row.id());
                    insert.setString(2, row.key());
                    insert.setInt(3, row.recipient());
                    insert.setString(4, row.key());
                    insert.setString(5, row.status());
                    insert.executeUpdate();
                    if ("OPEN".equals(row.status())) guard.complete(reservation);
                }
                seed.commit();
                try (var sql = seed.getConnection().createStatement();
                        var rs = sql.executeQuery(
                                "SELECT (SELECT COUNT(*) FROM sys_todo_biz_lock), (SELECT COUNT(*) FROM sys_todo_key_guard WHERE kind='LEGACY'), (SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='sample' AND recipient_user_id=501), (SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='sample' AND recipient_user_id=502)")) {
                    assertThat(rs.next()).isTrue();
                    assertThat(rs.getInt(1)).isEqualTo(3);
                    assertThat(rs.getInt(2)).isEqualTo(4);
                    assertThat(rs.getInt(3)).isEqualTo(2);
                    assertThat(rs.getInt(4)).isEqualTo(1);
                }
            }
            try (var first = factory.openSession(false)) {
                var mapper = first.getMapper(ManagedTodoLockMapper.class);
                mapper.ensureBusinessKey("sample", "race");
                assertThat(mapper.lockBusinessKey("sample", "race")).isEqualTo("race");
                mapper.ensureQuota("sample", 501);
                assertThat(mapper.lockQuota("sample", 501)).isEqualTo(2);
                assertThat(mapper.countLegacyOpenForUpdate("sample", 501)).isEqualTo(2);
                assertThat(mapper.countManagedOpenForUpdate("sample", 501)).isZero();
                assertThat(mapper.replaceQuota("sample", 501, 1, 2)).isZero();
                assertThat(mapper.replaceQuota("sample", 501, 2, -1)).isZero();
                assertThat(mapper.replaceQuota("sample", 501, 2, 3)).isEqualTo(1);
                assertThat(mapper.replaceQuota("sample", 501, 3, 2)).isEqualTo(1);
                assertThat(mapper.lockGuard("sample", "a", 501)).isEqualTo("LEGACY");
                var pool = Executors.newSingleThreadExecutor();
                try {
                    var started = new CountDownLatch(1);
                    var pending = pool.submit(() -> {
                        try (var second = factory.openSession(false)) {
                            var other = second.getMapper(ManagedTodoLockMapper.class);
                            started.countDown();
                            other.ensureBusinessKey("sample", "race");
                            String locked = other.lockBusinessKey("sample", "race");
                            second.commit();
                            return locked;
                        }
                    });
                    assertThat(started.await(5, TimeUnit.SECONDS)).isTrue();
                    assertThatThrownBy(() -> pending.get(250, TimeUnit.MILLISECONDS))
                            .isInstanceOf(TimeoutException.class);
                    first.commit();
                    assertThat(pending.get(10, TimeUnit.SECONDS)).isEqualTo("race");
                } finally {
                    pool.shutdownNow();
                }
            }
            try (var session = factory.openSession(false)) {
                var mapper = session.getMapper(ManagedTodoLockMapper.class);
                var guard = new com.kaiwu.module.operation.service.LegacyTodoOpenGuard(mapper);
                var existing = guard.prepare("sample", "a", 501, 2);
                assertThat(existing.increase()).isFalse();
                guard.complete(existing);
                assertThatThrownBy(() -> guard.prepare("sample", "fresh", 501, 2))
                        .isInstanceOf(com.kaiwu.common.ApiException.class);
                session.rollback();
            }
            try (var session = factory.openSession(false)) {
                var mapper = session.getMapper(ManagedTodoLockMapper.class);
                mapper.ensureBusinessKey("sample", "managed");
                mapper.insertGuard("sample", "managed", 501, "MANAGED");
                session.commit();
                var guard = new com.kaiwu.module.operation.service.LegacyTodoOpenGuard(mapper);
                assertThatThrownBy(() -> guard.prepare("sample", "managed", 501, 10))
                        .isInstanceOf(com.kaiwu.common.ApiException.class);
                session.rollback();
            }
            var dataSource = factory.getConfiguration().getEnvironment().getDataSource();
            var springConfiguration = new MybatisConfiguration();
            springConfiguration.setEnvironment(new Environment(
                    "spring", new org.mybatis.spring.transaction.SpringManagedTransactionFactory(), dataSource));
            springConfiguration.addMapper(ManagedTodoLockMapper.class);
            var springFactory = new MybatisSqlSessionFactoryBuilder().build(springConfiguration);
            var template = new org.springframework.transaction.support.TransactionTemplate(
                    new org.springframework.jdbc.datasource.DataSourceTransactionManager(dataSource));
            template.setIsolationLevel(java.sql.Connection.TRANSACTION_READ_COMMITTED);
            var sqlSession = new org.mybatis.spring.SqlSessionTemplate(springFactory);
            var closeGuard = new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(
                    sqlSession.getMapper(ManagedTodoLockMapper.class));
            var jdbc = new org.springframework.jdbc.core.JdbcTemplate(dataSource);
            assertThatThrownBy(() -> closeGuard.prepare("sample", "a", null))
                    .isInstanceOf(com.kaiwu.common.ApiException.class);
            template.executeWithoutResult(status -> {
                var reservation = closeGuard.prepare("sample", "a", null);
                assertThat(reservation.quotas()).hasSize(2);
                int closed = jdbc.update(
                        "UPDATE sys_todo SET status='DONE' WHERE project_code='sample' AND biz_key='a' AND status='OPEN'");
                closeGuard.complete(reservation, closed);
                status.setRollbackOnly();
            });
            assertThat(jdbc.queryForObject(
                            "SELECT COUNT(*) FROM sys_todo WHERE biz_key='a' AND status='OPEN'", Integer.class))
                    .isEqualTo(2);
            template.executeWithoutResult(status -> {
                var reservation = closeGuard.prepare("sample", "a", null);
                int closed = jdbc.update(
                        "UPDATE sys_todo SET status='DONE' WHERE project_code='sample' AND biz_key='a' AND status='OPEN'");
                closeGuard.complete(reservation, closed);
            });
            assertThat(jdbc.queryForObject(
                            "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='sample' AND recipient_user_id=501",
                            Long.class))
                    .isEqualTo(1);
            assertThat(jdbc.queryForObject(
                            "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='sample' AND recipient_user_id=502",
                            Long.class))
                    .isZero();
            var cleanup = new com.kaiwu.module.operation.service.LegacyTodoCleanupGuard(
                    sqlSession.getMapper(ManagedTodoLockMapper.class), closeGuard);
            var now = java.time.LocalDateTime.of(2026, 11, 1, 0, 0);
            assertThat(template.<Integer>execute(
                            status -> cleanup.cancelStale("sample", "b", 501, now.minusYears(10), now)))
                    .isZero();
            jdbc.update(
                    "UPDATE sys_todo SET updated_at='2020-01-01 00:00:00' WHERE project_code='sample' AND biz_key='b'");
            template.executeWithoutResult(status -> {
                assertThat(cleanup.cancelStale("sample", "b", 501, now.minusDays(90), now))
                        .isEqualTo(1);
                status.setRollbackOnly();
            });
            assertThat(jdbc.queryForObject(
                            "SELECT status FROM sys_todo WHERE project_code='sample' AND biz_key='b'", String.class))
                    .isEqualTo("OPEN");
            assertThat(template.<Integer>execute(
                            status -> cleanup.cancelStale("sample", "b", 501, now.minusDays(90), now)))
                    .isEqualTo(1);
            assertThat(jdbc.queryForObject(
                            "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='sample' AND recipient_user_id=501",
                            Long.class))
                    .isZero();
            assertThat(template.<Integer>execute(status -> cleanup.deleteClosed("sample", "b", 501, now.plusDays(1))))
                    .isEqualTo(1);
            assertThat(jdbc.queryForObject(
                            "SELECT COUNT(*) FROM sys_todo_key_guard WHERE project_code='sample' AND biz_key='b' AND recipient_user_id=501",
                            Integer.class))
                    .isZero();
        }
    }
}
