package com.kaiwu.module.ai;

import java.net.InetSocketAddress;
import java.net.ProxySelector;
import java.net.URI;
import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Fail-closed egress policy for configurable AI providers.
 *
 * <p>The application never connects to a provider directly. It only connects through an
 * explicitly configured egress proxy, while this policy restricts the requested destination to
 * an exact hostname allow-list. The proxy is the enforcement point that resolves DNS and must
 * deny private, loopback, link-local and metadata-service destinations. Keeping DNS resolution at
 * the enforcement point avoids a resolve-then-connect DNS-rebinding race in this process.
 */
@Component
public final class AiProviderNetworkPolicy {

    private final Set<String> allowedHosts;
    private final ProxySelector proxySelector;

    public AiProviderNetworkPolicy(
            @Value("${kaiwu.ai-provider.allowed-hosts:}") String allowedHosts,
            @Value("${kaiwu.ai-provider.egress-proxy-uri:}") String egressProxyUri) {
        this.allowedHosts = Arrays.stream(allowedHosts.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(value -> value.toLowerCase(Locale.ROOT))
                .collect(Collectors.toUnmodifiableSet());
        this.proxySelector = createProxySelector(egressProxyUri);
    }

    /**
     * 校验目标地址是否在允许的出站白名单内。
     *
     * <p>默认 fail-closed：没有配置白名单或代理时任何地址都拒绝，避免平台被当成
     * 任意 HTTP 出站跳板。</p>
     */
    public void verify(URI endpoint) {
        if (proxySelector == null) {
            throw new SecurityException("AI Provider 出站代理未配置");
        }
        String scheme = endpoint.getScheme();
        if (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme)) {
            throw new SecurityException("AI Provider 仅支持 HTTP 或 HTTPS");
        }
        String host = endpoint.getHost();
        if (host == null || host.isBlank() || isIpLiteral(host)) {
            throw new SecurityException("AI Provider 必须使用允许的 DNS 主机名");
        }
        if (!allowedHosts.contains(host.toLowerCase(Locale.ROOT))) {
            throw new SecurityException("AI Provider 主机不在允许列表");
        }
    }

    /** 取出站代理选择器；未配置时抛出而不是回退直连——直连会绕过整个出站管控。 */
    public ProxySelector proxySelector() {
        if (proxySelector == null) {
            throw new SecurityException("AI Provider 出站代理未配置");
        }
        return proxySelector;
    }

    private static ProxySelector createProxySelector(String configuredUri) {
        if (configuredUri == null || configuredUri.isBlank()) {
            return null;
        }
        URI uri;
        try {
            uri = URI.create(configuredUri.trim());
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("AI Provider 出站代理地址无效", exception);
        }
        if (!"http".equalsIgnoreCase(uri.getScheme())
                || uri.getHost() == null
                || uri.getHost().isBlank()
                || uri.getUserInfo() != null
                || (uri.getPath() != null && !uri.getPath().isEmpty())
                || uri.getQuery() != null
                || uri.getFragment() != null) {
            throw new IllegalArgumentException("AI Provider 出站代理必须是 http://host:port");
        }
        int port = uri.getPort();
        if (port < 1 || port > 65_535) {
            throw new IllegalArgumentException("AI Provider 出站代理端口无效");
        }
        return ProxySelector.of(InetSocketAddress.createUnresolved(uri.getHost(), port));
    }

    private static boolean isIpLiteral(String host) {
        return host.indexOf(':') >= 0 || host.chars().allMatch(ch -> Character.isDigit(ch) || ch == '.');
    }
}
