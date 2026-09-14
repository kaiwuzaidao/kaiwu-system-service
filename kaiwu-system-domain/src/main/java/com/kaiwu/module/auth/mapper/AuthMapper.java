package com.kaiwu.module.auth.mapper;

import com.kaiwu.module.auth.entity.NavigationMenuRow;
import com.kaiwu.module.auth.entity.OnlineSessionRow;
import com.kaiwu.module.auth.entity.UserAccountRow;
import java.time.LocalDateTime;
import java.util.List;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 身份、权限与在线会话 Mapper。
 *
 * <p>两条授权查询各有五个 JOIN，是 MyBatis-Plus 条件构造器表达不了的，原样保留为注解 SQL。
 * 这也是本次数据层迁移的边界：**授权链路的 SQL 一个字都没改**——它决定谁能看到什么，
 * 借换 ORM 的机会顺手"优化"它是不可接受的风险。</p>
 */
@Mapper
public interface AuthMapper {

    /** 登录校验；这是唯一会取出 {@code password_hash} 的查询。 */
    @Select(
            """
            SELECT id, username, password_hash, display_name, status,
                   locale, must_change_password
            FROM sys_user
            WHERE username = #{username}
            LIMIT 1
            """)
    UserAccountRow findUserByUsername(@Param("username") String username);

    @Select(
            """
            SELECT id, username, password_hash, display_name, status,
                   locale, must_change_password
            FROM sys_user
            WHERE id = #{userId}
            LIMIT 1
            """)
    UserAccountRow findUserById(@Param("userId") String userId);

    /**
     * 当前用户在内置 system 项目下的全部权限码。
     *
     * <p>链路是 项目 → 成员 → 成员角色 → 角色 → 角色菜单 → 菜单权限码，
     * 每一跳都带状态过滤：停用的角色、停用的菜单、非 ACTIVE 的成员都不产生权限。</p>
     */
    @Select(
            """
            SELECT DISTINCT menu.permission_code
            FROM sys_project project
            JOIN sys_project_member member
              ON member.project_id = project.id
             AND member.user_id = #{userId}
             AND member.status = 'ACTIVE'
            JOIN sys_project_member_role member_role
              ON member_role.project_id = project.id
             AND member_role.user_id = member.user_id
            JOIN sys_project_role role
              ON role.id = member_role.role_id
             AND role.project_id = project.id
             AND role.status = 'ACTIVE'
            JOIN sys_project_role_menu role_menu
              ON role_menu.project_id = project.id
             AND role_menu.role_id = role.id
            JOIN sys_project_menu menu
              ON menu.id = role_menu.menu_id
             AND menu.project_id = project.id
             AND menu.status = 'ACTIVE'
            WHERE project.project_code = 'system'
              AND project.built_in = 1
              AND project.status = 'ACTIVE'
              AND menu.permission_code IS NOT NULL
            ORDER BY menu.permission_code
            """)
    List<String> findPermissions(@Param("userId") String userId);

    /**
     * 用户在内置 system 项目下已授权的导航节点。
     *
     * <p>授权链路与 {@link #findPermissions} 完全一致，区别只在筛选：这里取
     * DIRECTORY/MENU 且可见启用的节点，权限码所在的 BUTTON 不进导航。</p>
     *
     * <p>菜单名不在这里解析：ADR 0013 起内置菜单的译文来自国际化资源目录，SQL 够不到
     * 目录缓存，继续在库里解析就得再 JOIN 一张表，让这条本就有五个 JOIN、每次登录都走的
     * 查询更重。这里只出原始数据，由 {@code AuthService} 用统一入口解析。</p>
     */
    @Select(
            """
            SELECT DISTINCT menu.id, menu.parent_id,
                   menu.menu_name, menu.menu_name_key,
                   menu.menu_type, menu.route_path, menu.icon, menu.sort_no
            FROM sys_project project
            JOIN sys_user user ON user.id = #{userId}
            JOIN sys_project_member member
              ON member.project_id = project.id
             AND member.user_id = user.id
             AND member.status = 'ACTIVE'
            JOIN sys_project_member_role member_role
              ON member_role.project_id = project.id
             AND member_role.user_id = member.user_id
            JOIN sys_project_role role
              ON role.id = member_role.role_id
             AND role.project_id = project.id
             AND role.status = 'ACTIVE'
            JOIN sys_project_role_menu role_menu
              ON role_menu.project_id = project.id
             AND role_menu.role_id = role.id
            JOIN sys_project_menu menu
              ON menu.id = role_menu.menu_id
             AND menu.project_id = project.id
             AND menu.status = 'ACTIVE'
             AND menu.visible = 1
             AND menu.menu_type IN ('DIRECTORY', 'MENU')
            WHERE project.project_code = 'system'
              AND project.built_in = 1
              AND project.status = 'ACTIVE'
            ORDER BY menu.sort_no, menu.id
            """)
    List<NavigationMenuRow> findNavigationMenus(@Param("userId") String userId);

