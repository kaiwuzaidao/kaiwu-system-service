package com.kaiwu.module.agent.controller;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.dto.AgentCapabilityRevision;
import com.kaiwu.module.agent.protocol.AgentManifestCodec;
import com.kaiwu.module.agent.service.AgentRegistryService;
import com.kaiwu.module.agent.vo.AgentRegistrationView;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.io.IOException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/** 内网机器注册入口；独立 kagent 凭据认证，不使用用户 Context，不配置 Gateway 外部路由。 */
@RestController
@RequestMapping("/api/internal/agent/capabilities")
public class InternalAgentRegistryController {
    private final AgentRegistryService service;

    public InternalAgentRegistryController(AgentRegistryService service) {
        this.service = service;
    }

    @PostMapping(value = "/register", consumes = "application/json")
    public Result<AgentRegistrationView> register(
            @RequestHeader(value = "Authorization", required = false) String authorization, HttpServletRequest request)
            throws IOException {
        // Read at most one byte above the ceiling, including requests with no Content-Length.
        byte[] body = request.getInputStream().readNBytes(AgentManifestCodec.MAX_BYTES + 1);
        if (body.length > AgentManifestCodec.MAX_BYTES) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "能力清单超过大小限制", "api.validation.failed");
        }
        return Result.ok(service.register(authorization, body));
    }

    @PostMapping("/heartbeat")
    public Result<AgentRegistrationView> heartbeat(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AgentCapabilityRevision revision) {
        return Result.ok(service.heartbeat(authorization, revision));
    }
}
