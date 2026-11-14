package com.kaiwu.module.project.mapper;

import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/** 只读取指定项目的候选人最小身份事实。 */
@Mapper
public interface ProjectMemberQueryMapper {
    /** 用凭据绑定项目 ID 与请求路径编码共同确认项目身份。 */
    @Select(
            "SELECT COUNT(*) FROM sys_project WHERE id=#{projectId} AND project_code=#{projectCode} AND status='ACTIVE'")
    int matchesProject(@Param("projectId") String projectId, @Param("projectCode") String projectCode);

    /** 判断目标角色是否在该项目存在且启用。 */
    @Select(
            "SELECT COUNT(*) FROM sys_project_role WHERE project_id=#{projectId} AND role_code=#{roleCode} AND status='ACTIVE'")
    int activeRole(@Param("projectId") String projectId, @Param("roleCode") String roleCode);

    /** 读取上限加一条，发现超限时由调用方整体拒绝。 */
    @Select(
            """
            SELECT DISTINCT m.user_id FROM sys_project_member m
            JOIN sys_user u ON u.id=m.user_id AND u.status='ENABLED'
            JOIN sys_project_member_role mr ON mr.project_id=m.project_id AND mr.user_id=m.user_id
            JOIN sys_project_role r ON r.id=mr.role_id AND r.project_id=m.project_id AND r.status='ACTIVE'
            WHERE m.project_id=#{projectId} AND m.status='ACTIVE' AND r.role_code=#{roleCode}
            ORDER BY m.user_id LIMIT #{limit}
            """)
    @Select(
            databaseId = "dm",
            value =
                    """
            SELECT DISTINCT m.user_id FROM sys_project_member m
            JOIN sys_user u ON u.id=m.user_id AND u.status='ENABLED'
            JOIN sys_project_member_role mr ON mr.project_id=m.project_id AND mr.user_id=m.user_id
            JOIN sys_project_role r ON r.id=mr.role_id AND r.project_id=m.project_id AND r.status='ACTIVE'
            WHERE m.project_id=#{projectId} AND m.status='ACTIVE' AND r.role_code=#{roleCode}
            ORDER BY m.user_id FETCH FIRST #{limit} ROWS ONLY
            """)
    List<String> membersByRole(
            @Param("projectId") String projectId, @Param("roleCode") String roleCode, @Param("limit") int limit);

    /** 一次性读取请求中仍有效的用户，角色过滤仅作用于该项目。 */
    @Select({
        "<script>",
        "SELECT DISTINCT m.user_id FROM sys_project_member m JOIN sys_user u ON u.id=m.user_id AND u.status='ENABLED'",
        "<if test='roleCode != null'> JOIN sys_project_member_role mr ON mr.project_id=m.project_id AND mr.user_id=m.user_id JOIN sys_project_role r ON r.id=mr.role_id AND r.project_id=m.project_id AND r.status='ACTIVE' AND r.role_code=#{roleCode}</if>",
        "WHERE m.project_id=#{projectId} AND m.status='ACTIVE' AND m.user_id IN",
        "<foreach collection='userIds' item='id' open='(' separator=',' close=')'>#{id}</foreach>",
        "ORDER BY m.user_id",
        "</script>"
    })
    List<String> eligibleMembers(
            @Param("projectId") String projectId,
            @Param("userIds") List<String> userIds,
            @Param("roleCode") String roleCode);
}
