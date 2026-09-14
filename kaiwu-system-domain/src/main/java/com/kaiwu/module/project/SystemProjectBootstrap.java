package com.kaiwu.module.project;

import com.kaiwu.module.project.mapper.SystemBootstrapMapper;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

/**
 * 新库首次创建 admin 后，幂等建立不可停用的 system 自管理项目。
 */
@Component
@Order(20)
public class SystemProjectBootstrap implements ApplicationRunner {

    public static final String SYSTEM_PROJECT_CODE = "system";
    private static final long SYSTEM_PROJECT_ID = 9_000_000_000_000_000_001L;
    private static final long SYSTEM_ADMIN_ROLE_ID = 9_000_000_000_000_001_001L;
    private static final long SYSTEM_MENU_OFFSET = 9_000_000_000_000_010_000L;
    /** 项目管理菜单由 legacy sys_menu(400) 迁入，体检按钮挂在它下面。 */
    private static final long PROJECTS_MENU_ID = SYSTEM_MENU_OFFSET + 400L;

    private static final long PROJECT_HEALTH_MENU_ID = 9_000_000_000_000_011_400L;
    private static final long PROJECT_FACTORY_MENU_ID = 9_000_000_000_000_010_700L;
    private static final long AI_PROVIDER_MENU_ID = 9_000_000_000_000_010_800L;
    private static final long GITLAB_CONFIG_MENU_ID = 9_000_000_000_000_010_900L;
    private static final long SCHEDULER_MENU_ID = 9_000_000_000_000_011_000L;
    private static final long SECURITY_MENU_ID = 9_000_000_000_000_012_000L;
    private static final long ORGANIZATION_MENU_ID = 9_000_000_000_000_013_000L;
    private static final long PLATFORM_DIRECTORY_ID = 9_000_000_000_000_014_000L;
    private static final long DELIVERY_DIRECTORY_ID = 9_000_000_000_000_014_001L;
    private static final long DASHBOARD_MENU_ID = 9_000_000_000_000_014_002L;
    private static final long NOTIFICATIONS_MENU_ID = 9_000_000_000_000_014_003L;

    private final SystemBootstrapMapper mapper;

