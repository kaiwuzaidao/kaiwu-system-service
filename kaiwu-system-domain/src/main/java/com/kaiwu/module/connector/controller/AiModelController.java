package com.kaiwu.module.connector.controller;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.ai.vo.AiConnectionTestView;
import com.kaiwu.module.connector.client.OpenAiCompatibleClient;
import com.kaiwu.module.connector.dto.AiModelRoutes;
import com.kaiwu.module.connector.dto.AiModelSaveRequest;
import com.kaiwu.module.connector.service.AiProviderService;
import com.kaiwu.module.connector.vo.AiModelView;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.web.bind.annotation.*;

/** 多模型及用途绑定；继承现有 AI 配置权限，不返回密钥。 */
@RestController
@RequestMapping("/api/ai")
public class AiModelController {
    private final AiProviderService service;
    private final OpenAiCompatibleClient client;
    private final AuditService audit;
    private final Clock clock;

    /** 初始化受权限控制的配置接口。 */
    public AiModelController(
            AiProviderService service, OpenAiCompatibleClient client, AuditService audit, Clock clock) {
        this.service = service;
        this.client = client;
        this.audit = audit;
        this.clock = clock;
    }

    /** 返回模型及脱敏配置状态。 */
    @GetMapping("/models")
    @RequirePermission("system:ai:list")
    public Result<List<AiModelView>> models() {
        return Result.ok(service.models());
    }

    /** 新建或更新模型并记录审计，不记录密钥。 */
    @PostMapping("/models")
    @RequirePermission("system:ai:save")
    public Result<AiModelView> save(@Valid @RequestBody AiModelSaveRequest body, HttpServletRequest request) {
        AiModelView saved = service.saveModel(body);
        audit.recordOperation(
                StarterContext.require(),
                "ai",
                "SAVE_MODEL",
                "/api/ai/models",
                "modelId=" + saved.id(),
                RequestMetadata.from(request));
        return Result.ok(saved);
    }

    /** 返回每个用途的绑定。 */
    @GetMapping("/model-routes")
    @RequirePermission("system:ai:list")
    public Result<AiModelRoutes> routes() {
        return Result.ok(service.routes());
    }

    /** 原子保存用途绑定并记录审计。 */
    @PostMapping("/model-routes")
    @RequirePermission("system:ai:save")
    public Result<AiModelRoutes> saveRoutes(@RequestBody AiModelRoutes body, HttpServletRequest request) {
        service.saveRoutes(body);
        audit.recordOperation(
                StarterContext.require(),
                "ai",
                "SAVE_MODEL_ROUTES",
                "/api/ai/model-routes",
                "plan=" + body.planModelId() + ",answer=" + body.answerModelId(),
                RequestMetadata.from(request));
        return Result.ok(service.routes());
    }

    /** 对指定已保存配置执行最小连接测试，结果不包含凭据。 */
    @PostMapping("/models/{id}/test")
    @RequirePermission("system:ai:test")
    public Result<AiConnectionTestView> test(@PathVariable String id, HttpServletRequest request) {
        AiProviderService.TestConfig snapshot = service.prepareModelTest(id)
                .orElseThrow(() -> new com.kaiwu.common.ApiException(
                        org.springframework.http.HttpStatus.BAD_REQUEST, "模型不存在", "api.common.badRequest"));
        AiProviderService.RuntimeConfig config = snapshot.config();
        LocalDateTime now = LocalDateTime.now(clock);
        long start = System.nanoTime();
        boolean success;
        try {
            client.chat(config, "You are a connectivity probe.", "Reply with exactly OK.", 8);
            success = true;
        } catch (Exception error) {
            success = false;
        }
        String message = success ? "连接成功" : "连接测试失败，请检查模型配置及网络";
        long latency = Math.max(0, (System.nanoTime() - start) / 1_000_000);
        if (!service.recordModelTestIfRevision(id, snapshot.revision(), success, message, now)) {
            success = false;
            message = "模型配置已变更，请重新测试";
        }
        audit.recordOperation(
                StarterContext.require(),
                "ai",
                "TEST_MODEL",
                "/api/ai/models/test",
                "modelId=" + id + ",success=" + success,
                RequestMetadata.from(request));
        return Result.ok(new AiConnectionTestView(success, config.model(), latency, message, now));
    }
}
