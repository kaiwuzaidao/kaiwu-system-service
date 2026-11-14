package com.kaiwu.module.operation.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.dto.TodoCloseRequest;
import com.kaiwu.module.operation.dto.TodoOpenRequest;
import com.kaiwu.module.operation.lifecycle.TodoCleaner;
import com.kaiwu.module.operation.mapper.TodoMapper;
import com.kaiwu.module.operation.service.impl.TodoServiceImpl;
import com.kaiwu.module.operation.vo.TodoSummaryView;
import com.kaiwu.module.operation.vo.TodoView;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 统一待办在真实 MySQL 上的行为（ADR 0034）。
 *
 * <p>重点验证几处只有真实数据库才会暴露的语义：{@code ON DUPLICATE KEY UPDATE} 里 {@code opened_at}
 * 必须先于 {@code status} 求值、唯一键如何隔离项目与处理人、按人与按业务键关闭的范围，
 * 以及清理的两条规则。一次性数据库，不依赖外部环境。
 */
class TodoMySqlTest {

    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
            DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                    .asCompatibleSubstituteFor("mysql"));
    private static final String ALICE = "501";
    private static final String BOB = "502";
    private static final String OUTSIDER = "503";

    private static SqlSessionFactory sessions;
    private SqlSession session;

    private final MutableClock clock = new MutableClock(LocalDateTime.parse("2026-10-23T10:00:00"));
    private TodoProperties properties;
    private TodoRepository repository;
    private TodoServiceImpl service;

    /** 可手动拨动的时钟，用来构造「N 天前」的数据而不必真的等待。 */
    private static final class MutableClock extends Clock {

        private Instant instant;

        /**
         * 创建时钟。
         *
         * @param start 起始时间，按 UTC 解释
         */
        MutableClock(LocalDateTime start) {
            this.instant = start.toInstant(ZoneOffset.UTC);
        }

        /**
         * 把时钟拨快指定时长。
         *
         * @param duration 拨快的时长
         */
        void advance(Duration duration) {
            instant = instant.plus(duration);
        }

        /**
         * 取当前时间的本地时间表示。
         *
         * @return 按 UTC 换算的本地时间
         */
        LocalDateTime instantNow() {
            return LocalDateTime.ofInstant(instant, ZoneOffset.UTC);
        }

        /** 固定为 UTC，测试里的本地时间一律按 UTC 解释。 */
        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        /** 时区固定，忽略切换请求。 */
        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        /** 返回当前被拨动到的时刻。 */
        @Override
        public Instant instant() {
            return instant;
        }
    }

    /**
     * 启动一次性 MySQL，迁移到最新版本并播种两个项目、三个用户。
     *
     * @throws Exception 容器或迁移失败
     */
    @BeforeAll
    static void start() throws Exception {
        MYSQL.start();
        Path directory = Path.of("../sql/increment").toAbsolutePath().normalize();
        Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + directory)
                .load()
                .migrate();
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            for (String user : new String[] {ALICE, BOB, OUTSIDER}) {
                statement.executeUpdate(
                        "INSERT INTO sys_user (id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES ("
                                + user + ",'todo-" + user + "','unused','Todo " + user + "','ENABLED',0,NOW(),NOW())");
            }
            statement.executeUpdate(
                    "INSERT INTO sys_project (id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES (601,'flow','Flow','ACTIVE',0,501,'com.example.flow','main',NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project (id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES (602,'other','Other','ACTIVE',0,501,'com.example.other','main',NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project (id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES (603,'paused','Paused','DISABLED',0,501,'com.example.paused','main',NOW(),NOW())");
            for (String member : new String[] {
                "601," + ALICE, "601," + BOB, "602," + ALICE, "603," + ALICE,
            }) {
                statement.executeUpdate(
                        "INSERT INTO sys_project_member (project_id,user_id,status,created_at,updated_at) VALUES ("
                                + member + ",'ACTIVE',NOW(),NOW())");
            }
        }
        MybatisConfiguration configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setEnvironment(new Environment(
                "todo-contract",
                new JdbcTransactionFactory(),
                new UnpooledDataSource(
                        "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())));
        configuration.addMapper(TodoMapper.class);
        configuration.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        sessions = new MybatisSqlSessionFactoryBuilder().build(configuration);
    }

    /** 停止数据库。 */
    @AfterAll
    static void stop() {
        MYSQL.stop();
    }

    /** 关闭本用例的会话。 */
    @AfterEach
    void closeSession() {
        session.close();
    }

    /**
     * 每个用例前清空待办表并重建服务，保证用例互不影响。
     *
     * @throws Exception 清表失败
     */
    @BeforeEach
    void reset() throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("DELETE FROM sys_todo");
            statement.executeUpdate("DELETE FROM sys_managed_todo");
            statement.executeUpdate("DELETE FROM sys_todo_key_guard");
            statement.executeUpdate("DELETE FROM sys_todo_biz_lock");
            statement.executeUpdate("DELETE FROM sys_todo_recipient_quota");
        }
        clock.instant = LocalDateTime.parse("2026-10-23T10:00:00").toInstant(ZoneOffset.UTC);
        // 每个用例新开会话：MyBatis 一级缓存只在会话内失效，清表走的是另一条连接，复用会话会读到上个用例的结果。
        session = sessions.openSession(true);
        properties = new TodoProperties();
        repository = new TodoRepository(session.getMapper(TodoMapper.class));
        service = new TodoServiceImpl(repository, properties, clock, null, null);
    }

    /** 构造一个最简的打开请求：缺省链接与截止时间。 */
    private TodoOpenRequest open(String project, String bizKey, String recipient) {
        return new TodoOpenRequest(project, bizKey, recipient, "待审批 " + bizKey, "正文", null, null);
    }

    /** 构造关闭请求。 */
    private TodoCloseRequest close(String project, String bizKey, String recipient, String result) {
        return new TodoCloseRequest(project, bizKey, recipient, result);
    }

    /** 用独立连接执行单值查询，绕开被测会话的缓存直接看数据库里的真实状态。 */
    private String scalar(String sql) throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery(sql)) {
            assertThat(result.next()).isTrue();
            return result.getString(1);
        }
    }

    /** 打开待办：缺省链接补成项目后台入口，且分页能读到。 */
    @Test
    void openCreatesTodoWithDefaultWorkspaceLink() {
        service.open(open("flow", "approval:1", ALICE));

        PageResult<TodoView> page = service.myTodos(ALICE, 1, 10, null, null);

        assertThat(page.total()).isEqualTo(1);
        TodoView todo = page.records().get(0);
        assertThat(todo.title()).isEqualTo("待审批 approval:1");
        assertThat(todo.status()).isEqualTo("OPEN");
        assertThat(todo.projectCode()).isEqualTo("flow");
        assertThat(todo.linkUrl()).isEqualTo("/workspace/601");
        assertThat(todo.overdue()).isFalse();
    }

    /** 同一业务键重复打开只更新内容，不新增行，且仍未处理的待办不改变排序依据 opened_at。 */
    @Test
    void reopeningAnOpenTodoUpdatesContentButKeepsOpenedAt() throws Exception {
        service.open(open("flow", "approval:1", ALICE));
        String firstOpened = scalar("SELECT opened_at FROM sys_todo");

        clock.advance(Duration.ofHours(3));
        service.open(new TodoOpenRequest("flow", "approval:1", ALICE, "改了标题", null, "/workspace/601", null));

        assertThat(scalar("SELECT COUNT(*) FROM sys_todo")).isEqualTo("1");
        assertThat(scalar("SELECT title FROM sys_todo")).isEqualTo("改了标题");
        assertThat(scalar("SELECT opened_at FROM sys_todo")).isEqualTo(firstOpened);
        assertThat(scalar("SELECT updated_at FROM sys_todo")).isNotEqualTo(firstOpened);
    }

    /** 已关闭的待办被重新打开：状态回到 OPEN、清空关闭时间，并刷新 opened_at。 */
    @Test
    void reopeningAClosedTodoResetsItAndRefreshesOpenedAt() throws Exception {
        service.open(open("flow", "approval:1", ALICE));
        service.close(close("flow", "approval:1", null, "DONE"));
        assertThat(scalar("SELECT status FROM sys_todo")).isEqualTo("DONE");
        String firstOpened = scalar("SELECT opened_at FROM sys_todo");

        clock.advance(Duration.ofDays(1));
        service.open(open("flow", "approval:1", ALICE));

        assertThat(scalar("SELECT status FROM sys_todo")).isEqualTo("OPEN");
        assertThat(scalar("SELECT closed_at IS NULL FROM sys_todo")).isEqualTo("1");
        assertThat(scalar("SELECT opened_at FROM sys_todo")).isNotEqualTo(firstOpened);
    }

    /** 不带处理人关闭：该业务键下所有处理人的待办一并关闭（或签），别的业务键与别的项目不受影响。 */
    @Test
    void closeWithoutRecipientClosesEveryRecipientOfThatKeyOnly() {
        service.open(open("flow", "approval:1", ALICE));
        service.open(open("flow", "approval:1", BOB));
        service.open(open("flow", "approval:2", ALICE));
        service.open(open("other", "approval:1", ALICE));

        long closed = service.close(close("flow", "approval:1", null, null));

        assertThat(closed).isEqualTo(2);
        assertThat(service.myTodos(ALICE, 1, 10, null, null).records())
                .extracting(TodoView::projectCode, view -> view.title())
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple("flow", "待审批 approval:2"),
                        org.assertj.core.groups.Tuple.tuple("other", "待审批 approval:1"));
        assertThat(service.myTodos(BOB, 1, 10, null, null).total()).isZero();
        assertThat(service.myTodos(ALICE, 1, 10, "DONE", null).total()).isEqualTo(1);
    }

    /** 带处理人关闭（会签）：只关闭该人的待办，其他处理人的仍然是 OPEN。 */
    @Test
    void closeWithRecipientClosesOnlyThatPerson() {
        service.open(open("flow", "approval:1", ALICE));
        service.open(open("flow", "approval:1", BOB));

        assertThat(service.close(close("flow", "approval:1", ALICE, "CANCELLED")))
                .isEqualTo(1);

        assertThat(service.myTodos(ALICE, 1, 10, null, null).total()).isZero();
        assertThat(service.myTodos(ALICE, 1, 10, "CANCELLED", null).total()).isEqualTo(1);
        assertThat(service.myTodos(BOB, 1, 10, null, null).total()).isEqualTo(1);
    }

    /** 关闭是幂等的：目标不存在或已关闭时返回 0，不报错也不改变已有的关闭结果。 */
    @Test
    void closeIsIdempotent() {
        service.open(open("flow", "approval:1", ALICE));
        assertThat(service.close(close("flow", "approval:1", null, "DONE"))).isEqualTo(1);

        assertThat(service.close(close("flow", "approval:1", null, "CANCELLED")))
                .isZero();
        assertThat(service.close(close("flow", "never-opened", null, null))).isZero();
        assertThat(service.myTodos(ALICE, 1, 10, "DONE", null).total()).isEqualTo(1);
    }

    /** 关闭只会减少待办，不要求处理人仍是成员：成员被移出项目后，他名下的待办仍能被关掉。 */
    @Test
    void closeDoesNotRequireCurrentMembership() throws Exception {
        service.open(open("flow", "approval:1", BOB));
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("UPDATE sys_project_member SET status='DISABLED' WHERE user_id=" + BOB);
        }

        assertThat(service.close(close("flow", "approval:1", BOB, null))).isEqualTo(1);

        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("UPDATE sys_project_member SET status='ACTIVE' WHERE user_id=" + BOB);
        }
    }

    /** 打开必须校验：来源项目存在且启用，处理人是该项目有效成员。 */
    @Test
    void openValidatesProjectAndMembership() {
        assertThatThrownBy(() -> service.open(open("flow", "approval:1", OUTSIDER)))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(403));
        assertThatThrownBy(() -> service.open(open("ghost", "approval:1", ALICE)))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(404));
        assertThatThrownBy(() -> service.open(open("paused", "approval:1", ALICE)))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(404));
        assertThat(service.myTodos(ALICE, 1, 10, null, null).total()).isZero();
    }

    /** 容量上限：超出拒绝；已处于 OPEN 的同键更新不占额度；关闭后额度释放。 */
    @Test
    void capacityLimitsOpenTodosPerRecipientAndProject() {
        properties.setMaxOpenPerRecipient(2);
        service.open(open("flow", "k1", ALICE));
        service.open(open("flow", "k2", ALICE));

        assertThatThrownBy(() -> service.open(open("flow", "k3", ALICE)))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(409));
        // 同键更新不占用额度；别的项目、别的处理人各有各的额度。
        service.open(new TodoOpenRequest("flow", "k1", ALICE, "更新", null, null, null));
        service.open(open("other", "k1", ALICE));
        service.open(open("flow", "k3", BOB));

        service.close(close("flow", "k1", ALICE, null));
        service.open(open("flow", "k3", ALICE));

        assertThat(service.myTodos(ALICE, 1, 10, null, "flow").total()).isEqualTo(2);
    }

    /** 逾期由服务端按当前时间计算：只有 OPEN 且设置了已过期的截止时间才算逾期，概览同步统计。 */
    @Test
    void overdueIsComputedByServerAndSummarised() {
        service.open(new TodoOpenRequest(
                "flow", "late", ALICE, "过期了", null, null, clock.instantNow().minusHours(1)));
        service.open(new TodoOpenRequest(
                "flow", "soon", ALICE, "还早", null, null, clock.instantNow().plusHours(5)));
        service.open(open("flow", "nodue", ALICE));

        TodoSummaryView summary = service.summary(ALICE);

        assertThat(summary.openCount()).isEqualTo(3);
        assertThat(summary.overdueCount()).isEqualTo(1);
        assertThat(summary.recent()).hasSize(3);
        assertThat(summary.recent())
                .filteredOn(TodoView::overdue)
                .extracting(TodoView::title)
                .containsExactly("过期了");
    }

    /** 只能读到自己的待办。 */
    @Test
    void usersOnlySeeTheirOwnTodos() {
        service.open(open("flow", "approval:1", ALICE));

        assertThat(service.myTodos(BOB, 1, 10, null, null).total()).isZero();
        assertThat(service.summary(BOB).openCount()).isZero();
    }

    /** 状态筛选只接受三个取值，其余直接拒绝而不是静默忽略。 */
    @Test
    void rejectsUnknownStatusFilter() {
        assertThatThrownBy(() -> service.myTodos(ALICE, 1, 10, "ARCHIVED", null))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(400));
    }

    /** 新协议开启后旧投递、批量关闭和共享额度在同一个真实数据库事务内变化。 */
    @Test
    void legacyWritesShareQuotaWhenManagedProtocolEnabled() throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("DELETE FROM sys_todo_key_guard");
            statement.executeUpdate("DELETE FROM sys_todo_biz_lock");
            statement.executeUpdate("DELETE FROM sys_todo_recipient_quota");
        }
        var dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var config = new MybatisConfiguration();
        config.setMapUnderscoreToCamelCase(true);
        config.setEnvironment(new Environment(
                "spring-test", new org.mybatis.spring.transaction.SpringManagedTransactionFactory(), dataSource));
        config.addMapper(TodoMapper.class);
        config.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var factory = new MybatisSqlSessionFactoryBuilder().build(config);
        var springSession = new org.mybatis.spring.SqlSessionTemplate(factory);
        var locks = springSession.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var guarded = new TodoServiceImpl(
                new TodoRepository(springSession.getMapper(TodoMapper.class)),
                properties,
                clock,
                new com.kaiwu.module.operation.service.LegacyTodoOpenGuard(locks),
                new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks));
        var tx = new org.springframework.transaction.support.TransactionTemplate(
                new org.springframework.jdbc.datasource.DataSourceTransactionManager(dataSource));
        tx.setIsolationLevel(java.sql.Connection.TRANSACTION_READ_COMMITTED);
        properties.setManagedProtocolEnabled(true);
        properties.setMaxOpenPerRecipient(2);
        tx.executeWithoutResult(status -> guarded.open(open("flow", "one", ALICE)));
        tx.executeWithoutResult(status -> guarded.open(open("flow", "one", ALICE)));
        tx.executeWithoutResult(status -> guarded.open(open("flow", "two", ALICE)));
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("2");
        assertThatThrownBy(() -> tx.executeWithoutResult(status -> guarded.open(open("flow", "three", ALICE))))
                .isInstanceOf(ApiException.class);
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo_key_guard WHERE project_code='flow' AND biz_key='three'"))
                .isEqualTo("0");
        tx.executeWithoutResult(status -> guarded.close(close("flow", "one", null, "DONE")));
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("1");
        tx.executeWithoutResult(status -> guarded.open(open("flow", "three", ALICE)));
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("2");
        tx.executeWithoutResult(status -> {
            guarded.close(close("flow", "three", ALICE, "DONE"));
            status.setRollbackOnly();
        });
        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='three'")).isEqualTo("OPEN");
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("2");
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("UPDATE sys_todo SET updated_at='2020-01-01 00:00:00' WHERE biz_key='two'");
            statement.executeUpdate("UPDATE sys_todo SET closed_at='2020-01-01 00:00:00' WHERE biz_key='one'");
        }
        var cleanupTarget = new com.kaiwu.module.operation.service.LegacyTodoCleanupGuard(
                locks, new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks));
        var proxyFactory = new org.springframework.transaction.interceptor.TransactionProxyFactoryBean();
        proxyFactory.setTarget(cleanupTarget);
        proxyFactory.setProxyTargetClass(true);
        proxyFactory.setTransactionManager(
                new org.springframework.jdbc.datasource.DataSourceTransactionManager(dataSource));
        var attributes = new java.util.Properties();
        attributes.setProperty("*", "PROPAGATION_REQUIRES_NEW,ISOLATION_READ_COMMITTED");
        proxyFactory.setTransactionAttributes(attributes);
        proxyFactory.afterPropertiesSet();
        var cleanupProxy = (com.kaiwu.module.operation.service.LegacyTodoCleanupGuard) proxyFactory.getObject();
        var runner = new com.kaiwu.module.operation.service.LegacyTodoCleanupRunner(locks, cleanupProxy);
        assertThat(runner.cancelBatch(clock.instantNow().minusDays(90), clock.instantNow(), 100))
                .isEqualTo(1);
        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='two'")).isEqualTo("CANCELLED");
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("1");
        assertThat(runner.deleteBatch(clock.instantNow().minusDays(180), 100)).isEqualTo(1);
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo_key_guard WHERE project_code='flow' AND biz_key='one'"))
                .isEqualTo("0");
        var pool = java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            var ready = new java.util.concurrent.CountDownLatch(2);
            var go = new java.util.concurrent.CountDownLatch(1);
            java.util.function.Function<String, java.util.concurrent.Callable<Boolean>> opening = key -> () -> {
                ready.countDown();
                go.await();
                try {
                    tx.executeWithoutResult(status -> guarded.open(open("flow", key, ALICE)));
                    return true;
                } catch (ApiException ex) {
                    assertThat(ex.getStatus().value()).isEqualTo(409);
                    return false;
                }
            };
            var first = pool.submit(opening.apply("race-a"));
            var second = pool.submit(opening.apply("race-b"));
            assertThat(ready.await(10, java.util.concurrent.TimeUnit.SECONDS)).isTrue();
            go.countDown();
            assertThat(first.get(30, java.util.concurrent.TimeUnit.SECONDS))
                    .isNotEqualTo(second.get(30, java.util.concurrent.TimeUnit.SECONDS));
        } finally {
            pool.shutdownNow();
        }
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("2");
    }

    /** 受管版本、终态和旧域冲突在真实 MySQL 事务中生效；身份使用固定测试替身。 */
    @Test
    void managedWritesRespectVersionsAndLegacyQuota() throws Exception {
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate("DELETE FROM sys_managed_todo");
            statement.executeUpdate("DELETE FROM sys_todo_key_guard");
            statement.executeUpdate("DELETE FROM sys_todo_biz_lock");
            statement.executeUpdate("DELETE FROM sys_todo_recipient_quota");
            statement.executeUpdate("DELETE FROM sys_todo_key_guard");
            statement.executeUpdate("DELETE FROM sys_todo_biz_lock");
            statement.executeUpdate("DELETE FROM sys_todo_recipient_quota");
        }
        var dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var config = new MybatisConfiguration();
        config.setMapUnderscoreToCamelCase(true);
        config.setEnvironment(new Environment(
                "managed-test", new org.mybatis.spring.transaction.SpringManagedTransactionFactory(), dataSource));
        config.addMapper(TodoMapper.class);
        config.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        config.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoMapper.class);
        var factory = new MybatisSqlSessionFactoryBuilder().build(config);
        var springSession = new org.mybatis.spring.SqlSessionTemplate(factory);
        var locks = springSession.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var credentials = mock(com.kaiwu.module.project.service.ProjectServiceCredentials.class);
        when(credentials.authenticateScopeBearer(anyString(), org.mockito.ArgumentMatchers.eq("todo:managed")))
                .thenReturn(new com.kaiwu.module.project.model.ProjectServiceCredential("1", "601", "workflow"));
        properties.setManagedProtocolEnabled(true);
        properties.setMaxOpenPerRecipient(2);
        var managed = new com.kaiwu.module.operation.service.impl.ManagedTodoServiceImpl(
                credentials,
                locks,
                springSession.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoMapper.class),
                properties,
                clock,
                30);
        var legacy = new TodoServiceImpl(
                new TodoRepository(springSession.getMapper(TodoMapper.class)),
                properties,
                clock,
                new com.kaiwu.module.operation.service.LegacyTodoOpenGuard(locks),
                new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks));
        var tx = new org.springframework.transaction.support.TransactionTemplate(
                new org.springframework.jdbc.datasource.DataSourceTransactionManager(dataSource));
        tx.setIsolationLevel(java.sql.Connection.TRANSACTION_READ_COMMITTED);
        var open = managedRequest("wf:1:task", ALICE, 1, "OPEN", false, "待审批");
        assertThat(tx.execute(status -> managed.put("Bearer fixture", open)).disposition())
                .isEqualTo("APPLIED");
        assertThat(tx.execute(status -> managed.put("Bearer fixture", open)).disposition())
                .isEqualTo("DUPLICATE");
        assertThatThrownBy(() -> tx.execute(status ->
                        managed.put("Bearer fixture", managedRequest("wf:1:task", ALICE, 1, "OPEN", false, "改变"))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(409));
        var open2 = managedRequest("wf:1:task", ALICE, 2, "OPEN", false, "待审批");
        assertThat(tx.execute(status -> managed.put("Bearer fixture", open2)).disposition())
                .isEqualTo("APPLIED");
        assertThat(tx.execute(status -> managed.put("Bearer fixture", open)).disposition())
                .isEqualTo("SUPERSEDED");
        tx.executeWithoutResult(status -> legacy.open(open("flow", "legacy", ALICE)));
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("2");
        assertThatThrownBy(() -> tx.execute(status ->
                        managed.put("Bearer fixture", managedRequest("wf:2:task", ALICE, 1, "OPEN", false, "待审批"))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(429));
        assertThatThrownBy(() -> tx.execute(status ->
                        managed.put("Bearer fixture", managedRequest("legacy", ALICE, 1, "OPEN", false, "待审批"))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(409));
        var done = managedRequest("wf:1:task", ALICE, 3, "DONE", true, null);
        assertThat(tx.execute(status -> managed.put("Bearer fixture", done)).storedState())
                .isEqualTo("DONE");
        assertThatThrownBy(() -> tx.execute(status -> managed.put("Bearer fixture", open)))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(409));
        assertThat(tx.execute(status -> managed.receipt("Bearer fixture", "wf:1:task", ALICE))
                        .storedSequence())
                .isEqualTo(3);
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("1");
        assertThatThrownBy(() -> tx.execute(status ->
                        managed.put("Bearer fixture", managedRequest("nonmember", OUTSIDER, 1, "OPEN", false, "待审批"))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        error -> assertThat(error.getStatus().value()).isEqualTo(403));
        assertThat(tx.execute(status -> managed.put(
                                "Bearer fixture", managedRequest("nonmember", OUTSIDER, 1, "CANCELLED", true, null)))
                        .storedState())
                .isEqualTo("CANCELLED");
    }

    /** 测试操作使用固定当前时钟和公开模拟正文。 */
    private com.kaiwu.module.operation.dto.ManagedTodoRequest managedRequest(
            String key, String user, long sequence, String state, boolean terminal, String title) {
        return new com.kaiwu.module.operation.dto.ManagedTodoRequest(
                "flow", key, user, sequence, state, terminal, clock.instant(), title, null, null, null);
    }

    /** 清理：长期未处理的 OPEN 被取消（无截止时间看更新时间，有截止时间看逾期时间），关闭已久的被删除。 */
    @Test
    void cleanerCancelsStaleOpenTodosAndDeletesOldClosedOnes() throws Exception {
        service.open(open("flow", "stale-no-due", ALICE));
        service.open(open("flow", "fresh-no-due", ALICE));
        service.open(new TodoOpenRequest(
                "flow",
                "stale-overdue",
                ALICE,
                "逾期很久",
                null,
                null,
                clock.instantNow().minusDays(100)));
        service.open(new TodoOpenRequest(
                "flow",
                "recently-overdue",
                ALICE,
                "刚逾期",
                null,
                null,
                clock.instantNow().minusDays(10)));
        service.open(open("flow", "closed-old", ALICE));
        service.open(open("flow", "closed-recent", ALICE));
        service.close(close("flow", "closed-old", null, "DONE"));
        service.close(close("flow", "closed-recent", null, "DONE"));
        // 把时间戳整体改成「过去」来构造各类数据，避免真的等待。
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            statement.executeUpdate(
                    "UPDATE sys_todo SET updated_at = DATE_SUB('2026-10-23 10:00:00', INTERVAL 91 DAY) WHERE biz_key IN ('stale-no-due')");
            statement.executeUpdate(
                    "UPDATE sys_todo SET updated_at = DATE_SUB('2026-10-23 10:00:00', INTERVAL 100 DAY) WHERE biz_key = 'stale-overdue'");
            statement.executeUpdate(
                    "UPDATE sys_todo SET closed_at = DATE_SUB('2026-10-23 10:00:00', INTERVAL 181 DAY) WHERE biz_key = 'closed-old'");
            statement.executeUpdate(
                    "UPDATE sys_todo SET closed_at = DATE_SUB('2026-10-23 10:00:00', INTERVAL 10 DAY) WHERE biz_key = 'closed-recent'");
        }
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        when(values.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(true);

        new TodoCleaner(repository, redis, properties, clock, null).cleanup();

        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='stale-no-due'"))
                .isEqualTo("CANCELLED");
        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='stale-overdue'"))
                .isEqualTo("CANCELLED");
        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='fresh-no-due'"))
                .isEqualTo("OPEN");
        assertThat(scalar("SELECT status FROM sys_todo WHERE biz_key='recently-overdue'"))
                .isEqualTo("OPEN");
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo WHERE biz_key='closed-old'"))
                .isEqualTo("0");
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo WHERE biz_key='closed-recent'"))
                .isEqualTo("1");
        // 刚被取消的待办关闭时间是现在，不会在同一轮被删除。
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo WHERE biz_key IN ('stale-no-due','stale-overdue')"))
                .isEqualTo("2");
    }
    /** 真实受管投影必须出现在收件人的现有工作台查询中，其他收件人看不到。 */
    @Test
    void managedProjectionAppearsInExistingWorkspaceReads() throws Exception {
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement()) {
            sql.executeUpdate(
                    "INSERT INTO sys_managed_todo(id,project_id,project_code,producer_service,biz_key,recipient_user_id,operation_sequence,state,terminal,payload_digest,operation_created_at,title,link_url,due_at,last_seen_at,created_at,updated_at) VALUES(8001,601,'flow','workflow','visible',501,1,'OPEN',0,UNHEX(REPEAT('00',32)),NOW(6),'Managed visible','/workspace/601',DATE_SUB(NOW(6),INTERVAL 1 DAY),NOW(6),NOW(6),NOW(6))");
        }
        assertThat(service.myTodos(ALICE, 1, 20, "OPEN", null).records())
                .extracting(TodoView::title)
                .contains("Managed visible");
        assertThat(service.summary(ALICE).openCount()).isEqualTo(1);
        assertThat(service.myTodos(BOB, 1, 20, "OPEN", null).records()).isEmpty();
    }
    /** 受管清理必须只看存活时间，保留dueAt/序号/摘要及关闭墓碑，且同步释放共享配额。 */
    @Test
    void managedCleanupUsesLastSeenAndPreservesTombstones() throws Exception {
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement()) {
            for (int i = 0; i < 2; i++) {
                String key = i == 0 ? "managed-stale" : "managed-fresh";
                sql.executeUpdate(
                        "INSERT INTO sys_managed_todo(id,project_id,project_code,producer_service,biz_key,recipient_user_id,operation_sequence,state,terminal,payload_digest,operation_created_at,title,due_at,last_seen_at,created_at,updated_at) VALUES("
                                + (8010 + i) + ",601,'flow','workflow','" + key
                                + "',501,1,'OPEN',0,UNHEX(REPEAT('00',32)),'2026-10-23','Managed','2020-01-01','"
                                + (i == 0 ? "2026-01-01" : "2026-10-23") + "','2026-01-01','2026-01-01')");
                sql.executeUpdate("INSERT INTO sys_todo_biz_lock VALUES('flow','" + key + "')");
                sql.executeUpdate("INSERT INTO sys_todo_key_guard VALUES('flow','" + key + "',501,'MANAGED')");
            }
            sql.executeUpdate("INSERT INTO sys_todo_recipient_quota VALUES('flow',501,2)");
        }
        var locks = session.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var close = new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks);
        var guard = new com.kaiwu.module.operation.service.LegacyTodoCleanupGuard(locks, close);
        var runner = new com.kaiwu.module.operation.service.LegacyTodoCleanupRunner(locks, guard);
        assertThat(runner.cancelBatch(clock.instantNow().minusDays(90), clock.instantNow(), 20))
                .isEqualTo(1);
        assertThat(scalar("SELECT state FROM sys_managed_todo WHERE biz_key='managed-fresh'"))
                .isEqualTo("OPEN");
        assertThat(scalar("SELECT state FROM sys_managed_todo WHERE biz_key='managed-stale'"))
                .isEqualTo("CANCELLED");
        assertThat(scalar("SELECT operation_sequence FROM sys_managed_todo WHERE biz_key='managed-stale'"))
                .isEqualTo("1");
        assertThat(scalar("SELECT HEX(payload_digest) FROM sys_managed_todo WHERE biz_key='managed-stale'"))
                .isEqualTo("00".repeat(32));
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("1");
        assertThat(runner.deleteBatch(clock.instantNow().plusDays(400), 20)).isZero();
        assertThat(scalar("SELECT COUNT(*) FROM sys_managed_todo")).isEqualTo("2");
        assertThat(scalar("SELECT COUNT(*) FROM sys_todo_key_guard WHERE kind='MANAGED'"))
                .isEqualTo("2");
    }
    /** 清理与刷新按同一业务键/额度锁串行，迟到扫描不能覆盖刷新；重复版本不续期，dueAt不被推迟。 */
    @Test
    void cleanupRefreshRaceCannotLoseVersionsOrQuota() throws Exception {
        var ds = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var cfg = new MybatisConfiguration();
        cfg.setMapUnderscoreToCamelCase(true);
        cfg.setEnvironment(new Environment(
                "cleanup-race", new org.mybatis.spring.transaction.SpringManagedTransactionFactory(), ds));
        cfg.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        cfg.addMapper(com.kaiwu.module.operation.mapper.ManagedTodoMapper.class);
        var template = new org.mybatis.spring.SqlSessionTemplate(new MybatisSqlSessionFactoryBuilder().build(cfg));
        var locks = template.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var records = template.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoMapper.class);
        var tx = new org.springframework.transaction.support.TransactionTemplate(
                new org.springframework.jdbc.datasource.DataSourceTransactionManager(ds));
        tx.setIsolationLevel(Connection.TRANSACTION_READ_COMMITTED);
        var credentials = mock(com.kaiwu.module.project.service.ProjectServiceCredentials.class);
        when(credentials.authenticateScopeBearer(anyString(), org.mockito.ArgumentMatchers.eq("todo:managed")))
                .thenReturn(new com.kaiwu.module.project.model.ProjectServiceCredential("1", "601", "workflow"));
        properties.setManagedProtocolEnabled(true);
        var managed = new com.kaiwu.module.operation.service.impl.ManagedTodoServiceImpl(
                credentials, locks, records, properties, clock, 30);
        var cleanup = new com.kaiwu.module.operation.service.LegacyTodoCleanupGuard(
                locks, new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks));
        var due = clock.instant().minus(Duration.ofDays(400));
        var first = new com.kaiwu.module.operation.dto.ManagedTodoRequest(
                "flow", "race", ALICE, 1L, "OPEN", false, clock.instant(), "审批", null, null, due);
        tx.execute(status -> managed.put("Bearer fixture", first));
        long id = Long.parseLong(scalar("SELECT id FROM sys_managed_todo WHERE biz_key='race'"));
        clock.advance(Duration.ofDays(91));
        LocalDateTime cutoff = clock.instantNow().minusDays(90);
        assertThat(locks.findStaleManaged(cutoff, 10)).hasSize(1);
        var refresh = new com.kaiwu.module.operation.dto.ManagedTodoRequest(
                "flow", "race", ALICE, 2L, "OPEN", false, clock.instant(), "审批", null, null, due);
        var holding = new java.util.concurrent.CountDownLatch(1);
        var release = new java.util.concurrent.CountDownLatch(1);
        var pool = java.util.concurrent.Executors.newFixedThreadPool(2);
        try {
            var write = pool.submit(() -> tx.execute(status -> {
                var result = managed.put("Bearer fixture", refresh);
                holding.countDown();
                try {
                    if (!release.await(10, java.util.concurrent.TimeUnit.SECONDS))
                        throw new IllegalStateException("release timeout");
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(interrupted);
                }
                return result;
            }));
            assertThat(holding.await(10, java.util.concurrent.TimeUnit.SECONDS)).isTrue();
            var started = new java.util.concurrent.CountDownLatch(1);
            var clean = pool.submit(() -> {
                started.countDown();
                return tx.execute(status -> cleanup.cancelManaged(id, "flow", "race", 501, cutoff, clock.instantNow()));
            });
            assertThat(started.await(10, java.util.concurrent.TimeUnit.SECONDS)).isTrue();
            assertThatThrownBy(() -> clean.get(250, java.util.concurrent.TimeUnit.MILLISECONDS))
                    .isInstanceOf(java.util.concurrent.TimeoutException.class);
            release.countDown();
            assertThat(write.get(10, java.util.concurrent.TimeUnit.SECONDS).disposition())
                    .isEqualTo("APPLIED");
            assertThat(clean.get(10, java.util.concurrent.TimeUnit.SECONDS)).isZero();
        } finally {
            release.countDown();
            pool.shutdownNow();
        }
        String last = scalar("SELECT last_seen_at FROM sys_managed_todo WHERE id=" + id);
        clock.advance(Duration.ofHours(1));
        assertThat(tx.execute(status -> managed.put("Bearer fixture", refresh)).disposition())
                .isEqualTo("DUPLICATE");
        assertThat(scalar("SELECT last_seen_at FROM sys_managed_todo WHERE id=" + id))
                .isEqualTo(last);
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("1");
        assertThat(tx.<Integer>execute(status ->
                        cleanup.cancelManaged(id, "flow", "race", 501, clock.instantNow(), clock.instantNow())))
                .isEqualTo(1);
        assertThat(
                        scalar(
                                "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code='flow' AND recipient_user_id=501"))
                .isEqualTo("0");
        assertThat(tx.execute(status -> managed.put("Bearer fixture", refresh)).storedState())
                .isEqualTo("CANCELLED");
        var reopen = new com.kaiwu.module.operation.dto.ManagedTodoRequest(
                "flow", "race", ALICE, 3L, "OPEN", false, clock.instant(), "审批", null, null, due);
        assertThat(tx.execute(status -> managed.put("Bearer fixture", reopen)).disposition())
                .isEqualTo("APPLIED");
        assertThat(scalar("SELECT due_at FROM sys_managed_todo WHERE id=" + id))
                .isEqualTo(
                        LocalDateTime.ofInstant(due, ZoneOffset.UTC).toString().replace('T', ' ') + ":00");
    }
    /** 配置为+09时，受管dueAt和存活比较仍以同一UTC时刻为准，不能提前逾期或提前清理。 */
    @Test
    void managedUtcTimesRespectTheConfiguredPlatformZone() throws Exception {
        var zoned = Clock.fixed(clock.instant(), ZoneId.of("Asia/Seoul"));
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement()) {
            sql.executeUpdate(
                    "INSERT INTO sys_managed_todo(id,project_id,project_code,producer_service,biz_key,recipient_user_id,operation_sequence,state,terminal,payload_digest,operation_created_at,title,due_at,last_seen_at,created_at,updated_at) VALUES(9000,601,'flow','workflow','zone',501,1,'OPEN',0,UNHEX(REPEAT('00',32)),'2026-10-23 10:00:00','UTC task','2026-10-23 11:00:00','2026-07-25 14:00:00','2026-10-23','2026-10-23')");
        }
        var repo = new TodoRepository(session.getMapper(TodoMapper.class), zoned);
        var reader = new TodoServiceImpl(repo, properties, zoned, null, null);
        assertThat(reader.summary(ALICE).overdueCount()).isZero();
        assertThat(reader.myTodos(ALICE, 1, 20, "OPEN", null)
                        .records()
                        .getFirst()
                        .dueAt())
                .isEqualTo(LocalDateTime.parse("2026-10-23T20:00:00"));
        var locks = session.getMapper(com.kaiwu.module.operation.mapper.ManagedTodoLockMapper.class);
        var guard = new com.kaiwu.module.operation.service.LegacyTodoCleanupGuard(
                locks, new com.kaiwu.module.operation.service.LegacyTodoCloseGuard(locks));
        var runner = new com.kaiwu.module.operation.service.LegacyTodoCleanupRunner(locks, guard, zoned);
        var local = LocalDateTime.now(zoned);
        assertThat(runner.cancelBatch(local.minusDays(90), local, 20)).isZero();
        assertThat(scalar("SELECT state FROM sys_managed_todo WHERE id=9000")).isEqualTo("OPEN");
    }
}
