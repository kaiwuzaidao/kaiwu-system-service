package com.kaiwu.module.agent.repository;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.module.agent.catalog.CapabilityCatalog;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.entity.*;
import com.kaiwu.module.agent.execution.AgentActionAccess;
import com.kaiwu.module.agent.mapper.*;
import com.kaiwu.module.agent.planning.AgentPlan;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.protocol.CapabilityManifestValidator;
import com.kaiwu.module.agent.service.impl.AgentActionServiceImpl;
import com.kaiwu.module.agent.service.impl.AgentRegistryServiceImpl;
import com.kaiwu.module.agent.store.AgentActionRecord;
import com.kaiwu.module.agent.store.AgentActionStore;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.module.configuration.service.ConfigEncryptionService;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.sql.*;
import java.time.*;
import java.util.Set;
import java.util.concurrent.*;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.*;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/** 验证真实 MySQL 的基线与重复迁移、XML 权限 JOIN、JSON 字段、显式清空和项目锁；仅用一次性数据库。 */
class AgentRegistryMySqlTest {
    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
            DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                    .asCompatibleSubstituteFor("mysql"));
    private static SqlSessionFactory sessions;
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-23T00:00:00Z"), ZoneOffset.UTC);
    private static final KaiwuContext ADMIN = new KaiwuContext(
            "402",
            "session",
            null,
            null,
            Set.of("system:project:list", "system:project:update"),
            Set.of(),
            "v1",
            "kaiwu-system-service",
            CLOCK.instant(),
            CLOCK.instant().plusSeconds(60),
            "jti");
    private final AgentManifestCodec codec = new AgentManifestCodec();

    @BeforeAll
    static void start() throws Exception {
        MYSQL.start();
        Path directory = Path.of("../sql/increment").toAbsolutePath().normalize();
        var flyway = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + directory)
                .load();
        assertThat(flyway.migrate().migrationsExecuted).isPositive();
        assertThat(flyway.migrate().migrationsExecuted).isZero();
        try (Connection connection = MYSQL.createConnection("");
                Statement statement = connection.createStatement()) {
            try (ResultSet result = statement.executeQuery(
                    "SELECT COUNT(*) FROM sys_dict_item i JOIN sys_dict_type t ON i.dict_type_id = t.id WHERE t.dict_code IN ('agent.capability.status', 'agent.capability.connection') AND t.scope_id = 0")) {
                assertThat(result.next()).isTrue();
                assertThat(result.getInt(1)).isEqualTo(5);
            }

            try (ResultSet result = statement.executeQuery(
                    "SELECT COUNT(*) FROM sys_dict_item i JOIN sys_dict_type t ON i.dict_type_id = t.id WHERE t.dict_code = 'agent.action.status' AND t.scope_id = 0")) {
                assertThat(result.next()).isTrue();
                assertThat(result.getInt(1)).isEqualTo(8);
            }

            statement.executeUpdate(
                    "INSERT INTO sys_user (id,username,password_hash,display_name,status,must_change_password,created_at,updated_at) VALUES (402,'agent-contract','unused','Agent Contract','ENABLED',0,NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project (id,project_code,project_name,status,built_in,created_by,package_name,default_branch,created_at,updated_at) VALUES (401,'crm','Agent Contract','ACTIVE',0,402,'com.example.agent','main',NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project_member (project_id,user_id,status,created_at,updated_at) VALUES (401,402,'ACTIVE',NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project_role (id,project_id,role_code,role_name,status,built_in,created_at,updated_at) VALUES (403,401,'project-admin','Admin','ACTIVE',1,NOW(),NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project_member_role (project_id,user_id,role_id,created_at) VALUES (401,402,403,NOW())");
            statement.executeUpdate(
                    "INSERT INTO sys_project_menu (id,project_id,menu_name,menu_type,permission_code,sort_no,visible,status,created_at,updated_at) VALUES (404,401,'List','BUTTON','record:record:list',0,1,'ACTIVE',NOW(),NOW())");
        }
        MybatisConfiguration configuration = new MybatisConfiguration();
        configuration.setMapUnderscoreToCamelCase(true);
        configuration.setEnvironment(new Environment(
                "agent-contract",
                new JdbcTransactionFactory(),
                new UnpooledDataSource(
                        "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())));
        configuration.addMapper(AgentCapabilityMapper.class);
        configuration.addMapper(AgentCredentialMapper.class);
        configuration.addMapper(AgentRegistryEventMapper.class);
        configuration.addMapper(AgentRemoteActionMapper.class);
        sessions = new MybatisSqlSessionFactoryBuilder().build(configuration);
    }

    @AfterAll
    static void stop() {
        MYSQL.stop();
    }

    @Test
    void remoteActionStoreUsesRealMysqlCasAndEncryptedPayload() throws Exception {
        LocalDateTime now = LocalDateTime.now(CLOCK);
        AgentRemoteActionEntity pending = remoteAction(now);
        try (SqlSession session = sessions.openSession(true)) {
            var store = new AgentRemoteActionRepository(session.getMapper(AgentRemoteActionMapper.class));
            store.create(pending);
            assertThat(store.owned(pending.getActionId(), "403", pending.getSessionId()))
                    .isEmpty();
            assertThat(store.owned(pending.getActionId(), pending.getUserId(), "wrong-session"))
                    .isEmpty();
            assertThat(store.owned(pending.getActionId(), pending.getUserId(), pending.getSessionId()))
                    .isPresent()
                    .get()
                    .extracting(AgentRemoteActionEntity::getFrozenCiphertext)
                    .asString()
                    .startsWith("v1:");
        }

        CountDownLatch start = new CountDownLatch(1);
        java.util.concurrent.atomic.AtomicInteger winners = new java.util.concurrent.atomic.AtomicInteger();
        try (ExecutorService pool = Executors.newFixedThreadPool(16)) {
            var jobs = new java.util.ArrayList<Future<?>>();
            for (int index = 0; index < 16; index++) {
                final int choice = index;
                jobs.add(pool.submit(() -> {
                    try {
                        start.await();
                        try (SqlSession session = sessions.openSession(true)) {
                            var store =
                                    new AgentRemoteActionRepository(session.getMapper(AgentRemoteActionMapper.class));
                            boolean changed = choice % 2 == 0
                                    ? store.claim(pending, now)
                                    : store.closePending(pending, "CANCELLED", null, now);
                            if (changed) winners.incrementAndGet();
                        }
                    } catch (InterruptedException failure) {
                        Thread.currentThread().interrupt();
                        throw new IllegalStateException(failure);
                    }
                }));
            }
            start.countDown();
            for (Future<?> job : jobs) job.get(10, TimeUnit.SECONDS);
        }
        assertThat(winners).hasValue(1);

        try (SqlSession session = sessions.openSession(true)) {
            var store = new AgentRemoteActionRepository(session.getMapper(AgentRemoteActionMapper.class));
            var winner = store.owned(pending.getActionId(), pending.getUserId(), pending.getSessionId())
                    .orElseThrow();
            assertThat(winner.getRevision()).isEqualTo(1);
            assertThat(winner.getStatus()).isIn("EXECUTING", "CANCELLED");
            AgentRemoteActionEntity toReconcile = remoteAction(now);
            store.create(toReconcile);
            assertThat(store.claim(toReconcile, now)).isTrue();
            var executing = store.owned(toReconcile.getActionId(), toReconcile.getUserId(), toReconcile.getSessionId())
                    .orElseThrow();
            executing.setUserId("403");
            assertThat(store.markUnknown(executing, now.plusSeconds(1), now.plusSeconds(1)))
                    .isFalse();
            executing.setUserId("402");
            assertThat(store.markUnknown(executing, now.minusSeconds(1), now.plusSeconds(1)))
                    .isFalse();
            assertThat(store.markUnknown(executing, now.plusSeconds(1), now.plusSeconds(1)))
                    .isTrue();
            var unknown = store.owned(toReconcile.getActionId(), toReconcile.getUserId(), toReconcile.getSessionId())
                    .orElseThrow();
            assertThat(unknown.getStatus()).isEqualTo("UNKNOWN");
            assertThat(store.claim(unknown, now.plusSeconds(1))).isFalse();
            var crypto = testEncryption();
            assertThat(store.reconcile(
                            unknown, "SUCCEEDED", crypto.encrypt("{\"saved\":true}"), null, now.plusSeconds(2)))
                    .isTrue();
            assertThat(crypto.decrypt(
                            store.owned(toReconcile.getActionId(), toReconcile.getUserId(), toReconcile.getSessionId())
                                    .orElseThrow()
                                    .getResultCiphertext()))
                    .isEqualTo("{\"saved\":true}");

            AgentRemoteActionEntity expired = remoteAction(now);
            expired.setExpiresAt(now.minusSeconds(1));
            store.create(expired);
            assertThat(store.claim(expired, now)).isFalse();
            assertThat(store.closePending(expired, "CANCELLED", null, now)).isFalse();
            assertThat(store.closePending(expired, "EXPIRED", null, now)).isTrue();
            assertThatThrownBy(() -> store.closePending(expired, "EXECUTING", null, now))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    private static AgentRemoteActionEntity remoteAction(LocalDateTime now) {
        AgentRemoteActionEntity action = new AgentRemoteActionEntity();
        action.setActionId(java.util.UUID.randomUUID().toString());
        action.setProjectId("401");
        action.setUserId("402");
        action.setSessionId("agent-session");
        action.setCapabilityCode("crm.record.update");
        action.setCapabilityVersion("1");
        action.setManifestHash("a".repeat(64));
        action.setParamsHash("b".repeat(64));
        action.setPreconditionsHash("c".repeat(64));
        action.setPreviewHash("d".repeat(64));
        action.setFrozenCiphertext(testEncryption().encrypt("{\"note\":\"secret\"}"));
        action.setTokenHash(AgentManifestCodec.digest("token-not-persisted"));
        action.setConfirmationMode("REQUIRED");
        action.setStatus("PENDING");
        action.setExpiresAt(now.plusMinutes(5));
        action.setRevision(0);
        action.setCreatedAt(now);
        action.setUpdatedAt(now);
        return action;
    }

    private static ConfigEncryptionService testEncryption() {
        return new ConfigEncryptionService(java.util.Base64.getEncoder().encodeToString(new byte[32]));
    }

    @Test
    void persistsCredentialRegistrationApprovalAndRevocationWithoutLeakingToken() {
        String token;
        try (SqlSession session = sessions.openSession(false)) {
            token = service(session).rotateCredential("401", ADMIN, null).token();
            session.commit();
        }
        AgentRegistrationView registered;
        try (SqlSession session = sessions.openSession(false)) {
            var service = service(session);
            registered = service.register(
                    "Bearer " + token,
                    codec.canonical(com.kaiwu.testing.AgentTestFixtures.manifest("1"))
                            .getBytes(StandardCharsets.UTF_8));
            assertThat(registered.status()).isEqualTo("PENDING");
            session.commit();
        }
        try (SqlSession session = sessions.openSession(false)) {
            var service = service(session);
            var revision = new AgentCapabilityRevision(registered.capabilityCode(), "1", registered.manifestHash());
            assertThat(service.review("401", new AgentCapabilityReviewRequest(revision, "APPROVED"), ADMIN, null)
                            .status())
                    .isEqualTo("APPROVED");
            var mapper = session.getMapper(AgentCapabilityMapper.class);
            assertThat(mapper.visibleCandidates("402", LocalDateTime.now(CLOCK).minusSeconds(180)))
                    .extracting(AgentCapabilityEntity::getCapabilityCode)
                    .containsExactly(registered.capabilityCode());
            assertThat(mapper.visibleCandidates(
                            "unknown", LocalDateTime.now(CLOCK).minusSeconds(180)))
                    .isEmpty();
            assertThat(mapper.visibleCandidates("402", LocalDateTime.now(CLOCK).plusSeconds(1)))
                    .isEmpty();
            service.revokeCredential("401", ADMIN, null);
            assertThat(mapper.visibleCandidates("402", LocalDateTime.now(CLOCK).minusSeconds(180)))
                    .isEmpty();
            session.commit();
        }
        try (SqlSession session = sessions.openSession(false)) {
            var credential = session.getMapper(AgentCredentialMapper.class).selectById("401");
            assertThat(credential.getTokenHash()).isEqualTo(AgentManifestCodec.digest(token));
            assertThat(credential.getStatus()).isEqualTo("REVOKED");
            var row = session.getMapper(AgentCapabilityMapper.class).selectById(registered.id());
            assertThat(row.getStatus()).isEqualTo("REVOKED");
            assertThat(row.getLastSeenAt()).isNull();
            assertThat(codec.decode(row.getManifestJson().getBytes(StandardCharsets.UTF_8))
                            .code())
                    .isEqualTo(registered.capabilityCode());
            assertThat(service(session).list("401", ADMIN).getFirst().online()).isFalse();
            assertThat(session.getMapper(AgentRegistryEventMapper.class).selectCount(null))
                    .isEqualTo(4);
        }
    }

    @Test
    void projectRowLockSerializesConcurrentLifecycleTransactions() throws Exception {
        try (SqlSession first = sessions.openSession(false);
                ExecutorService executor = Executors.newSingleThreadExecutor()) {
            assertThat(first.getMapper(AgentCapabilityMapper.class).lockProject("401"))
                    .isEqualTo("crm");
            CountDownLatch started = new CountDownLatch(1);
            Future<String> second = executor.submit(() -> {
                try (SqlSession session = sessions.openSession(false)) {
                    started.countDown();
                    String code = session.getMapper(AgentCapabilityMapper.class).lockProject("401");
                    session.rollback(true);
                    return code;
                }
            });
            try {
                assertThat(started.await(5, TimeUnit.SECONDS)).isTrue();
                assertThatThrownBy(() -> second.get(150, TimeUnit.MILLISECONDS)).isInstanceOf(TimeoutException.class);
            } finally {
                first.rollback(true);
            }
            assertThat(second.get(5, TimeUnit.SECONDS)).isEqualTo("crm");
        }
    }

    @Test
    void databaseRejectsInvalidRegistryStateAndDuplicateCapability() {
        try (SqlSession session = sessions.openSession(false)) {
            AgentCapabilityEntity row = new AgentCapabilityEntity();
            row.setId("410");
            row.setProjectId("401");
            row.setCapabilityCode("crm.contract.unique");
            row.setVersion("1");
            row.setManifestHash("a".repeat(64));
            row.setManifestJson("{}");
            row.setStatus("PENDING");
            row.setCreatedAt(LocalDateTime.now(CLOCK));
            row.setUpdatedAt(LocalDateTime.now(CLOCK));
            AgentCapabilityMapper mapper = session.getMapper(AgentCapabilityMapper.class);
            mapper.insert(row);
            row.setId("411");
            assertThatThrownBy(() -> mapper.insert(row)).isInstanceOf(RuntimeException.class);
            row.setCapabilityCode("crm.contract.invalid");
            row.setStatus("READY");
            assertThatThrownBy(() -> mapper.insert(row)).isInstanceOf(RuntimeException.class);
            session.rollback(true);
        }
    }

    @Test
    void confirmedCreationCommitsProjectAdminAndMembershipAndAuditFailureRollsBack() throws Exception {
        var dataSource = new UnpooledDataSource(
                "com.mysql.cj.jdbc.Driver", MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var config = new MybatisConfiguration();
        config.setMapUnderscoreToCamelCase(true);
        config.setEnvironment(new Environment(
                "project-action", new org.mybatis.spring.transaction.SpringManagedTransactionFactory(), dataSource));
        config.addMapper(com.kaiwu.module.project.mapper.ProjectMapper.class);
        config.addMapper(com.kaiwu.module.project.mapper.ProjectRoleMapper.class);
        config.addMapper(com.kaiwu.module.project.mapper.ProjectMenuMapper.class);
        var sql = new org.mybatis.spring.SqlSessionTemplate(new MybatisSqlSessionFactoryBuilder().build(config));
        var repository = new com.kaiwu.module.project.repository.ProjectRepository(
                sql.getMapper(com.kaiwu.module.project.mapper.ProjectMapper.class),
                sql.getMapper(com.kaiwu.module.project.mapper.ProjectRoleMapper.class),
                sql.getMapper(com.kaiwu.module.project.mapper.ProjectMenuMapper.class));
        var domainAudit = mock(com.kaiwu.module.operation.service.AuditService.class);
        var target = new com.kaiwu.module.project.service.impl.ProjectServiceImpl(
                repository,
                domainAudit,
                mock(com.kaiwu.module.project.service.SystemPermissionSessionService.class),
                mock(com.kaiwu.module.configuration.service.I18nService.class));
        var proxy = new org.springframework.aop.framework.ProxyFactory(target);
        proxy.setProxyTargetClass(true);
        proxy.addAdvice(new org.springframework.transaction.interceptor.TransactionInterceptor(
                new org.springframework.jdbc.datasource.DataSourceTransactionManager(dataSource),
                new org.springframework.transaction.annotation.AnnotationTransactionAttributeSource()));
        var projects = (com.kaiwu.module.project.service.ProjectService) proxy.getProxy();
        var actor = com.kaiwu.testing.AgentTestFixtures.actor("402", "action-session");
        var auth = mock(com.kaiwu.module.identity.repository.AuthRepository.class);
        when(auth.findSession(actor.sessionId()))
                .thenReturn(java.util.Optional.of(new com.kaiwu.module.identity.repository.AuthRepository.OnlineSession(
                        actor.sessionId(),
                        actor.userId(),
                        "hash",
                        "ONLINE",
                        "WEB",
                        Instant.now().plusSeconds(600))));
        when(auth.findUserById(actor.userId()))
                .thenReturn(java.util.Optional.of(new com.kaiwu.module.identity.repository.AuthRepository.UserAccount(
                        actor.userId(), "user", "hash", "User", "ENABLED", "zh-CN", false, false)));
        when(auth.findPermissions(actor.userId())).thenReturn(Set.of("system:agent:ask", "system:project:create"));
        // Redis 原子语义由 AgentActionServiceTest 的真 Redis 覆盖；这里验证领域事务确实提交/回滚。
        var state = new java.util.concurrent.atomic.AtomicReference<AgentActionRecord>();
        var store = mock(AgentActionStore.class);
        doAnswer(call -> {
                    state.set(call.getArgument(0));
                    return null;
                })
                .when(store)
                .create(any());
        when(store.get(anyString())).thenAnswer(call -> state.get());
        when(store.replace(any(), any()))
                .thenAnswer(call -> state.compareAndSet(call.getArgument(0), call.getArgument(1)));
        try (var validation = jakarta.validation.Validation.buildDefaultValidatorFactory()) {
            var actions = new AgentActionServiceImpl(
                    store,
                    new AgentActionAccess(auth),
                    new CapabilityCatalog(),
                    projects,
                    validation.getValidator(),
                    tools.jackson.databind.json.JsonMapper.builder().build(),
                    mock(AuditPort.class));
            var preview = actions.preview(
                    new AgentPlan.Call(
                            CapabilityCatalog.PROJECT_CREATE,
                            java.util.Map.of("projectCode", "action-created", "projectName", "对话创建")),
                    actor,
                    null);
            assertThat(repository.projectCodeExists("action-created")).isFalse();
            var result = actions.confirm(preview.actionId(), preview.confirmationToken(), actor, null);
            assertThat(result.status()).isEqualTo("SUCCEEDED");
            assertThat(repository.findProject(result.projectId())).isPresent();
            try (Connection connection = dataSource.getConnection();
                    Statement statement = connection.createStatement();
                    ResultSet rows = statement.executeQuery(
                            "SELECT COUNT(*) FROM sys_project p JOIN sys_project_member m ON m.project_id=p.id JOIN sys_project_member_role mr ON mr.project_id=p.id AND mr.user_id=m.user_id JOIN sys_project_role r ON r.id=mr.role_id AND r.project_id=p.id WHERE p.project_code='action-created' AND m.user_id=402 AND m.status='ACTIVE' AND r.role_code='project-admin'")) {
                assertThat(rows.next()).isTrue();
                assertThat(rows.getInt(1)).isEqualTo(1);
            }
            doThrow(new IllegalStateException("audit failure"))
                    .when(domainAudit)
                    .recordOperation(any(), anyString(), anyString(), anyString(), anyString(), any());
            var failed = actions.preview(
                    new AgentPlan.Call(
                            CapabilityCatalog.PROJECT_CREATE,
                            java.util.Map.of("projectCode", "action-rollback", "projectName", "回滚验证")),
                    actor,
                    null);
            assertThat(actions.confirm(failed.actionId(), failed.confirmationToken(), actor, null)
                            .status())
                    .isEqualTo("UNKNOWN");
            assertThat(repository.projectCodeExists("action-rollback")).isFalse();
        }
    }

    private AgentRegistryServiceImpl service(SqlSession session) {
        return new AgentRegistryServiceImpl(
                new AgentRegistryRepository(
                        session.getMapper(AgentCapabilityMapper.class),
                        session.getMapper(AgentCredentialMapper.class),
                        session.getMapper(AgentRegistryEventMapper.class)),
                new CapabilityManifestValidator(),
                codec,
                CLOCK,
                mock(AuditPort.class));
    }
}
