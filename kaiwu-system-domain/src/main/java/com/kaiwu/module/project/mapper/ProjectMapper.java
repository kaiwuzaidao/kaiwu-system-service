package com.kaiwu.module.project.mapper;

import com.kaiwu.module.project.entity.ProjectMemberJoinRow;
import com.kaiwu.module.project.entity.ProjectMenuRow;
import com.kaiwu.module.project.entity.ProjectRoleRow;
import com.kaiwu.module.project.entity.ProjectRow;
import java.util.List;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 项目、成员、角色与菜单 Mapper。
 *
 * <p>这是平台权限事实的核心：{@code sys_project_*} 六张表决定谁在哪个项目里有哪些菜单和
 * 权限码（CLAUDE.md 工程约束第 10 条）。**下面三条授权查询的 SQL 一个字都没改。**</p>
 *
 * <p>四张关联表（member / member_role / role_menu）都是复合主键，不套 {@code BaseMapper}。
 * 其余单表读写目前也留在本类的注解 SQL 里——这是迁移时为了整体平移做的取舍，不是必需，
 * 后续可逐步收敛到条件构造器（批量归属校验已经先走了这条路，见
 * {@code ProjectRoleMapper} / {@code ProjectMenuMapper}）。</p>
 *
 * <p>不使用 MyBatis 的 {@code <script>} 动态标签：可选筛选一律写成
 * {@code (#{x} IS NULL OR col = #{x})} 的静态 SQL，批量 {@code IN} 交给条件构造器。
 * 标签是塞进 Java 字符串里的 XML，IDE 不高亮也不校验，写错只有运行时才炸。</p>
 */
@Mapper
public interface ProjectMapper {

    @Select(
            """
            SELECT COUNT(*) FROM sys_project
            WHERE (#{keyword} IS NULL
                   OR project_code LIKE #{keyword} OR project_name LIKE #{keyword})
            """)
    Long countProjects(@Param("keyword") String keyword);

    @Select(
            """
            SELECT id, project_code, project_name, description, status, built_in,
                   created_by, package_name, repository_url, gitlab_project_id,
                   default_branch, backend_url, backend_label, service_url,
                   created_at, updated_at
            FROM sys_project
            WHERE (#{keyword} IS NULL
                   OR project_code LIKE #{keyword} OR project_name LIKE #{keyword})
            ORDER BY built_in DESC, created_at DESC, id DESC
            LIMIT #{size} OFFSET #{offset}
            """)
    List<ProjectRow> pageProjects(
            @Param("keyword") String keyword, @Param("size") long size, @Param("offset") long offset);

    @Select(
            """
            SELECT p.id, p.project_code, p.project_name, p.description, p.status,
                   p.built_in, p.created_by, p.package_name, p.repository_url,
                   p.gitlab_project_id, p.default_branch, p.backend_url,
                   p.backend_label, p.service_url, p.created_at, p.updated_at
            FROM sys_project p
            JOIN sys_project_member m ON m.project_id = p.id
            WHERE m.user_id = #{userId} AND m.status = 'ACTIVE' AND p.status = 'ACTIVE'
            ORDER BY p.project_name, p.id
            """)
    List<ProjectRow> findCurrentProjects(@Param("userId") String userId);

    @Select(
            """
            SELECT id, project_code, project_name, description, status, built_in,
                   created_by, package_name, repository_url, gitlab_project_id,
                   default_branch, backend_url, backend_label, service_url,
                   created_at, updated_at
            FROM sys_project WHERE id = #{projectId}
            """)
    ProjectRow findProject(@Param("projectId") String projectId);

    @Select("SELECT COUNT(*) FROM sys_project WHERE project_code = #{code}")
    int countProjectCode(@Param("code") String code);

    @Select(
            """
            SELECT COUNT(*)
            FROM sys_dict_type type
            JOIN sys_dict_item item ON item.dict_type_id = type.id
            WHERE type.scope_id = 0 AND type.dict_code = 'platform.locale'
              AND type.status = 'ENABLED' AND item.status = 'ENABLED'
              AND item.item_value = #{locale}
            """)
    int countEnabledLocale(@Param("locale") String locale);

    @Insert(
            """
            INSERT INTO sys_project
                (id, project_code, project_name, description, status, created_by,
                 built_in, package_name, default_branch, created_at, updated_at)
            VALUES (#{id}, #{code}, #{name}, #{description}, 'ACTIVE', #{createdBy}, 0,
                    #{packageName}, 'main', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int createProject(
            @Param("id") String id,
            @Param("code") String code,
            @Param("name") String name,
            @Param("description") String description,
            @Param("createdBy") String createdBy,
            @Param("packageName") String packageName);

    @Update(
            """
            UPDATE sys_project
            SET project_name = #{name}, description = #{description},
                package_name = #{packageName}, repository_url = #{repositoryUrl},
                gitlab_project_id = #{gitlabProjectId}, default_branch = #{defaultBranch},
                backend_url = #{backendUrl}, backend_label = #{backendLabel},
                service_url = #{serviceUrl},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updateProject(
            @Param("id") String id,
            @Param("name") String name,
            @Param("description") String description,
            @Param("packageName") String packageName,
            @Param("repositoryUrl") String repositoryUrl,
            @Param("gitlabProjectId") String gitlabProjectId,
            @Param("defaultBranch") String defaultBranch,
            @Param("backendUrl") String backendUrl,
            @Param("backendLabel") String backendLabel,
            @Param("serviceUrl") String serviceUrl);

    @Update("UPDATE sys_project SET status = #{status}, updated_at = CURRENT_TIMESTAMP WHERE id = #{id}")
    int updateProjectStatus(@Param("id") String id, @Param("status") String status);

    @Select(
            """
            SELECT m.project_id, m.user_id, u.username, u.display_name, m.status,
                   m.created_at, m.updated_at
            FROM sys_project_member m
            JOIN sys_user u ON u.id = m.user_id
            WHERE m.project_id = #{projectId}
            ORDER BY m.created_at, m.user_id
            """)
    List<ProjectMemberJoinRow> findMembers(@Param("projectId") String projectId);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_member
            WHERE project_id = #{projectId} AND user_id = #{userId}
            """)
    int countMember(@Param("projectId") String projectId, @Param("userId") String userId);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_member
            WHERE project_id = #{projectId} AND user_id = #{userId} AND status = 'ACTIVE'
            """)
    int countActiveMember(@Param("projectId") String projectId, @Param("userId") String userId);

    @Select("SELECT locale FROM sys_user WHERE id = #{userId}")
    String findUserLocale(@Param("userId") String userId);

    @Select("SELECT COUNT(*) FROM sys_user WHERE id = #{userId}")
    int countUser(@Param("userId") String userId);

    @Insert(
            """
            INSERT INTO sys_project_member
                (project_id, user_id, status, created_at, updated_at)
            VALUES (#{projectId}, #{userId}, #{status}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE status = VALUES(status), updated_at = CURRENT_TIMESTAMP
            """)
    int upsertMember(
            @Param("projectId") String projectId, @Param("userId") String userId, @Param("status") String status);

    @Select(
            """
            SELECT role_id FROM sys_project_member_role
            WHERE project_id = #{projectId} AND user_id = #{userId} ORDER BY role_id
            """)
    List<String> findMemberRoleIds(@Param("projectId") String projectId, @Param("userId") String userId);

    @Delete(
            """
            DELETE FROM sys_project_member_role
            WHERE project_id = #{projectId} AND user_id = #{userId}
            """)
    int deleteMemberRoles(@Param("projectId") String projectId, @Param("userId") String userId);

    @Insert(
            """
            INSERT INTO sys_project_member_role (project_id, user_id, role_id, created_at)
            VALUES (#{projectId}, #{userId}, #{roleId}, CURRENT_TIMESTAMP)
            """)
    int insertMemberRole(
            @Param("projectId") String projectId, @Param("userId") String userId, @Param("roleId") String roleId);

    @Delete(
            """
            DELETE FROM sys_project_member
            WHERE project_id = #{projectId} AND user_id = #{userId}
            """)
    int deleteMember(@Param("projectId") String projectId, @Param("userId") String userId);

    @Select(
            """
            SELECT id, project_id, role_code, role_name, description, status,
                   built_in, created_at, updated_at
            FROM sys_project_role
            WHERE project_id = #{projectId} ORDER BY built_in DESC, created_at, id
            """)
    List<ProjectRoleRow> findRoles(@Param("projectId") String projectId);

    @Select(
            """
            SELECT id, project_id, role_code, role_name, description, status,
                   built_in, created_at, updated_at
            FROM sys_project_role
            WHERE project_id = #{projectId} AND id = #{roleId}
            """)
    ProjectRoleRow findRole(@Param("projectId") String projectId, @Param("roleId") String roleId);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_role
            WHERE project_id = #{projectId} AND role_code = #{code}
            """)
    int countRoleCode(@Param("projectId") String projectId, @Param("code") String code);

    @Insert(
            """
            INSERT INTO sys_project_role
                (id, project_id, role_code, role_name, description, status, built_in,
                 created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{code}, #{name}, #{description}, 'ACTIVE',
                    #{builtIn}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int createRole(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("code") String code,
            @Param("name") String name,
            @Param("description") String description,
            @Param("builtIn") boolean builtIn);

    @Update(
            """
            UPDATE sys_project_role
            SET role_name = #{name}, description = #{description},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updateRole(@Param("id") String id, @Param("name") String name, @Param("description") String description);

    @Update("UPDATE sys_project_role SET status = #{status}, updated_at = CURRENT_TIMESTAMP WHERE id = #{id}")
    int updateRoleStatus(@Param("id") String id, @Param("status") String status);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_member_role
            WHERE project_id = #{projectId} AND role_id = #{roleId}
            """)
    int countRoleAssignments(@Param("projectId") String projectId, @Param("roleId") String roleId);

    @Delete(
            """
            DELETE FROM sys_project_role_menu
            WHERE project_id = #{projectId} AND role_id = #{roleId}
            """)
    int deleteRoleMenus(@Param("projectId") String projectId, @Param("roleId") String roleId);

    @Delete("DELETE FROM sys_project_role WHERE id = #{roleId}")
    int deleteRole(@Param("roleId") String roleId);

    @Select(
            """
            SELECT menu_id FROM sys_project_role_menu
            WHERE project_id = #{projectId} AND role_id = #{roleId} ORDER BY menu_id
            """)
    List<String> findRoleMenuIds(@Param("projectId") String projectId, @Param("roleId") String roleId);

    @Insert(
            """
            INSERT INTO sys_project_role_menu (project_id, role_id, menu_id, created_at)
            VALUES (#{projectId}, #{roleId}, #{menuId}, CURRENT_TIMESTAMP)
            """)
    int insertRoleMenu(
            @Param("projectId") String projectId, @Param("roleId") String roleId, @Param("menuId") String menuId);

    @Select(
            """
            SELECT id FROM sys_project_role
            WHERE project_id = #{projectId} AND role_code = 'project-admin'
            """)
    List<String> findProjectAdminRoleIds(@Param("projectId") String projectId);

    @Select(
            """
            SELECT id, project_id, parent_id, menu_name, menu_name_key, menu_type,
                   route_path, component_path, permission_code, icon, sort_no,
                   visible, status, created_at, updated_at
            FROM sys_project_menu
            WHERE project_id = #{projectId} ORDER BY sort_no, id
            """)
    List<ProjectMenuRow> findMenus(@Param("projectId") String projectId);

    @Select(
            """
            SELECT id, project_id, parent_id, menu_name, menu_name_key, menu_type,
                   route_path, component_path, permission_code, icon, sort_no,
                   visible, status, created_at, updated_at
            FROM sys_project_menu
            WHERE project_id = #{projectId} AND id = #{menuId}
            """)
    ProjectMenuRow findMenu(@Param("projectId") String projectId, @Param("menuId") String menuId);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_menu
            WHERE project_id = #{projectId} AND permission_code = #{permissionCode}
              AND (#{excludedId} IS NULL OR id <> #{excludedId})
            """)
    int countMenuPermissionUsage(
            @Param("projectId") String projectId,
            @Param("permissionCode") String permissionCode,
            @Param("excludedId") String excludedId);

    @Select(
            """
            SELECT COUNT(*) FROM sys_project_menu
            WHERE project_id = #{projectId} AND parent_id = #{menuId}
            """)
    int countMenuChildren(@Param("projectId") String projectId, @Param("menuId") String menuId);

    @Insert(
            """
            INSERT INTO sys_project_menu
                (id, project_id, parent_id, menu_name, menu_name_key,
                 menu_type, route_path,
                 component_path, permission_code, icon, sort_no, visible, status,
                 created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{parentId}, #{menuName}, #{menuNameKey},
                    #{menuType}, #{routePath}, #{componentPath}, #{permissionCode},
                    #{icon}, #{sortNo}, #{visible}, 'ACTIVE',
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int createMenu(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("parentId") String parentId,
            @Param("menuName") String menuName,
            @Param("menuNameKey") String menuNameKey,
            @Param("menuType") String menuType,
            @Param("routePath") String routePath,
            @Param("componentPath") String componentPath,
            @Param("permissionCode") String permissionCode,
            @Param("icon") String icon,
            @Param("sortNo") int sortNo,
            @Param("visible") boolean visible);

    /**
     * 将确定性代码生成产出的菜单登记到目标项目。
     *
     * <p>同一项目重复生成时更新原节点；{@code icon} 与 {@code menu_name_key} 不在更新列表里，
     * 是有意的——它们是管理员的人工设置，不该被一次重新生成冲掉。</p>
     */
    @Update(
            """
            INSERT INTO sys_project_menu
                (id, project_id, parent_id, menu_name, menu_type, route_path,
                 component_path, permission_code, sort_no, visible, status,
                 created_at, updated_at)
            VALUES (#{id}, #{projectId}, #{parentId}, #{menuName}, #{menuType}, #{routePath},
                    #{componentPath}, #{permissionCode}, #{sortNo}, 1, 'ACTIVE',
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE
                parent_id = VALUES(parent_id),
                menu_name = VALUES(menu_name),
                menu_type = VALUES(menu_type),
                route_path = VALUES(route_path),
                component_path = VALUES(component_path),
                sort_no = VALUES(sort_no),
                visible = 1,
                status = 'ACTIVE',
                updated_at = CURRENT_TIMESTAMP
            """)
    int upsertGeneratedMenu(
            @Param("id") String id,
            @Param("projectId") String projectId,
            @Param("parentId") String parentId,
            @Param("menuName") String menuName,
            @Param("menuType") String menuType,
            @Param("routePath") String routePath,
            @Param("componentPath") String componentPath,
            @Param("permissionCode") String permissionCode,
            @Param("sortNo") int sortNo);

    @Select(
            """
            SELECT id FROM sys_project_menu
            WHERE project_id = #{projectId} AND permission_code = #{permissionCode}
            """)
    List<String> findMenuIdsByPermission(
            @Param("projectId") String projectId, @Param("permissionCode") String permissionCode);

    @Update(
            """
            UPDATE sys_project_menu
            SET parent_id = #{parentId}, menu_name = #{menuName},
                menu_name_key = #{menuNameKey}, menu_type = #{menuType},
                route_path = #{routePath}, component_path = #{componentPath},
                permission_code = #{permissionCode}, icon = #{icon},
                sort_no = #{sortNo}, visible = #{visible},
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updateMenu(
            @Param("id") String id,
            @Param("parentId") String parentId,
            @Param("menuName") String menuName,
            @Param("menuNameKey") String menuNameKey,
            @Param("menuType") String menuType,
            @Param("routePath") String routePath,
            @Param("componentPath") String componentPath,
            @Param("permissionCode") String permissionCode,
            @Param("icon") String icon,
            @Param("sortNo") int sortNo,
            @Param("visible") boolean visible);

    @Update("UPDATE sys_project_menu SET status = #{status}, updated_at = CURRENT_TIMESTAMP WHERE id = #{id}")
    int updateMenuStatus(@Param("id") String id, @Param("status") String status);

    @Delete(
            """
            DELETE FROM sys_project_role_menu
            WHERE project_id = #{projectId} AND menu_id = #{menuId}
            """)
    int deleteRoleMenusByMenu(@Param("projectId") String projectId, @Param("menuId") String menuId);

    @Delete("DELETE FROM sys_project_menu WHERE id = #{menuId}")
    int deleteMenu(@Param("menuId") String menuId);

    @Insert(
            """
            INSERT IGNORE INTO sys_project_role_menu (project_id, role_id, menu_id, created_at)
            VALUES (#{projectId}, #{roleId}, #{menuId}, CURRENT_TIMESTAMP)
            """)
    int grantMenuToRole(
            @Param("projectId") String projectId, @Param("roleId") String roleId, @Param("menuId") String menuId);

    // ---- 授权事实查询：以下三条 SQL 决定谁能看到什么，迁移中未作任何改动 ----

    @Select(
            """
            SELECT r.role_code
            FROM sys_project_member m
            JOIN sys_project_member_role mr
              ON mr.project_id = m.project_id AND mr.user_id = m.user_id
            JOIN sys_project_role r ON r.id = mr.role_id
            WHERE m.project_id = #{projectId} AND m.user_id = #{userId}
              AND m.status = 'ACTIVE' AND r.status = 'ACTIVE'
            ORDER BY r.role_code
            """)
    List<String> findCurrentRoleCodes(@Param("projectId") String projectId, @Param("userId") String userId);

    @Select(
            """
            SELECT DISTINCT rm.menu_id
            FROM sys_project_member m
            JOIN sys_project_member_role mr
              ON mr.project_id = m.project_id AND mr.user_id = m.user_id
            JOIN sys_project_role r ON r.id = mr.role_id AND r.status = 'ACTIVE'
            JOIN sys_project_role_menu rm
              ON rm.project_id = m.project_id AND rm.role_id = r.id
            JOIN sys_project_menu pm ON pm.id = rm.menu_id AND pm.status = 'ACTIVE'
            WHERE m.project_id = #{projectId} AND m.user_id = #{userId}
              AND m.status = 'ACTIVE'
            """)
    List<String> findCurrentMenuIds(@Param("projectId") String projectId, @Param("userId") String userId);

    @Select(
            """
            SELECT DISTINCT pm.permission_code
            FROM sys_project_member m
            JOIN sys_project_member_role mr
              ON mr.project_id = m.project_id AND mr.user_id = m.user_id
            JOIN sys_project_role r ON r.id = mr.role_id AND r.status = 'ACTIVE'
            JOIN sys_project_role_menu rm
              ON rm.project_id = m.project_id AND rm.role_id = r.id
            JOIN sys_project_menu pm ON pm.id = rm.menu_id AND pm.status = 'ACTIVE'
            WHERE m.project_id = #{projectId} AND m.user_id = #{userId}
              AND m.status = 'ACTIVE'
              AND pm.permission_code IS NOT NULL
            ORDER BY pm.permission_code
            """)
    List<String> findCurrentPermissions(@Param("projectId") String projectId, @Param("userId") String userId);

    /**
     * 按项目编码取可对外提供服务的项目 ID。
     *
     * <p>只认 ACTIVE 项目：停用或归档的项目不应再有外部入口，这一跳就是那道闸。</p>
     */
    @Select(
            """
            SELECT id FROM sys_project
            WHERE project_code = #{projectCode} AND status = 'ACTIVE'
            """)
    String findActiveProjectIdByCode(@Param("projectCode") String projectCode);

    /** 成员在本项目下的角色编码，供业务服务做粗粒度判断。 */
    @Select(
            """
            SELECT DISTINCT r.role_code
            FROM sys_project_member m
            JOIN sys_project_member_role mr
              ON mr.project_id = m.project_id AND mr.user_id = m.user_id
            JOIN sys_project_role r ON r.id = mr.role_id AND r.status = 'ACTIVE'
            WHERE m.project_id = #{projectId} AND m.user_id = #{userId}
              AND m.status = 'ACTIVE'
            ORDER BY r.role_code
            """)
    List<String> findMemberRoleCodes(@Param("projectId") String projectId, @Param("userId") String userId);
}
