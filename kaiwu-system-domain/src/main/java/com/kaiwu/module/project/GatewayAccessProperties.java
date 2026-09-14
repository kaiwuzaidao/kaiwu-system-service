package com.kaiwu.module.project;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Gateway 读取项目入口授权时使用的内部凭据配置。
 *
 * <p>{@code internalToken} 只从环境变量注入；未配置时入口授权端点直接拒绝，
 * 不提供代码内默认值——一个有默认值的内部凭据等于没有凭据。</p>
 */
@ConfigurationProperties(prefix = "kaiwu.gateway-access")
public class GatewayAccessProperties {

    private String internalToken;

    public String getInternalToken() {
        return internalToken;
    }

    public void setInternalToken(String internalToken) {
        this.internalToken = internalToken;
    }
}
