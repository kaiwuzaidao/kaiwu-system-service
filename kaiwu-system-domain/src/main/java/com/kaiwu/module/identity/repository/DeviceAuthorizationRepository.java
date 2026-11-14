package com.kaiwu.module.identity.repository;

import com.kaiwu.module.identity.entity.DeviceAuthorizationRow;
import com.kaiwu.module.identity.mapper.DeviceAuthorizationMapper;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.springframework.stereotype.Repository;

/**
 * 设备授权请求的持久化（ADR 0035）。
 *
 * <p>时间一律由调用方以 {@link Instant} 传入并按系统默认时区落成 DATETIME，与在线会话的
 * 落库方式一致；过期判断用同一个 now，避免应用与数据库时钟差造成边界不一致。</p>
 */
@Repository
public class DeviceAuthorizationRepository {

    private final DeviceAuthorizationMapper mapper;

    /** 注入设备授权 Mapper。 */
    public DeviceAuthorizationRepository(DeviceAuthorizationMapper mapper) {
        this.mapper = mapper;
    }

    /** 写入一条待确认请求。 */
    public void create(
            String id,
            String deviceCodeHash,
            String userCode,
            String clientName,
            String requestIp,
            Instant expiresAt,
            Instant now) {
        mapper.insert(id, deviceCodeHash, userCode, clientName, requestIp, local(expiresAt), local(now));
    }

    /** 按短码查仍可确认的请求。 */
    public Optional<Request> findPending(String userCode, Instant now) {
        return Optional.ofNullable(mapper.findPendingByUserCode(userCode, local(now)))
                .map(DeviceAuthorizationRepository::toRequest);
    }

    /** 按设备码摘要查请求。 */
    public Optional<Request> findByDeviceCodeHash(String deviceCodeHash) {
        return Optional.ofNullable(mapper.findByDeviceCodeHash(deviceCodeHash))
                .map(DeviceAuthorizationRepository::toRequest);
    }

    /** 记录允许或拒绝；返回 false 表示请求已被处理或已过期。 */
    public boolean decide(String id, String decision, String userId, Instant now) {
        return mapper.decide(id, decision, userId, local(now)) == 1;
    }

    /** 一次性兑换已允许的请求；返回 false 表示已兑换、被拒绝或已过期。 */
    public boolean consume(String id, Instant now) {
        return mapper.consume(id, local(now)) == 1;
    }

    /** 删除过期时间早于阈值的请求。 */
    public void deleteExpiredBefore(Instant threshold) {
        mapper.deleteExpiredBefore(local(threshold));
    }

    /** 落库时间换算。 */
    private static LocalDateTime local(Instant instant) {
        return LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
    }

    /** 行到领域记录的转换。 */
    private static Request toRequest(DeviceAuthorizationRow row) {
        return new Request(
                row.getId(),
                row.getUserCode(),
                row.getClientName(),
                row.getRequestIp(),
                row.getAuthStatus(),
                row.getUserId(),
                row.getCreatedAt(),
                row.getExpiresAt().atZone(ZoneId.systemDefault()).toInstant());
    }

    /**
     * 一条设备授权请求。
     *
     * @param status PENDING / APPROVED / DENIED / CONSUMED
     * @param userId 允许或拒绝的用户；PENDING 时为空
     */
    public record Request(
            String id,
            String userCode,
            String clientName,
            String requestIp,
            String status,
            String userId,
            LocalDateTime createdAt,
            Instant expiresAt) {}
}
