package com.kaiwu.module.agent.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.agent.entity.AgentCapabilityEntity;
import java.util.Set;
import org.apache.ibatis.annotations.*;

/** 项目锁把凭据轮换、注册、心跳、审核和撤销串行化，防止并发复活已撤销能力。 */
@Mapper
public interface AgentCapabilityMapper extends BaseMapper<AgentCapabilityEntity> {
    @Select("SELECT project_code FROM sys_project WHERE id = #{projectId} AND built_in = 0 FOR UPDATE")
    String lockProject(@Param("projectId") String projectId);

    @Select(
            "SELECT permission_code FROM sys_project_menu WHERE project_id = #{projectId} AND menu_type = 'BUTTON' AND status = 'ACTIVE' AND permission_code IS NOT NULL")
    Set<String> permissions(@Param("projectId") String projectId);

    /** 项目已启用的受控数据资源码（ADR 0044），与权限码前缀「模块:资源」同形。 */
    @Select(
            "SELECT resource_code FROM sys_project_data_resource WHERE project_id = #{projectId} AND status = 'ENABLED'")
    Set<String> controlledResources(@Param("projectId") String projectId);

    @Select("SELECT COUNT(*) FROM sys_project WHERE id = #{projectId} AND status = 'ACTIVE' AND built_in = 0")
    int countActiveProject(@Param("projectId") String projectId);

    /** 只扫描调用者仍是有效成员的已审核在线能力；后续逐条核验当前项目权限。 */
    @Select(
            """
            SELECT c.id, c.project_id, c.capability_code, c.version, c.manifest_json, c.manifest_hash,
                   c.status, c.last_seen_at, c.created_at, c.updated_at
            FROM sys_agent_capability c
            JOIN sys_project p ON p.id = c.project_id AND p.status = 'ACTIVE' AND p.built_in = 0
            JOIN sys_project_member m ON m.project_id = p.id AND m.user_id = #{userId} AND m.status = 'ACTIVE'
            WHERE c.status = 'APPROVED' AND c.last_seen_at > #{after}
            ORDER BY c.capability_code LIMIT 100
            """)
    java.util.List<com.kaiwu.module.agent.entity.AgentCapabilityEntity> visibleCandidates(
            @Param("userId") String userId, @Param("after") java.time.LocalDateTime after);

    int countProjectAdmin(@Param("projectId") String projectId, @Param("userId") String userId);
}
