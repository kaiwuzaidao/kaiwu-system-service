package com.kaiwu.module.operation.config;

import com.kaiwu.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * 业务服务向 System 投递（站内信、待办）时的服务凭据校验。
 *
 * <p>两类投递端点共用同一个凭据与同一份校验实现，避免安全逻辑在多个控制器里各写一份、日后漂移。
 * 凭据未配置时一律拒绝，不提供任何默认放行；比较使用常量时间，避免经响应时间猜测凭据。
 */
@Component
@EnableConfigurationProperties(NotificationProperties.class)
public class DeliveryTokenVerifier {

    /** 业务服务携带投递凭据的请求头。 */
    public static final String HEADER = "X-Kaiwu-Delivery-Token";

    private final NotificationProperties properties;

    /**
     * 创建校验器。
     *
     * @param properties 站内信投递配置，凭据来自其中的 {@code deliveryToken}
     */
    public DeliveryTokenVerifier(NotificationProperties properties) {
        this.properties = properties;
    }

    /**
     * 校验请求携带的投递凭据，不通过则抛出异常。
     *
     * @param token 请求头里的凭据，可能为空
     * @throws ApiException 凭据未配置时 503，凭据缺失或不匹配时 401
     */
    public void require(String token) {
        String expected = properties.getDeliveryToken();
        if (!StringUtils.hasText(expected)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "站内信投递未启用", "api.common.serviceUnavailable");
        }
        if (!StringUtils.hasText(token) || !constantTimeEquals(expected, token)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "投递凭据无效", "api.common.unauthorized");
        }
    }

    /** 常量时间比较，凭据长度与内容都不通过响应时间泄露。 */
    private static boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }
}
