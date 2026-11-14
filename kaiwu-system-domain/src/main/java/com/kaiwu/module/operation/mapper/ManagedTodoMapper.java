package com.kaiwu.module.operation.mapper;

import java.time.LocalDateTime;
import java.util.Map;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** 受管待办的条件读写；调用方须先取得 D05 规定的跨域键与配额锁。 */
@Mapper
public interface ManagedTodoMapper {
    /** 单条入库内容，凭据事实和摘要均由服务端取得。 */
    record Row(
            long id,
            long projectId,
            String project,
            String producer,
            String key,
            long recipient,
            long sequence,
            String state,
            boolean terminal,
            byte[] digest,
            LocalDateTime operationCreatedAt,
            String title,
            String content,
            String link,
            LocalDateTime dueAt,
            LocalDateTime now) {}

    /** 锁定本生产者的投影事实；开启当前读并清理会话缓存。 */
    @Options(flushCache = Options.FlushCachePolicy.TRUE)
    @Select(
            """
            SELECT id,operation_sequence AS operationSequence,state,terminal,payload_digest AS payloadDigest
            FROM sys_managed_todo WHERE project_code=#{project} AND producer_service=#{producer}
              AND biz_key=#{key} AND recipient_user_id=#{recipient} FOR UPDATE
            """)
    Map<String, Object> lockProjection(
            @Param("project") String project,
            @Param("producer") String producer,
            @Param("key") String key,
            @Param("recipient") long recipient);

    /** 按生产者范围读取回执，不返回待办正文。 */
    @Options(flushCache = Options.FlushCachePolicy.TRUE)
    @Select(
            """
            SELECT operation_sequence AS operationSequence,state,terminal,payload_digest AS payloadDigest
            FROM sys_managed_todo WHERE project_code=#{project} AND producer_service=#{producer}
              AND biz_key=#{key} AND recipient_user_id=#{recipient}
            """)
    Map<String, Object> receipt(
            @Param("project") String project,
            @Param("producer") String producer,
            @Param("key") String key,
            @Param("recipient") long recipient);

    /** 首次写入，允许无 OPEN 前驱的关闭墓碑。 */
    @Insert(
            """
            INSERT INTO sys_managed_todo(id,project_id,project_code,producer_service,biz_key,recipient_user_id,
                operation_sequence,state,terminal,stale,payload_digest,operation_created_at,title,content,link_url,due_at,
                last_seen_at,created_at,updated_at)
            VALUES(#{id},#{projectId},#{project},#{producer},#{key},#{recipient},#{sequence},#{state},#{terminal},0,
                #{digest},#{operationCreatedAt},#{title},#{content},#{link},#{dueAt},#{now},#{now},#{now})
            """)
    int insert(Row row);

    /** 锁内应用新版本；更新完整内容并清除过期标记。 */
    @Update(
            """
            UPDATE sys_managed_todo SET operation_sequence=#{sequence},state=#{state},terminal=#{terminal},stale=0,
                payload_digest=#{digest},operation_created_at=#{operationCreatedAt},title=#{title},content=#{content},
                link_url=#{link},due_at=#{dueAt},last_seen_at=#{now},updated_at=#{now}
            WHERE id=#{id} AND project_code=#{project} AND producer_service=#{producer} AND biz_key=#{key}
                AND recipient_user_id=#{recipient}
            """)
    int update(Row row);

    /** 根据凭据绑定的项目 ID 取得唯一有效项目编码。 */
    @Select("SELECT project_code FROM sys_project WHERE id=#{projectId} AND status='ACTIVE'")
    String activeProjectCode(@Param("projectId") long projectId);

    /** 锁定用户，避免成功 OPEN 与用户停用并发交错。 */
    @Select("SELECT status FROM sys_user WHERE id=#{user} FOR UPDATE")
    String lockUserStatus(@Param("user") long user);

    /** 锁定成员关系，避免成功 OPEN 与成员停用并发交错。 */
    @Select("SELECT status FROM sys_project_member WHERE project_id=#{projectId} AND user_id=#{user} FOR UPDATE")
    String lockMemberStatus(@Param("projectId") long projectId, @Param("user") long user);
}
