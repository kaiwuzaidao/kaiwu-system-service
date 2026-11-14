package com.kaiwu.module.project.lifecycle;

import com.kaiwu.module.project.mapper.SystemBootstrapMapper;
import java.util.List;
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

    private static final List<String> RETIRED_PERMISSION_CODES = List.of(
            "system:project:health",
            "system:project-factory:push",
            "system:git:list",
            "system:git:save",
            "system:git:test");
    private static final String RETIRED_GITLAB_CONFIG_ROUTE = "/gitlab-config";
    private static final long PROJECT_FACTORY_MENU_ID = 9_000_000_000_000_010_700L;
    private static final long AI_PROVIDER_MENU_ID = 9_000_000_000_000_010_800L;
    private static final long SCHEDULER_MENU_ID = 9_000_000_000_000_011_000L;
    private static final long SECURITY_MENU_ID = 9_000_000_000_000_012_000L;
    private static final long ORGANIZATION_MENU_ID = 9_000_000_000_000_013_000L;
    private static final long I18N_MENU_ID = 9_000_000_000_000_015_000L;
    private static final long PLATFORM_DIRECTORY_ID = 9_000_000_000_000_014_000L;
    private static final long DELIVERY_DIRECTORY_ID = 9_000_000_000_000_014_001L;
    private static final long DASHBOARD_MENU_ID = 9_000_000_000_000_014_002L;
    private static final long NOTIFICATIONS_MENU_ID = 9_000_000_000_000_014_003L;
    private static final long AGENT_MENU_ID = 9_000_000_000_000_014_004L;
    private static final long STORAGE_MENU_ID = 9_000_000_000_000_016_000L;

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
        // 先于 i18n key 回填：新菜单在同一次启动里就能拿到 menu.system.* 资源。
        upsertStorageMenus();
        upsertServiceCredentialMenus();
        removeRetiredMenus();
        assignBuiltInMenuI18nKeys();
        groupProjectFactoryUnderDelivery();
        upsertAiProviderMenus();
        upsertAgentMenus();
        upsertSchedulerMenus();
        upsertSecurityMenus();
        upsertOrganizationMenus();
        upsertI18nMenus();
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
     * 清理已下线功能的菜单与授权（ADR 0038）。
     *
     * <p>启动时幂等执行：存量库里这些按钮还在，不删的话角色里会留着指向不存在接口的权限；
     * 全新库由旧迁移种下后，同样在这里被清掉。表本身保留，物理清理见 ADR 0038 阶段 4。</p>
     */
    private void removeRetiredMenus() {
        for (String permissionCode : RETIRED_PERMISSION_CODES) {
            mapper.deleteRoleMenusByPermission(SYSTEM_PROJECT_CODE, permissionCode);
            mapper.deleteMenusByPermission(SYSTEM_PROJECT_CODE, permissionCode);
        }
        mapper.deleteRoleMenusByRoute(SYSTEM_PROJECT_CODE, RETIRED_GITLAB_CONFIG_ROUTE);
        mapper.deleteMenuByRoute(SYSTEM_PROJECT_CODE, RETIRED_GITLAB_CONFIG_ROUTE);
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
        grantSystemMenuRange(PROJECT_FACTORY_MENU_ID, PROJECT_FACTORY_MENU_ID + 3);
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

    /**
     * 对象存储（ADR 0039）：存储账号与项目绑定，挂在「平台管理」目录下。
     */
    private void upsertStorageMenus() {
        upsertSystemMenu(
                STORAGE_MENU_ID,
                PLATFORM_DIRECTORY_ID,
                "对象存储",
                "MENU",
                "/storage",
                "Storage",
                null,
                "CloudServerOutlined",
                75);
        upsertSystemMenu(
                STORAGE_MENU_ID + 1, STORAGE_MENU_ID, "查看对象存储", "BUTTON", null, null, "system:storage:list", 10);
        upsertSystemMenu(
                STORAGE_MENU_ID + 2, STORAGE_MENU_ID, "保存对象存储", "BUTTON", null, null, "system:storage:save", 20);
        upsertSystemMenu(
                STORAGE_MENU_ID + 3, STORAGE_MENU_ID, "测试对象存储连接", "BUTTON", null, null, "system:storage:test", 30);
        grantSystemMenuRange(STORAGE_MENU_ID, STORAGE_MENU_ID + 3);
    }

    /**
     * AI 助手是一个全局对话窗，不占导航位置。
     *
     * <p>这条 BUTTON 菜单的作用是承载 {@code system:agent:ask} 权限码，让管理员可以授权，
     * 而不是在侧边栏加一项。</p>
     */
    private void upsertAgentMenus() {
        upsertSystemMenu(AGENT_MENU_ID, null, "AI 助手", "BUTTON", null, null, "system:agent:ask", 90);
        grantSystemMenuRange(AGENT_MENU_ID, AGENT_MENU_ID);
    }

    /** 确保全新安装与升级环境均具备服务凭据平台权限，只授予系统项目管理员。 */
    private void upsertServiceCredentialMenus() {
        long firstId = 9_200_000_000_000_008_500L;
        upsertSystemMenu(
                firstId, PROJECTS_MENU_ID, "查看服务凭据", "BUTTON", null, null, "system:service-credential:list", 110);
        upsertSystemMenu(
                firstId + 1, PROJECTS_MENU_ID, "管理服务凭据", "BUTTON", null, null, "system:service-credential:manage", 120);
        grantSystemMenuRange(firstId, firstId + 1);
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

    /**
     * 国际化资源：管理页与 list/save/delete 权限，缺 seed 的原因同 {@link #upsertSecurityMenus()}。
     *
     * <p>V10 只能在 system 项目已存在的存量库生效；全新库没有这个菜单，admin 既看不到入口，
     * 字典/配置/菜单表单里的「引用国际化资源」读取目录也会 403。</p>
     */
    private void upsertI18nMenus() {
        upsertSystemMenu(
                I18N_MENU_ID,
                PLATFORM_DIRECTORY_ID,
                "国际化资源",
                "MENU",
                "/i18n-resources",
                "I18nResources",
                null,
                "TranslationOutlined",
                80);
        upsertSystemMenu(I18N_MENU_ID + 1, I18N_MENU_ID, "查询国际化资源", "BUTTON", null, null, "system:i18n:list", 10);
        upsertSystemMenu(I18N_MENU_ID + 2, I18N_MENU_ID, "保存国际化资源", "BUTTON", null, null, "system:i18n:save", 20);
        upsertSystemMenu(I18N_MENU_ID + 3, I18N_MENU_ID, "删除国际化资源", "BUTTON", null, null, "system:i18n:delete", 30);
        grantSystemMenuRange(I18N_MENU_ID, I18N_MENU_ID + 3);
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
