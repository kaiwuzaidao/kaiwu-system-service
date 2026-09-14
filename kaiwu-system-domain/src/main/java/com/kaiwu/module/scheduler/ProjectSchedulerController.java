package com.kaiwu.module.scheduler;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/scheduler")
public class ProjectSchedulerController {

    private final ProjectSchedulerService service;

    public ProjectSchedulerController(ProjectSchedulerService service) {
        this.service = service;
    }

    @GetMapping("/jobs")
    @RequirePermission("system:scheduler:list")
    public Result<PageResult<SchedulerJobView>> jobs(
            @RequestParam(required = false) String projectId,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.jobs(projectId, current, size, StarterContext.require()));
    }

    /** 新建调度任务。 */
    @PostMapping("/jobs")
    @RequirePermission("system:scheduler:save")
    public Result<SchedulerJobView> create(
            @Valid @RequestBody SchedulerJobSaveRequest request, HttpServletRequest servletRequest) {
        SchedulerJobView job =
                service.saveJob(null, request, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(job);
    }

    /** 编辑调度任务；会递增配置版本，让正在执行的旧配置失效。 */
    @PutMapping("/jobs/{id}")
    @RequirePermission("system:scheduler:save")
    public Result<SchedulerJobView> update(
            @PathVariable String id,
            @Valid @RequestBody SchedulerJobSaveRequest request,
            HttpServletRequest servletRequest) {
        SchedulerJobView job =
                service.saveJob(id, request, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(job);
    }

    /** 逻辑删除调度任务，同时停用以免仍被调度器捞起。 */
    @DeleteMapping("/jobs/{id}")
    @RequirePermission("system:scheduler:save")
    public Result<Void> delete(@PathVariable String id, HttpServletRequest servletRequest) {
        service.deleteJob(id, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/handlers")
    @RequirePermission("system:scheduler:list")
    public Result<List<SchedulerHandlerView>> handlers(@RequestParam String projectId) {
        return Result.ok(service.handlers(projectId, StarterContext.require()));
    }

    @GetMapping("/executions")
    @RequirePermission("system:scheduler:list")
    public Result<PageResult<SchedulerExecutionView>> executions(
            @RequestParam(required = false) String projectId,
            @RequestParam(required = false) String jobId,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.executions(projectId, jobId, current, size, StarterContext.require()));
    }

    /** 轮换项目调度凭据；明文只在本次响应返回一次，之后无法再取。 */
    @PostMapping("/projects/{projectId}/credential/rotate")
    @RequirePermission("system:scheduler:credential")
    public Result<SchedulerCredentialView> rotateCredential(
            @PathVariable String projectId, HttpServletRequest servletRequest) {
        SchedulerCredentialView credential =
                service.rotateCredential(projectId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(credential);
    }
}
