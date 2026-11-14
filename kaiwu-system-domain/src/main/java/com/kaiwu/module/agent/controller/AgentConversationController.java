package com.kaiwu.module.agent.controller;

import com.kaiwu.common.*;
import com.kaiwu.module.agent.dto.*;
import com.kaiwu.module.agent.service.AgentConversationService;
import com.kaiwu.module.agent.store.AgentConversationStore;
import com.kaiwu.module.agent.vo.*;
import com.kaiwu.module.auth.vo.CurrentUserView;
import com.kaiwu.module.identity.service.AuthService;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.List;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

/** All resources belong to the current account. No endpoint accepts an owner/user ID. */
@RestController
@RequestMapping("/api/agent")
@Validated
public class AgentConversationController {
    private final AgentConversationStore store;
    private final AgentConversationService service;
    private final AuthService authService;

    public AgentConversationController(
            AgentConversationStore store, AgentConversationService service, AuthService authService) {
        this.store = store;
        this.service = service;
        this.authService = authService;
    }

    private String owner(HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return StarterContext.require().userId();
    }

    @GetMapping("/conversations")
    @RequirePermission("system:agent:ask")
    public Result<PageResult<AgentConversationView>> list(
            @RequestParam(defaultValue = "1") @Min(1) @Max(10000) int current, HttpServletResponse response) {
        return Result.ok(store.list(owner(response), current));
    }

    @PostMapping("/conversations")
    @RequirePermission("system:agent:ask")
    public Result<AgentConversationView> create(
            @Valid @RequestBody AgentConversationRequest request, HttpServletResponse response) {
        return Result.ok(store.create(owner(response), request));
    }

    @PatchMapping("/conversations/{id}")
    @RequirePermission("system:agent:ask")
    public Result<AgentConversationView> update(
            @PathVariable String id,
            @Valid @RequestBody AgentConversationRequest request,
            HttpServletResponse response) {
        return Result.ok(store.update(owner(response), id, request));
    }

    @DeleteMapping("/conversations/{id}")
    @RequirePermission("system:agent:ask")
    public Result<Void> delete(@PathVariable String id, HttpServletResponse response) {
        store.delete(owner(response), id);
        return Result.ok(null);
    }

    @GetMapping("/conversations/{id}/messages")
    @RequirePermission("system:agent:ask")
    public Result<PageResult<AgentMessageView>> messages(
            @PathVariable String id,
            @RequestParam(defaultValue = "1") @Min(1) @Max(10000) int current,
            HttpServletResponse response) {
        return Result.ok(store.messages(owner(response), id, current));
    }

    @PostMapping("/conversations/{id}/messages")
    @RequirePermission("system:agent:ask")
    public Result<AgentMessageResult> ask(
            @PathVariable String id,
            @Valid @RequestBody AgentMessageRequest request,
            HttpServletRequest servletRequest,
            HttpServletResponse response) {
        owner(response);
        return Result.ok(service.ask(id, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @GetMapping("/memories")
    @RequirePermission("system:agent:ask")
    public Result<List<AgentMemoryView>> memories(HttpServletResponse response) {
        return Result.ok(store.memories(owner(response)));
    }

    @PostMapping("/memories")
    @RequirePermission("system:agent:ask")
    public Result<AgentMemoryView> createMemory(
            @Valid @RequestBody AgentMemoryRequest request, HttpServletResponse response) {
        return Result.ok(store.saveMemory(owner(response), null, request));
    }

    @PatchMapping("/memories/{id}")
    @RequirePermission("system:agent:ask")
    public Result<AgentMemoryView> updateMemory(
            @PathVariable String id, @Valid @RequestBody AgentMemoryRequest request, HttpServletResponse response) {
        return Result.ok(store.saveMemory(owner(response), id, request));
    }

    @DeleteMapping("/memories/{id}")
    @RequirePermission("system:agent:ask")
    public Result<Void> deleteMemory(@PathVariable String id, HttpServletResponse response) {
        store.deleteMemory(owner(response), id);
        return Result.ok(null);
    }

    /**
     * 「登录后默认进入 AI 助手」偏好。
     *
     * <p>放在 /api/agent 下而不是 /api/auth/me/*：网关对 /api/auth 逐条放行，这里沿用已放行的
     * /api/agent/**，且只有能使用助手的用户才需要这个入口。值存在 sys_user，随用户快照下发。
     */
    @PutMapping("/preferences")
    @RequirePermission("system:agent:ask")
    public Result<CurrentUserView> updatePreferences(
            @Valid @RequestBody AgentPreferenceRequest request, HttpServletResponse response) {
        owner(response);
        return Result.ok(authService.updateAgentAutoOpen(StarterContext.require(), request.autoOpen()));
    }
}
