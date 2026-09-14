package com.kaiwu.module.project;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.module.project.mapper.SystemBootstrapMapper;
import java.lang.reflect.Method;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Update;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * 自举逻辑的行为约束。
 *
 * <p>数据层迁移到 MyBatis-Plus 后，SQL 从字符串变成了 Mapper 上的注解，因此断言分两类：
 * 「调用了哪个语义」用 Mockito 验证方法调用，「SQL 本身长什么样」直接反射读注解——
 * 后者比迁移前捕获 JdbcTemplate 参数更直接，读到的就是真正会执行的语句。</p>
 */
class SystemProjectBootstrapTest {

    private static String sqlOf(String methodName, Class<?>... parameterTypes) throws Exception {
        Method method = SystemBootstrapMapper.class.getMethod(methodName, parameterTypes);
        Insert insert = method.getAnnotation(Insert.class);
        if (insert != null) {
            return String.join("\n", insert.value());
        }
        return String.join("\n", method.getAnnotation(Update.class).value());
    }

    @Test
    void bootstrapPreservesExistingNavigationParentAssignments() throws Exception {
        // 管理员调整过的菜单层级与图标不能被启动逻辑重排回去，
        // 因此 parent_id / icon 不得出现在 ON DUPLICATE KEY UPDATE 列表里。
        String upsert = sqlOf(
                "upsertSystemMenu",
                long.class,
                Long.class,
                String.class,
                String.class,
                String.class,
                String.class,
                String.class,
                String.class,
                int.class);

        assertThat(upsert).contains("ON DUPLICATE KEY UPDATE");
        assertThat(upsert).doesNotContain("parent_id = VALUES(parent_id)");
        assertThat(upsert).doesNotContain("icon = VALUES(icon)");
    }

    @Test
    void bootstrapSeedsCompleteNavigationForFreshDatabase() throws Exception {
        SystemBootstrapMapper mapper = mock(SystemBootstrapMapper.class);

        new SystemProjectBootstrap(mapper).run(null);

        ArgumentCaptor<String> names = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> routes = ArgumentCaptor.forClass(String.class);
        verify(mapper, atLeast(1))
                .upsertSystemMenu(
                        anyLong(),
                        any(),
                        names.capture(),
                        anyString(),
                        routes.capture(),
                        any(),
                        any(),
                        any(),
                        anyInt());

        assertThat(names.getAllValues())
                .contains("平台管理", "研发交付", "工作台", "消息中心", "项目工厂")
                .doesNotContain("交付中心");
        assertThat(routes.getAllValues()).contains("/", "/notifications", "/project-factory");
    }

    @Test
    void bootstrapRemovesLegacyDeliveryCenterFromExistingDatabase() throws Exception {
        SystemBootstrapMapper mapper = mock(SystemBootstrapMapper.class);

        new SystemProjectBootstrap(mapper).run(null);

        verify(mapper).deleteRoleMenusByRoute("system", "/deliveries");
        verify(mapper).deleteMenuByRoute("system", "/deliveries");
    }

    @Test
    void bootstrapGroupsProjectFactoryUnderDelivery() throws Exception {
        SystemBootstrapMapper mapper = mock(SystemBootstrapMapper.class);

        new SystemProjectBootstrap(mapper).run(null);

        verify(mapper).moveMenuUnderParent(9_000_000_000_000_014_001L, "system", "/project-factory");
    }

    @Test
    void bootstrapKeepsProjectManagementAtTopLevelForFreshDatabase() throws Exception {
        SystemBootstrapMapper mapper = mock(SystemBootstrapMapper.class);
        // 新库会从 legacy sys_menu 首次迁入菜单，只有这个分支才执行初始分组。
        when(mapper.importLegacyMenus(anyLong())).thenReturn(1);

        new SystemProjectBootstrap(mapper).run(null);

        verify(mapper).groupFreshDatabaseMenus(9_000_000_000_000_014_000L);
        String grouping = sqlOf("groupFreshDatabaseMenus", long.class);
        assertThat(grouping)
                .contains("WHEN '/projects' THEN NULL")
                .contains("WHEN '/projects' THEN 12")
                .contains("WHEN '/projects' THEN 'AppstoreOutlined'");
    }
}
