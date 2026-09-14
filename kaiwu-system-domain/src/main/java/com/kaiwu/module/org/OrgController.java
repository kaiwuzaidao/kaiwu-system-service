package com.kaiwu.module.org;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.org.dto.DepartmentSaveRequest;
import com.kaiwu.module.org.dto.UserDepartmentRequest;
import com.kaiwu.module.org.vo.DepartmentView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 组织架构与用户部门归属接口。 */
@RestController
@RequestMapping("/api/org")
public class OrgController {

    private final OrgService service;

    public OrgController(OrgService service) {
        this.service = service;
    }

    @GetMapping("/departments")
    @RequirePermission("system:org:list")
    public Result<List<DepartmentView>> departments() {
        return Result.ok(service.departments());
    }

    @PostMapping("/departments")
    @RequirePermission("system:org:save")
    public Result<DepartmentView> saveDepartment(
            @Valid @RequestBody DepartmentSaveRequest request, HttpServletRequest servletRequest) {
        return Result.ok(
                service.saveDepartment(request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }

    @DeleteMapping("/departments/{id}")
    @RequirePermission("system:org:delete")
    public Result<Void> deleteDepartment(@PathVariable String id, HttpServletRequest servletRequest) {
        service.deleteDepartment(id, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(null);
    }

    @GetMapping("/users/{userId}/departments")
    @RequirePermission("system:org:list")
    public Result<List<String>> userDepartments(@PathVariable String userId) {
        return Result.ok(service.userDepartments(userId));
    }

    @GetMapping("/user-departments")
    @RequirePermission("system:org:list")
    public Result<Map<String, List<String>>> userDepartments(@RequestParam List<String> userIds) {
        return Result.ok(service.userDepartments(userIds));
    }

    @PostMapping("/users/{userId}/departments")
    @RequirePermission("system:org:assign")
    public Result<List<String>> assignDepartments(
            @PathVariable String userId,
            @Valid @RequestBody UserDepartmentRequest request,
            HttpServletRequest servletRequest) {
        return Result.ok(service.assignDepartments(
                userId, request, StarterContext.require(), RequestMetadata.from(servletRequest)));
    }
}
