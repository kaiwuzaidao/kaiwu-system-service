package com.kaiwu.module.projecthealth;

import com.kaiwu.common.Result;
import com.kaiwu.module.projecthealth.vo.ProjectHealthView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 只读项目体检接口（ADR 0012）。体检只报告，不阻断任何流程。 */
@RestController
public class ProjectHealthController {

    private final ProjectHealthService service;

    public ProjectHealthController(ProjectHealthService service) {
        this.service = service;
    }

    @PostMapping("/api/projects/{projectId}/health-check")
    @RequirePermission("system:project:health")
    public Result<ProjectHealthView> check(@PathVariable String projectId) {
        return Result.ok(service.check(projectId, StarterContext.require().userId()));
    }

    @GetMapping("/api/projects/{projectId}/health-check")
    @RequirePermission("system:project:health")
    public Result<ProjectHealthView> latest(@PathVariable String projectId) {
        return Result.ok(service.latest(projectId, StarterContext.require().userId()));
    }

    @PostMapping("/api/projects/{projectId}/health-check/enabled")
    @RequirePermission("system:project:health")
    public Result<Void> setEnabled(@PathVariable String projectId, @RequestParam boolean enabled) {
        service.setEnabled(projectId, StarterContext.require().userId(), enabled);
        return Result.ok(null);
    }
}
