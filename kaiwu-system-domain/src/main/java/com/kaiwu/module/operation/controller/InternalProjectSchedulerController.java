package com.kaiwu.module.operation.controller;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.Result;
import com.kaiwu.module.operation.dto.request.SchedulerClaimRequest;
import com.kaiwu.module.operation.dto.request.SchedulerCompletionRequest;
import com.kaiwu.module.operation.dto.request.SchedulerLeaseRequest;
import com.kaiwu.module.operation.dto.request.SchedulerSyncRequest;
import com.kaiwu.module.operation.service.ProjectSchedulerService;
import com.kaiwu.module.operation.vo.SchedulerClaimView;
import com.kaiwu.module.operation.vo.SchedulerJobView;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/internal/scheduler")
public class InternalProjectSchedulerController {

    private final ProjectSchedulerService service;

    public InternalProjectSchedulerController(ProjectSchedulerService service) {
        this.service = service;
    }

    @PostMapping("/sync")
    public Result<List<SchedulerJobView>> synchronize(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
            @Valid @RequestBody SchedulerSyncRequest request) {
        return Result.ok(service.synchronize(bearer(authorization), request));
    }

    @PostMapping("/claim")
    public Result<SchedulerClaimView> claim(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
            @Valid @RequestBody SchedulerClaimRequest request) {
        return Result.ok(service.claim(bearer(authorization), request));
    }

    @PostMapping("/executions/{executionId}/complete")
    public Result<Void> complete(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
            @PathVariable String executionId,
            @Valid @RequestBody SchedulerCompletionRequest request) {
        service.complete(bearer(authorization), executionId, request);
        return Result.ok(null);
    }

    @PostMapping("/executions/{executionId}/renew")
    public Result<Boolean> renew(
            @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization,
            @PathVariable String executionId,
            @Valid @RequestBody SchedulerLeaseRequest request) {
        return Result.ok(service.renew(bearer(authorization), executionId, request));
    }

    private static String bearer(String authorization) {
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "缺少项目调度凭据", "api.common.unauthorized");
        }
        return authorization.substring("Bearer ".length()).trim();
    }
}
