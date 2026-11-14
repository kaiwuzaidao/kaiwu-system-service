package com.kaiwu.module.project.controller;

import com.kaiwu.common.Result;
import com.kaiwu.module.project.service.ProjectMemberQueryService;
import com.kaiwu.module.project.vo.ProjectMemberEligibilityResult;
import com.kaiwu.module.project.vo.ProjectMemberRoleResult;
import java.util.List;
import org.springframework.web.bind.annotation.*;

/** 内部候选人查询；只接受绑定项目及 member:read 的服务凭据。 */
@RestController
@RequestMapping("/api/internal/projects/{projectCode}/members")
public class InternalProjectMemberController {
    private final ProjectMemberQueryService service;
    /** 注入受限查询服务。 */
    public InternalProjectMemberController(ProjectMemberQueryService service) {
        this.service = service;
    }
    /** 一次返回角色的完整成员，超限整体失败。 */
    @GetMapping("/by-role")
    public Result<ProjectMemberRoleResult> byRole(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable String projectCode,
            @RequestParam String roleCode) {
        return Result.ok(service.byRole(authorization, projectCode, roleCode));
    }
    /** 查询既有候选人的有效资格。 */
    @PostMapping("/eligibility")
    public Result<ProjectMemberEligibilityResult> eligibility(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable String projectCode,
            @RequestBody EligibilityRequest request) {
        return Result.ok(service.eligibility(authorization, projectCode, request.userIds(), request.roleCode()));
    }
    /** 批量候选 ID 与可选角色限制。 */
    public record EligibilityRequest(List<String> userIds, String roleCode) {}
}
