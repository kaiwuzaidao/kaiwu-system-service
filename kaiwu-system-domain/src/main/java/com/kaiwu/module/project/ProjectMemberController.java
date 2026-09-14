package com.kaiwu.module.project;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.project.dto.ProjectMemberRequest;
import com.kaiwu.module.project.vo.ProjectMemberView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/projects/{projectId}/members")
public class ProjectMemberController {

    private final ProjectService service;

    public ProjectMemberController(ProjectService service) {
        this.service = service;
    }

    @GetMapping
    @RequirePermission("system:project:member")
    public Result<List<ProjectMemberView>> list(@PathVariable String projectId) {
        return Result.ok(service.members(projectId));
    }

    @PutMapping("/{userId}")
    @RequirePermission("system:project:member")
    public Result<List<ProjectMemberView>> save(
            @PathVariable String projectId,
            @PathVariable String userId,
            @Valid @RequestBody ProjectMemberRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.saveMember(
                projectId, userId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    /** 移除项目成员；创建人与当前登录用户自己不允许被移除。 */
    @DeleteMapping("/{userId}")
    @RequirePermission("system:project:member")
    public Result<Void> delete(
            @PathVariable String projectId, @PathVariable String userId, HttpServletRequest servletRequest) {
        service.deleteMember(projectId, userId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }
}
