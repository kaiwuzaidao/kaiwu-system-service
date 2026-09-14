package com.kaiwu.module.audit.mapper;

import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * 审计写入与保留期清理 Mapper。
 *
 * <p>写入不复用 {@code OperationLogMapper} 的 {@code BaseMapper.insert}：审计行有多个由
 * 数据库或常量固定的列（{@code request_method = 'WRITE'}、{@code response_status = 200}、
 * {@code created_at = CURRENT_TIMESTAMP}），显式 SQL 比构造一个半空的实体更贴近事实。</p>
 */
@Mapper
public interface AuditWriteMapper {

    @Insert(
            """
            INSERT INTO sys_login_log
                (username, user_id, login_status, message, client_ip, trace_id, created_at)
            VALUES (#{username}, #{userId}, #{status}, #{message}, #{clientIp}, #{traceId},
                    CURRENT_TIMESTAMP)
            """)
    int insertLoginLog(
            @Param("username") String username,
            @Param("userId") String userId,
            @Param("status") String status,
            @Param("message") String message,
            @Param("clientIp") String clientIp,
            @Param("traceId") String traceId);

    @Select("SELECT username FROM sys_user WHERE id = #{userId}")
    String findUsername(@Param("userId") String userId);

    @Insert(
            """
            INSERT INTO sys_oper_log
                (user_id, username, module, operation, request_method, request_path,
                 response_status, detail, client_ip, trace_id, created_at)
            VALUES (#{userId}, #{username}, #{module}, #{operation}, 'WRITE', #{path},
                    200, #{detail}, #{clientIp}, #{traceId}, CURRENT_TIMESTAMP)
            """)
    int insertOperationLog(
            @Param("userId") String userId,
            @Param("username") String username,
            @Param("module") String module,
            @Param("operation") String operation,
            @Param("path") String path,
            @Param("detail") String detail,
            @Param("clientIp") String clientIp,
            @Param("traceId") String traceId);

    @Insert(
            """
            INSERT INTO sys_oper_log
                (user_id, username, module, operation, request_method, request_path,
                 response_status, detail, target_type, target_id, change_json,
                 client_ip, trace_id, created_at)
            VALUES (#{userId}, #{username}, #{module}, #{operation}, 'WRITE', #{path},
                    200, #{detail}, #{targetType}, #{targetId}, #{changeJson},
                    #{clientIp}, #{traceId}, CURRENT_TIMESTAMP)
            """)
    int insertOperationLogWithDiff(
            @Param("userId") String userId,
            @Param("username") String username,
            @Param("module") String module,
            @Param("operation") String operation,
            @Param("path") String path,
            @Param("detail") String detail,
            @Param("targetType") String targetType,
            @Param("targetId") String targetId,
            @Param("changeJson") String changeJson,
            @Param("clientIp") String clientIp,
            @Param("traceId") String traceId);

    /**
     * 分批删除到期的登录日志。
     *
     * <p>登录与操作日志各写一条而不是把表名做成参数：表名只能用 {@code ${}} 拼接，
     * 那会在这个类里凭空开一个字符串拼 SQL 的口子。两张表、两条常量 SQL 更安全。
     * {@code LIMIT} 同理用 {@code ${}} 无法避免，因此由调用方传入的 batchSize 必须
     * 来自配置而非请求——它确实来自 {@code AuditRetentionProperties}。</p>
     */
    @Delete("DELETE FROM sys_login_log WHERE created_at < #{before} LIMIT ${batchSize}")
    int deleteLoginLogsBefore(@Param("before") LocalDateTime before, @Param("batchSize") int batchSize);

    @Delete("DELETE FROM sys_oper_log WHERE created_at < #{before} LIMIT ${batchSize}")
    int deleteOperationLogsBefore(@Param("before") LocalDateTime before, @Param("batchSize") int batchSize);
}
