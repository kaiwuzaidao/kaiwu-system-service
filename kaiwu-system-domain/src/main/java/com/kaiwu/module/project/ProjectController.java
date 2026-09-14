package com.kaiwu.module.project;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import com.kaiwu.module.project.dto.ProjectStatusRequest;
import com.kaiwu.module.project.dto.ProjectUpdateRequest;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/projects")
public class ProjectController {

    private final ProjectService service;

    public ProjectController(ProjectService service) {
        this.service = service;
    }

    @GetMapping
    @RequirePermission("system:project:list")
    public Result<PageResult<ProjectView>> page(
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.page(keyword, current, size));
    }

    /** 取该项目的 Gateway 显式路由片段，供运维放进受管配置。 */
    @GetMapping("/{projectId}/gateway-route")
    @RequirePermission("system:project:list")
    public Result<String> gatewayRoute(@PathVariable String projectId) {
        return Result.ok(service.gatewayRoute(projectId));
    }

    @PostMapping
    @RequirePermission("system:project:create")
    public Result<ProjectView> create(
            @Valid @RequestBody ProjectCreateRequest request, HttpServletRequest servletRequest) {
        return Result.ok(service.create(request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{projectId}")
    @RequirePermission("system:project:update")
    public Result<ProjectView> update(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectUpdateRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.update(projectId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{projectId}/status")
    @RequirePermission("system:project:status")
    public Result<ProjectView> updateStatus(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectStatusRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.updateStatus(
                projectId, request.status(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }
}
