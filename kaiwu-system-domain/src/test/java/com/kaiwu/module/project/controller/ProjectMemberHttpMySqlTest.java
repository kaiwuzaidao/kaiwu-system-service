package com.kaiwu.module.project.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.common.GlobalExceptionHandler;
import com.kaiwu.module.operation.mapper.ProjectSchedulerMapper;
import com.kaiwu.module.operation.repository.ProjectSchedulerRepository;
import com.kaiwu.module.project.mapper.ProjectMemberQueryMapper;
import com.kaiwu.module.project.repository.ProjectMemberQueryRepository;
import com.kaiwu.module.project.service.ProjectServiceCredentials;
import com.kaiwu.module.project.service.impl.ProjectMemberQueryServiceImpl;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.LocalCacheScope;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 使用真实MySQL和BCrypt串起HTTP、凭据事实及成员SQL；不访问共享环境或把成员查询当用户授权。 */
class ProjectMemberHttpMySqlTest {
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
            DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                    .asCompatibleSubstituteFor("mysql"));
    private static SqlSession session;
    private static MockMvc mvc;

    /** 从上一步V119升级到本步V120，构造两个项目和200/201边界，保留旧凭据及其他scope。 */
    @BeforeAll
    static void prepare() throws Exception {
        MYSQL.start();
        var latest = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + Path.of("../sql/increment").toAbsolutePath())
                .load();
        latest.migrate();
        assertThat(latest.migrate().migrationsExecuted).isZero();
        sql(
                "INSERT INTO sys_user(id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES(1,'c3-owner','test-only','Owner','ENABLED',0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
        for (int project : List.of(10, 20, 30))
            sql(
                    "INSERT INTO sys_project(id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES("
                            + project + ",'sample" + project + "','Project','" + (project == 30 ? "ARCHIVED" : "ACTIVE")
                            + "',0,1,'com.example.c3','main',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
        for (String role : List.of("approver", "overflow", "inactive"))
            sql(
                    "INSERT INTO sys_project_role(id,project_id,role_code,role_name,status,built_in,created_at,updated_at) VALUES("
                            + (role.equals("approver") ? 40 : role.equals("overflow") ? 41 : 42) + ",10,'" + role
                            + "','Role','" + (role.equals("inactive") ? "DISABLED" : "ACTIVE")
                            + "',0,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
        try (var c = MYSQL.createConnection("");
                var u = c.prepareStatement(
                        "INSERT INTO sys_user(id,username,password_hash,display_name,status,created_at,updated_at) VALUES(?,?,'test-only','Candidate',?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                var m = c.prepareStatement(
                        "INSERT INTO sys_project_member(project_id,user_id,status,created_at,updated_at) VALUES(10,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)");
                var r = c.prepareStatement(
                        "INSERT INTO sys_project_member_role(project_id,user_id,role_id,created_at) VALUES(10,?,?,CURRENT_TIMESTAMP)")) {
            for (int i = 0; i < 203; i++) {
                long id = 1000 + i;
                u.setLong(1, id);
                u.setString(2, "candidate" + id);
                u.setString(3, i == 201 ? "DISABLED" : "ENABLED");
                u.addBatch();
                m.setLong(1, id);
                m.setString(2, i == 202 ? "DISABLED" : "ACTIVE");
                m.addBatch();
                r.setLong(1, id);
                r.setLong(2, 41);
                r.addBatch();
                if (i != 200) {
                    r.setLong(1, id);
                    r.setLong(2, 40);
                    r.addBatch();
                }
            }
            u.executeBatch();
            m.executeBatch();
            r.executeBatch();
        }
        var configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setLocalCacheScope(LocalCacheScope.STATEMENT);
        configuration.setEnvironment(new Environment(
                "c3-http",
                new JdbcTransactionFactory(),
                new UnpooledDataSource(
                        "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())));
        configuration.addMapper(ProjectSchedulerMapper.class);
        configuration.addMapper(ProjectMemberQueryMapper.class);
        session = new MybatisSqlSessionFactoryBuilder().build(configuration).openSession(true);
        var store = new ProjectSchedulerRepository(session.getMapper(ProjectSchedulerMapper.class));
        var encoder = new BCryptPasswordEncoder(4);
        for (int id = 1; id <= 6; id++) {
            String service = id == 2 ? "default" : "workflow";
            store.insertScopedCredential(
                    Integer.toString(id),
                    id == 6 ? "30" : "10",
                    encoder.encode("zsch_" + id + "_test-only"),
                    service,
                    LocalDateTime.now(ZoneOffset.UTC).plusHours(id == 4 ? -1 : 1),
                    id == 2 ? Set.of() : Set.of(id == 3 ? "todo:managed" : "member:read"));
        }
        store.revokeScopedCredential("10", "5");
        var service = new ProjectMemberQueryServiceImpl(
                new ProjectServiceCredentials(store, encoder),
                new ProjectMemberQueryRepository(session.getMapper(ProjectMemberQueryMapper.class)),
                200);
        mvc = MockMvcBuilders.standaloneSetup(new InternalProjectMemberController(service))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    /** 所有SQL仅针对本测试启动的一次性容器。 */
    private static void sql(String statement) throws SQLException {
        try (Connection c = MYSQL.createConnection("");
                var s = c.createStatement()) {
            s.executeUpdate(statement);
        }
    }

    /** 测试完成关闭会话与容器，不清理共享库。 */
    @AfterAll
    static void close() {
        if (session != null) session.close();
        MYSQL.stop();
    }

    /** 项目A凭据不能读取B；旧default、缺scope、过期、撤销及停用项目都不得取得候选。 */
    @Test
    void deniesForeignProjectsAndInvalidStoredCredentials() throws Exception {
        assertThat(mvc.perform(get("/api/internal/projects/sample20/members/by-role?roleCode=approver")
                                .header("Authorization", "Bearer zsch_1_test-only"))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(403);
        for (int id = 2; id <= 6; id++) {
            var response = mvc.perform(get("/api/internal/projects/sample10/members/by-role?roleCode=approver")
                            .header("Authorization", "Bearer zsch_" + id + "_test-only"))
                    .andReturn()
                    .getResponse();
            assertThat(response.getStatus()).isEqualTo(id <= 3 ? 403 : 401);
            assertThat(response.getContentAsString())
                    .doesNotContain("Candidate", "password_hash", "token_hash", "zsch_");
        }
        for (String value : List.of("Bearer ordinary-user-jwt", "Bearer zsch_1_wrong"))
            assertThat(mvc.perform(get("/api/internal/projects/sample10/members/by-role?roleCode=approver")
                                    .header("Authorization", value)
                                    .header("X-User-Id", "1"))
                            .andReturn()
                            .getResponse()
                            .getStatus())
                    .isEqualTo(401);
        assertThat(mvc.perform(get("/api/internal/projects/sample10/members/by-role?roleCode=approver")
                                .header("X-User-Id", "1")
                                .header("X-Kaiwu-Context", "forged"))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(401);
    }

    /** 200人完整成功，201人整体422且不附部分ID；停用角色不存在，失效成员/用户均被SQL过滤。 */
    @Test
    void returnsCompleteTwoHundredOrFailsWithoutPartialCandidates() throws Exception {
        var response = mvc.perform(authorize(get("/api/internal/projects/sample10/members/by-role?roleCode=approver")))
                .andReturn()
                .getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        var body = new tools.jackson.databind.json.JsonMapper().readTree(response.getContentAsByteArray());
        assertThat(body.path("data").path("userIds").size()).isEqualTo(200);
        assertThat(response.getContentAsString()).doesNotContain("1200", "1201", "1202", "username", "password");
        response = mvc.perform(authorize(get("/api/internal/projects/sample10/members/by-role?roleCode=overflow")))
                .andReturn()
                .getResponse();
        assertThat(response.getStatus()).isEqualTo(422);
        assertThat(response.getContentAsString())
                .contains("project.members.candidateLimitExceeded")
                .doesNotContain("userIds", "1000");
        assertThat(mvc.perform(authorize(get("/api/internal/projects/sample10/members/by-role?roleCode=inactive")))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(404);
    }

    /** 资格快照只报告请求ID，保留去重顺序；超限、非法ID和跨项目请求整体拒绝。 */
    @Test
    void validatesEligibilitySnapshotsAgainstCurrentMembership() throws Exception {
        var response = mvc.perform(authorize(post("/api/internal/projects/sample10/members/eligibility"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"userIds\":[\"1000\",\"1201\",\"1202\",\"9999\",\"1000\"]}"))
                .andReturn()
                .getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        var items = new tools.jackson.databind.json.JsonMapper()
                .readTree(response.getContentAsByteArray())
                .path("data")
                .path("items");
        assertThat(items.size()).isEqualTo(4);
        assertThat(items.get(0).path("eligible").booleanValue()).isTrue();
        for (int i = 1; i < 4; i++)
            assertThat(items.get(i).path("eligible").booleanValue()).isFalse();
        for (String ids : List.of(
                "\"9223372036854775808\"",
                "null",
                IntStream.range(1000, 1201).mapToObj(i -> "\"" + i + "\"").collect(Collectors.joining(","))))
            assertThat(mvc.perform(authorize(post("/api/internal/projects/sample10/members/eligibility"))
                                    .contentType(MediaType.APPLICATION_JSON)
                                    .content("{\"userIds\":[" + ids + "]}"))
                            .andReturn()
                            .getResponse()
                            .getStatus())
                    .isEqualTo(400);
        assertThat(mvc.perform(authorize(post("/api/internal/projects/sample20/members/eligibility"))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"userIds\":[\"1000\"]}"))
                        .andReturn()
                        .getResponse()
                        .getStatus())
                .isEqualTo(403);
    }

    /** 固定测试凭据，不使用用户Context、浏览器身份头或环境秘密。 */
    private static MockHttpServletRequestBuilder authorize(MockHttpServletRequestBuilder request) {
        return request.header("Authorization", "Bearer zsch_1_test-only");
    }
}
