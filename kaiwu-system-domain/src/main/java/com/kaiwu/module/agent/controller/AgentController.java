package com.kaiwu.module.agent.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.dto.AgentAskRequest;
import com.kaiwu.module.agent.service.AgentService;
import com.kaiwu.module.agent.vo.AgentAnswerView;
import com.kaiwu.module.agent.vo.AgentLocalCapabilityView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Agent 对话入口：查询或生成待确认预览；提问本身不执行写操作，会话不落库。 */
@RestController
@RequestMapping("/api/agent")
public class AgentController {

    private final AgentService service;

    public AgentController(AgentService service) {
        this.service = service;
    }

    @GetMapping("/local-capabilities")
    @RequirePermission("system:agent:ask")
    public Result<List<AgentLocalCapabilityView>> localCapabilities(HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.localCapabilities(StarterContext.require()));
    }

    @PostMapping("/ask")
    @RequirePermission("system:agent:ask")
    public Result<AgentAnswerView> ask(
            @Valid @RequestBody AgentAskRequest request,
            HttpServletRequest servletRequest,
            HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.ask(
                request.question(),
                request.history(),
                request.input(),
                StarterContext.require(),
                RequestMetadata.from(servletRequest)));
    }
}
