package com.kaiwu.module.user.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.user.entity.UserEntity;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 平台用户 Mapper。
 *
 * <p>单表增删改查走 {@link BaseMapper}；下面三条注解 SQL 是 MyBatis-Plus 表达不了或
 * 表达出来更难读的部分：改密要同时置强制改密标记，会话操作跨到 {@code sys_online_session}。</p>
 *
 * <p>{@code sys_online_session} 的实体归 auth 模块所有（后续批次迁移），这里只用注解 SQL
 * 做用户维度的两个操作，避免同一张表出现两份实体定义。</p>
 */
@Mapper
public interface UserMapper extends BaseMapper<UserEntity> {

    /**
     * 管理员重置他人密码。
     *
     * <p>置 {@code must_change_password = 1}，使该用户下次登录必须自行设置新密码——
     * 重置后的临时密码经由人工渠道传递，不应长期使用。这两列必须同时改，
     * 拆成两次更新会出现「密码已重置但不强制改密」的中间态。</p>
     */
    @Update(
            """
            UPDATE sys_user
            SET password_hash = #{passwordHash}, must_change_password = 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = #{id}
            """)
    int updatePassword(@Param("id") long id, @Param("passwordHash") String passwordHash);

    /** 查询该用户当前在线的会话 ID，用于停用账号后逐个下线。 */
    @Select(
            """
            SELECT id FROM sys_online_session
            WHERE user_id = #{userId} AND session_status = 'ONLINE'
            """)
    List<String> findOnlineSessionIds(@Param("userId") long userId);

    /** 将该用户所有在线会话置为已撤销。 */
    @Update(
            """
            UPDATE sys_online_session
            SET session_status = 'REVOKED', revoked_at = CURRENT_TIMESTAMP
            WHERE user_id = #{userId} AND session_status = 'ONLINE'
            """)
    int revokeOnlineSessions(@Param("userId") long userId);
}
