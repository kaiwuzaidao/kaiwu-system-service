package com.kaiwu.module.audit.mapper;

import com.kaiwu.module.audit.entity.OnlineSessionJoinRow;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 在线会话的连接查询与定点撤销。
 *
 * <p>不继承 {@code BaseMapper}：这些查询都要连 {@code sys_user} 取用户名，
 * 没有单表实体与之对应。</p>
 *
 * <p>可选筛选用 {@code (#{x} IS NULL OR col = #{x})} 的空值短路写成**静态 SQL**，
 * 不用 MyBatis 的 {@code <script>} 动态标签：标签是塞进 Java 字符串里的一段 XML，
 * IDE 不高亮也不校验，写错只有运行时才炸。空串在 Repository 层已统一归一成 null
 * （{@code trim()} 对空白返回 null），因此这里只需判 null。</p>
 */
@Mapper
public interface OnlineSessionQueryMapper {

    @Select(
            """
            SELECT COUNT(*)
            FROM sys_online_session s
            JOIN sys_user u ON u.id = s.user_id
            WHERE (#{username} IS NULL OR u.username LIKE #{username})
              AND (#{status} IS NULL OR s.session_status = #{status})
            """)
    long count(@Param("username") String username, @Param("status") String status);

    @Select(
            """
            SELECT s.id, s.user_id, u.username, s.session_status,
                   s.created_at, s.last_seen_at, s.expires_at, s.revoked_at
            FROM sys_online_session s
            JOIN sys_user u ON u.id = s.user_id
            WHERE (#{username} IS NULL OR u.username LIKE #{username})
              AND (#{status} IS NULL OR s.session_status = #{status})
            ORDER BY s.created_at DESC, s.id DESC
            LIMIT #{size} OFFSET #{offset}
            """)
    List<OnlineSessionJoinRow> page(
            @Param("username") String username,
            @Param("status") String status,
            @Param("size") long size,
            @Param("offset") long offset);

    @Select(
            """
            SELECT s.id, s.user_id, u.username, s.session_status,
                   s.created_at, s.last_seen_at, s.expires_at, s.revoked_at
            FROM sys_online_session s
            JOIN sys_user u ON u.id = s.user_id
            WHERE s.id = #{sessionId}
            """)
    OnlineSessionJoinRow findById(@Param("sessionId") String sessionId);

    /** 定点强制下线；只对仍在线的会话生效，重复操作不会刷新撤销时间。 */
    @Update(
            """
            UPDATE sys_online_session
            SET session_status = 'REVOKED', revoked_at = CURRENT_TIMESTAMP
            WHERE id = #{sessionId} AND session_status = 'ONLINE'
            """)
    int forceOffline(@Param("sessionId") String sessionId);
}
