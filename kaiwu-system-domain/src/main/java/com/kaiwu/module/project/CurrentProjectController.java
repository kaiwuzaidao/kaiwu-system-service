package com.kaiwu.module.project;

import com.kaiwu.common.Result;
import com.kaiwu.module.project.vo.CurrentProjectAccessView;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.module.project.vo.ProjectView;
import com.kaiwu.starter.StarterContext;
import java.util.List;
import java.util.Set;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/current/projects")
public class CurrentProjectController {

    private final ProjectService service;

    public CurrentProjectController(ProjectService service) {
        this.service = service;
    }

    @GetMapping
    public Result<List<ProjectView>> projects() {
        return Result.ok(service.currentProjects(StarterContext.require().userId()));
    }

    @GetMapping("/{projectId}/access")
    public Result<CurrentProjectAccessView> access(@PathVariable String projectId) {
        return Result.ok(
                service.currentAccess(projectId, StarterContext.require().userId()));
    }

    @GetMapping("/{projectId}/menus")
    public Result<List<ProjectMenuView>> menus(@PathVariable String projectId) {
        return Result.ok(
                service.currentAccess(projectId, StarterContext.require().userId())
                        .menus());
    }

    @GetMapping("/{projectId}/permissions")
    public Result<Set<String>> permissions(@PathVariable String projectId) {
        return Result.ok(
                service.currentAccess(projectId, StarterContext.require().userId())
                        .permissions());
    }
}
