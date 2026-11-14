package com.kaiwu.module.operation.mapper;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/** D05 共享锁存储；方法须在同一事务按业务键、配额、占用记录顺序调用。 */
@Mapper
public interface ManagedTodoLockMapper {
    /** 建立不可缺失的业务键锁行；重复调用不得改变业务事实。 */
    @Insert(
            """
            INSERT INTO sys_todo_biz_lock(project_code,biz_key) VALUES(#{project},#{key})
            ON DUPLICATE KEY UPDATE biz_key=biz_key
            """)
    @Insert(
            databaseId = "dm",
            value =
                    """
            MERGE INTO sys_todo_biz_lock t USING (SELECT #{project} AS project_code,#{key} AS biz_key FROM dual) s
            ON (t.project_code=s.project_code AND t.biz_key=s.biz_key)
            WHEN NOT MATCHED THEN INSERT(project_code,biz_key) VALUES(s.project_code,s.biz_key)
            """)
    int ensureBusinessKey(@Param("project") String project, @Param("key") String key);

    /** 锁住同项目同业务键，直到调用事务完成。 */
    @Select("SELECT biz_key FROM sys_todo_biz_lock WHERE project_code=#{project} AND biz_key=#{key} FOR UPDATE")
    String lockBusinessKey(@Param("project") String project, @Param("key") String key);

    /** 建立额度锁行；新行必须由调用方与两表实际 OPEN 数量核对。 */
    @Insert(
            """
            INSERT INTO sys_todo_recipient_quota(project_code,recipient_user_id,open_count) VALUES(#{project},#{recipient},0)
            ON DUPLICATE KEY UPDATE open_count=open_count
            """)
    @Insert(
            databaseId = "dm",
            value =
                    """
            MERGE INTO sys_todo_recipient_quota t USING (SELECT #{project} AS project_code,#{recipient} AS recipient_user_id FROM dual) s
            ON (t.project_code=s.project_code AND t.recipient_user_id=s.recipient_user_id)
            WHEN NOT MATCHED THEN INSERT(project_code,recipient_user_id,open_count) VALUES(s.project_code,s.recipient_user_id,0)
            """)
    int ensureQuota(@Param("project") String project, @Param("recipient") long recipient);

    /** 锁住跨旧/新待办共享的收件人额度。 */
    @Select(
            "SELECT open_count FROM sys_todo_recipient_quota WHERE project_code=#{project} AND recipient_user_id=#{recipient} FOR UPDATE")
    Long lockQuota(@Param("project") String project, @Param("recipient") long recipient);

    /** 在配额锁内按当前读核对旧待办 OPEN 实数，不依赖事务早先的快照。 */
    @Select(
            "SELECT COUNT(*) FROM sys_todo WHERE project_code=#{project} AND recipient_user_id=#{recipient} AND status='OPEN' FOR UPDATE")
    long countLegacyOpenForUpdate(@Param("project") String project, @Param("recipient") long recipient);

    /** 在配额锁内按当前读核对受管待办 OPEN 实数。 */
    @Select(
            "SELECT COUNT(*) FROM sys_managed_todo WHERE project_code=#{project} AND recipient_user_id=#{recipient} AND state='OPEN' FOR UPDATE")
    long countManagedOpenForUpdate(@Param("project") String project, @Param("recipient") long recipient);

    /** 持配额锁时按期望旧值更新，防止丢失或意外写入负数。 */
    @Update(
            "UPDATE sys_todo_recipient_quota SET open_count=#{next} WHERE project_code=#{project} AND recipient_user_id=#{recipient} AND open_count=#{expected} AND #{next}>=0")
    int replaceQuota(
            @Param("project") String project,
            @Param("recipient") long recipient,
            @Param("expected") long expected,
            @Param("next") long next);

    /** 锁定已有键域占用；不存在时由持业务键锁的调用方决定是否建立。 */
    @Select(
            "SELECT kind FROM sys_todo_key_guard WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} FOR UPDATE")
    String lockGuard(@Param("project") String project, @Param("key") String key, @Param("recipient") long recipient);

    /** 在持业务键及配额锁后以当前读检查旧域占用。 */
    @Select(
            "SELECT COUNT(*) FROM sys_todo WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} FOR UPDATE")
    long countLegacyKeyForUpdate(
            @Param("project") String project, @Param("key") String key, @Param("recipient") long recipient);

    /** 按当前状态判断旧待办是否已经占用 OPEN 配额。 */
    @Select(
            "SELECT COUNT(*) FROM sys_todo WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} AND status='OPEN' FOR UPDATE")
    long countLegacyOpenKeyForUpdate(
            @Param("project") String project, @Param("key") String key, @Param("recipient") long recipient);

    /** 首次占用域，须先持业务键锁并确认旧、新记录不冲突。 */
    @Insert(
            "INSERT INTO sys_todo_key_guard(project_code,biz_key,recipient_user_id,kind) VALUES(#{project},#{key},#{recipient},#{kind})")
    int insertGuard(
            @Param("project") String project,
            @Param("key") String key,
            @Param("recipient") long recipient,
            @Param("kind") String kind);

