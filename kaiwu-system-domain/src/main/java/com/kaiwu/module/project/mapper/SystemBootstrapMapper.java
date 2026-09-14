package com.kaiwu.module.project.mapper;

import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/**
 * 内置 system 项目的自举 Mapper。
 *
 * <p>这里的每条语句都必须幂等：它们在**每次启动**时执行，既要能在全新空库上建立完整的
 * 平台菜单与权限，也不能覆盖运维在运行库里做过的调整。SQL 全部由
 * {@code SystemProjectBootstrap} 原样迁入，一个字都没改。</p>
 */
@Mapper
public interface SystemBootstrapMapper {

    @Insert(
            """
            INSERT INTO sys_project
                (id, project_code, project_name, description, status, built_in,
                 created_by, package_name, default_branch, created_at, updated_at)
            SELECT #{projectId}, 'system', 'Kaiwu System',
                   'Kaiwu 平台自身的内置项目，承载平台成员、角色、菜单与权限',
                   'ACTIVE', 1, admin.id, 'com.kaiwu', 'main',
                   CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM sys_user admin
            WHERE admin.username = 'admin'
              AND NOT EXISTS (
                  SELECT 1 FROM sys_project WHERE project_code = 'system'
              )
            LIMIT 1
            """)
    int insertSystemProject(@Param("projectId") long projectId);

    /** system 项目不可停用、不可归档（CLAUDE.md 工程约束第 10 条），每次启动强制归位。 */
    @Update(
            """
            UPDATE sys_project
            SET built_in = 1, status = 'ACTIVE', updated_at = CURRENT_TIMESTAMP
            WHERE project_code = 'system'
            """)
    int forceSystemProjectActive();

    @Insert(
            """
            INSERT INTO sys_project_role
                (id, project_id, role_code, role_name, description, status, built_in,
                 created_at, updated_at)
            SELECT #{roleId}, project.id, 'project-admin', '系统项目管理员',
                   '拥有 system 项目全部平台菜单与权限', 'ACTIVE', 1,
                   CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM sys_project project
            WHERE project.project_code = 'system'
              AND NOT EXISTS (
                  SELECT 1 FROM sys_project_role role
                  WHERE role.project_id = project.id
                    AND role.role_code = 'project-admin'
              )
            """)
    int insertSystemAdminRole(@Param("roleId") long roleId);

    @Insert(
            """
            INSERT INTO sys_project_member
                (project_id, user_id, status, created_at, updated_at)
            SELECT project.id, admin.id, 'ACTIVE',
                   CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM sys_project project
            JOIN sys_user admin ON admin.username = 'admin'
            WHERE project.project_code = 'system'
            ON DUPLICATE KEY UPDATE
                status = 'ACTIVE', updated_at = CURRENT_TIMESTAMP
            """)
    int upsertAdminMembership();

    @Insert(
            """
            INSERT IGNORE INTO sys_project_member_role
                (project_id, user_id, role_id, created_at)
            SELECT project.id, admin.id, role.id, CURRENT_TIMESTAMP
            FROM sys_project project
            JOIN sys_user admin ON admin.username = 'admin'
            JOIN sys_project_role role
              ON role.project_id = project.id
             AND role.role_code = 'project-admin'
            WHERE project.project_code = 'system'
            """)
    int grantAdminProjectRole();

    /**
     * 把 legacy {@code sys_menu} 迁入 {@code sys_project_menu}。
     *
     * <p>只在项目还没有任何菜单时执行一次，因此重启幂等。</p>
     *
     * <p>V36 已删除退役的平台角色/菜单种子；这里仍保留排除条件作为升级防线，避免历史异常库
     * 在自举时把退役权限重新导入 System 项目，同时也让静态 i18n 门禁能识别有效菜单集合。</p>
     */
    @Insert(
            """
            INSERT IGNORE INTO sys_project_menu
                (id, project_id, parent_id, menu_name, menu_type, route_path,
                 component_path, permission_code, sort_no, visible, status,
                 created_at, updated_at)
            SELECT #{offset} + menu.id,
                   project.id,
                   CASE WHEN menu.parent_id IS NULL
                        THEN NULL ELSE #{offset} + menu.parent_id END,
                   menu.menu_name, menu.menu_type, menu.route_path, menu.component_path,
                   menu.permission_code, menu.sort_no, menu.visible,
                   CASE WHEN menu.status = 'ENABLED' THEN 'ACTIVE' ELSE 'DISABLED' END,
                   menu.created_at, menu.updated_at
            FROM sys_menu menu
            JOIN sys_project project ON project.project_code = 'system'
            WHERE (menu.route_path IS NULL
                   OR menu.route_path NOT IN ('/roles', '/menus'))
              AND (menu.permission_code IS NULL
                   OR (menu.permission_code <> 'system:user:assign-role'
                       AND menu.permission_code NOT LIKE 'system:role:%'
                       AND menu.permission_code NOT LIKE 'system:menu:%'))
              AND NOT EXISTS (
                SELECT 1 FROM sys_project_menu existing
                WHERE existing.project_id = project.id
            )
            """)
    int importLegacyMenus(@Param("offset") long offset);

