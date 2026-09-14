package com.kaiwu.module.notification;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 站内信投递配置。
 *
 * <p>{@code deliveryToken} 是业务服务调用投递端点的共享凭据，只从环境变量注入。
 * 未配置时投递端点直接拒绝，不提供代码内默认值。
 */
@ConfigurationProperties(prefix = "kaiwu.notification")
public class NotificationProperties {

    private String deliveryToken;

    public String getDeliveryToken() {
        return deliveryToken;
    }

    public void setDeliveryToken(String deliveryToken) {
        this.deliveryToken = deliveryToken;
    }
}
