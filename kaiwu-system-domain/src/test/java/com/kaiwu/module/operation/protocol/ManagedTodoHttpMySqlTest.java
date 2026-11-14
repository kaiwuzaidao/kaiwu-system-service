package com.kaiwu.module.operation.protocol;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.common.ApiException;
import com.kaiwu.common.GlobalExceptionHandler;
import com.kaiwu.module.operation.config.TodoProperties;
import com.kaiwu.module.operation.controller.ManagedTodoController;
import com.kaiwu.module.operation.dto.ManagedTodoRequest;
import com.kaiwu.module.operation.dto.TodoOpenRequest;
import com.kaiwu.module.operation.mapper.ManagedTodoLockMapper;
import com.kaiwu.module.operation.mapper.ManagedTodoMapper;
import com.kaiwu.module.operation.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.operation.mapper.TodoMapper;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.module.operation.repository.TodoRepository;
import com.kaiwu.module.operation.service.LegacyTodoCloseGuard;
import com.kaiwu.module.operation.service.LegacyTodoOpenGuard;
import com.kaiwu.module.operation.service.ManagedTodoService;
import com.kaiwu.module.operation.service.impl.ManagedTodoServiceImpl;
import com.kaiwu.module.operation.service.impl.TodoServiceImpl;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Set;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionTemplate;
import org.mybatis.spring.transaction.SpringManagedTransactionFactory;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.http.MediaType;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;
import tools.jackson.databind.json.JsonMapper;