    @Insert(
            """
            INSERT IGNORE INTO sys_project_role_menu
                (project_id, role_id, menu_id, created_at)
            SELECT project.id, role.id, menu.id, CURRENT_TIMESTAMP
            FROM sys_project project
            JOIN sys_project_role role
              ON role.project_id = project.id
             AND role.role_code = 'project-admin'
            JOIN sys_project_menu menu ON menu.project_id = project.id
            WHERE project.project_code = 'system'
            """)
    int grantAllMenusToAdminRole();

    @Delete(
            """
            DELETE role_menu
            FROM sys_project_role_menu role_menu
            JOIN sys_project_menu menu
              ON menu.project_id = role_menu.project_id
             AND menu.id = role_menu.menu_id
            JOIN sys_project project
              ON project.id = menu.project_id
            WHERE project.project_code = #{projectCode}
              AND menu.route_path = #{routePath}
            """)
    int deleteRoleMenusByRoute(@Param("projectCode") String projectCode, @Param("routePath") String routePath);

    @Delete(
            """
            DELETE menu
            FROM sys_project_menu menu
            JOIN sys_project project
              ON project.id = menu.project_id
            WHERE project.project_code = #{projectCode}
              AND menu.route_path = #{routePath}
            """)
    int deleteMenuByRoute(@Param("projectCode") String projectCode, @Param("routePath") String routePath);

    /** 有路由的菜单：key 可从 route_path 推导，与 V11 回填和 check:i18n 用同一套约定。 */
    @Update(
            """
            UPDATE sys_project_menu menu
            JOIN sys_project project ON project.id = menu.project_id
            SET menu.menu_name_key = CONCAT('menu.system.',
                    CASE WHEN menu.route_path = '/' THEN 'home'
                         ELSE REPLACE(TRIM(LEADING '/' FROM menu.route_path), '/', '.')
                    END),
                menu.updated_at = CURRENT_TIMESTAMP
            WHERE project.project_code = #{projectCode}
              AND menu.menu_type = 'MENU'
              AND menu.route_path IS NOT NULL
              AND menu.menu_name_key IS NULL
            """)
    int assignRoutedMenuI18nKeys(@Param("projectCode") String projectCode);

    /** 只补空值：已有 key 可能被运维在资源页调整过，不能被启动逻辑覆盖。 */
    @Update(
            """
            UPDATE sys_project_menu
            SET menu_name_key = #{messageKey}, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{menuId} AND menu_name_key IS NULL
            """)
    int assignDirectoryI18nKey(@Param("menuId") long menuId, @Param("messageKey") String messageKey);

    /** BUTTON 没有 route_path，按稳定权限码生成唯一的内置菜单资源 key。 */
    @Update(
            """
            UPDATE sys_project_menu menu
            JOIN sys_project project ON project.id = menu.project_id
            SET menu.menu_name_key = CONCAT(
                    'menu.system.permission.', REPLACE(menu.permission_code, ':', '.')),
                menu.updated_at = CURRENT_TIMESTAMP
            WHERE project.project_code = #{projectCode}
              AND menu.menu_type = 'BUTTON'
              AND menu.permission_code IS NOT NULL
              AND menu.menu_name_key IS NULL
            """)
    int assignButtonMenuI18nKeys(@Param("projectCode") String projectCode);

