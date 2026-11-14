package com.kaiwu.module.agent.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.agent.dto.AgentCapabilityBatchReviewRequest;
import com.kaiwu.module.agent.dto.AgentCapabilityReviewRequest;
import com.kaiwu.module.agent.service.AgentRegistryService;
import com.kaiwu.module.agent.vo.AgentCapabilityDetailView;
import com.kaiwu.module.agent.vo.AgentCredentialView;
import com.kaiwu.module.agent.vo.AgentRegistrationView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

/** 管理入口复用项目查看/编辑权限，并由 Service 复核目标项目管理员身份。 */
@RestController
@RequestMapping("/api/projects/{projectId}/agent")
public class AgentRegistryController {
    private final AgentRegistryService service;

    public AgentRegistryController(AgentRegistryService service) {
        this.service = service;
    }

    @PostMapping("/credential")
    @RequirePermission("system:project:update")
    public Result<AgentCredentialView> rotate(
            @PathVariable String projectId, HttpServletRequest request, HttpServletResponse response) {
        response.setHeader("Cache-Control", "no-store");
        return Result.ok(service.rotateCredential(projectId, StarterContext.require(), RequestMetadata.from(request)));
    }

    @DeleteMapping("/credential")
    @RequirePermission("system:project:update")
    public Result<Void> revoke(@PathVariable String projectId, HttpServletRequest request) {
        service.revokeCredential(projectId, StarterContext.require(), RequestMetadata.from(request));
        return Result.ok(null);
    }

    @GetMapping("/capabilities")
    @RequirePermission("system:project:list")
    public Result<List<AgentRegistrationView>> list(@PathVariable String projectId) {
        return Result.ok(service.list(projectId, StarterContext.require()));
    }

    @GetMapping("/capabilities/{code}")
    @RequirePermission("system:project:list")
    public Result<AgentCapabilityDetailView> detail(@PathVariable String projectId, @PathVariable String code) {
        return Result.ok(service.detail(projectId, code, StarterContext.require()));
    }

    @PostMapping("/capabilities/review")
    @RequirePermission("system:project:update")
    public Result<AgentRegistrationView> review(
            @PathVariable String projectId,
            @Valid @RequestBody AgentCapabilityReviewRequest body,
            HttpServletRequest request) {
        return Result.ok(service.review(projectId, body, StarterContext.require(), RequestMetadata.from(request)));
    }

    @PostMapping("/capabilities/review-batch")
    @RequirePermission("system:project:update")
    public Result<List<AgentRegistrationView>> reviewBatch(
            @PathVariable String projectId,
            @Valid @RequestBody AgentCapabilityBatchReviewRequest body,
            HttpServletRequest request) {
        return Result.ok(service.reviewBatch(projectId, body, StarterContext.require(), RequestMetadata.from(request)));
    }
}
