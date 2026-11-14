package com.kaiwu.module.identity.service.impl;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.identity.repository.DeviceAuthorizationRepository;
import com.kaiwu.module.identity.service.AuthService;
import com.kaiwu.module.identity.service.DeviceAuthorizationService;
import com.kaiwu.module.identity.vo.DeviceAuthorizationPendingView;
import com.kaiwu.module.identity.vo.DeviceAuthorizationStartView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Base64;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * CLI 设备授权实现（ADR 0035）。
 *
 * <p>安全要点：设备码只以 SHA-256 摘要落库；短码只在已登录用户的确认页使用；
 * 允许、拒绝与兑换都是带前置状态的条件更新，并发下只有一方成功；兑换成功后才签发会话，
 * 且只签发一次。</p>
 */
@Service
public class DeviceAuthorizationServiceImpl implements DeviceAuthorizationService {

    /** 授权请求有效期：足够用户切到浏览器核对，又不会让悬挂请求长期可用。 */
    static final Duration REQUEST_TTL = Duration.ofMinutes(10);

    /** 建议的轮询间隔。 */
    static final long POLL_INTERVAL_SECONDS = 5;

    /** 单个客户端地址在限流窗口内最多可发起的授权请求数。 */
    static final long START_LIMIT = 20;

    /** 限流窗口。 */
    static final Duration START_WINDOW = Duration.ofMinutes(10);

    /** 短码字母表：去掉元音与易混淆的 0/O/1/I，避免拼出单词或看错。 */
    private static final char[] USER_CODE_ALPHABET = "BCDFGHJKLMNPQRSTVWXZ23456789".toCharArray();

    private static final String START_KEY_PREFIX = "kaiwu:auth:device:start:";

    private final DeviceAuthorizationRepository repository;
    private final AuthService authService;
    private final AuditPort auditService;
    private final StringRedisTemplate redisTemplate;
    private final Clock clock;
    private final SecureRandom secureRandom = new SecureRandom();

    /** Spring 使用的构造器，时钟取系统 UTC；显式标注以免与测试构造器产生歧义。 */
    @Autowired
    public DeviceAuthorizationServiceImpl(
            DeviceAuthorizationRepository repository,
            AuthService authService,
            AuditPort auditService,
            StringRedisTemplate redisTemplate) {
        this(repository, authService, auditService, redisTemplate, Clock.systemUTC());
    }

    /** 测试使用的构造器，可注入固定时钟。 */
    DeviceAuthorizationServiceImpl(
            DeviceAuthorizationRepository repository,
            AuthService authService,
            AuditPort auditService,
            StringRedisTemplate redisTemplate,
            Clock clock) {
        this.repository = repository;
        this.authService = authService;
        this.auditService = auditService;
        this.redisTemplate = redisTemplate;
        this.clock = clock;
    }

    /**
     * 发起授权。
     *
     * <p>先限流再写库；顺带清理一天前就已过期的请求，避免单独的定时任务。</p>
     */
    @Override
    @Transactional
    public DeviceAuthorizationStartView start(String clientName, RequestMetadata metadata) {
        enforceStartLimit(metadata.clientIp());
        Instant now = clock.instant();
        repository.deleteExpiredBefore(now.minus(Duration.ofDays(1)));
        String deviceCode = randomDeviceCode();
        String userCode = randomUserCode();
        repository.create(
                UUID.randomUUID().toString(),
                sha256(deviceCode),
                userCode,
                clientName.trim(),
                metadata.clientIp(),
                now.plus(REQUEST_TTL),
                now);
        return new DeviceAuthorizationStartView(
                deviceCode, userCode, "/device", REQUEST_TTL.toSeconds(), POLL_INTERVAL_SECONDS);
    }

    /** 查看待确认请求；不存在、已处理或已过期一律返回同一个 404，不泄露请求状态。 */
    @Override
    public DeviceAuthorizationPendingView pending(String userCode) {
        DeviceAuthorizationRepository.Request request = requirePending(userCode);
        return new DeviceAuthorizationPendingView(
                request.userCode(),
                request.clientName(),
                request.requestIp(),
                request.createdAt(),
                LocalDateTime.ofInstant(request.expiresAt(), ZoneId.systemDefault()));
    }

