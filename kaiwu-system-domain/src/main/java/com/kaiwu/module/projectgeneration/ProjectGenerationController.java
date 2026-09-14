package com.kaiwu.module.projectgeneration;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.projectgeneration.dto.MysqlSchemaImportRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationCreateRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationPushRequest;
import com.kaiwu.module.projectgeneration.dto.ProjectGenerationRetryRequest;
import com.kaiwu.module.projectgeneration.vo.MysqlSchemaImportView;
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
    private final MysqlSchemaImportService schemaImportService;
    private final AuditService auditService;

    public ProjectGenerationController(
            ProjectGenerationService service, MysqlSchemaImportService schemaImportService, AuditService auditService) {
        this.service = service;
        this.schemaImportService = schemaImportService;
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

    /** 向已验证为空的 GitLab 仓库执行一次初始推送；不可重复推送。 */
    @PostMapping("/{taskNo}/push")
    @RequirePermission("system:project-factory:push")
    public Result<ProjectGenerationView> push(
            @PathVariable String taskNo,
            @Valid @RequestBody ProjectGenerationPushRequest request,
            HttpServletRequest servletRequest) {
        ProjectGenerationView task =
                service.startPush(taskNo, request, StarterContext.require().userId());
        auditService.recordOperation(
                StarterContext.require(),
                "project-factory",
                "PUSH_INITIAL",
                "/api/project-generations/" + taskNo + "/push",
                "taskNo=" + taskNo,
                RequestMetadata.from(servletRequest));
        return Result.ok(task);
    }

    /**
     * 临时只读导入 MySQL 库结构，供生成蓝图参考。
     *
     * <p>只接受拆分的 host/port/database/username/password，不接受完整 JDBC URL；
     * 密码不落库、不进日志、不进入生成任务（CLAUDE.md 工程约束第 12 条）。</p>
     */
    @PostMapping("/schema/mysql")
    @RequirePermission("system:project-factory:generate")
    public Result<MysqlSchemaImportView> importMysql(
            @Valid @RequestBody MysqlSchemaImportRequest request, HttpServletRequest servletRequest) {
        MysqlSchemaImportView result = schemaImportService.importSchema(
                request, StarterContext.require().userId());
        auditService.recordOperation(
                StarterContext.require(),
                "project-factory",
                "IMPORT_MYSQL_SCHEMA",
                "/api/project-generations/schema/mysql",
                "projectId=" + request.projectId()
                        + ",database=" + request.database()
                        + ",tableCount=" + result.tableCount(),
                RequestMetadata.from(servletRequest));
        return Result.ok(result);
    }
}
