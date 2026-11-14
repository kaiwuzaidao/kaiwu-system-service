package com.kaiwu.module.agent.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.agent.entity.AgentRemoteActionEntity;
import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/** 状态迁移使用 SQL CAS，绝不通过实体非 null 字段更新覆盖已认领结果。 */
@Mapper
public interface AgentRemoteActionMapper extends BaseMapper<AgentRemoteActionEntity> {
    @Update(
            """
            UPDATE sys_agent_remote_action
            SET status = 'EXECUTING', started_at = #{now}, updated_at = #{now}, revision = revision + 1
            WHERE action_id = #{actionId} AND user_id = #{userId} AND session_id = #{sessionId}
              AND status = 'PENDING' AND revision = #{revision} AND expires_at > #{now}
            """)
    int claim(
            @Param("actionId") String actionId,
            @Param("userId") String userId,
            @Param("sessionId") String sessionId,
            @Param("revision") int revision,
            @Param("now") LocalDateTime now);

    @Update(
            """
            UPDATE sys_agent_remote_action
            SET status = #{target}, finished_at = #{now}, updated_at = #{now}, revision = revision + 1,
                result_ciphertext = #{resultCiphertext}, reason_code = #{reasonCode}
            WHERE action_id = #{actionId} AND user_id = #{userId} AND session_id = #{sessionId}
              AND status = 'EXECUTING' AND revision = #{revision}
            """)
    int complete(
            @Param("actionId") String actionId,
            @Param("userId") String userId,
            @Param("sessionId") String sessionId,
            @Param("revision") int revision,
            @Param("target") String target,
            @Param("resultCiphertext") String resultCiphertext,
            @Param("reasonCode") String reasonCode,
            @Param("now") LocalDateTime now);

    @Update(
            """
            UPDATE sys_agent_remote_action
            SET status = #{target}, finished_at = #{now}, updated_at = #{now}, revision = revision + 1,
                reason_code = #{reasonCode}
            WHERE action_id = #{actionId} AND user_id = #{userId} AND session_id = #{sessionId}
              AND status = 'PENDING' AND revision = #{revision}
              AND ((#{target} = 'EXPIRED' AND expires_at <= #{now})
                OR (#{target} IN ('CANCELLED', 'REJECTED') AND expires_at > #{now}))
            """)
    int closePending(
            @Param("actionId") String actionId,
            @Param("userId") String userId,
            @Param("sessionId") String sessionId,
            @Param("revision") int revision,
            @Param("target") String target,
            @Param("reasonCode") String reasonCode,
            @Param("now") LocalDateTime now);

    @Update(
            """
            UPDATE sys_agent_remote_action
            SET status = 'UNKNOWN', finished_at = #{now}, updated_at = #{now}, revision = revision + 1,
                reason_code = 'UNKNOWN_OUTCOME'
            WHERE action_id = #{actionId} AND user_id = #{userId} AND session_id = #{sessionId}
              AND status = 'EXECUTING' AND revision = #{revision}
              AND started_at <= #{cutoff}
            """)
    int markUnknown(
            @Param("actionId") String actionId,
            @Param("userId") String userId,
            @Param("sessionId") String sessionId,
            @Param("revision") int revision,
            @Param("cutoff") LocalDateTime cutoff,
            @Param("now") LocalDateTime now);

    @Update(
            """
            UPDATE sys_agent_remote_action
            SET status = #{target}, result_ciphertext = #{resultCiphertext}, reason_code = #{reasonCode},
                finished_at = #{now}, updated_at = #{now}, revision = revision + 1
            WHERE action_id = #{actionId} AND user_id = #{userId} AND session_id = #{sessionId}
              AND status = 'UNKNOWN' AND revision = #{revision}
            """)
    int reconcile(
            @Param("actionId") String actionId,
            @Param("userId") String userId,
            @Param("sessionId") String sessionId,
            @Param("revision") int revision,
            @Param("target") String target,
            @Param("resultCiphertext") String resultCiphertext,
            @Param("reasonCode") String reasonCode,
            @Param("now") LocalDateTime now);
}
