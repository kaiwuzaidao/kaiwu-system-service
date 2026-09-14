package com.kaiwu.module.auth;

import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import java.time.Instant;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

/**
 * 统一签发和清理浏览器 Refresh Token Cookie。
 *
 * <p>Refresh Token 不进入 JSON，也不能被 JavaScript 读取；生产环境必须通过 HTTPS
 * 下发 Secure Cookie，本地 HTTP profile 才允许关闭。</p>
 */
@Component
public class RefreshCookieManager {

    public static final String COOKIE_NAME = "kaiwu_refresh";
    private static final String COOKIE_PATH = "/api/auth";
    private final AuthProperties properties;

    public RefreshCookieManager(AuthProperties properties) {
        this.properties = properties;
    }

    /** 写入 HttpOnly 的 refresh Cookie；已过期则直接写成删除指令，不留无效 Cookie。 */
    public void write(HttpServletResponse response, String refreshToken, Instant absoluteExpiresAt) {
        long maxAgeSeconds = Duration.between(Instant.now(), absoluteExpiresAt).getSeconds();
        if (maxAgeSeconds <= 0) {
            clear(response);
            return;
        }
        add(response, refreshToken, Duration.ofSeconds(maxAgeSeconds));
    }

    public void clear(HttpServletResponse response) {
        add(response, "", Duration.ZERO);
    }

    private void add(HttpServletResponse response, String value, Duration maxAge) {
        ResponseCookie cookie = ResponseCookie.from(COOKIE_NAME, value)
                .httpOnly(true)
                .secure(properties.isRefreshCookieSecure())
                .sameSite("Strict")
                .path(COOKIE_PATH)
                .maxAge(maxAge)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }
}
