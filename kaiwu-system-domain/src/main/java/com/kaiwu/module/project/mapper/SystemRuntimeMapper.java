package com.kaiwu.module.project.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * system 项目权限变更后需要失效会话的用户集合。
 *
 * <p>只负责「找出受影响的人」；真正的会话撤销走 auth 模块的
 * {@code OnlineSessionMapper} + 条件构造器，不在这里再写一份 {@code IN (...)} SQL——
 * 迁移过程中这份 SQL 一度在本类和 {@code RoleMapper} 里各有一份逐字相同的副本。</p>
 */
@Mapper
public interface SystemRuntimeMapper {

    @Select(
            """
            SELECT user_id
            FROM sys_project_member_role
            WHERE project_id = #{projectId} AND role_id = #{roleId}
            """)
    List<String> findRoleMemberUserIds(@Param("projectId") String projectId, @Param("roleId") String roleId);

    @Select("SELECT user_id FROM sys_project_member WHERE project_id = #{projectId}")
    List<String> findProjectMemberUserIds(@Param("projectId") String projectId);
}
