package com.kaiwu.module.audit;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.audit.vo.LoginLogView;
import com.kaiwu.module.audit.vo.OnlineSessionView;
import com.kaiwu.module.audit.vo.OperationLogView;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 登录日志、操作日志和在线会话管理接口。 */
@RestController
@RequestMapping("/api/logs")
public class LogCenterController {

    private final LogCenterService service;

    public LogCenterController(LogCenterService service) {
        this.service = service;
    }

    @GetMapping("/operations")
    @RequirePermission("system:audit:list")
    public Result<PageResult<OperationLogView>> operations(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String module,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.operations(username, module, current, size));
    }

    @GetMapping("/logins")
    @RequirePermission("system:audit:list")
    public Result<PageResult<LoginLogView>> logins(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.logins(username, status, current, size));
    }

    @GetMapping("/sessions")
    @RequirePermission("system:session:list")
    public Result<PageResult<OnlineSessionView>> sessions(
            @RequestParam(required = false) String username,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size) {
        return Result.ok(service.sessions(username, status, current, size));
    }

    @PostMapping("/sessions/{sessionId}/force-offline")
    @RequirePermission("system:session:force-offline")
    public Result<Void> forceOffline(
            @PathVariable String sessionId, @RequestParam(required = false) String reason, HttpServletRequest request) {
        service.forceOffline(sessionId, reason, StarterContext.require(), RequestMetadata.from(request));
        return Result.ok(null);
    }
}