    /** 允许请求；只记录决定，会话在 CLI 兑换时才签发。 */
    @Override
    @Transactional
    public void approve(KaiwuContext context, String userCode, RequestMetadata metadata) {
        decide(context, userCode, "APPROVED", "APPROVE_DEVICE_AUTHORIZATION", metadata);
    }

    /** 拒绝请求。 */
    @Override
    @Transactional
    public void deny(KaiwuContext context, String userCode, RequestMetadata metadata) {
        decide(context, userCode, "DENIED", "DENY_DEVICE_AUTHORIZATION", metadata);
    }

    /**
     * CLI 轮询。
     *
     * <p>已允许的请求在同一事务内先一次性兑换再签发会话；兑换失败说明请求已被另一方兑换，
     * 按已过期处理，不签发第二个会话。</p>
     */
    @Override
    @Transactional
    public PollResult poll(String deviceCode, RequestMetadata metadata) {
        Instant now = clock.instant();
        DeviceAuthorizationRepository.Request request =
                repository.findByDeviceCodeHash(sha256(deviceCode)).orElse(null);
        if (request == null || !request.expiresAt().isAfter(now)) {
            return status("EXPIRED");
        }
        return switch (request.status()) {
            case "PENDING" -> status("PENDING");
            case "DENIED" -> status("DENIED");
            case "APPROVED" -> {
                if (!repository.consume(request.id(), now)) {
                    yield status("EXPIRED");
                }
                AuthService.AuthSession session =
                        authService.openDeviceSession(request.userId(), request.clientName(), metadata);
                yield new PollResult("APPROVED", session.token(), session.refreshToken(), session.absoluteExpiresAt());
            }
            default -> status("EXPIRED");
        };
    }

    /** 记录允许或拒绝并写操作审计。 */
    private void decide(
            KaiwuContext context, String userCode, String decision, String operation, RequestMetadata metadata) {
        DeviceAuthorizationRepository.Request request = requirePending(userCode);
        if (!repository.decide(request.id(), decision, context.userId(), clock.instant())) {
            throw notFound();
        }
        auditService.recordOperation(
                context,
                operation,
                "/api/auth/device/" + request.userCode(),
                "client=" + request.clientName() + ",ip=" + request.requestIp(),
                metadata);
    }

    /** 按短码取仍可确认的请求；输入统一转大写并去掉空白，兼容用户手工输入。 */
    private DeviceAuthorizationRepository.Request requirePending(String userCode) {
        String normalized = userCode == null ? "" : userCode.trim().toUpperCase(Locale.ROOT);
        return repository
                .findPending(normalized, clock.instant())
                .orElseThrow(DeviceAuthorizationServiceImpl::notFound);
    }

    /** 按客户端地址计数限流；计数放 Redis，丢失只会放宽限流，不影响正确性。 */
    private void enforceStartLimit(String clientIp) {
        String key = START_KEY_PREFIX + (clientIp == null ? "unknown" : clientIp);
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, START_WINDOW);
        }
        if (count != null && count > START_LIMIT) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "设备授权请求过于频繁，请稍后再试", "api.common.badRequest");
        }
    }

    /** 32 字节随机数的 URL 安全编码，作为只有发起方持有的设备码。 */
    private String randomDeviceCode() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** 形如 WDJB-MJHT 的 8 位短码，约 38 位熵，配合 10 分钟有效期与登录态要求足以抵御猜测。 */
    String randomUserCode() {
        StringBuilder code = new StringBuilder(9);
        for (int index = 0; index < 8; index++) {
            if (index == 4) {
                code.append('-');
            }
            code.append(USER_CODE_ALPHABET[secureRandom.nextInt(USER_CODE_ALPHABET.length)]);
        }
        return code.toString();
    }

    /** 只带状态的轮询结果。 */
    private static PollResult status(String status) {
        return new PollResult(status, null, null, null);
    }

    /** 统一的不存在错误。 */
    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "授权码不存在或已过期", "api.common.notFound");
    }

    /** 设备码摘要，与 Refresh Token 摘要同一算法。 */
    static String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 不可用", exception);
        }
    }
}
