package com.kaiwu.module.identity.mapper;

import com.kaiwu.module.identity.entity.DeviceAuthorizationRow;
import java.time.LocalDateTime;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

/**
 * 设备授权请求的数据访问（ADR 0035）。
 *
 * <p>状态流转全部用带前置状态的条件更新完成：同一请求被并发允许、拒绝或兑换时，
 * 只有一方能让影响行数为 1，其余调用据此失败关闭。</p>
 */
@Mapper
public interface DeviceAuthorizationMapper {

    /** 写入一条待确认的授权请求。 */
    @Insert(
            """
            INSERT INTO sys_device_authorization
                (id, device_code_hash, user_code, client_name, request_ip, auth_status,
                 expires_at, created_at)
            VALUES (#{id}, #{deviceCodeHash}, #{userCode}, #{clientName}, #{requestIp}, 'PENDING',
                    #{expiresAt}, #{now})
            """)
    int insert(
            @Param("id") String id,
            @Param("deviceCodeHash") String deviceCodeHash,
            @Param("userCode") String userCode,
            @Param("clientName") String clientName,
            @Param("requestIp") String requestIp,
            @Param("expiresAt") LocalDateTime expiresAt,
            @Param("now") LocalDateTime now);

    /** 按短码查仍可确认的请求；过期请求视同不存在。 */
    @Select(
            """
            SELECT id, user_code, client_name, request_ip, auth_status, user_id, expires_at, created_at
            FROM sys_device_authorization
            WHERE user_code = #{userCode} AND auth_status = 'PENDING' AND expires_at > #{now}
            ORDER BY created_at DESC
            LIMIT 1
            """)
    DeviceAuthorizationRow findPendingByUserCode(@Param("userCode") String userCode, @Param("now") LocalDateTime now);

    /** 按设备码摘要查请求，供 CLI 轮询。 */
    @Select(
            """
            SELECT id, user_code, client_name, request_ip, auth_status, user_id, expires_at, created_at
            FROM sys_device_authorization
            WHERE device_code_hash = #{deviceCodeHash}
            LIMIT 1
            """)
    DeviceAuthorizationRow findByDeviceCodeHash(@Param("deviceCodeHash") String deviceCodeHash);

    /** 允许或拒绝；只对仍在等待且未过期的请求生效。 */
    @Update(
            """
            UPDATE sys_device_authorization
            SET auth_status = #{decision}, user_id = #{userId}, decided_at = #{now}
            WHERE id = #{id} AND auth_status = 'PENDING' AND expires_at > #{now}
            """)
    int decide(
            @Param("id") String id,
            @Param("decision") String decision,
            @Param("userId") String userId,
            @Param("now") LocalDateTime now);

    /** 兑换已允许的请求；一次性，成功后同一设备码不能再换出会话。 */
    @Update(
            """
            UPDATE sys_device_authorization
            SET auth_status = 'CONSUMED', consumed_at = #{now}
            WHERE id = #{id} AND auth_status = 'APPROVED' AND expires_at > #{now}
            """)
    int consume(@Param("id") String id, @Param("now") LocalDateTime now);

    /** 清理早已过期的请求，避免表无限增长；只删过期时间早于阈值的行。 */
    @Delete("DELETE FROM sys_device_authorization WHERE expires_at < #{threshold}")
    int deleteExpiredBefore(@Param("threshold") LocalDateTime threshold);
}
