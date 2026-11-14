package com.kaiwu.module.agent.controller;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.catalog.RemoteCapabilitySource;
import com.kaiwu.module.agent.dto.AgentRemoteWriteAuthorizationRequest;
import com.kaiwu.module.agent.planning.PlanRejectedException;
import com.kaiwu.module.agent.service.AgentRemoteActionService;
import com.kaiwu.module.agent.vo.AgentRemoteWriteAuthorizationView;
import com.kaiwu.module.project.config.GatewayAccessProperties;
import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.StreamReadFeature;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.json.JsonMapper;

/** 与只读授权隔离的 Gateway 写用途入口。仅内部凭据可调用，绝不接受客户端自报 confirmed。 */
@RestController
public class InternalAgentWriteAuthorizationController {
    private static final JsonMapper JSON = JsonMapper.builder()
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            .enable(DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .enable(StreamReadFeature.STRICT_DUPLICATE_DETECTION)
            .build();

    private final GatewayAccessProperties gateway;
    private final RemoteCapabilitySource source;
    private final AgentRemoteActionService actions;

    public InternalAgentWriteAuthorizationController(
            GatewayAccessProperties gateway, RemoteCapabilitySource source, AgentRemoteActionService actions) {
        this.gateway = gateway;
        this.source = source;
        this.actions = actions;
    }

    @PostMapping("/api/internal/gateway/agent-write-access")
    public Result<AgentRemoteWriteAuthorizationView> authorize(HttpServletRequest http) throws IOException {
        String expected = gateway.getInternalToken();
        String token = http.getHeader("X-Kaiwu-Internal-Token");
        if (expected == null || expected.isBlank())
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "内部授权不可用", "api.common.serviceUnavailable");
        if (token == null
                || !MessageDigest.isEqual(
                        expected.getBytes(StandardCharsets.UTF_8), token.getBytes(StandardCharsets.UTF_8)))
            throw new ApiException(HttpStatus.UNAUTHORIZED, "内部凭据无效", "api.common.unauthorized");
        byte[] body = http.getInputStream().readNBytes(4097);
        if (body.length > 4096) throw invalid();
        AgentRemoteWriteAuthorizationRequest request;
        try {
            request = JSON.readValue(body, AgentRemoteWriteAuthorizationRequest.class);
            validate(request);
        } catch (RuntimeException badRequest) {
            throw invalid();
        }
        try {
            String user = source.user(request.sessionId());
            if ("PREVIEW".equals(request.operation())) {
                var approved = source.authorizeWrite(
                        request.code(), request.version(), request.manifestHash(), request.sessionId());
                return Result.ok(view(request, user, approved.access(), approved.timeoutMs(), false));
            }
            var authorized = actions.authorizeDelegation(request, user);
            return Result.ok(view(request, authorized.userId(), authorized.access(), authorized.timeoutMs(), true));
        } catch (PlanRejectedException | ApiException denied) {
            throw new ApiException(HttpStatus.FORBIDDEN, "无权执行", "api.common.forbidden");
        }
    }

    private static AgentRemoteWriteAuthorizationView view(
            AgentRemoteWriteAuthorizationRequest request,
            String userId,
            com.kaiwu.module.project.vo.ProjectAccessView access,
            int timeoutMs,
            boolean confirmed) {
        return new AgentRemoteWriteAuthorizationView(
                userId,
                access.projectId(),
                access.projectCode(),
                request.operation(),
                request.code(),
                request.version(),
                request.manifestHash(),
                request.paramsHash(),
                request.preconditionsHash(),
                request.previewHash(),
                request.actionId(),
                request.actionExpiresAt(),
                request.correlationId(),
                confirmed,
                timeoutMs,
                access.permissions(),
                access.projectRoleCodes(),
                access.dataScope());
    }

    private static void validate(AgentRemoteWriteAuthorizationRequest value) {
        if (value == null
                || value.sessionId() == null
                || !value.sessionId().matches("[A-Za-z0-9-]{1,128}")
                || value.code() == null
                || value.code().length() > 160
                || !value.code().matches("[a-z][a-z0-9-]*(\\.[a-z][a-z0-9-]*)+")
                || value.version() == null
                || value.version().length() > 16
                || !value.version().matches("[0-9]+(?:\\.[0-9]+){0,2}")
                || !hash(value.manifestHash())
                || !hash(value.paramsHash())
                || value.correlationId() == null
                || !value.correlationId().matches("[A-Za-z0-9-]{1,64}")) throw invalid();
        if ("PREVIEW".equals(value.operation())) {
            if (value.preconditionsHash() != null
                    || value.previewHash() != null
                    || value.actionId() != null
                    || value.actionExpiresAt() != null) throw invalid();
        } else if ("EXECUTE".equals(value.operation()) || "RESULT".equals(value.operation())) {
            if (!hash(value.preconditionsHash())
                    || !hash(value.previewHash())
                    || value.actionId() == null
                    || !value.actionId().matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
                    || value.actionExpiresAt() == null
                    || value.actionExpiresAt() <= 0) throw invalid();
        } else {
            throw invalid();
        }
    }

    private static boolean hash(String value) {
        return value != null && value.matches("[0-9a-f]{64}");
    }

    private static ApiException invalid() {
        return new ApiException(HttpStatus.BAD_REQUEST, "请求格式错误", "api.common.badRequest");
    }
}
