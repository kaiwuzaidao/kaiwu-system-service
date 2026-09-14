package com.kaiwu.module.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.mock.web.MockHttpServletResponse;

class RefreshCookieManagerTest {

    @Test
    void writesHttpOnlyStrictCookieAndUsesConfiguredSecureFlag() {
        AuthProperties properties = new AuthProperties();
        properties.setRefreshCookieSecure(true);
        RefreshCookieManager manager = new RefreshCookieManager(properties);
        MockHttpServletResponse response = new MockHttpServletResponse();

        manager.write(response, "opaque-refresh", Instant.now().plusSeconds(3600));

        assertThat(response.getHeader(HttpHeaders.SET_COOKIE))
                .contains("kaiwu_refresh=opaque-refresh")
                .contains("Path=/api/auth")
                .contains("Max-Age=")
                .contains("Secure")
                .contains("HttpOnly")
                .contains("SameSite=Strict");
    }

    @Test
    void clearsCookieWithSameSecurityAttributes() {
        AuthProperties properties = new AuthProperties();
        properties.setRefreshCookieSecure(false);
        RefreshCookieManager manager = new RefreshCookieManager(properties);
        MockHttpServletResponse response = new MockHttpServletResponse();

        manager.clear(response);

        assertThat(response.getHeader(HttpHeaders.SET_COOKIE))
                .contains("kaiwu_refresh=")
                .contains("Path=/api/auth")
                .contains("Max-Age=0")
                .contains("HttpOnly")
                .contains("SameSite=Strict")
                .doesNotContain("Secure");
    }
}
