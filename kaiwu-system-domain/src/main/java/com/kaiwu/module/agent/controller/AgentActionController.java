package com.kaiwu.module.agent.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.dto.AgentActionConfirmRequest;
import com.kaiwu.module.agent.service.AgentActionService;
import com.kaiwu.module.agent.vo.AgentActionView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

/** 确认、取消及结果查询仅接受原会话；服务内部另查实时项目创建权限。 */
@RestController
@RequestMapping("/api/agent/actions")
public class AgentActionController {
    private final AgentActionService service;

    public AgentActionController(AgentActionService service) {
        this.service = service;
    }

    @PostMapping("/{id}/confirm")
    @RequirePermission("system:agent:ask")
    public Result<AgentActionView> confirm(
            @PathVariable String id,
            @Valid @RequestBody AgentActionConfirmRequest request,
            HttpServletRequest http,
            HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.confirm(
                id,
                request.confirmationToken(),
                request.confirmationPhrase(),
                StarterContext.require(),
                RequestMetadata.from(http)));
    }

    @PostMapping("/{id}/cancel")
    @RequirePermission("system:agent:ask")
    public Result<AgentActionView> cancel(
            @PathVariable String id, HttpServletRequest http, HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.cancel(id, StarterContext.require(), RequestMetadata.from(http)));
    }

    @GetMapping("/{id}")
    @RequirePermission("system:agent:ask")
    public Result<AgentActionView> status(@PathVariable String id, HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.status(id, StarterContext.require()));
    }
}
