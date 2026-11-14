package com.kaiwu.module.operation.controller;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.operation.service.ServiceCredentialManager;
import com.kaiwu.module.operation.vo.ServiceCredentialView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import java.util.Set;
import org.springframework.web.bind.annotation.*;

/** 平台项目服务凭据管理入口；新凭据签发默认关闭。 */
@RestController
@RequestMapping("/api/projects/{projectId}/service-credentials")
public class ServiceCredentialController {
    private final ServiceCredentialManager manager;

    /** 注入受事务和成员关系约束的凭据管理器。 */
    public ServiceCredentialController(ServiceCredentialManager manager) {
        this.manager = manager;
    }

    /** 平台列表权限与目标项目有效成员共同控制不含密钥的元数据读取。 */
    @GetMapping
    @RequirePermission("system:service-credential:list")
    public Result<PageResult<ServiceCredentialView>> list(
            @PathVariable String projectId,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "20") long size) {
        return Result.ok(manager.list(projectId, current, size, StarterContext.require()));
    }

    /** 管理权限与目标项目有效成员共同控制签发，明文仅返回一次。 */
    @PostMapping
    @RequirePermission("system:service-credential:manage")
    public Result<ServiceCredentialManager.Issued> issue(
            @PathVariable String projectId, @RequestBody IssueRequest request, HttpServletRequest servletRequest) {
        return Result.ok(manager.issue(
                projectId,
                request.serviceCode(),
                request.scopes(),
                request.expiresAt(),
                StarterContext.require(),
                RequestMetadata.from(servletRequest)));
    }

    /** 管理权限与目标项目有效成员共同控制撤销。 */
    @PostMapping("/{credentialId}/revoke")
    @RequirePermission("system:service-credential:manage")
    public Result<RevokeResponse> revoke(
            @PathVariable String projectId, @PathVariable String credentialId, HttpServletRequest servletRequest) {
        manager.revoke(projectId, credentialId, StarterContext.require(), RequestMetadata.from(servletRequest));
        return Result.ok(new RevokeResponse(credentialId, "REVOKED"));
    }

    /** 申请的服务身份、不可变能力范围与绝对到期时间。 */
    public record IssueRequest(String serviceCode, Set<String> scopes, Instant expiresAt) {}
    /** 撤销成功后的安全状态。 */
    public record RevokeResponse(String credentialId, String status) {}
}
