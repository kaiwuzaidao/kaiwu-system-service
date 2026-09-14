package com.kaiwu.module.notification;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.PageResult;
import com.kaiwu.common.Result;
import com.kaiwu.module.notification.dto.NotificationSendRequest;
import com.kaiwu.module.notification.vo.NotificationSummaryView;
import com.kaiwu.module.notification.vo.NotificationView;
import com.kaiwu.starter.StarterContext;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.HttpStatus;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 站内信接口（ADR 0007）。
 *
 * <p>{@code /api/current/notifications**} 只操作当前登录用户自己的收件箱，
 * 不接受 userId 参数，因此不需要额外权限码。
 * {@code /api/internal/notifications} 是服务端到服务端的单向投递，
 * 由 Gateway 的 InternalEndpointBlockFilter 阻断外部访问，并校验服务凭据。
 */
@RestController
@EnableConfigurationProperties(NotificationProperties.class)
public class NotificationController {

    private static final String DELIVERY_TOKEN_HEADER = "X-Kaiwu-Delivery-Token";

    private final NotificationService service;
    private final NotificationProperties properties;

    public NotificationController(NotificationService service, NotificationProperties properties) {
        this.service = service;
        this.properties = properties;
    }

    @GetMapping("/api/current/notifications")
    public Result<PageResult<NotificationView>> myNotifications(
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size,
            @RequestParam(defaultValue = "false") boolean unreadOnly,
            @RequestParam(required = false) String type) {
        return Result.ok(service.myNotifications(StarterContext.require().userId(), current, size, unreadOnly, type));
    }

    @GetMapping("/api/current/notifications/summary")
    public Result<NotificationSummaryView> summary() {
        return Result.ok(service.summary(StarterContext.require().userId()));
    }

    @PutMapping("/api/current/notifications/{id}/read")
    public Result<Void> markRead(@PathVariable String id) {
        service.markRead(id, StarterContext.require().userId());
        return Result.ok(null);
    }

    @PutMapping("/api/current/notifications/read-all")
    public Result<Long> markAllRead() {
        return Result.ok(service.markAllRead(StarterContext.require().userId()));
    }

    /**
     * 业务服务投递站内信。凭据未配置时一律拒绝，不提供任何默认放行。
     */
    @PostMapping("/api/internal/notifications")
    public Result<Void> deliver(
            @RequestHeader(value = DELIVERY_TOKEN_HEADER, required = false) String token,
            @Valid @RequestBody NotificationSendRequest request) {
        requireDeliveryToken(token);
        service.deliver(request);
        return Result.ok(null);
    }

    private void requireDeliveryToken(String token) {
        String expected = properties.getDeliveryToken();
        if (!StringUtils.hasText(expected)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "站内信投递未启用", "api.common.serviceUnavailable");
        }
        if (!StringUtils.hasText(token) || !constantTimeEquals(expected, token)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "投递凭据无效", "api.common.unauthorized");
        }
    }

    private static boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }
}