    public SystemProjectBootstrap(SystemBootstrapMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void run(ApplicationArguments args) {
        mapper.insertSystemProject(SYSTEM_PROJECT_ID);
        mapper.forceSystemProjectActive();
        mapper.insertSystemAdminRole(SYSTEM_ADMIN_ROLE_ID);
        mapper.upsertAdminMembership();
        mapper.grantAdminProjectRole();
        removeLegacyDeliveryCenter();
        int insertedBaseMenus = mapper.importLegacyMenus(SYSTEM_MENU_OFFSET);
        mapper.grantAllMenusToAdminRole();
        upsertNavigationStructure();
        upsertProjectFactoryMenus();
        upsertProjectHealthMenu();
        assignBuiltInMenuI18nKeys();
        groupProjectFactoryUnderDelivery();
        upsertAiProviderMenus();
        upsertGitlabConfigMenus();
        upsertSchedulerMenus();
        upsertSecurityMenus();
        upsertOrganizationMenus();
        if (insertedBaseMenus > 0) {
            groupFreshDatabaseMenus();
        }
    }

    private void removeLegacyDeliveryCenter() {
        mapper.deleteRoleMenusByRoute(SYSTEM_PROJECT_CODE, "/deliveries");
        mapper.deleteMenuByRoute(SYSTEM_PROJECT_CODE, "/deliveries");
    }

    /**
     * 给内置菜单补 menu_name_key（ADR 0013）。
     *
     * <p>指向 V11 已回填的 `menu.system.*` 资源，不新建资源——另造一套 key 会凭空产生
     * 两份同义资源，翻译工作量直接翻倍。</p>
     *
     * <p>与体检菜单同理：全新库执行 Flyway 时菜单还不存在，迁移里的赋值只对存量库生效，
     * 这里负责让全新安装也拿到 key。</p>
     */
    private void assignBuiltInMenuI18nKeys() {
        // 有路由的菜单：key 可从 route_path 推导，与 V11 回填和 check:i18n 用同一套约定。
        mapper.assignRoutedMenuI18nKeys(SYSTEM_PROJECT_CODE);
        // 目录没有路由，key 推导不出来，只有这里知道哪个 ID 是哪个目录。
        assignDirectoryI18nKey(PLATFORM_DIRECTORY_ID, "menu.system.directory.platform");
        assignDirectoryI18nKey(DELIVERY_DIRECTORY_ID, "menu.system.directory.delivery");
        // BUTTON 没有路由，但权限码是稳定的三段事实键，可在新库自举时确定性推导。
        mapper.assignButtonMenuI18nKeys(SYSTEM_PROJECT_CODE);
    }

    /** 只补空值：已有 key 可能被运维在资源页调整过，不能被启动逻辑覆盖。 */
    private void assignDirectoryI18nKey(long menuId, String messageKey) {
        mapper.assignDirectoryI18nKey(menuId, messageKey);
    }

    /**
     * 项目体检按钮（ADR 0012）。
     *
     * <p>必须在这里自举，不能只写增量 SQL：全新库执行 Flyway 时 sys_project 还是空的，
     * `INSERT ... SELECT FROM sys_project` 会插入 0 行，全新安装将没有这个菜单，
     * 管理员无法把体检权限授予任何角色。</p>
     */
    private void upsertProjectHealthMenu() {
        upsertSystemMenu(
                PROJECT_HEALTH_MENU_ID, PROJECTS_MENU_ID, "项目体检", "BUTTON", null, null, "system:project:health", 80);
        grantSystemMenuRange(PROJECT_HEALTH_MENU_ID, PROJECT_HEALTH_MENU_ID);
    }

    private void upsertProjectFactoryMenus() {
        upsertSystemMenu(
                PROJECT_FACTORY_MENU_ID,
                DELIVERY_DIRECTORY_ID,
                "项目工厂",
                "MENU",
                "/project-factory",
                "ProjectFactory",
                null,
                "CodeOutlined",
                30);
        upsertSystemMenu(
                PROJECT_FACTORY_MENU_ID + 1,
                PROJECT_FACTORY_MENU_ID,
                "查看项目生成",
                "BUTTON",
                null,
                null,
                "system:project-factory:list",
                10);
        upsertSystemMenu(
                PROJECT_FACTORY_MENU_ID + 2,
                PROJECT_FACTORY_MENU_ID,
                "生成项目",
                "BUTTON",
                null,
                null,
                "system:project-factory:generate",
                20);
        upsertSystemMenu(
                PROJECT_FACTORY_MENU_ID + 3,
                PROJECT_FACTORY_MENU_ID,
                "下载项目制品",
                "BUTTON",
                null,
                null,
                "system:project-factory:download",
                30);
        upsertSystemMenu(
                PROJECT_FACTORY_MENU_ID + 4,
                PROJECT_FACTORY_MENU_ID,
                "初始推送 GitLab",
                "BUTTON",
                null,
                null,
                "system:project-factory:push",
                40);
        grantSystemMenuRange(PROJECT_FACTORY_MENU_ID, PROJECT_FACTORY_MENU_ID + 4);
    }

    /**
     * 项目工厂属于研发交付主流程，历史基线迁入的顶层菜单必须收敛到该目录。
     *
     * <p>通用菜单 upsert 刻意保留管理员调整过的父级；这里只修复产品信息架构定义明确的
     * 项目工厂节点，避免启动时重排其他菜单。</p>
     */
    private void groupProjectFactoryUnderDelivery() {
        mapper.moveMenuUnderParent(DELIVERY_DIRECTORY_ID, SYSTEM_PROJECT_CODE, "/project-factory");
    }

    private void upsertAiProviderMenus() {
        upsertSystemMenu(
                AI_PROVIDER_MENU_ID,
                DELIVERY_DIRECTORY_ID,
                "大模型配置",
                "MENU",
                "/ai-provider",
                "AiProvider",
                null,
                "ApiOutlined",
                10);
        upsertSystemMenu(
                AI_PROVIDER_MENU_ID + 1, AI_PROVIDER_MENU_ID, "查看大模型配置", "BUTTON", null, null, "system:ai:list", 10);
        upsertSystemMenu(
                AI_PROVIDER_MENU_ID + 2, AI_PROVIDER_MENU_ID, "保存大模型配置", "BUTTON", null, null, "system:ai:save", 20);
        upsertSystemMenu(
                AI_PROVIDER_MENU_ID + 3, AI_PROVIDER_MENU_ID, "测试大模型连接", "BUTTON", null, null, "system:ai:test", 30);
        grantSystemMenuRange(AI_PROVIDER_MENU_ID, AI_PROVIDER_MENU_ID + 3);
    }

    private void upsertGitlabConfigMenus() {
        upsertSystemMenu(
                GITLAB_CONFIG_MENU_ID,
                DELIVERY_DIRECTORY_ID,
                "GitLab 配置",
                "MENU",
                "/gitlab-config",
                "GitlabConfig",
                null,
                "GitlabOutlined",
                20);
        upsertSystemMenu(
                GITLAB_CONFIG_MENU_ID + 1,
                GITLAB_CONFIG_MENU_ID,
                "查看 GitLab 配置",
                "BUTTON",
                null,
                null,
                "system:git:list",
                10);
        upsertSystemMenu(
                GITLAB_CONFIG_MENU_ID + 2,
                GITLAB_CONFIG_MENU_ID,
                "保存 GitLab 配置",
                "BUTTON",
                null,
                null,
                "system:git:save",
                20);
        upsertSystemMenu(
                GITLAB_CONFIG_MENU_ID + 3,
                GITLAB_CONFIG_MENU_ID,
                "测试 GitLab 连接",
                "BUTTON",
                null,
                null,
                "system:git:test",
                30);
        grantSystemMenuRange(GITLAB_CONFIG_MENU_ID, GITLAB_CONFIG_MENU_ID + 3);
    }

    private void upsertSchedulerMenus() {
        upsertSystemMenu(
                SCHEDULER_MENU_ID,
                PLATFORM_DIRECTORY_ID,
                "定时任务",
                "MENU",
                "/scheduler",
                "Scheduler",
                null,
                "FieldTimeOutlined",
                70);
        upsertSystemMenu(
                SCHEDULER_MENU_ID + 1, SCHEDULER_MENU_ID, "查看定时任务", "BUTTON", null, null, "system:scheduler:list", 10);
        upsertSystemMenu(
                SCHEDULER_MENU_ID + 2, SCHEDULER_MENU_ID, "保存定时任务", "BUTTON", null, null, "system:scheduler:save", 20);
        upsertSystemMenu(
                SCHEDULER_MENU_ID + 3,
                SCHEDULER_MENU_ID,
                "轮换项目调度凭据",
                "BUTTON",
                null,
                null,
                "system:scheduler:credential",
                30);
        grantSystemMenuRange(SCHEDULER_MENU_ID, SCHEDULER_MENU_ID + 3);
    }

    private void upsertNavigationStructure() {
        upsertSystemMenu(PLATFORM_DIRECTORY_ID, null, "平台管理", "DIRECTORY", null, null, null, "SettingOutlined", 20);
        upsertSystemMenu(DELIVERY_DIRECTORY_ID, null, "研发交付", "DIRECTORY", null, null, null, "RocketOutlined", 60);
        upsertSystemMenu(DASHBOARD_MENU_ID, null, "工作台", "MENU", "/", "Home", null, "DashboardOutlined", 10);
        upsertSystemMenu(
                NOTIFICATIONS_MENU_ID,
                null,
                "消息中心",
                "MENU",
                "/notifications",
                "Notifications",
                null,
                "BellOutlined",
                15);
        grantSystemMenuRange(PLATFORM_DIRECTORY_ID, NOTIFICATIONS_MENU_ID);
    }

    private void groupFreshDatabaseMenus() {
        mapper.groupFreshDatabaseMenus(PLATFORM_DIRECTORY_ID);
    }

    private void grantSystemMenuRange(long firstId, long lastId) {
        mapper.grantSystemMenuRange(firstId, lastId);
    }

    /**
     * 安全运营：审计日志与在线会话。
     *
     * <p>这些按钮此前只有 Controller 注解、没有任何 seed，全新库里管理员在「项目菜单」
     * 里看不到它们，也就无法授权给任何角色——功能等于不可用。开发库看起来正常只是因为
     * 手工建过菜单。</p>
     */
    private void upsertSecurityMenus() {
        upsertSystemMenu(
                SECURITY_MENU_ID,
                PLATFORM_DIRECTORY_ID,
                "安全运营",
                "MENU",
                "/security",
                "Security",
                null,
                "SafetyCertificateOutlined",
                20);
        upsertSystemMenu(
                SECURITY_MENU_ID + 1, SECURITY_MENU_ID, "查看审计日志", "BUTTON", null, null, "system:audit:list", 10);
        upsertSystemMenu(
                SECURITY_MENU_ID + 2, SECURITY_MENU_ID, "查看在线会话", "BUTTON", null, null, "system:session:list", 20);
        upsertSystemMenu(
                SECURITY_MENU_ID + 3,
                SECURITY_MENU_ID,
                "强制用户下线",
                "BUTTON",
                null,
                null,
                "system:session:force-offline",
                30);
        grantSystemMenuRange(SECURITY_MENU_ID, SECURITY_MENU_ID + 3);
    }

    /** 组织架构：部门维护与用户任职，缺 seed 的原因同 {@link #upsertSecurityMenus()}。 */
    private void upsertOrganizationMenus() {
        upsertSystemMenu(
                ORGANIZATION_MENU_ID,
                PLATFORM_DIRECTORY_ID,
                "组织架构",
                "MENU",
                "/organization",
                "Organization",
                null,
                "ApartmentOutlined",
                30);
        upsertSystemMenu(
                ORGANIZATION_MENU_ID + 1, ORGANIZATION_MENU_ID, "查看组织架构", "BUTTON", null, null, "system:org:list", 10);
        upsertSystemMenu(
                ORGANIZATION_MENU_ID + 2, ORGANIZATION_MENU_ID, "维护部门", "BUTTON", null, null, "system:org:save", 20);
        upsertSystemMenu(
                ORGANIZATION_MENU_ID + 3, ORGANIZATION_MENU_ID, "删除部门", "BUTTON", null, null, "system:org:delete", 30);
        upsertSystemMenu(
                ORGANIZATION_MENU_ID + 4,
                ORGANIZATION_MENU_ID,
                "分配用户部门",
                "BUTTON",
                null,
                null,
                "system:org:assign",
                40);
        grantSystemMenuRange(ORGANIZATION_MENU_ID, ORGANIZATION_MENU_ID + 4);
    }

    private void upsertSystemMenu(
            long id,
            Long parentId,
            String name,
            String type,
            String routePath,
            String componentPath,
            String permission,
            int sortNo) {
        upsertSystemMenu(id, parentId, name, type, routePath, componentPath, permission, null, sortNo);
    }

    private void upsertSystemMenu(
            long id,
            Long parentId,
            String name,
            String type,
            String routePath,
            String componentPath,
            String permission,
            String icon,
            int sortNo) {
        mapper.upsertSystemMenu(id, parentId, name, type, routePath, componentPath, permission, icon, sortNo);
    }
}
