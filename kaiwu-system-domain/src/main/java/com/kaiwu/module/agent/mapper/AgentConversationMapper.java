package com.kaiwu.module.agent.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.agent.entity.AgentConversationEntity;
import org.apache.ibatis.annotations.*;

@Mapper
public interface AgentConversationMapper extends BaseMapper<AgentConversationEntity> {

    @Select("SELECT id FROM sys_user WHERE id = #{userId} FOR UPDATE")
    String lockOwner(@Param("userId") String userId);

    @Select(
            "SELECT id, user_id, title, use_memory, run_id, busy_until, created_at, updated_at FROM sys_agent_conversation WHERE id = #{id} AND user_id = #{userId} FOR UPDATE")
    AgentConversationEntity lockOwned(@Param("id") String id, @Param("userId") String userId);
}
