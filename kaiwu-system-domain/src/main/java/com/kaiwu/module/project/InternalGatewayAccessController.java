package com.kaiwu.module.project;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.vo.ProjectAccessView;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.http.HttpStatus;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gateway 查询业务项目入口授权（ADR 0003）。
 *
 * <p>与业务服务用的内部端点区别在身份来源：那些用项目服务凭据、项目由凭据决定；
 * 这条的调用方是 Gateway 这个平台组件，项目由 Route 绑定的 {@code projectCode} 决定，
 * 用户由 Gateway 已验证的 Access Token 决定。两者都不接受客户端提交的项目 ID。</p>
 *
 * <p>调用方必须缓存结果。这条接口在请求路径上，如果每个业务请求都同步打过来，
 * System 的可用性就成了所有业务流量的前置依赖——那正是 ADR 0003 要避免的。</p>
 */
@RestController
@RequestMapping("/api/internal/gateway")
@EnableConfigurationProperties(GatewayAccessProperties.class)
public class InternalGatewayAccessController {

    static final String INTERNAL_TOKEN_HEADER = "X-Kaiwu-Internal-Token";

    private final GatewayProjectAccessService service;
    private final GatewayAccessProperties properties;

    public InternalGatewayAccessController(GatewayProjectAccessService service, GatewayAccessProperties properties) {
        this.service = service;
        this.properties = properties;
    }

    /**
     * 解析入口授权。
     *
     * <p>不是成员时返回 403 而不是空快照：空权限的通行证会让越权表现成
     * 「进得去但什么都点不了」，把成员关系问题伪装成权限配置问题。</p>
     */
    @GetMapping("/project-access")
    public Result<ProjectAccessView> projectAccess(
            @RequestHeader(value = INTERNAL_TOKEN_HEADER, required = false) String token,
            @RequestParam("projectCode") String projectCode,
            @RequestParam("userId") String userId) {
        requireInternalToken(token);
        if (!StringUtils.hasText(projectCode) || !StringUtils.hasText(userId)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "缺少 projectCode 或 userId", "api.common.badRequest");
        }
        return Result.ok(service.resolve(projectCode, userId)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "无权访问该项目", "api.common.forbidden")));
    }

    private void requireInternalToken(String token) {
        String expected = properties.getInternalToken();
        if (!StringUtils.hasText(expected)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "项目入口授权未启用", "api.common.serviceUnavailable");
        }
        if (!StringUtils.hasText(token) || !constantTimeEquals(expected, token)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "内部凭据无效", "api.common.unauthorized");
        }
    }

    /** 定长比较：普通字符串比较的耗时随前缀匹配长度变化，可被用来逐字节猜测凭据。 */
    private static boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }
}
