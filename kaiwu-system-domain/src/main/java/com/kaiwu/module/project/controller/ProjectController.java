package com.kaiwu.module.project.controller;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.identity.model.CliSessionScope;
import com.kaiwu.module.project.dto.ProjectCreateRequest;
import com.kaiwu.module.project.dto.ProjectEntryRequest;
import com.kaiwu.module.project.dto.ProjectStatusRequest;
import com.kaiwu.module.project.dto.ProjectUpdateRequest;
import com.kaiwu.module.project.service.ProjectService;
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

    /**
     * 项目分页；状态与是否内置为可选筛选，不传时行为与此前一致。
     *
     * @param keyword 编码或名称关键字
     * @param status 项目状态（ACTIVE / DISABLED / ARCHIVED），不传不过滤
     * @param builtIn 是否平台内置项目，不传不过滤
     * @param current 页码，从 1 开始
     * @param size 每页条数
     * @return 当前页项目与总数
     */
    @GetMapping
    @RequirePermission("system:project:list")
    public Result<PageResult<ProjectView>> page(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Boolean builtIn,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.page(keyword, status, builtIn, current, size));
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

    /** 设备会话只能凭专用权限登记业务项目入口。 */
    @PutMapping("/{projectId}/entry")
    @RequirePermission(CliSessionScope.PROJECT_ENTRY)
    public Result<ProjectView> updateEntry(
            @PathVariable String projectId, @Valid @RequestBody ProjectEntryRequest entry, HttpServletRequest request) {
        return Result.ok(
                service.updateEntry(projectId, entry, StarterContext.require(), RequestMetadata.from(request)));
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
