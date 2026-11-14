package com.kaiwu.module.connector.client;

import java.net.InetSocketAddress;
import java.net.ProxySelector;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * 对象存储出站管控（ADR 0039 第 8 节）。
 *
 * <p>System 只连接管理员登记、且在 {@code kaiwu.storage.allowed-hosts} 白名单内的 STS 与存储主机，
 * 白名单为空时一律拒绝（fail-closed），避免存储配置被用作任意出站跳板。只接受 DNS 主机名，
 * 不接受 IP 字面量，防止直接指向元数据服务等内部地址。
 *
 * <p>与 AI 服务商不同，出站代理是可选的：存储常部署在内网（如 MinIO），强制代理会让内网部署
 * 无法使用。配置了 {@code kaiwu.storage.egress-proxy-uri} 时所有请求都经过代理。
 */
@Component
public class StorageNetworkPolicy {

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);

    private final Set<String> allowedHosts;
    private final ProxySelector proxySelector;

    /**
     * 读取白名单与可选代理。
     *
     * @param allowedHosts 逗号分隔的主机名白名单，精确匹配、不区分大小写
     * @param egressProxyUri 可选的 HTTP 出站代理，形如 {@code http://host:port}
     * @throws IllegalArgumentException 代理地址格式错误时抛出，应用启动随之失败
     */
    public StorageNetworkPolicy(
            @Value("${kaiwu.storage.allowed-hosts:}") String allowedHosts,
            @Value("${kaiwu.storage.egress-proxy-uri:}") String egressProxyUri) {
        this.allowedHosts = Arrays.stream(allowedHosts.split(","))
                .map(String::trim)
                .filter(value -> !value.isEmpty())
                .map(value -> value.toLowerCase(Locale.ROOT))
                .collect(Collectors.toUnmodifiableSet());
        this.proxySelector = createProxySelector(egressProxyUri);
    }

    /**
     * 校验目标地址可以出站。
     *
     * @param endpoint STS 或存储地址
     * @throws SecurityException 协议、主机或白名单不满足时抛出
     */
    public void verify(URI endpoint) {
        String scheme = endpoint.getScheme();
        if (!"https".equalsIgnoreCase(scheme) && !"http".equalsIgnoreCase(scheme)) {
            throw new SecurityException("存储地址仅支持 HTTP 或 HTTPS");
        }
        String host = endpoint.getHost();
        if (host == null || host.isBlank() || isIpLiteral(host)) {
            throw new SecurityException("存储地址必须使用 DNS 主机名");
        }
        if (!allowedHosts.contains(host.toLowerCase(Locale.ROOT))) {
            throw new SecurityException("存储主机不在 kaiwu.storage.allowed-hosts 白名单内：" + host);
        }
    }

    /**
     * 创建一次性使用的 HTTP 客户端：不跟随重定向，避免白名单内的地址把请求转到白名单外。
     *
     * @return 已应用代理与超时的客户端
     */
    public HttpClient newClient() {
        HttpClient.Builder builder =
                HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).followRedirects(HttpClient.Redirect.NEVER);
        if (proxySelector != null) {
            builder.proxy(proxySelector);
        } else {
            builder.proxy(HttpClient.Builder.NO_PROXY);
        }
        return builder.build();
    }

    /**
     * 解析出站代理地址。
     *
     * @param configuredUri 配置值，可为空
     * @return 代理选择器，未配置时为 {@code null}
     */
    private static ProxySelector createProxySelector(String configuredUri) {
        if (configuredUri == null || configuredUri.isBlank()) {
            return null;
        }
        URI uri;
        try {
            uri = URI.create(configuredUri.trim());
        } catch (IllegalArgumentException exception) {
            throw new IllegalArgumentException("存储出站代理地址无效", exception);
        }
        if (!"http".equalsIgnoreCase(uri.getScheme())
                || uri.getHost() == null
                || uri.getHost().isBlank()
                || uri.getUserInfo() != null
                || (uri.getPath() != null && !uri.getPath().isEmpty())
                || uri.getQuery() != null
                || uri.getFragment() != null
                || uri.getPort() < 1
                || uri.getPort() > 65_535) {
            throw new IllegalArgumentException("存储出站代理必须是 http://host:port");
        }
        return ProxySelector.of(InetSocketAddress.createUnresolved(uri.getHost(), uri.getPort()));
    }

    /**
     * 判断主机是否是 IP 字面量。
     *
     * @param host 主机
     * @return IPv4 或 IPv6 字面量时返回 {@code true}
     */
    private static boolean isIpLiteral(String host) {
        return host.indexOf(':') >= 0 || host.chars().allMatch(ch -> Character.isDigit(ch) || ch == '.');
    }
}
