package com.kaiwu.module.factory.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.factory.service.ProjectGenerationService;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationRetryRequest;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationInputView;
import com.kaiwu.module.projectgeneration.vo.ProjectGenerationView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/project-generations")
public class ProjectGenerationController {

    private final ProjectGenerationService service;
    private final AuditService auditService;

    public ProjectGenerationController(ProjectGenerationService service, AuditService auditService) {
        this.service = service;
        this.auditService = auditService;
    }

    /** 提交生成任务；每个项目只能成功生成一次。 */
    @PostMapping
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectGenerationView> create(
            @Valid @RequestBody ProjectGenerationCreateRequest request, HttpServletRequest servletRequest) {
        ProjectGenerationView task =
                service.create(request, StarterContext.require().userId());
        auditService.recordOperation(
                StarterContext.require(),
                "project-factory",
                "CREATE_GENERATION",
                "/api/project-generations",
                "projectId=" + request.projectId() + ",mode=" + request.generationMode() + ",taskNo=" + task.taskNo(),
                RequestMetadata.from(servletRequest));
        return Result.ok(task);
    }

    @GetMapping
    @RequirePermission("system:project-factory:list")
    public Result<List<ProjectGenerationView>> list(@RequestParam(required = false) String projectId) {
        return Result.ok(service.list(StarterContext.require().userId(), projectId));
    }

    @GetMapping("/{taskNo}")
    @RequirePermission("system:project-factory:list")
    public Result<ProjectGenerationView> get(@PathVariable String taskNo) {
        return Result.ok(service.get(taskNo, StarterContext.require().userId()));
    }

    @GetMapping("/{taskNo}/input")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectGenerationInputView> input(@PathVariable String taskNo) {
        return Result.ok(service.editableInput(taskNo, StarterContext.require().userId()));
    }

    /** 修改输入后重试；仅 FAILED 任务可重试。 */
    @PostMapping("/{taskNo}/retry")
    @RequirePermission("system:project-factory:generate")
    public Result<ProjectGenerationView> retry(
            @PathVariable String taskNo,
            @Valid @RequestBody(required = false) ProjectGenerationRetryRequest request,
            HttpServletRequest servletRequest) {
        ProjectGenerationView task =
                service.retry(taskNo, request, StarterContext.require().userId());
        auditService.recordOperation(
                StarterContext.require(),
                "project-factory",
                "RETRY_GENERATION",
                "/api/project-generations/" + taskNo + "/retry",
                "taskNo=" + taskNo,
                RequestMetadata.from(servletRequest));
        return Result.ok(task);
    }

    /** 下载生成产物压缩包；{@code repositoryType} 取 BACKEND 或 FRONTEND。 */
    @GetMapping("/{taskNo}/download/{repositoryType}")
    @RequirePermission("system:project-factory:download")
    public ResponseEntity<org.springframework.core.io.Resource> download(
            @PathVariable String taskNo, @PathVariable String repositoryType) {
        ProjectGenerationService.Download download = service.download(
                taskNo, repositoryType, StarterContext.require().userId());
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(
                        HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment()
                                .filename(download.filename(), StandardCharsets.UTF_8)
                                .build()
                                .toString())
                .body(download.resource());
    }
}
