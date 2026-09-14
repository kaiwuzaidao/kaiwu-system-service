package com.kaiwu.module.gitlab;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.module.gitlab.dto.GitlabConfigSaveRequest;
import com.kaiwu.module.gitlab.vo.GitlabConfigView;
import com.kaiwu.module.gitlab.vo.GitlabConnectionTestView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.LocalDateTime;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/gitlab/config")
public class GitlabConfigController {

    private final GitlabConfigService service;
    private final GitlabApiClient client;
    private final AuditService auditService;
    private final Clock clock;

    public GitlabConfigController(
            GitlabConfigService service, GitlabApiClient client, AuditService auditService, Clock clock) {
        this.service = service;
        this.client = client;
        this.auditService = auditService;
        this.clock = clock;
    }

    @GetMapping
    @RequirePermission("system:git:list")
    public Result<GitlabConfigView> current() {
        return Result.ok(service.current());
    }

    /** 保存 GitLab 配置；令牌落库前加密，回读时掩码。 */
    @PutMapping
    @RequirePermission("system:git:save")
    public Result<GitlabConfigView> save(
            @Valid @RequestBody GitlabConfigSaveRequest request, HttpServletRequest servletRequest) {
        service.save(request);
        auditService.recordOperation(
                StarterContext.require(),
                "gitlab",
                "SAVE_CONFIG",
                "/api/gitlab/config",
                "enabled=" + request.enabled(),
                RequestMetadata.from(servletRequest));
        return Result.ok(service.current());
    }

    /** 发起一次连通性测试，结果记入配置行供页面展示。 */
    @PostMapping("/test")
    @RequirePermission("system:git:test")
    public Result<GitlabConnectionTestView> test(HttpServletRequest servletRequest) {
        LocalDateTime testedAt = LocalDateTime.now(clock);
        try {
            GitlabApiClient.TestResult result = client.testConnection();
            service.recordTest(true, result.message(), testedAt);
            auditService.recordOperation(
                    StarterContext.require(),
                    "gitlab",
                    "TEST_CONNECTION",
                    "/api/gitlab/config/test",
                    "success=true",
                    RequestMetadata.from(servletRequest));
            return Result.ok(new GitlabConnectionTestView(true, result.message(), testedAt));
        } catch (ApiException exception) {
            service.recordTest(false, exception.getMessage(), testedAt);
            throw exception;
        } catch (Exception exception) {
            service.recordTest(false, "GitLab 连接测试失败", testedAt);
            throw new ApiException(HttpStatus.BAD_GATEWAY, "GitLab 连接测试失败", "api.common.upstreamFailed");
        }
    }
}
