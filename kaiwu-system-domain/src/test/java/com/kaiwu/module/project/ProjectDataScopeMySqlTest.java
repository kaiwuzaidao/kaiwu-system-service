package com.kaiwu.module.project;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.MybatisSqlSessionFactoryBuilder;
import com.kaiwu.common.ApiException;
import com.kaiwu.module.operation.model.FieldChange;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest;
import com.kaiwu.module.project.dto.ProjectRoleDataScopeRequest.Item;
import com.kaiwu.module.project.mapper.ProjectDataScopeMapper;
import com.kaiwu.module.project.repository.ProjectDataScopeRepository;
import com.kaiwu.module.project.repository.ProjectRepository;
import com.kaiwu.module.project.service.impl.ProjectDataScopeServiceImpl;
import com.kaiwu.module.project.vo.DataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleDataScopeView;
import com.kaiwu.module.project.vo.ProjectRoleView;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * 项目数据范围的真实 MySQL 契约（ADR 0044、docs/DATA_SCOPE.md §3–§4、§8）。
 *
 * <p>只连接 Testcontainers 创建的一次性实例。夹具 ID 都在 {@link #BASE} 之上，每个用例开始前按外键顺序清理，
 * 不触碰迁移写入的种子数据。</p>
 */
class ProjectDataScopeMySqlTest {

    /** 夹具 ID 号段起点，高于迁移种子，低于 19 位。 */
    private static final long BASE = 700_000_000_000_000_000L;

    private static final long LONG_BASE = 1_780_000_000_000_000_000L;

    private static final long PROJECT = BASE + 1;
    private static final long OTHER_PROJECT = BASE + 2;
    private static final long ADMIN_USER = BASE + 11;
    private static final long STAFF_USER = BASE + 12;
    private static final long MANAGER_USER = BASE + 13;
    private static final long NO_DEPT_USER = BASE + 14;
    private static final long MULTI_USER = BASE + 15;

    private static final long HQ = BASE + 101;
    private static final long EAST = BASE + 102;
    private static final long EAST_GROUP = BASE + 103;
    private static final long NORTH = BASE + 104;

    private static final long ADMIN_ROLE = BASE + 201;
    private static final long STAFF_ROLE = BASE + 202;
    private static final long MANAGER_ROLE = BASE + 203;
    private static final long FINANCE_ROLE = BASE + 204;
    private static final long INACTIVE_ROLE = BASE + 205;

    private static final MySQLContainer<?> MYSQL = new MySQLContainer<>(
                    DockerImageName.parse(System.getenv().getOrDefault("KAIWU_TEST_MYSQL_IMAGE", "mysql:8.4"))
                            .asCompatibleSubstituteFor("mysql"))
            .withDatabaseName("kaiwu_data_scope")
            .withUsername("kaiwu_data_scope")
            .withPassword("kaiwu_data_scope");

    private static SqlSession session;

    private final ProjectRepository projectRepository = mock(ProjectRepository.class);
    private final AuditService auditService = mock(AuditService.class);
    private ProjectDataScopeServiceImpl service;

    /** 启动一次性 MySQL 并迁移到最新版本。 */
    @BeforeAll
    static void startMysqlAndMigrate() {
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
        // 夹具通过独立连接写库，长期存活的会话若保留一级缓存，会把上一个用例的查询结果带到下一个用例。
        configuration.setLocalCacheScope(org.apache.ibatis.session.LocalCacheScope.STATEMENT);
        configuration.setEnvironment(new Environment("data-scope", new JdbcTransactionFactory(), dataSource));
        configuration.addMapper(ProjectDataScopeMapper.class);
        configuration.addMapper(com.kaiwu.module.agent.mapper.AgentCapabilityMapper.class);
        session = new MybatisSqlSessionFactoryBuilder().build(configuration).openSession(true);
    }

    /** 关闭会话与 MySQL 容器。 */
    @AfterAll
    static void stopMysql() {
        session.close();
        MYSQL.stop();
    }

    /** 每个用例前按外键顺序清理夹具号段并重建项目、部门、角色、成员和受控资源。 */
    @BeforeEach
    void freshFixture() throws Exception {
        for (String sql : new String[] {
            "DELETE FROM sys_project_role_data_scope WHERE project_id >= " + BASE,
            "DELETE FROM sys_project_data_resource WHERE project_id >= " + BASE,
            "DELETE FROM sys_project_member_role WHERE project_id >= " + BASE,
            "DELETE FROM sys_project_member WHERE project_id >= " + BASE,
            "DELETE FROM sys_project_role WHERE project_id >= " + BASE,
            "DELETE FROM sys_project WHERE id >= " + BASE,
            "DELETE FROM sys_user_department WHERE user_id >= " + BASE,
            "UPDATE sys_department SET parent_id = NULL WHERE id >= " + BASE,
            "DELETE FROM sys_department WHERE id >= " + BASE,
            "DELETE FROM sys_user WHERE id >= " + BASE
        }) {
            exec(sql);
        }
        for (long user : new long[] {ADMIN_USER, STAFF_USER, MANAGER_USER, NO_DEPT_USER, MULTI_USER}) {
            exec(
                    "INSERT INTO sys_user (id, username, password_hash, display_name, status, created_at, updated_at)"
                            + " VALUES (?, ?, 'x', ?, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                    user,
                    "ds-" + user,
                    "u" + user);
        }
        project(PROJECT, "ds-main");
        project(OTHER_PROJECT, "ds-other");
        department(HQ, null, "HQ");
        department(EAST, HQ, "EAST");
        department(EAST_GROUP, EAST, "EAST-G");
        department(NORTH, HQ, "NORTH");
        userDepartment(STAFF_USER, EAST_GROUP, true);
        userDepartment(MANAGER_USER, EAST, true);
        userDepartment(MULTI_USER, NORTH, true);
        userDepartment(MULTI_USER, EAST_GROUP, false);

        role(ADMIN_ROLE, "project-admin", true, "ACTIVE");
        role(STAFF_ROLE, "staff", false, "ACTIVE");
        role(MANAGER_ROLE, "manager", false, "ACTIVE");
        role(FINANCE_ROLE, "finance", false, "ACTIVE");
        role(INACTIVE_ROLE, "retired", false, "DISABLED");
        member(ADMIN_USER, ADMIN_ROLE);
        member(STAFF_USER, STAFF_ROLE);
        member(MANAGER_USER, MANAGER_ROLE);
        member(NO_DEPT_USER, MANAGER_ROLE);
        member(MULTI_USER, MANAGER_ROLE);
        member(MULTI_USER, FINANCE_ROLE);

        resource(PROJECT, "crm:customer", "ALL,DEPT_AND_CHILD,DEPT,SELF,CUSTOM_DEPT", "ENABLED");
        resource(PROJECT, "crm:followup", "DEPT,SELF", "ENABLED");
        resource(PROJECT, "crm:contract", "ALL,SELF", "DISABLED");

        service = new ProjectDataScopeServiceImpl(
                new ProjectDataScopeRepository(session.getMapper(ProjectDataScopeMapper.class)),
                projectRepository,
                auditService);
    }

    // ---- 快照 ----

    /** 没有受控资源的项目不产生数据范围快照。 */
    @Test
    void aProjectWithoutControlledResourcesHasNoSnapshot() {
        assertThat(service.snapshot(String.valueOf(OTHER_PROJECT), String.valueOf(STAFF_USER)))
                .isEmpty();
    }

    /** 内置项目管理员在每个已启用资源上都是全部，已下线的资源不出现。 */
    @Test
    void projectAdminSeesEverythingOnEveryEnabledResourceOnly() {
        DataScopeView view = snapshot(ADMIN_USER);

        assertThat(view.rules()).containsOnlyKeys("crm:customer", "crm:followup");
        assertThat(view.rules().values())
                .allSatisfy(rule -> assertThat(rule.all()).isTrue());
        assertThat(view.depts()).isEmpty();
        assertThat(view.primaryDeptId()).isNull();
    }

    /** 未配置的角色固定为仅本人，并带上用户的主部门。 */
    @Test
    void anUnconfiguredRoleIsSelfOnly() {
        DataScopeView view = snapshot(STAFF_USER);

        assertThat(view.rules().get("crm:customer").set()).isEmpty();
        assertThat(view.rules().get("crm:followup").set()).isEmpty();
        assertThat(view.primaryDeptId()).isEqualTo(String.valueOf(EAST_GROUP));
    }

    /** 本部门及下级覆盖用户所属部门的整棵子树。 */
    @Test
    void deptAndChildCoversTheWholeSubtreeOfEveryDepartmentTheUserBelongsTo() {
        scope(MANAGER_ROLE, "crm:customer", "DEPT_AND_CHILD", false);

        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).containsExactly(EAST, EAST_GROUP);
    }

    /** 配置的范围不在资源允许范围内时按仅本人处理，只会变窄。 */
    @Test
    void aScopeOutsideTheResourceAllowListNarrowsToSelf() {
        // crm:followup 只允许 DEPT 和 SELF，这条 DEPT_AND_CHILD 配置是脏数据，必须按仅本人处理。
        scope(MANAGER_ROLE, "crm:followup", "DEPT_AND_CHILD", false);

        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:followup")).isEmpty();
    }

    /** 已下线的资源即使留有配置也不会进入快照。 */
    @Test
    void aDisabledResourceNeverReachesTheSnapshotEvenIfConfigured() {
        scope(MANAGER_ROLE, "crm:contract", "ALL", false);

        assertThat(snapshot(MANAGER_USER).rules()).doesNotContainKey("crm:contract");
    }

    /** 指定部门可选是否包含下级。 */
    @Test
    void customDeptHonoursIncludeChild() {
        long configId = scope(MANAGER_ROLE, "crm:customer", "CUSTOM_DEPT", true);
        customDepartment(configId, EAST);

        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).containsExactly(EAST, EAST_GROUP);
    }

    /** 多角色取并集，任一角色为全部则结果为全部。 */
    @Test
    void multipleRolesUnionAndAnAllRoleWins() {
        scope(MANAGER_ROLE, "crm:customer", "DEPT", false);
        long custom = scope(FINANCE_ROLE, "crm:customer", "CUSTOM_DEPT", false);
        customDepartment(custom, HQ);

        DataScopeView union = snapshot(MULTI_USER);
        assertThat(departmentsOf(union, "crm:customer")).containsExactly(HQ, EAST_GROUP, NORTH);
        assertThat(union.primaryDeptId()).isEqualTo(String.valueOf(NORTH));

        scope(FINANCE_ROLE, "crm:followup", "DEPT", false);
        exec(
                "UPDATE sys_project_role_data_scope SET scope_type='ALL' WHERE role_id=? AND resource_code='crm:customer'",
                FINANCE_ROLE);
        assertThat(snapshot(MULTI_USER).rules().get("crm:customer").all()).isTrue();
    }

    /** 已停用的角色不贡献任何范围。 */
    @Test
    void aDisabledRoleContributesNothing() {
        member(STAFF_USER, INACTIVE_ROLE);
        scope(INACTIVE_ROLE, "crm:customer", "ALL", false);

        assertThat(snapshot(STAFF_USER).rules().get("crm:customer").all()).isNull();
    }

    /** 没有所属部门的用户，按部门的范围退化为仅本人。 */
    @Test
    void aUserWithoutDepartmentsDegradesDeptScopesToSelf() {
        scope(MANAGER_ROLE, "crm:customer", "DEPT_AND_CHILD", false);

        DataScopeView view = snapshot(NO_DEPT_USER);
        assertThat(view.rules().get("crm:customer").set()).isEmpty();
        assertThat(view.primaryDeptId()).isNull();
    }

    /** 没有任何部门被标为主部门时，取数值最小的所属部门作为主部门。 */
    @Test
    void withoutAPrimaryFlagTheSmallestDepartmentIdIsThePrimary() {
        exec("UPDATE sys_user_department SET primary_department = 0 WHERE user_id = ?", MULTI_USER);

        assertThat(snapshot(MULTI_USER).primaryDeptId()).isEqualTo(String.valueOf(EAST_GROUP));
    }

    /** 删除被指定的部门只会让范围变窄，既不阻塞删除也不放宽。 */
    @Test
    void deletingADepartmentNarrowsACustomScopeInsteadOfBlockingOrWidening() {
        // 应用层本来就禁止删除有成员的部门，所以用一个没有成员的临时部门。
        long temp = BASE + 105;
        department(temp, HQ, "TEMP");
        long configId = scope(MANAGER_ROLE, "crm:customer", "CUSTOM_DEPT", false);
        customDepartment(configId, temp);
        customDepartment(configId, EAST);
        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).containsExactly(EAST, temp);

        exec("DELETE FROM sys_department WHERE id = ?", temp);

        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).containsExactly(EAST);
    }

    /** 删除角色时其范围配置和勾选的部门随外键级联删除。 */
    @Test
    void deletingARoleRemovesItsScopesAndDepartments() {
        long configId = scope(FINANCE_ROLE, "crm:customer", "CUSTOM_DEPT", false);
        customDepartment(configId, NORTH);

        exec("DELETE FROM sys_project_member_role WHERE role_id = ?", FINANCE_ROLE);
        exec("DELETE FROM sys_project_role WHERE id = ?", FINANCE_ROLE);

        assertThat(count("SELECT COUNT(*) FROM sys_project_role_data_scope WHERE role_id = " + FINANCE_ROLE))
                .isZero();
        assertThat(count("SELECT COUNT(*) FROM sys_project_role_data_scope_dept WHERE scope_id = " + configId))
                .isZero();
    }

    /** 快照超过体积上限时以文档约定的 403 拒绝，而不是截断。 */
    @Test
    void anOversizedSnapshotIsDeniedWithTheDocumentedErrorInsteadOfTruncated() throws Exception {
        // 300 个 19 位部门挂在同一棵树下，DEPT_AND_CHILD 展开后必然超过 6144 字节。
        long root = LONG_BASE;
        department(root, null, "BIG-ROOT");
        for (int i = 1; i <= 300; i++) {
            department(root + i, root, "BIG-" + i);
        }
        userDepartment(MANAGER_USER, root, true);
        scope(MANAGER_ROLE, "crm:customer", "DEPT_AND_CHILD", false);

        assertThatThrownBy(() -> snapshot(MANAGER_USER)).isInstanceOfSatisfying(ApiException.class, e -> {
            assertThat(e.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
            assertThat(e.getMessageKey()).isEqualTo("api.project.dataScopeTooLarge");
            assertThat(e.getMessageArgs()).containsEntry("reason", "DATA_SCOPE_TOO_LARGE");
            assertThat(e.getMessageArgs()).containsEntry("limitBytes", 6144);
        });
    }

    // ---- 管理：读取与保存 ----

    /** 内置管理员角色在管理视图里只读，所有资源显示为全部。 */
    @Test
    void theBuiltInAdminRoleIsReadOnlyAndShowsAll() {
        ProjectRoleDataScopeView view = service.roleScopes(String.valueOf(PROJECT), String.valueOf(ADMIN_ROLE));

        assertThat(view.readOnly()).isTrue();
        assertThat(view.items())
                .extracting(ProjectRoleDataScopeView.Item::scope)
                .containsOnly("ALL");
    }

    /** 未配置的资源也列在管理视图里，显示为默认的仅本人。 */
    @Test
    void unconfiguredResourcesAreListedAsDefaultSelf() {
        ProjectRoleDataScopeView view = service.roleScopes(String.valueOf(PROJECT), String.valueOf(STAFF_ROLE));

        assertThat(view.readOnly()).isFalse();
        assertThat(view.items())
                .extracting(ProjectRoleDataScopeView.Item::resourceCode)
                .containsExactly("crm:customer", "crm:followup");
        assertThat(view.items()).allSatisfy(item -> {
            assertThat(item.scope()).isEqualTo("SELF");
            assertThat(item.configured()).isFalse();
        });
    }

    /** 保存整体替换角色配置，并写出逐资源的前后值审计。 */
    @Test
    void savingReplacesTheConfigurationAndWritesAnAuditDiff() {
        save(MANAGER_ROLE, item("crm:customer", "CUSTOM_DEPT", true, EAST, NORTH), item("crm:followup", "DEPT", false));

        ProjectRoleDataScopeView view = service.roleScopes(String.valueOf(PROJECT), String.valueOf(MANAGER_ROLE));
        ProjectRoleDataScopeView.Item customer = view.items().get(0);
        assertThat(customer.scope()).isEqualTo("CUSTOM_DEPT");
        assertThat(customer.includeChild()).isTrue();
        assertThat(customer.deptIds()).containsExactly(String.valueOf(EAST), String.valueOf(NORTH));
        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).containsExactly(EAST, EAST_GROUP, NORTH);

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<FieldChange>> changes = ArgumentCaptor.forClass(List.class);
        verify(auditService)
                .recordOperationWithDiff(
                        any(),
                        eq("project"),
                        eq("SAVE_PROJECT_ROLE_DATA_SCOPE"),
                        any(),
                        eq("ProjectRole"),
                        eq(String.valueOf(MANAGER_ROLE)),
                        changes.capture(),
                        any());
        assertThat(changes.getValue()).extracting(FieldChange::field).containsExactly("crm:customer", "crm:followup");
        assertThat(changes.getValue().get(1).before()).isEqualTo("SELF");
        assertThat(changes.getValue().get(1).after()).isEqualTo("DEPT");
    }

    /** 省略资源或选择仅本人都回到默认，且不落库。 */
    @Test
    void omittingAResourceOrChoosingSelfReturnsItToTheDefaultAndStoresNothing() {
        save(MANAGER_ROLE, item("crm:customer", "DEPT", false), item("crm:followup", "DEPT", false));

        save(MANAGER_ROLE, item("crm:customer", "SELF", false));

        assertThat(count("SELECT COUNT(*) FROM sys_project_role_data_scope WHERE role_id = " + MANAGER_ROLE))
                .isZero();
    }

    /** 重复保存相同配置不产生第二条审计。 */
    @Test
    void savingTheSameConfigurationTwiceWritesNoSecondAudit() {
        save(MANAGER_ROLE, item("crm:customer", "DEPT", false));
        save(MANAGER_ROLE, item("crm:customer", "DEPT", false));

        verify(auditService, org.mockito.Mockito.times(1))
                .recordOperationWithDiff(any(), any(), any(), any(), any(), any(), anyList(), any());
    }

    /** 非法请求被拒绝，且不改动已有配置。 */
    @Test
    void invalidRequestsAreRejectedAndLeaveTheExistingConfigurationAlone() {
        save(MANAGER_ROLE, item("crm:customer", "DEPT", false));

        assertInvalid(item("crm:unknown", "DEPT", false));
        assertInvalid(item("crm:contract", "SELF", false));
        assertInvalid(item("crm:customer", "NOT_A_SCOPE", false));
        assertInvalid(item("crm:followup", "ALL", false));
        assertInvalid(item("crm:customer", "DEPT", true));
        assertInvalid(item("crm:customer", "DEPT", false, EAST));
        assertInvalid(item("crm:customer", "CUSTOM_DEPT", false));
        assertInvalid(item("crm:customer", "CUSTOM_DEPT", false, BASE + 999_999));
        assertInvalid(item("crm:customer", "CUSTOM_DEPT", false, EAST, EAST));
        assertInvalid(item("crm:customer", "DEPT", false), item("crm:customer", "SELF", false));

        assertThat(service.roleScopes(String.valueOf(PROJECT), String.valueOf(MANAGER_ROLE))
                        .items()
                        .get(0)
                        .scope())
                .isEqualTo("DEPT");
    }

    /** 内置管理员角色不可保存，也不写审计。 */
    @Test
    void theBuiltInAdminRoleCannotBeSaved() {
        assertThatThrownBy(() -> service.saveRoleScopes(
                        String.valueOf(PROJECT),
                        String.valueOf(ADMIN_ROLE),
                        new ProjectRoleDataScopeRequest(List.of()),
                        null,
                        null))
                .isInstanceOfSatisfying(
                        ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST));
        verify(auditService, never())
                .recordOperationWithDiff(any(), any(), any(), any(), any(), any(), anyList(), any());
    }

    /** 查询不存在的角色返回 404。 */
    @Test
    void anUnknownRoleIs404() {
        when(projectRepository.findRole(String.valueOf(PROJECT), "1")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.roleScopes(String.valueOf(PROJECT), "1"))
                .isInstanceOfSatisfying(
                        ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.NOT_FOUND));
    }

    // ---- 资源声明 ----

    /** 保存资源先新增，再原地更新并重新启用，不产生重复行。 */
    @Test
    void savingAResourceInsertsThenUpdatesInPlaceAndReenablesIt() {
        String project = String.valueOf(PROJECT);

        service.saveResource(project, "crm:order", "订单", List.of("ALL", "SELF"));
        assertThat(service.resources(project))
                .filteredOn(resource -> resource.code().equals("crm:order"))
                .singleElement()
                .satisfies(resource -> {
                    assertThat(resource.name()).isEqualTo("订单");
                    assertThat(resource.allowedScopes()).containsExactly("ALL", "SELF");
                    assertThat(resource.status()).isEqualTo("ENABLED");
                });

        exec("UPDATE sys_project_data_resource SET status = 'DISABLED' WHERE resource_code = 'crm:order'");
        service.saveResource(project, "crm:order", "销售订单", List.of("SELF", "CUSTOM_DEPT"));

        assertThat(service.resources(project))
                .filteredOn(resource -> resource.code().equals("crm:order"))
                .singleElement()
                .satisfies(resource -> {
                    assertThat(resource.name()).isEqualTo("销售订单");
                    assertThat(resource.allowedScopes()).containsExactly("SELF", "CUSTOM_DEPT");
                    assertThat(resource.status()).isEqualTo("ENABLED");
                });
        assertThat(count("SELECT COUNT(*) FROM sys_project_data_resource WHERE resource_code = 'crm:order'"))
                .isEqualTo(1);
    }

    /** 资源列表包含已下线的资源。 */
    @Test
    void resourcesListsDisabledOnesToo() {
        assertThat(service.resources(String.valueOf(PROJECT)))
                .extracting(resource -> resource.code() + ":" + resource.status())
                .containsExactly("crm:contract:DISABLED", "crm:customer:ENABLED", "crm:followup:ENABLED");
    }

    /** 保存资源声明不改动任何角色配置，授权不随代码下发。 */
    @Test
    void savingAResourceNeverTouchesRoleConfigurations() {
        scope(MANAGER_ROLE, "crm:customer", "DEPT_AND_CHILD", false);

        service.saveResource(String.valueOf(PROJECT), "crm:customer", "客户（改名）", List.of("SELF"));

        assertThat(count("SELECT COUNT(*) FROM sys_project_role_data_scope WHERE role_id = " + MANAGER_ROLE))
                .isEqualTo(1);
        // 配置还在，但已不在允许范围内，快照按仅本人处理。
        assertThat(departmentsOf(snapshot(MANAGER_USER), "crm:customer")).isEmpty();
    }

    /** 只统计超出收窄后允许范围的配置数。 */
    @Test
    void countsOnlyTheConfigurationsOutsideTheNarrowedAllowList() {
        scope(MANAGER_ROLE, "crm:customer", "DEPT_AND_CHILD", false);
        scope(FINANCE_ROLE, "crm:customer", "DEPT", false);
        scope(STAFF_ROLE, "crm:customer", "SELF", false);

        assertThat(service.configsOutside(String.valueOf(PROJECT), "crm:customer", List.of("ALL", "SELF")))
                .isEqualTo(2);
        assertThat(service.configsOutside(String.valueOf(PROJECT), "crm:customer", List.of("DEPT", "SELF")))
                .isEqualTo(1);
        assertThat(service.configsOutside(String.valueOf(PROJECT), "crm:followup", List.of("SELF")))
                .isZero();
    }

    /** Agent 能力注册只能看到项目已启用的受控资源。 */
    @Test
    void agentRegistrationSeesOnlyEnabledControlledResources() {
        assertThat(session.getMapper(com.kaiwu.module.agent.mapper.AgentCapabilityMapper.class)
                        .controlledResources(String.valueOf(PROJECT)))
                .containsExactlyInAnyOrder("crm:customer", "crm:followup");
        assertThat(session.getMapper(com.kaiwu.module.agent.mapper.AgentCapabilityMapper.class)
                        .controlledResources(String.valueOf(OTHER_PROJECT)))
                .isEmpty();
    }

    // ---- 辅助 ----

    /** 解析用户在测试项目内的数据范围快照。 */
    private DataScopeView snapshot(long userId) {
        return service.snapshot(String.valueOf(PROJECT), String.valueOf(userId)).orElseThrow();
    }

    /** 把某资源的部门字典下标还原成部门 ID。 */
    private static List<Long> departmentsOf(DataScopeView view, String resource) {
        List<Long> result = new ArrayList<>();
        for (int index : view.rules().get(resource).set()) {
            result.add(Long.parseLong(view.depts().get(index)));
        }
        return result;
    }

    /** 构造保存请求里的一项。 */
    private static Item item(String resource, String scope, boolean includeChild, long... depts) {
        List<String> ids = new ArrayList<>();
        for (long dept : depts) {
            ids.add(String.valueOf(dept));
        }
        return new Item(resource, scope, includeChild, ids);
    }

    /** 按给定配置保存经理角色的数据范围。 */
    private void save(long roleId, Item... items) {
        service.saveRoleScopes(
                String.valueOf(PROJECT),
                String.valueOf(roleId),
                new ProjectRoleDataScopeRequest(List.of(items)),
                null,
                null);
    }

    /** 断言给定配置作为经理角色的保存请求被判为无效。 */
    private void assertInvalid(Item... items) {
        assertThatThrownBy(() -> save(MANAGER_ROLE, items)).isInstanceOfSatisfying(ApiException.class, e -> {
            assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
            assertThat(e.getMessageKey()).isEqualTo("api.project.dataScopeInvalid");
        });
    }

    /** 插入测试项目。 */
    private void project(long id, String code) {
        exec(
                "INSERT INTO sys_project (id, project_code, project_name, status, built_in, created_by, package_name,"
                        + " default_branch, created_at, updated_at) VALUES (?, ?, ?, 'ACTIVE', 0, ?, 'com.kaiwu.ds',"
                        + " 'main', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                id,
                code,
                code,
                ADMIN_USER);
    }

    /** 插入测试部门。 */
    private void department(long id, Long parent, String code) {
        exec(
                "INSERT INTO sys_department (id, parent_id, dept_name, dept_code, sort_no, status, created_at, updated_at)"
                        + " VALUES (?, ?, ?, ?, 0, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                id,
                parent,
                code,
                code);
    }

    /** 给用户加入部门，可标为主部门。 */
    private void userDepartment(long user, long department, boolean primary) {
        exec(
                "INSERT INTO sys_user_department (user_id, department_id, primary_department, created_at)"
                        + " VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                user,
                department,
                primary ? 1 : 0);
    }

    /** 插入项目角色，并让被模拟的项目仓储能查到它。 */
    private void role(long id, String code, boolean builtIn, String status) {
        exec(
                "INSERT INTO sys_project_role (id, project_id, role_code, role_name, status, built_in, created_at,"
                        + " updated_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                id,
                PROJECT,
                code,
                code,
                status,
                builtIn ? 1 : 0);
        ProjectRoleView view = new ProjectRoleView(
                String.valueOf(id),
                String.valueOf(PROJECT),
                code,
                code,
                null,
                status,
                builtIn,
                Set.of(),
                LocalDateTime.now(),
                LocalDateTime.now());
        when(projectRepository.findRole(String.valueOf(PROJECT), String.valueOf(id)))
                .thenReturn(Optional.of(view));
        when(projectRepository.findRoleForUpdate(String.valueOf(PROJECT), String.valueOf(id)))
                .thenReturn(Optional.of(view));
    }

    /** 把用户加入项目并授予角色。 */
    private void member(long user, long roleId) {
        exec(
                "INSERT IGNORE INTO sys_project_member (project_id, user_id, status, created_at, updated_at)"
                        + " VALUES (?, ?, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                PROJECT,
                user);
        exec(
                "INSERT INTO sys_project_member_role (project_id, user_id, role_id, created_at)"
                        + " VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                PROJECT,
                user,
                roleId);
    }

    /** 登记受控资源。 */
    private void resource(long project, String code, String allowed, String status) {
        exec(
                "INSERT INTO sys_project_data_resource (id, project_id, resource_code, resource_name, allowed_scopes,"
                        + " status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
                BASE + 300 + Math.abs(code.hashCode() % 1000),
                project,
                code,
                code,
                allowed,
                status);
    }

    /** 给角色配置某资源上的范围，返回配置行 ID。 */
    private long scope(long roleId, String resource, String type, boolean includeChild) {
        long id = BASE + 400 + Math.abs((roleId + resource).hashCode() % 100_000);
        exec(
                "INSERT INTO sys_project_role_data_scope (id, project_id, role_id, resource_code, scope_type,"
                        + " include_child, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP,"
                        + " CURRENT_TIMESTAMP)",
                id,
                PROJECT,
                roleId,
                resource,
                type,
                includeChild ? 1 : 0);
        return id;
    }

    /** 给指定部门类型的配置勾选部门。 */
    private void customDepartment(long scopeId, long department) {
        exec(
                "INSERT INTO sys_project_role_data_scope_dept (scope_id, department_id) VALUES (?, ?)",
                scopeId,
                department);
    }

    /** 执行计数查询。 */
    private static long count(String sql) {
        try (Connection connection = MYSQL.createConnection("");
                var statement = connection.createStatement();
                var rows = statement.executeQuery(sql)) {
            rows.next();
            return rows.getLong(1);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    /** 用独立连接执行写入语句，失败时带上 SQL 抛出。 */
    private static void exec(String sql, Object... args) {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            for (int i = 0; i < args.length; i++) {
                statement.setObject(i + 1, args[i]);
            }
            statement.executeUpdate();
        } catch (Exception e) {
            throw new IllegalStateException(sql, e);
        }
    }

    /** 向上查找仓库的迁移目录。 */
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
