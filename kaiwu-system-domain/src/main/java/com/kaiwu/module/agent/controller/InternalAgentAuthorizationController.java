package com.kaiwu.module.agent.controller;

import com.kaiwu.common.*;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentRemoteAuthorizationRequest;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.vo.AgentRemoteAuthorizationView;
import com.kaiwu.module.project.config.GatewayAccessProperties;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

/** Gateway 专用复核入口；沿用现有 Gateway 内部凭据，不接受 Agent 注册凭据。 */
@RestController
public class InternalAgentAuthorizationController {
    private static final JsonMapper JSON = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();
    private final GatewayAccessProperties gateway;
    private final RemoteCapabilitySource source;

    public InternalAgentAuthorizationController(GatewayAccessProperties gateway, RemoteCapabilitySource source) {
        this.gateway = gateway;
        this.source = source;
    }

    @PostMapping("/api/internal/gateway/agent-access")
    public Result<AgentRemoteAuthorizationView> authorize(HttpServletRequest http) throws IOException {
        String token = http.getHeader("X-Kaiwu-Internal-Token");
        String expected = gateway.getInternalToken();
        if (expected == null || expected.isBlank())
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "内部授权不可用", "api.common.serviceUnavailable");
        if (token == null
                || !MessageDigest.isEqual(
                        expected.getBytes(StandardCharsets.UTF_8), token.getBytes(StandardCharsets.UTF_8)))
            throw new ApiException(HttpStatus.UNAUTHORIZED, "内部凭据无效", "api.common.unauthorized");
        byte[] body = http.getInputStream().readNBytes(4097);
        if (body.length > 4096) throw new ApiException(HttpStatus.BAD_REQUEST, "请求格式错误", "api.common.badRequest");
        AgentRemoteAuthorizationRequest request;
        try {
            request = JSON.readValue(body, AgentRemoteAuthorizationRequest.class);
            if (request == null
                    || request.code() == null
                    || !request.code().matches("[a-z][a-z0-9-]*(\\.[a-z][a-z0-9-]*)+")
                    || request.code().length() > 160
                    || request.version() == null
                    || request.manifestHash() == null) throw new IllegalArgumentException();
        } catch (RuntimeException invalid) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "请求格式错误", "api.common.badRequest");
        }
        try {
            var approved =
                    source.authorize(request.code(), request.version(), request.manifestHash(), request.sessionId());
            var access = approved.access();
            return Result.ok(new AgentRemoteAuthorizationView(
                    source.user(request.sessionId()),
                    access.projectId(),
                    access.projectCode(),
                    request.code(),
                    request.version(),
                    request.manifestHash(),
                    approved.timeoutMs(),
                    access.permissions(),
                    access.projectRoleCodes(),
                    access.dataScope()));
        } catch (PlanRejectedException denied) {
            throw new ApiException(HttpStatus.FORBIDDEN, "无权执行", "api.common.forbidden");
        }
    }
}