    @Insert(
            """
            INSERT INTO sys_online_session
                (id, user_id, refresh_token_hash, session_status, expires_at,
                 created_at, last_seen_at)
            VALUES (#{sessionId}, #{userId}, #{refreshTokenHash}, 'ONLINE', #{expiresAt},
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int createSession(
            @Param("sessionId") String sessionId,
            @Param("userId") String userId,
            @Param("refreshTokenHash") String refreshTokenHash,
            @Param("expiresAt") LocalDateTime expiresAt);

    @Select(
            """
            SELECT id, user_id, refresh_token_hash, session_status, expires_at
            FROM sys_online_session
            WHERE id = #{sessionId}
            LIMIT 1
            """)
    OnlineSessionRow findSession(@Param("sessionId") String sessionId);

    @Update(
            """
            UPDATE sys_online_session
            SET last_seen_at = CURRENT_TIMESTAMP
            WHERE id = #{sessionId} AND session_status = 'ONLINE'
            """)
    int touchSession(@Param("sessionId") String sessionId);

    @Update(
            """
            UPDATE sys_online_session
            SET refresh_token_hash = #{newHash}, last_seen_at = CURRENT_TIMESTAMP
            WHERE id = #{sessionId}
              AND refresh_token_hash = #{expectedHash}
              AND session_status = 'ONLINE'
            """)
    int rotateRefreshToken(
            @Param("sessionId") String sessionId,
            @Param("expectedHash") String expectedHash,
            @Param("newHash") String newHash);

    @Update(
            """
            UPDATE sys_online_session
            SET session_status = 'REVOKED', revoked_at = CURRENT_TIMESTAMP
            WHERE id = #{sessionId} AND session_status = 'ONLINE'
            """)
    int revokeSession(@Param("sessionId") String sessionId);

    /** 用户自助改密：同时清除强制改密标记。 */
    @Update(
            """
            UPDATE sys_user
            SET password_hash = #{passwordHash}, must_change_password = 0,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{userId}
            """)
    int updatePassword(@Param("userId") String userId, @Param("passwordHash") String passwordHash);

    /** 更新当前用户的界面语言偏好，不改变任何会话或权限事实。 */
    @Update(
            """
            UPDATE sys_user
            SET locale = #{locale}, updated_at = CURRENT_TIMESTAMP
            WHERE id = #{userId}
            """)
    int updateLocale(@Param("userId") String userId, @Param("locale") String locale);

    /** 该用户除当前会话外的其它在线会话，用于改密码后定点下线。 */
    @Select(
            """
            SELECT id FROM sys_online_session
            WHERE user_id = #{userId} AND id <> #{keepSessionId} AND session_status = 'ONLINE'
            """)
    List<String> findOtherOnlineSessionIds(
            @Param("userId") String userId, @Param("keepSessionId") String keepSessionId);

    @Update(
            """
            UPDATE sys_online_session
            SET session_status = 'REVOKED', revoked_at = CURRENT_TIMESTAMP
            WHERE user_id = #{userId} AND id <> #{keepSessionId} AND session_status = 'ONLINE'
            """)
    int revokeOtherSessions(@Param("userId") String userId, @Param("keepSessionId") String keepSessionId);

    @Select("SELECT COUNT(*) FROM sys_user WHERE username = #{username}")
    int countByUsername(@Param("username") String username);

    /**
     * 首次启动创建内置管理员。
     *
     * <p>{@code must_change_password = 1} 是有意的：引导密码来自环境变量，可能留存于
     * 部署脚本、CI 变量与聊天记录，因此首次登录必须由本人改掉。</p>
     */
    @Insert(
            """
            INSERT INTO sys_user
                (id, username, password_hash, display_name, status,
                 must_change_password, created_at, updated_at)
            VALUES (1, 'admin', #{passwordHash}, '平台管理员', 'ENABLED', 1,
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """)
    int insertBootstrapAdmin(@Param("passwordHash") String passwordHash);
}
