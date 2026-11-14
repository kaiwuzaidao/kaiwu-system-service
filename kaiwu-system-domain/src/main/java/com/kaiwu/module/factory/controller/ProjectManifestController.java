package com.kaiwu.module.factory.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.factory.dto.ProjectManifestRequest;
import com.kaiwu.module.factory.service.ProjectManifestExportService;
import com.kaiwu.module.factory.service.ProjectManifestService;
import com.kaiwu.module.factory.vo.ProjectHandoverView;
import com.kaiwu.module.factory.vo.ProjectManifestExportView;
import com.kaiwu.module.factory.vo.ProjectManifestPlanView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 业务项目平台资源清单同步接口（ADR 0036）。
 *
 * <p>入口权限沿用项目工厂的生成权限；具体写入还要求字典、配置、国际化、菜单与角色的保存权限，
 * 由服务在计划里报告、在执行时整体校验。</p>
 */
@RestController
@RequestMapping("/api/projects/{projectId}/manifest")
public class ProjectManifestController {

    private final ProjectManifestService service;
    private final ProjectManifestExportService exporter;

    /** 注入清单同步与移交包导出用例。 */
    public ProjectManifestController(ProjectManifestService service, ProjectManifestExportService exporter) {
        this.service = service;
        this.exporter = exporter;
    }

    /** 导出项目配置移交包（全量快照，只读，ADR 0042）。 */
    @GetMapping("/export")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectManifestExportView> export(@PathVariable String projectId, HttpServletRequest servletRequest) {
        String forwarded = servletRequest.getHeader("X-Forwarded-Host");
        String host = forwarded != null && !forwarded.isBlank() ? forwarded : servletRequest.getServerName();
        return Result.ok(exporter.export(projectId, StarterContext.require(), host));
    }

    /** 计算同步计划，不改变数据。 */
    @PostMapping("/plan")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectManifestPlanView> plan(
            @PathVariable String projectId, @Valid @RequestBody ProjectManifestRequest request) {
        return Result.ok(service.plan(projectId, request, StarterContext.require()));
    }

    /** 按计划哈希执行同步。 */
    @PostMapping("/apply")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectManifestPlanView> apply(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectManifestRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.apply(projectId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 项目的移交记录，最新在前（ADR 0042）。 */
    @GetMapping("/handovers")
    @RequirePermission("system:project-factory:generate")
    public Result<List<ProjectHandoverView>> handovers(@PathVariable String projectId) {
        return Result.ok(service.handovers(projectId, StarterContext.require()));
    }

    /** 一条移交记录及其条目明细。 */
    @GetMapping("/handovers/{handoverId}")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectHandoverView> handover(@PathVariable String projectId, @PathVariable String handoverId) {
        return Result.ok(service.handover(projectId, handoverId, StarterContext.require()));
    }
}
