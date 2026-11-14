package com.kaiwu.module.identity.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.module.auth.vo.TokenView;
import com.kaiwu.module.identity.repository.DeviceAuthorizationRepository;
import com.kaiwu.module.identity.service.impl.DeviceAuthorizationServiceImpl;
import com.kaiwu.module.identity.vo.DeviceAuthorizationStartView;
import com.kaiwu.port.AuditPort;
import com.kaiwu.starter.KaiwuContext;
import java.lang.reflect.Constructor;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpStatus;

/**
 * CLI 设备授权的状态流转、一次性兑换与限流（ADR 0035）。
 */
class DeviceAuthorizationServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-28T08:00:00Z");
    private static final RequestMetadata METADATA = new RequestMetadata("10.0.0.8", "trace-1");

    private DeviceAuthorizationRepository repository;
    private AuthService authService;
    private AuditPort auditService;
    private ValueOperations<String, String> valueOperations;
    private DeviceAuthorizationService service;
    private KaiwuContext context;

    /** 用固定时钟构造被测服务，Redis 计数默认未超限。 */
    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() throws Exception {
        repository = mock(DeviceAuthorizationRepository.class);
        authService = mock(AuthService.class);
        auditService = mock(AuditPort.class);
        StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
        valueOperations = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.increment(anyString())).thenReturn(1L);
        Constructor<DeviceAuthorizationServiceImpl> constructor =
                DeviceAuthorizationServiceImpl.class.getDeclaredConstructor(
                        DeviceAuthorizationRepository.class,
                        AuthService.class,
                        AuditPort.class,
                        StringRedisTemplate.class,
                        Clock.class);
        constructor.setAccessible(true);
        service = constructor.newInstance(
                repository, authService, auditService, redisTemplate, Clock.fixed(NOW, ZoneOffset.UTC));
        context = new KaiwuContext(
                "42",
                "session-1",
                null,
                null,
                Set.of(),
                Set.of(),
                "v1",
                "kaiwu-system-service",
                NOW,
                NOW.plusSeconds(60),
                "context-1");
    }

    /** 发起授权只把设备码摘要落库，明文设备码只返回给发起方。 */
    @Test
    void startStoresOnlyDeviceCodeDigestAndReturnsReadableUserCode() {
        DeviceAuthorizationStartView view = service.start(" Trae ", METADATA);

        ArgumentCaptor<String> digest = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> userCode = ArgumentCaptor.forClass(String.class);
        verify(repository)
                .create(
                        anyString(),
                        digest.capture(),
                        userCode.capture(),
                        eq("Trae"),
                        eq("10.0.0.8"),
                        eq(NOW.plusSeconds(600)),
                        eq(NOW));
        assertThat(digest.getValue()).isNotEqualTo(view.deviceCode()).doesNotContain(view.deviceCode());
        assertThat(view.userCode()).isEqualTo(userCode.getValue()).matches("[B-Z2-9]{4}-[B-Z2-9]{4}");
        assertThat(view.userCode()).doesNotContainPattern("[AEIOU01]");
        assertThat(view.verificationUri()).isEqualTo("/device");
        assertThat(view.expiresInSeconds()).isEqualTo(600);
    }

    /** 同一地址超过限流阈值后拒绝发起，且不再写库。 */
    @Test
    void startRejectsWhenClientExceedsRateLimit() {
        when(valueOperations.increment(anyString())).thenReturn(21L);

        assertThatThrownBy(() -> service.start("Trae", METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.TOO_MANY_REQUESTS));
        verify(repository, never()).create(any(), any(), any(), any(), any(), any(), any());
    }

    /** 允许请求只记录决定并写审计，不在此时签发会话；短码大小写与空白被归一。 */
    @Test
    void approveRecordsDecisionAndAuditWithoutIssuingSession() {
        when(repository.findPending("WDJB-MJHT", NOW)).thenReturn(Optional.of(request("PENDING", null)));
        when(repository.decide("req-1", "APPROVED", "42", NOW)).thenReturn(true);

        service.approve(context, " wdjb-mjht ", METADATA);

        verify(auditService)
                .recordOperation(
                        eq(context),
                        eq("APPROVE_DEVICE_AUTHORIZATION"),
                        eq("/api/auth/device/WDJB-MJHT"),
                        eq("client=Trae,ip=10.0.0.8"),
                        eq(METADATA));
        verify(authService, never()).openDeviceSession(any(), any(), any());
    }

    /** 并发下请求已被另一方处理时，允许失败关闭为 404。 */
    @Test
    void approveFailsClosedWhenRequestWasAlreadyDecided() {
        when(repository.findPending("WDJB-MJHT", NOW)).thenReturn(Optional.of(request("PENDING", null)));
        when(repository.decide("req-1", "APPROVED", "42", NOW)).thenReturn(false);

        assertThatThrownBy(() -> service.approve(context, "WDJB-MJHT", METADATA))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.NOT_FOUND));
        verify(auditService, never()).recordOperation(any(), any(), any(), any(), any());
    }

    /** 不存在或已过期的短码统一返回 404，不泄露请求状态。 */
    @Test
    void pendingReturnsNotFoundForUnknownCode() {
        when(repository.findPending("NOPE-NOPE", NOW)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.pending("NOPE-NOPE"))
                .isInstanceOfSatisfying(ApiException.class, error -> assertThat(error.getStatus())
                        .isEqualTo(HttpStatus.NOT_FOUND));
    }

    /** 等待中、已拒绝、未知设备码都只返回状态，不签发会话。 */
    @Test
    void pollReturnsStatusOnlyUntilApproved() {
        when(repository.findByDeviceCodeHash(anyString()))
                .thenReturn(Optional.of(request("PENDING", null)))
                .thenReturn(Optional.of(request("DENIED", "42")))
                .thenReturn(Optional.empty());

        assertThat(service.poll("device-code", METADATA).status()).isEqualTo("PENDING");
        assertThat(service.poll("device-code", METADATA).status()).isEqualTo("DENIED");
        assertThat(service.poll("device-code", METADATA).status()).isEqualTo("EXPIRED");
        verify(authService, never()).openDeviceSession(any(), any(), any());
    }

    /** 已允许的请求一次性兑换后签发会话，Refresh Token 只交给 Controller 写 Cookie。 */
    @Test
    void pollConsumesApprovedRequestOnceAndOpensSession() {
        when(repository.findByDeviceCodeHash(anyString())).thenReturn(Optional.of(request("APPROVED", "42")));
        when(repository.consume("req-1", NOW)).thenReturn(true);
        TokenView token = new TokenView("access", 900, null);
        when(authService.openDeviceSession("42", "Trae", METADATA))
                .thenReturn(new AuthService.AuthSession(token, "refresh", NOW.plusSeconds(604800)));

        DeviceAuthorizationService.PollResult result = service.poll("device-code", METADATA);

        assertThat(result.status()).isEqualTo("APPROVED");
        assertThat(result.token()).isSameAs(token);
        assertThat(result.refreshToken()).isEqualTo("refresh");
    }

    /** 兑换的条件更新失败说明已被兑换过，按过期处理，绝不签发第二个会话。 */
    @Test
    void pollNeverIssuesSecondSessionWhenAlreadyConsumed() {
        when(repository.findByDeviceCodeHash(anyString())).thenReturn(Optional.of(request("APPROVED", "42")));
        when(repository.consume("req-1", NOW)).thenReturn(false);

        assertThat(service.poll("device-code", METADATA).status()).isEqualTo("EXPIRED");
        verify(authService, never()).openDeviceSession(any(), any(), any());
    }

    /** 已过期的已允许请求不能再兑换。 */
    @Test
    void pollTreatsExpiredApprovedRequestAsExpired() {
        DeviceAuthorizationRepository.Request expired = new DeviceAuthorizationRepository.Request(
                "req-1",
                "WDJB-MJHT",
                "Trae",
                "10.0.0.8",
                "APPROVED",
                "42",
                LocalDateTime.of(2026, 10, 28, 7, 0),
                NOW.minusSeconds(1));
        when(repository.findByDeviceCodeHash(anyString())).thenReturn(Optional.of(expired));

        assertThat(service.poll("device-code", METADATA).status()).isEqualTo("EXPIRED");
        verify(repository, never()).consume(any(), any());
    }

    /** 构造一条尚未过期的请求。 */
    private static DeviceAuthorizationRepository.Request request(String status, String userId) {
        return new DeviceAuthorizationRepository.Request(
                "req-1",
                "WDJB-MJHT",
                "Trae",
                "10.0.0.8",
                status,
                userId,
                LocalDateTime.of(2026, 10, 28, 7, 55),
                NOW.plusSeconds(300));
    }
}