/** 真实HTTP映射、C5持久凭据、Spring事务代理及一次性MySQL共同验证C2，不访问共享环境。 */
class ManagedTodoHttpMySqlTest {
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
            DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                    .asCompatibleSubstituteFor("mysql"));
    private static final Clock CLOCK = Clock.fixed(Instant.now().truncatedTo(ChronoUnit.SECONDS), ZoneOffset.UTC);
    private static final JsonMapper JSON = new JsonMapper();
    private static MockMvc mvc;
    private static TodoProperties properties;
    private static TodoServiceImpl legacy;
    private static TransactionTemplate tx;

    /** 全量迁移、只在容器中植入测试凭据；默认协议开关保持关闭以验证拒绝。 */
    @BeforeAll
    static void prepare() throws Exception {
        MYSQL.start();
        Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + Path.of("../sql/increment").toAbsolutePath())
                .load()
                .migrate();
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement()) {
            sql.executeUpdate(
                    "INSERT INTO sys_user(id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES(501,'c2-recipient','test-only','Recipient','ENABLED',0,NOW(),NOW())");
            sql.executeUpdate(
                    "INSERT INTO sys_project(id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES(601,'sample','Sample','ACTIVE',0,501,'com.example.c2','main',NOW(),NOW())");
            sql.executeUpdate(
                    "INSERT INTO sys_project_member(project_id,user_id,status,created_at,updated_at) VALUES(601,501,'ACTIVE',NOW(),NOW())");
        }
        var ds = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var cfg = new MybatisConfiguration();
        cfg.setMapUnderscoreToCamelCase(true);
        cfg.setEnvironment(new Environment("c2-http", new SpringManagedTransactionFactory(), ds));
        cfg.addMapper(ManagedTodoLockMapper.class);
        cfg.addMapper(ManagedTodoMapper.class);
        cfg.addMapper(ProjectSchedulerMapper.class);
        cfg.addMapper(TodoMapper.class);
        var session = new SqlSessionTemplate(new MybatisSqlSessionFactoryBuilder().build(cfg));
        var store = new ProjectSchedulerRepository(session.getMapper(ProjectSchedulerMapper.class));
        var encoder = new BCryptPasswordEncoder(4);
        for (int id = 1; id <= 6; id++)
            store.insertScopedCredential(
                    Integer.toString(id),
                    "601",
                    encoder.encode("zsch_" + id + "_test-only"),
                    id == 2 ? "default" : id == 6 ? "other" : "workflow",
                    LocalDateTime.now(ZoneOffset.UTC).plusHours(id == 4 ? -1 : 1),
                    id == 2 ? Set.of() : Set.of(id == 3 ? "member:read" : "todo:managed"));
        store.revokeScopedCredential("601", "5");
        properties = new TodoProperties();
        var locks = session.getMapper(ManagedTodoLockMapper.class);
        var manager = new DataSourceTransactionManager(ds);
        var target = new ManagedTodoServiceImpl(
                new ProjectServiceCredentials(store, encoder),
                locks,
                session.getMapper(ManagedTodoMapper.class),
                properties,
                CLOCK,
                30);
        var proxy = new ProxyFactory(target);
        proxy.addAdvice(new TransactionInterceptor(manager, new AnnotationTransactionAttributeSource()));
        mvc = MockMvcBuilders.standaloneSetup(new ManagedTodoController((ManagedTodoService) proxy.getProxy()))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
        legacy = new TodoServiceImpl(
                new TodoRepository(session.getMapper(TodoMapper.class), CLOCK),
                properties,
                CLOCK,
                new LegacyTodoOpenGuard(locks),
                new LegacyTodoCloseGuard(locks));
        tx = new TransactionTemplate(manager);
        tx.setIsolationLevel(java.sql.Connection.TRANSACTION_READ_COMMITTED);
    }

    /** 停止本测试容器，不对外部数据库执行清理。 */
    @AfterAll
    static void close() {
        MYSQL.stop();
    }

    /** 操作时间和业务键固定，序号递增时由调用方显式持久化新操作。 */
    private static ManagedTodoRequest operation(String key, long sequence, String state, boolean terminal) {
        return new ManagedTodoRequest(
                "sample",
                key,
                "501",
                sequence,
                state,
                terminal,
                CLOCK.instant(),
                state.equals("OPEN") ? "待审批" : null,
                null,
                "/workspace/601",
                null);
    }

    /** 调用真实PUT映射，身份只取Authorization，不携带用户Context。 */
    private static org.springframework.mock.web.MockHttpServletResponse send(int credential, ManagedTodoRequest request)
            throws Exception {
        return mvc.perform(put("/api/internal/managed-todos")
                        .header("Authorization", "Bearer zsch_" + credential + "_test-only")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(JSON.writeValueAsBytes(request)))
                .andReturn()
                .getResponse();
    }

    /** 真正凭据缺失、旧default、缺scope、过期/撤销均被拒，默认关闭无写入，项目归属不能由正文覆盖。 */
    @Test
    void deniesInvalidCredentialsAndKeepsProtocolDisabledByDefault() throws Exception {
        properties.setManagedProtocolEnabled(false);
        assertThat(send(1, operation("disabled", 1, "OPEN", false)).getStatus()).isEqualTo(503);
        assertThat(mvc.perform(put("/api/internal/managed-todos")
                                .header("X-User-Id", "501")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(JSON.writeValueAsBytes(operation("spoof", 1, "OPEN", false))))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(401);
        properties.setManagedProtocolEnabled(true);
        for (int id = 2; id <= 5; id++)
            assertThat(send(id, operation("invalid", 1, "OPEN", false)).getStatus())
                    .isEqualTo(id <= 3 ? 403 : 401);
        var wrong = new ManagedTodoRequest(
                "other", "wrong-project", "501", 1L, "OPEN", false, CLOCK.instant(), "审批", null, null, null);
        assertThat(send(1, wrong).getStatus()).isEqualTo(403);
        var external = new ManagedTodoRequest(
                "sample",
                "external",
                "501",
                1L,
                "OPEN",
                false,
                CLOCK.instant(),
                "审批",
                null,
                "https://external.invalid/steal",
                null);
        assertThat(send(1, external).getStatus()).isEqualTo(400);
    }

    /** 重复、冲突、旧序号及终态通过真实事务生效；其他生产者只可读取自己的回执。 */
    @Test
    void enforcesSequenceTerminalAndProducerIsolation() throws Exception {
        properties.setManagedProtocolEnabled(true);
        assertThat(send(1, operation("http-version", 1, "OPEN", false)).getContentAsString())
                .contains("APPLIED");
        assertThat(send(1, operation("http-version", 1, "OPEN", false)).getContentAsString())
                .contains("DUPLICATE");
        assertThat(send(1, operation("http-version", 1, "CANCELLED", false)).getStatus())
                .isEqualTo(409);
        assertThat(send(1, operation("http-version", 2, "OPEN", false)).getStatus())
                .isEqualTo(200);
        assertThat(send(1, operation("http-version", 1, "OPEN", false)).getContentAsString())
                .contains("SUPERSEDED");
        var read = get("/api/internal/managed-todos/receipt")
                .param("bizKey", "http-version")
                .param("recipientUserId", "501")
                .header("Authorization", "Bearer zsch_6_test-only");
        assertThat(mvc.perform(read).andReturn().getResponse().getStatus()).isEqualTo(404);
        assertThat(send(1, operation("http-version", 3, "DONE", true)).getStatus())
                .isEqualTo(200);
        assertThat(send(1, operation("http-version", 4, "OPEN", false)).getStatus())
                .isEqualTo(409);
        assertThat(send(1, operation("http-version", 1, "OPEN", false)).getStatus())
                .isEqualTo(409);
        assertThat(legacy.summary("501").recent()).noneMatch(row -> row.title().equals("待审批"));
    }

    /** 无前驱关闭建立墓碑，旧legacy接口不能复活或改写受管投影；原单服务投递仍可独立使用。 */
    @Test
    void closeFirstBlocksDelayedOpenAndLegacyCannotOverwrite() throws Exception {
        properties.setManagedProtocolEnabled(true);
        assertThat(send(1, operation("close-first", 2, "CANCELLED", true)).getStatus())
                .isEqualTo(200);
        assertThat(send(1, operation("close-first", 1, "OPEN", false)).getStatus())
                .isEqualTo(409);
        assertThatThrownBy(() -> tx.executeWithoutResult(status ->
                        legacy.open(new TodoOpenRequest("sample", "close-first", "501", "旧写入", null, null, null))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        e -> assertThat(e.getStatus().value()).isEqualTo(409));
        tx.executeWithoutResult(
                status -> legacy.open(new TodoOpenRequest("sample", "legacy-only", "501", "旧兼容", null, null, null)));
        assertThat(legacy.myTodos("501", 1, 100, "OPEN", null).records())
                .anyMatch(row -> row.title().equals("旧兼容"));
    }
    /** 恢复数据缺少guard时不能被旧写入重新认领；应失败关闭并保留原受管行供对账。 */
    @Test
    void legacyFailsClosedWhenManagedGuardIsMissing() throws Exception {
        properties.setManagedProtocolEnabled(true);
        var orphan = new ManagedTodoRequest(
                "sample",
                "missing-guard",
                "501",
                1L,
                "OPEN",
                false,
                CLOCK.instant(),
                "Guard fixture",
                null,
                null,
                null);
        assertThat(send(1, orphan).getStatus()).isEqualTo(200);
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement()) {
            sql.executeUpdate("DELETE FROM sys_todo_key_guard WHERE project_code='sample' AND biz_key='missing-guard'");
        }
        assertThatThrownBy(() -> tx.executeWithoutResult(status ->
                        legacy.open(new TodoOpenRequest("sample", "missing-guard", "501", "旧写入", null, null, null))))
                .isInstanceOfSatisfying(
                        ApiException.class,
                        e -> assertThat(e.getStatus().value()).isEqualTo(503));
        try (var c = MYSQL.createConnection("");
                var sql = c.createStatement();
                var rows = sql.executeQuery(
                        "SELECT (SELECT COUNT(*) FROM sys_todo WHERE biz_key='missing-guard'),(SELECT COUNT(*) FROM sys_managed_todo WHERE biz_key='missing-guard' AND state='OPEN')")) {
            assertThat(rows.next()).isTrue();
            assertThat(rows.getInt(1)).isZero();
            assertThat(rows.getInt(2)).isEqualTo(1);
        }
    }
}
