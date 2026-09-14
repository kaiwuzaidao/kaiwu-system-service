package com.kaiwu.module.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatNoException;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import org.junit.jupiter.api.Test;

class AiProviderNetworkPolicyTest {

    @Test
    void failsClosedWithoutAnEgressProxy() {
        AiProviderNetworkPolicy policy = new AiProviderNetworkPolicy("api.example.com", "");

        assertThatThrownBy(() -> policy.verify(URI.create("https://api.example.com/v1")))
                .isInstanceOf(SecurityException.class)
                .hasMessageContaining("代理");
    }

    @Test
    void rejectsAnIpLiteralEvenWhenListed() {
        AiProviderNetworkPolicy policy = new AiProviderNetworkPolicy("127.0.0.1", "http://egress-proxy:3128");

        assertThatThrownBy(() -> policy.verify(URI.create("http://127.0.0.1:11434/v1")))
                .isInstanceOf(SecurityException.class)
                .hasMessageContaining("DNS");
    }

    @Test
    void rejectsAHostnameOutsideTheExactAllowList() {
        AiProviderNetworkPolicy policy = new AiProviderNetworkPolicy("api.example.com", "http://egress-proxy:3128");

        assertThatThrownBy(() -> policy.verify(URI.create("https://evil.example/v1")))
                .isInstanceOf(SecurityException.class)
                .hasMessageContaining("允许列表");
    }

    @Test
    void permitsAnAllowedHostnameOnlyThroughTheConfiguredProxy() {
        AiProviderNetworkPolicy policy = new AiProviderNetworkPolicy("api.example.com", "http://egress-proxy:3128");

        assertThatNoException().isThrownBy(() -> policy.verify(URI.create("https://api.example.com/v1")));
        assertThat(policy.proxySelector().select(URI.create("https://api.example.com/v1")))
                .singleElement()
                .satisfies(proxy -> assertThat(proxy.address().toString())
                        .contains("egress-proxy")
                        .contains("3128"));
    }

    @Test
    void rejectsMalformedProxyConfigurationAtStartup() {
        assertThatThrownBy(() -> new AiProviderNetworkPolicy("api.example.com", "https://user:pass@proxy/path"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("http://host:port");
    }
}
