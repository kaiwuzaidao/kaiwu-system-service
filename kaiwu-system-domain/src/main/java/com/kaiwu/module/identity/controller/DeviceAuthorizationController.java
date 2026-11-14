package com.kaiwu.module.identity.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.identity.dto.DeviceAuthorizationStartRequest;
import com.kaiwu.module.identity.dto.DeviceTokenRequest;
import com.kaiwu.module.identity.service.DeviceAuthorizationService;
import com.kaiwu.module.identity.service.RefreshCookieManager;
import com.kaiwu.module.identity.vo.DeviceAuthorizationPendingView;
import com.kaiwu.module.identity.vo.DeviceAuthorizationStartView;
import com.kaiwu.module.identity.vo.DeviceTokenView;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * CLI 设备授权接口（ADR 0035）。
 *
 * <p>{@code start} 与 {@code token} 是 Gateway 显式登记的 PUBLIC 端点；其余端点要求登录，
 * 且不加 {@code @RequirePermission}：允许或拒绝的是"以我自己的身份"签发会话，
 * 与自助改密一样属于登录用户的固有能力，作用对象只取自 Context。</p>
 */
@RestController
@RequestMapping("/api/auth/device")
public class DeviceAuthorizationController {

    private final DeviceAuthorizationService deviceAuthorizationService;
    private final RefreshCookieManager refreshCookieManager;

    /** 注入设备授权用例与 Refresh Cookie 写入器。 */
    public DeviceAuthorizationController(
            DeviceAuthorizationService deviceAuthorizationService, RefreshCookieManager refreshCookieManager) {
        this.deviceAuthorizationService = deviceAuthorizationService;
        this.refreshCookieManager = refreshCookieManager;
    }

    /** CLI 发起授权（PUBLIC）。 */
    @PostMapping("/start")
    public Result<DeviceAuthorizationStartView> start(
            @Valid @RequestBody DeviceAuthorizationStartRequest request, HttpServletRequest servletRequest) {
        return Result.ok(deviceAuthorizationService.start(request.clientName(), RequestMetadata.from(servletRequest)));
    }

    /**
     * CLI 轮询（PUBLIC）。
     *
     * <p>允许后与登录接口一致：Access Token 进响应体，Refresh Token 只写 HttpOnly Cookie。</p>
     */
    @PostMapping("/token")
    public Result<DeviceTokenView> token(
            @Valid @RequestBody DeviceTokenRequest request,
            HttpServletRequest servletRequest,
            HttpServletResponse servletResponse) {
        DeviceAuthorizationService.PollResult result =
                deviceAuthorizationService.poll(request.deviceCode(), RequestMetadata.from(servletRequest));
        if (result.refreshToken() != null) {
            refreshCookieManager.write(servletResponse, result.refreshToken(), result.absoluteExpiresAt());
        }
        return Result.ok(new DeviceTokenView(result.status(), result.token()));
    }

    /** 确认页查看待确认请求。 */
    @GetMapping("/{userCode}")
    public Result<DeviceAuthorizationPendingView> pending(@PathVariable String userCode) {
        StarterContext.require();
        return Result.ok(deviceAuthorizationService.pending(userCode));
    }

    /** 当前用户允许请求。 */
    @PostMapping("/{userCode}/approve")
    public Result<Void> approve(@PathVariable String userCode, HttpServletRequest servletRequest) {
        deviceAuthorizationService.approve(StarterContext.require(), userCode, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    /** 当前用户拒绝请求。 */
    @PostMapping("/{userCode}/deny")
    public Result<Void> deny(@PathVariable String userCode, HttpServletRequest servletRequest) {
        deviceAuthorizationService.deny(StarterContext.require(), userCode, RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }
}