    /** 持业务键锁后在 READ COMMITTED 事务中读取旧 OPEN 收件人，按统一顺序锁额度。 */
    @Options(flushCache = Options.FlushCachePolicy.TRUE)
    @Select({
        "<script>",
        "SELECT recipient_user_id FROM sys_todo WHERE project_code=#{project} AND biz_key=#{key} AND status='OPEN'",
        "<if test='recipient != null'> AND recipient_user_id=#{recipient}</if>",
        "ORDER BY recipient_user_id",
        "</script>"
    })
    List<Long> legacyOpenRecipients(
            @Param("project") String project, @Param("key") String key, @Param("recipient") Long recipient);

    /** 在相同业务键锁内按原清理条件取消单条旧待办。 */
    @Update(
            """
            UPDATE sys_todo SET status='CANCELLED',closed_at=#{now},updated_at=#{now}
            WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient}
              AND status='OPEN' AND COALESCE(due_at,updated_at)<#{before}
            """)
    int cancelLegacyStale(
            @Param("project") String project,
            @Param("key") String key,
            @Param("recipient") long recipient,
            @Param("before") LocalDateTime before,
            @Param("now") LocalDateTime now);

    /** 在业务键锁内条件删除已经关闭并超出保留期的旧记录。 */
    @Delete(
            """
            DELETE FROM sys_todo WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient}
              AND status<>'OPEN' AND closed_at<#{before}
            """)
    int deleteLegacyClosed(
            @Param("project") String project,
            @Param("key") String key,
            @Param("recipient") long recipient,
            @Param("before") LocalDateTime before);

    /** 删除旧占用域前确认不存在同键受管行，保护受管墓碑。 */
    @Select(
            "SELECT COUNT(*) FROM sys_managed_todo WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} FOR UPDATE")
    long countManagedKeyForUpdate(
            @Param("project") String project, @Param("key") String key, @Param("recipient") long recipient);

    /** 仅在同键旧记录已删除且没有受管记录时释放 LEGACY 占用。 */
    @Delete(
            "DELETE FROM sys_todo_key_guard WHERE project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} AND kind='LEGACY'")
    int deleteLegacyGuard(
            @Param("project") String project, @Param("key") String key, @Param("recipient") long recipient);

    /** 扫描候选，真正清理时必须重新持锁并验证条件。 */
    @Select(
            "SELECT project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_todo WHERE status='OPEN' AND COALESCE(due_at,updated_at)<#{before} ORDER BY project_code,biz_key,recipient_user_id LIMIT #{limit}")
    @Select(
            databaseId = "dm",
            value =
                    "SELECT project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_todo WHERE status='OPEN' AND COALESCE(due_at,updated_at)<#{before} ORDER BY project_code,biz_key,recipient_user_id FETCH FIRST #{limit} ROWS ONLY")
    List<Map<String, Object>> findStaleLegacy(@Param("before") LocalDateTime before, @Param("limit") int limit);

    /** 扫描已关闭候选，真正删除时重新持锁并检查保留期。 */
    @Select(
            "SELECT project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_todo WHERE status<>'OPEN' AND closed_at<#{before} ORDER BY project_code,biz_key,recipient_user_id LIMIT #{limit}")
    @Select(
            databaseId = "dm",
            value =
                    "SELECT project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_todo WHERE status<>'OPEN' AND closed_at<#{before} ORDER BY project_code,biz_key,recipient_user_id FETCH FIRST #{limit} ROWS ONLY")
    List<Map<String, Object>> findClosedLegacy(@Param("before") LocalDateTime before, @Param("limit") int limit);
    /** 扫描只按last_seen_at过期的受管OPEN，due_at继续用于逾期展示，不能提前取消活跃任务。 */
    @Select(
            "SELECT id,project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_managed_todo WHERE state='OPEN' AND terminal=0 AND last_seen_at<#{before} ORDER BY project_code,biz_key,recipient_user_id,id LIMIT #{limit}")
    @Select(
            databaseId = "dm",
            value =
                    "SELECT id,project_code AS projectCode,biz_key AS bizKey,recipient_user_id AS recipientUserId FROM sys_managed_todo WHERE state='OPEN' AND terminal=0 AND last_seen_at<#{before} ORDER BY project_code,biz_key,recipient_user_id,id FETCH FIRST #{limit} ROWS ONLY")
    List<Map<String, Object>> findStaleManaged(@Param("before") LocalDateTime before, @Param("limit") int limit);

    /** 持共享锁重新检查存活时间；仅标记临时关闭，不改序号、摘要、due_at、last_seen_at或永久终态标记。 */
    @Update(
            "UPDATE sys_managed_todo SET state='CANCELLED',stale=1,updated_at=#{now} WHERE id=#{id} AND project_code=#{project} AND biz_key=#{key} AND recipient_user_id=#{recipient} AND state='OPEN' AND terminal=0 AND last_seen_at<#{before}")
    int cancelManagedStale(
            @Param("id") long id,
            @Param("project") String project,
            @Param("key") String key,
            @Param("recipient") long recipient,
            @Param("before") LocalDateTime before,
            @Param("now") LocalDateTime now);
}
