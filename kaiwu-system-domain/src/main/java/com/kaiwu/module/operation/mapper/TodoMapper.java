package com.kaiwu.module.operation.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kaiwu.module.operation.entity.TodoEntity;
import java.time.LocalDateTime;
import java.util.Map;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 统一待办 Mapper（ADR 0034）。 */
@Mapper
public interface TodoMapper extends BaseMapper<TodoEntity> {

    /**
     * 打开待办：不存在则新建，存在则更新内容并重新打开。
     *
     * <p>幂等键是唯一索引 {@code (project_code, biz_key, recipient_user_id)}。{@code opened_at} 只在待办此前不是
     * OPEN 时才刷新，因此对一条仍未处理的待办重复投递不会改变它在列表里的排序；该表达式必须写在
     * {@code status} 赋值之前，MySQL 按书写顺序依次求值，否则读到的已经是被改成 OPEN 之后的状态。
     *
     * @param entity 待办内容，状态固定写入 OPEN
     * @return MySQL 的影响行数：新建为 1，更新为 2，内容完全相同为 0
     */
    @Insert(
            databaseId = "dm",
            value =
                    """
            MERGE INTO sys_todo t
            USING (
            SELECT incoming.id, incoming.project_id, incoming.project_code, incoming.biz_key, incoming.recipient_user_id, incoming.title, incoming.content, incoming.link_url, incoming.status, incoming.due_at, incoming.opened_at, incoming.closed_at, incoming.created_at, incoming.updated_at, (SELECT existing.id FROM sys_todo existing WHERE (existing.id = incoming.id) OR (existing.project_code = incoming.project_code AND existing.biz_key = incoming.biz_key AND existing.recipient_user_id = incoming.recipient_user_id)) AS match_id
            FROM (
            SELECT #{id} AS id,
                   #{projectId} AS project_id,
                   #{projectCode} AS project_code,
                   #{bizKey} AS biz_key,
                   #{recipientUserId} AS recipient_user_id,
                   #{title} AS title,
                   #{content} AS content,
                   #{linkUrl} AS link_url,
                   'OPEN' AS status,
                   #{dueAt} AS due_at,
                   #{openedAt} AS opened_at,
                   NULL AS closed_at,
                   #{createdAt} AS created_at,
                   #{updatedAt} AS updated_at
            FROM dual
            ) incoming
            ) s
            ON (t.id = s.match_id)
            WHEN MATCHED THEN UPDATE SET t.title = s.title,
                t.content = s.content,
                t.link_url = s.link_url,
                t.due_at = s.due_at,
                t.opened_at = CASE WHEN t.status = 'OPEN' THEN t.opened_at ELSE s.opened_at END,
                t.closed_at = NULL,
                t.status = 'OPEN',
                t.updated_at = s.updated_at
            WHEN NOT MATCHED THEN INSERT (id, project_id, project_code, biz_key, recipient_user_id, title, content, link_url, status, due_at, opened_at, closed_at, created_at, updated_at)
            VALUES (s.id, s.project_id, s.project_code, s.biz_key, s.recipient_user_id, s.title, s.content, s.link_url, s.status, s.due_at, s.opened_at, s.closed_at, s.created_at, s.updated_at)
            """)
    @Insert(
            """
            INSERT INTO sys_todo
                (id, project_id, project_code, biz_key, recipient_user_id, title, content, link_url,
                 status, due_at, opened_at, closed_at, created_at, updated_at)
            VALUES
                (#{id}, #{projectId}, #{projectCode}, #{bizKey}, #{recipientUserId}, #{title}, #{content}, #{linkUrl},
                 'OPEN', #{dueAt}, #{openedAt}, NULL, #{createdAt}, #{updatedAt})
            ON DUPLICATE KEY UPDATE
                title = VALUES(title),
                content = VALUES(content),
                link_url = VALUES(link_url),
                due_at = VALUES(due_at),
                opened_at = IF(status = 'OPEN', opened_at, VALUES(opened_at)),
                closed_at = NULL,
                status = 'OPEN',
                updated_at = VALUES(updated_at)
            """)
    int upsertOpen(TodoEntity entity);

    /**
     * 统计某收件人在某项目下处于 OPEN 的待办数，用于容量上限。
     *
     * @param projectCode 来源项目编码
     * @param recipientUserId 收件人
     * @return OPEN 待办数
     */
    @Select(
            """
            SELECT COUNT(*) FROM sys_todo
            WHERE project_code = #{projectCode} AND recipient_user_id = #{recipientUserId} AND status = 'OPEN'
            """)
    long countOpenByRecipient(@Param("projectCode") String projectCode, @Param("recipientUserId") long recipientUserId);

    /**
     * 某条待办当前是否已经是 OPEN。已处于 OPEN 的同键更新不占用额度，所以容量检查要先排除它。
     *
     * @param projectCode 来源项目编码
     * @param bizKey 业务唯一键
     * @param recipientUserId 收件人
     * @return 命中的 OPEN 行数，0 或 1
     */
    @Select(
            """
            SELECT COUNT(*) FROM sys_todo
            WHERE project_code = #{projectCode} AND biz_key = #{bizKey}
              AND recipient_user_id = #{recipientUserId} AND status = 'OPEN'
            """)
    long countOpenByKey(
            @Param("projectCode") String projectCode,
            @Param("bizKey") String bizKey,
            @Param("recipientUserId") long recipientUserId);

    /**
     * 统计某收件人已逾期的 OPEN 待办数。
     *
     * @param recipientUserId 收件人
     * @param now 判定逾期的当前时间
     * @return 已逾期数量
     */
    @Select(
            """
            SELECT COUNT(*) FROM sys_todo
            WHERE recipient_user_id = #{recipientUserId} AND status = 'OPEN'
              AND due_at IS NOT NULL AND due_at < #{now}
            """)
    long countOverdue(@Param("recipientUserId") long recipientUserId, @Param("now") LocalDateTime now);

