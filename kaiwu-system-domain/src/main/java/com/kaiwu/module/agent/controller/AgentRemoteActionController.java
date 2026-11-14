package com.kaiwu.module.agent.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.dto.AgentRemoteActionConfirmRequest;
import com.kaiwu.module.agent.execution.RemoteWriteActionCoordinator;
import com.kaiwu.module.agent.vo.AgentRemoteActionView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.bind.annotation.*;

/** 浏览器确认/取消与结果核实；确认请求不允许提交新参数或覆盖冻结摘要。 */
@RestController
@RequestMapping("/api/agent/remote-actions")
public class AgentRemoteActionController {
    private final RemoteWriteActionCoordinator coordinator;

    public AgentRemoteActionController(RemoteWriteActionCoordinator coordinator) {
        this.coordinator = coordinator;
    }

    @PostMapping("/{id}/confirm")
    @RequirePermission("system:agent:ask")
    public Result<AgentRemoteActionView> confirm(
            @PathVariable String id,
            @RequestBody AgentRemoteActionConfirmRequest request,
            HttpServletRequest http,
            HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(coordinator.confirm(
                id,
                request.confirmationToken(),
                request.typedPhrase(),
                StarterContext.require(),
                RequestMetadata.from(http)));
    }

    @PostMapping("/{id}/cancel")
    @RequirePermission("system:agent:ask")
    public Result<AgentRemoteActionView> cancel(
            @PathVariable String id, HttpServletRequest http, HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(coordinator.cancel(id, StarterContext.require(), RequestMetadata.from(http)));
    }

    @GetMapping("/{id}")
    @RequirePermission("system:agent:ask")
    public Result<AgentRemoteActionView> status(@PathVariable String id, HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(coordinator.status(id, StarterContext.require()));
    }
}
