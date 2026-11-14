package com.kaiwu.module.project.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.service.ProjectBackendService;
import com.kaiwu.module.project.vo.BackendServiceView;
import com.kaiwu.module.project.vo.GatewayRoutesView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import org.springframework.web.bind.annotation.*;

/** 项目后端服务登记和审核路由片段，不自动发布到 Gateway。 */
@RestController
@RequestMapping("/api/projects/{projectId}")
public class ProjectBackendServiceController {
    private final ProjectBackendService service;
    /** 注入目标项目管理员检查和事务审计服务。 */
    public ProjectBackendServiceController(ProjectBackendService service) {
        this.service = service;
    }
    /** 项目管理员查看服务。 */
    @GetMapping("/backend-services")
    @RequirePermission("system:project:list")
    public Result<List<BackendServiceView>> list(@PathVariable String projectId) {
        return Result.ok(service.list(projectId, StarterContext.require()));
    }
    /** 登记非默认服务。 */
    @PostMapping("/backend-services")
    @RequirePermission("system:project:update")
    public Result<BackendServiceView> create(
            @PathVariable String projectId, @RequestBody CreateRequest body, HttpServletRequest request) {
        return Result.ok(service.create(
                projectId,
                body.serviceCode(),
                body.serviceUrl(),
                StarterContext.require(),
                RequestMetadata.from(request)));
    }
    /** 修改地址；default 与原项目地址一致。 */
    @PutMapping("/backend-services/{serviceCode}")
    @RequirePermission("system:project:update")
    public Result<BackendServiceView> update(
            @PathVariable String projectId,
            @PathVariable String serviceCode,
            @RequestBody AddressRequest body,
            HttpServletRequest request) {
        return Result.ok(service.updateUrl(
                projectId, serviceCode, body.serviceUrl(), StarterContext.require(), RequestMetadata.from(request)));
    }
    /** 启用或停用某服务的后续可发布片段。 */
    @PutMapping("/backend-services/{serviceCode}/status")
    @RequirePermission("system:project:update")
    public Result<BackendServiceView> status(
            @PathVariable String projectId,
            @PathVariable String serviceCode,
            @RequestBody StatusRequest body,
            HttpServletRequest request) {
        return Result.ok(service.updateStatus(
                projectId, serviceCode, body.status(), StarterContext.require(), RequestMetadata.from(request)));
    }
    /** 查看所有有地址且启用的路由片段。 */
    @GetMapping("/gateway-routes")
    @RequirePermission("system:project:list")
    public Result<GatewayRoutesView> routes(@PathVariable String projectId) {
        return Result.ok(service.routes(projectId, StarterContext.require()));
    }
    /** 创建请求的服务标识和上游地址。 */
    public record CreateRequest(String serviceCode, String serviceUrl) {}
    /** 更新请求的上游地址。 */
    public record AddressRequest(String serviceUrl) {}
    /** 更新请求的启用状态。 */
    public record StatusRequest(String status) {}
}
