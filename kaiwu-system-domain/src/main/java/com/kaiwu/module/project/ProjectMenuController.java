package com.kaiwu.module.project;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.ProjectMenuRequest;
import com.kaiwu.module.project.dto.ProjectMenuStatusRequest;
import com.kaiwu.module.project.vo.ProjectMenuView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/projects/{projectId}/menus")
public class ProjectMenuController {

    private final ProjectService service;

    public ProjectMenuController(ProjectService service) {
        this.service = service;
    }

    @GetMapping
    @RequirePermission("system:project:menu")
    public Result<List<ProjectMenuView>> tree(@PathVariable String projectId) {
        return Result.ok(service.menus(projectId));
    }

    @PostMapping
    @RequirePermission("system:project:menu")
    public Result<ProjectMenuView> create(
            @PathVariable String projectId,
            @Valid @RequestBody ProjectMenuRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(
                service.createMenu(projectId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{menuId}")
    @RequirePermission("system:project:menu")
    public Result<ProjectMenuView> update(
            @PathVariable String projectId,
            @PathVariable String menuId,
            @Valid @RequestBody ProjectMenuRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.updateMenu(
                projectId, menuId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @PutMapping("/{menuId}/status")
    @RequirePermission("system:project:menu")
    public Result<ProjectMenuView> updateStatus(
            @PathVariable String projectId,
            @PathVariable String menuId,
            @Valid @RequestBody ProjectMenuStatusRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.updateMenuStatus(
                projectId, menuId, request.status(), StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 删除项目菜单；有子菜单时拒绝。 */
    @DeleteMapping("/{menuId}")
    @RequirePermission("system:project:menu")
    public Result<Void> delete(
            @PathVariable String projectId, @PathVariable String menuId, HttpServletRequest servletRequest) {
        service.deleteMenu(projectId, menuId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }
}