    /**
     * 兜底取消长期未处理的 OPEN 待办。
     *
     * <p>无截止时间的按最后更新时间算，有截止时间的按逾期时间算，二者都早于 {@code before} 才取消。
     * 每次最多处理 {@code batchSize} 行；{@code LIMIT} 无法参数化，数值只来自配置而非请求。
     *
     * @param before 截止线：早于它的视为长期未处理
     * @param now 写入关闭时间的当前时间
     * @param batchSize 单批行数，来自配置
     * @return 本批实际取消行数
     */
    @Update(
            """
            UPDATE sys_todo SET status = 'CANCELLED', closed_at = #{now}, updated_at = #{now}
            WHERE status = 'OPEN' AND COALESCE(due_at, updated_at) < #{before}
            LIMIT ${batchSize}
            """)
    int cancelStaleBefore(
            @Param("before") LocalDateTime before, @Param("now") LocalDateTime now, @Param("batchSize") int batchSize);

    /**
     * 物理删除关闭已久的待办，限制表的增长。
     *
     * @param before 截止线：关闭时间早于它的才删除
     * @param batchSize 单批行数，来自配置
     * @return 本批实际删除行数
     */
    @Delete("DELETE FROM sys_todo WHERE status <> 'OPEN' AND closed_at < #{before} LIMIT ${batchSize}")
    int deleteClosedBefore(@Param("before") LocalDateTime before, @Param("batchSize") int batchSize);

    /**
     * 按项目编码查启用中的项目，用于校验投递来源；项目表归 project 模块所有，这里只读。
     *
     * @param projectCode 项目编码
     * @return 含 id 与 projectCode 的行，不存在或未启用为空
     */
    @Select(
            """
            SELECT id, project_code AS projectCode FROM sys_project
            WHERE project_code = #{projectCode} AND status = 'ACTIVE'
            """)
    Map<String, Object> findEnabledProjectByCode(@Param("projectCode") String projectCode);

    /**
     * 收件人必须是该项目的有效成员，防止业务服务向全体用户灌入待办。
     *
     * @param projectId 项目 ID
     * @param userId 用户 ID
     * @return 有效成员行数，0 表示不是
     */
    @Select(
            """
            SELECT COUNT(*) FROM sys_project_member
            WHERE project_id = #{projectId} AND user_id = #{userId} AND status = 'ACTIVE'
            """)
    long countActiveMember(@Param("projectId") long projectId, @Param("userId") long userId);
    /** 合并只读投影时保持既有待办字段；受管版本/摘要/生产者仅供内部协议使用。 */
    String VISIBLE_TODOS =
            "SELECT 0 AS managed_projection,id,project_id,project_code,biz_key,recipient_user_id,title,content,link_url,status,due_at,opened_at,closed_at,created_at,updated_at FROM sys_todo UNION ALL SELECT 1 AS managed_projection,id,project_id,project_code,biz_key,recipient_user_id,title,content,link_url,state AS status,due_at,operation_created_at AS opened_at,CASE WHEN state='OPEN' THEN NULL ELSE updated_at END AS closed_at,created_at,updated_at FROM sys_managed_todo";

    /** 只统计当前收件人符合筛选的旧/新待办，协议内部表不直接暴露给浏览器。 */
    @Select({
        "<script>",
        "SELECT COUNT(*) FROM (" + VISIBLE_TODOS
                + ") visible WHERE recipient_user_id=#{recipient} AND status=#{status}",
        "<if test='project != null'> AND project_code=#{project}</if>",
        "</script>"
    })
    long countVisible(
            @Param("recipient") long recipient, @Param("status") String status, @Param("project") String project);

    /** 跨两种存储统一排序分页，避免分别取页造成漏项或错误总数。 */
    @Select({
        "<script>",
        "SELECT managed_projection,id,project_id,project_code,biz_key,recipient_user_id,title,content,link_url,status,due_at,opened_at,closed_at,created_at,updated_at FROM ("
                + VISIBLE_TODOS + ") visible WHERE recipient_user_id=#{recipient} AND status=#{status}",
        "<if test='project != null'> AND project_code=#{project}</if>",
        "ORDER BY opened_at DESC,id DESC LIMIT #{size} OFFSET #{offset}",
        "</script>"
    })
    @Select(
            databaseId = "dm",
            value = {
                "<script>",
                "SELECT managed_projection,id,project_id,project_code,biz_key,recipient_user_id,title,content,link_url,status,due_at,opened_at,closed_at,created_at,updated_at FROM ("
                        + VISIBLE_TODOS + ") visible WHERE recipient_user_id=#{recipient} AND status=#{status}",
                "<if test='project != null'> AND project_code=#{project}</if>",
                "ORDER BY opened_at DESC,id DESC OFFSET #{offset} ROWS FETCH NEXT #{size} ROWS ONLY",
                "</script>"
            })
    java.util.List<TodoEntity> pageVisible(
            @Param("recipient") long recipient,
            @Param("status") String status,
            @Param("project") String project,
            @Param("offset") long offset,
            @Param("size") long size);

    /** 逾期仅用于展示，受管清理不能复用due_at判定活跃状态。 */
    @Select(
            "SELECT COUNT(*) FROM (" + VISIBLE_TODOS
                    + ") visible WHERE recipient_user_id=#{recipient} AND status='OPEN' AND due_at IS NOT NULL AND due_at<CASE WHEN managed_projection=1 THEN #{utcNow} ELSE #{now} END")
    long countVisibleOverdue(
            @Param("recipient") long recipient, @Param("now") LocalDateTime now, @Param("utcNow") LocalDateTime utcNow);
}