    @Update(
            """
            UPDATE sys_project_menu factory
            JOIN sys_project project
              ON project.id = factory.project_id
            SET factory.parent_id = #{parentId},
                factory.updated_at = CURRENT_TIMESTAMP
            WHERE project.project_code = #{projectCode}
              AND factory.menu_type = 'MENU'
              AND factory.route_path = #{routePath}
            """)
    int moveMenuUnderParent(
            @Param("parentId") long parentId,
            @Param("projectCode") String projectCode,
            @Param("routePath") String routePath);

    @Update(
            """
            UPDATE sys_project_menu menu
            JOIN sys_project project
              ON project.id = menu.project_id
             AND project.project_code = 'system'
            SET menu.parent_id = CASE menu.route_path
                    -- 项目管理管的是业务项目本身，不是平台自身配置，保持 V1 基线里的
                    -- 顶层位置，仅参与下面的图标与排序初始化。
                    WHEN '/projects' THEN NULL
                    ELSE #{platformDirectoryId}
                END,
                menu.sort_no = CASE menu.route_path
                    -- 顶层顺序：工作台 10、项目管理 12、消息中心 15、平台管理 20。
                    WHEN '/projects' THEN 12
                    ELSE menu.sort_no
                END,
                menu.icon = CASE menu.route_path
                    WHEN '/users' THEN 'UserOutlined'
                    WHEN '/security' THEN 'SafetyCertificateOutlined'
                    WHEN '/organization' THEN 'ApartmentOutlined'
                    WHEN '/projects' THEN 'AppstoreOutlined'
                    WHEN '/configs' THEN 'SettingOutlined'
                    WHEN '/dictionaries' THEN 'BookOutlined'
                    ELSE menu.icon
                END
            WHERE menu.menu_type = 'MENU'
              AND menu.route_path IN (
                  '/users', '/security', '/organization',
                  '/projects', '/configs', '/dictionaries'
              )
            """)
    int groupFreshDatabaseMenus(@Param("platformDirectoryId") long platformDirectoryId);

    @Insert(
            """
            INSERT IGNORE INTO sys_project_role_menu
                (project_id, role_id, menu_id, created_at)
            SELECT project.id, role.id, menu.id, CURRENT_TIMESTAMP
            FROM sys_project project
            JOIN sys_project_role role
              ON role.project_id = project.id
             AND role.role_code = 'project-admin'
            JOIN sys_project_menu menu
              ON menu.project_id = project.id
             AND menu.id BETWEEN #{firstId} AND #{lastId}
            WHERE project.project_code = 'system'
            """)
    int grantSystemMenuRange(@Param("firstId") long firstId, @Param("lastId") long lastId);

    /**
     * 内置菜单的幂等 upsert。
     *
     * <p>**{@code parent_id} 与 {@code icon} 不在 {@code ON DUPLICATE KEY UPDATE} 列表里，
     * 这是硬约束**：管理员在界面上调整过的菜单层级和图标不能被一次升级重排回去。
     * 测试 {@code bootstrapPreservesExistingNavigationParentAssignments} 守着这一点，
     * 加进去会直接变红。</p>
     */
    @Insert(
            """
            INSERT INTO sys_project_menu
                (id, project_id, parent_id, menu_name, menu_type, route_path,
                 component_path, permission_code, icon, sort_no, visible, status,
                 created_at, updated_at)
            SELECT #{id}, project.id, #{parentId}, #{name}, #{type}, #{routePath},
                   #{componentPath}, #{permission}, #{icon}, #{sortNo}, 1, 'ACTIVE',
                   CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM sys_project project
            WHERE project.project_code = 'system'
            ON DUPLICATE KEY UPDATE
                menu_name = VALUES(menu_name),
                menu_type = VALUES(menu_type),
                route_path = VALUES(route_path),
                component_path = VALUES(component_path),
                permission_code = VALUES(permission_code),
                sort_no = VALUES(sort_no),
                visible = 1,
                status = 'ACTIVE',
                updated_at = CURRENT_TIMESTAMP
            """)
    int upsertSystemMenu(
            @Param("id") long id,
            @Param("parentId") Long parentId,
            @Param("name") String name,
            @Param("type") String type,
            @Param("routePath") String routePath,
            @Param("componentPath") String componentPath,
            @Param("permission") String permission,
            @Param("icon") String icon,
            @Param("sortNo") int sortNo);
}
