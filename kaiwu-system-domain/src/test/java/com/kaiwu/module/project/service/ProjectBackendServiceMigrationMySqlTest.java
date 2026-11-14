package com.kaiwu.module.project.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.common.ApiException;
import com.kaiwu.module.project.mapper.ProjectBackendServiceMapper;
import com.kaiwu.module.project.mapper.ProjectMapper;
import com.kaiwu.module.project.mapper.ProjectMenuMapper;
import com.kaiwu.module.project.mapper.ProjectRoleMapper;
import com.kaiwu.module.project.repository.ProjectBackendServiceRepository;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.impl.ProjectBackendServiceImpl;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.file.Path;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.LocalCacheScope;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 在一次性 MySQL 验证存量项目地址和空地址在默认后端路由中的兼容行为。 */
class ProjectBackendServiceMigrationMySqlTest {
    /** 用实际 Mapper 同步默认服务，并验证重复迁移和新旧代码交替写入后的路由。 */
    @Test
    void upgradesLegacyProjectsAndKeepsDefaultRoutesCompatible() throws Exception {
        try (var db = new MySQLContainer<>(
                DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                        .asCompatibleSubstituteFor("mysql"))) {
            db.start();
            String location = "filesystem:" + Path.of("../sql/increment").toAbsolutePath();
            Flyway.configure()
                    .dataSource(db.getJdbcUrl(), db.getUsername(), db.getPassword())
                    .locations(location)
                    .load()
                    .migrate();
            try (var c = db.createConnection("");
                    var sql = c.createStatement()) {
                sql.executeUpdate(
                        "INSERT INTO sys_user(id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES(1,'c1-owner','test-only','Owner','ENABLED',0,NOW(),NOW())");
                sql.executeUpdate(
                        "INSERT INTO sys_project(id,project_code,project_name,status,built_in,created_by,package_name,default_branch,service_url,created_at,updated_at) VALUES(10,'legacy','Legacy','ACTIVE',0,1,'com.example.legacy','main','http://old:8080/legacy',NOW(),NOW()),(11,'empty','Empty','ACTIVE',0,1,'com.example.empty','main',NULL,NOW(),NOW())");
                sql.executeUpdate(
                        "INSERT INTO sys_project_member(project_id,user_id,status,created_at,updated_at) VALUES(10,1,'ACTIVE',NOW(),NOW())");
                sql.executeUpdate(
                        "INSERT INTO sys_project_role(id,project_id,role_code,role_name,status,built_in,created_at,updated_at) VALUES(20,10,'project-admin','Admin','ACTIVE',1,NOW(),NOW())");
                sql.executeUpdate(
                        "INSERT INTO sys_project_member_role(project_id,user_id,role_id,created_at) VALUES(10,1,20,NOW())");
            }
            var latest = Flyway.configure()
                    .dataSource(db.getJdbcUrl(), db.getUsername(), db.getPassword())
                    .locations(location)
                    .load();
            latest.migrate();
            assertThat(latest.migrate().migrationsExecuted).isZero();
            var cfg = new MybatisConfiguration();
            cfg.setMapUnderscoreToCamelCase(true);
            cfg.setLocalCacheScope(LocalCacheScope.STATEMENT);
            cfg.setEnvironment(new Environment(
                    "c1-upgrade",
                    new JdbcTransactionFactory(),
                    new UnpooledDataSource(
                            "com.mysql.cj.jdbc.Driver", db.getJdbcUrl(), db.getUsername(), db.getPassword())));
            cfg.addMapper(ProjectMapper.class);
            cfg.addMapper(ProjectBackendServiceMapper.class);
            try (var session = new MybatisSqlSessionFactoryBuilder().build(cfg).openSession(true)) {
                var mapper = session.getMapper(ProjectBackendServiceMapper.class);
                var projectMapper = session.getMapper(ProjectMapper.class);
                assertThat(projectMapper.syncDefaultBackendService("10")).isPositive();
                assertThat(projectMapper.syncDefaultBackendService("11")).isPositive();
                assertThat(mapper.find("10", "default").getServiceUrl()).isEqualTo("http://old:8080/legacy");
                assertThat(mapper.find("11", "default").getServiceUrl()).isNull();
                var projects = new ProjectRepository(
                        projectMapper, mock(ProjectRoleMapper.class), mock(ProjectMenuMapper.class));
                var store = new ProjectBackendServiceRepository(mapper, projectMapper);
                var actor = mock(KaiwuContext.class);
                when(actor.userId()).thenReturn("1");
                var off = new ProjectBackendServiceImpl(store, projects, mock(AuditPort.class), false);
                var on = new ProjectBackendServiceImpl(store, projects, mock(AuditPort.class), true);
                try (var c = db.createConnection("");
                        var sql = c.createStatement()) {
                    sql.executeUpdate("UPDATE sys_project SET service_url='http://new:8080/legacy' WHERE id=10");
                }
                assertThat(off.routes("10", actor).fragments()).singleElement().satisfies(fragment -> assertThat(
                                fragment.fragment())
                        .contains(
                                "uri: http://new:8080/legacy",
                                "Path=/legacy-api/**",
                                "audience: kaiwu-legacy-service"));
                assertThatThrownBy(() -> on.routes("10", actor))
                        .isInstanceOfSatisfying(
                                ApiException.class,
                                ex -> assertThat(ex.getStatus().value()).isEqualTo(503));
                assertThat(projectMapper.syncDefaultBackendService("10")).isPositive();
                assertThat(on.routes("10", actor).fragments())
                        .singleElement()
                        .satisfies(fragment -> assertThat(fragment.fragment()).contains("uri: http://new:8080/legacy"));
            }
        }
    }
}
