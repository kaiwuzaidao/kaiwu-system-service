package com.kaiwu.module.agent.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/** 只读与写能力分别启用；地址属于运维配置，模型与 manifest 均不得覆盖。 */
@Component
@ConfigurationProperties(prefix = "kaiwu.agent.remote")
public class AgentRemoteProperties {
    private boolean enabled;
    private boolean writeEnabled;
    private String gatewayBaseUrl;

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean value) {
        enabled = value;
    }

    public boolean isWriteEnabled() {
        return writeEnabled;
    }

    public void setWriteEnabled(boolean value) {
        writeEnabled = value;
    }

    public String getGatewayBaseUrl() {
        return gatewayBaseUrl;
    }

    public void setGatewayBaseUrl(String value) {
        gatewayBaseUrl = value;
    }
}
