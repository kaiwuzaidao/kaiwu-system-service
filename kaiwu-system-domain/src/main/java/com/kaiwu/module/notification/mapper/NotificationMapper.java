package com.kaiwu.module.notification.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.notification.entity.NotificationEntity;
import java.util.Map;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 站内信 Mapper。 */
@Mapper
public interface NotificationMapper extends BaseMapper<NotificationEntity> {

    /**
     * 标记单条已读。
     *
     * <p>WHERE 同时限定收件人，避免越权标记他人消息；再加 {@code read_at IS NULL}
     * 使重复点击不会刷新已读时间。</p>
     *
     * @return 实际更新行数，0 表示消息不存在、不属于该用户或已读
     */
    @Update(
            """
            UPDATE sys_notification SET read_at = CURRENT_TIMESTAMP
            WHERE id = #{id} AND recipient_user_id = #{recipientUserId} AND read_at IS NULL
            """)
    int markRead(@Param("id") long id, @Param("recipientUserId") long recipientUserId);

    @Update(
            """
            UPDATE sys_notification SET read_at = CURRENT_TIMESTAMP
            WHERE recipient_user_id = #{recipientUserId} AND read_at IS NULL
            """)
    int markAllRead(@Param("recipientUserId") long recipientUserId);

    /** 按项目编码查启用中的项目，用于校验投递来源；项目表归 project 模块所有。 */
    @Select(
            """
            SELECT id, project_code AS projectCode FROM sys_project
            WHERE project_code = #{projectCode} AND status = 'ACTIVE'
            """)
    Map<String, Object> findEnabledProjectByCode(@Param("projectCode") String projectCode);

    /** 收件人必须是该项目的有效成员，防止业务服务向全体用户群发。 */
    @Select(
            """
            SELECT COUNT(*) FROM sys_project_member
            WHERE project_id = #{projectId} AND user_id = #{userId} AND status = 'ACTIVE'
            """)
    long countActiveMember(@Param("projectId") long projectId, @Param("userId") long userId);
}
