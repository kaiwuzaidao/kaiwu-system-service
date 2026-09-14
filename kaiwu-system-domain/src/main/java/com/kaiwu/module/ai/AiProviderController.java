package com.kaiwu.module.ai;

import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.ai.dto.AiProviderSaveRequest;
import com.kaiwu.module.ai.vo.AiConnectionTestView;
import com.kaiwu.module.ai.vo.AiProviderView;
import com.kaiwu.module.audit.AuditService;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.net.ConnectException;
import java.net.http.HttpTimeoutException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Optional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/ai/provider")
public class AiProviderController {

    private final AiProviderService service;
    private final OpenAiCompatibleClient client;
    private final AuditService auditService;
    private final Clock clock;

    public AiProviderController(
            AiProviderService service, OpenAiCompatibleClient client, AuditService auditService, Clock clock) {
        this.service = service;
        this.client = client;
        this.auditService = auditService;
        this.clock = clock;
    }

    @GetMapping
    @RequirePermission("system:ai:list")
    public Result<AiProviderView> current() {
        return Result.ok(service.current());
    }

    /** 保存 AI 服务配置；API Key 落库前加密，回读时掩码。 */
    @PostMapping
    @RequirePermission("system:ai:save")
    public Result<AiProviderView> save(
            @Valid @RequestBody AiProviderSaveRequest request, HttpServletRequest servletRequest) {
        service.save(request);
        auditService.recordOperation(
                StarterContext.require(),
                "ai",
                "SAVE_PROVIDER",
                "/api/ai/provider",
                "provider=" + request.providerName().trim()
                        + ",model=" + request.model().trim()
                        + ",enabled=" + (request.enabled() == null || request.enabled()),
                RequestMetadata.from(servletRequest));
        return Result.ok(service.current());
    }

    /** 用当前配置发起一次连通性测试，结果记入配置行供页面展示。 */
    @PostMapping("/test")
    @RequirePermission("system:ai:test")
    public Result<AiConnectionTestView> test(HttpServletRequest servletRequest) {
        Optional<AiProviderService.RuntimeConfig> optional = service.effective();
        LocalDateTime testedAt = LocalDateTime.now(clock);
        if (optional.isEmpty()) {
            // 未启用同样要落库：否则运行状态会一直停留在上一次成功的结果上，
            // 用户点多少次测试都清不掉那条过期记录，看到的状态与实际不符。
            String disabled = "大模型配置未启用";
            service.recordTest(false, disabled, testedAt);
            return Result.ok(new AiConnectionTestView(false, null, 0, disabled, testedAt));
        }
        AiProviderService.RuntimeConfig config = optional.get();
        long start = System.nanoTime();
        boolean success = false;
        String message;
        try {
            client.chat(config, "You are a connectivity probe.", "Reply with exactly OK.", 8);
            success = true;
            message = "连接成功";
        } catch (Exception exception) {
            message = safeMessage(exception);
        }
        long latency = Math.max(0, (System.nanoTime() - start) / 1_000_000);
        service.recordTest(success, message, testedAt);
        auditService.recordOperation(
                StarterContext.require(),
                "ai",
                "TEST_PROVIDER",
                "/api/ai/provider/test",
                "model=" + config.model() + ",success=" + success + ",latencyMs=" + latency,
                RequestMetadata.from(servletRequest));
        return Result.ok(new AiConnectionTestView(success, config.model(), latency, message, testedAt));
    }

    /**
     * 把测试异常压成可回显、可诊断且不含内部实现细节的提示。
     *
     * <p>{@code IllegalStateException} 全部由 {@link OpenAiCompatibleClient} 自行构造，内容是中文
     * 诊断信息加 Provider 返回的错误摘要（不含 API Key），可以直接展示；其余异常只回通用文案，
     * 仅用底层异常类名补充线索，避免把堆栈内部信息带到界面上。
     *
     * <p>原实现用消息前缀白名单放行，DNS、SSL 等失败会被压成"连接测试失败"，配置页因此无法定位问题。
     */
    private String safeMessage(Exception exception) {
        Throwable cause = exception;
        while (cause.getCause() != null) {
            cause = cause.getCause();
        }
        if (cause instanceof HttpTimeoutException) return "连接模型服务超时";
        if (cause instanceof ConnectException) return "无法连接模型服务";
        String message = exception.getMessage();
        if (exception instanceof IllegalStateException && message != null && !message.isBlank()) {
            // 底层原因的文字已经拼进消息时不再补类名，避免"…出站代理未配置（SecurityException）"这种冗余。
            boolean causeAlreadyDescribed =
                    cause == exception || cause.getMessage() == null || message.contains(cause.getMessage());
            return causeAlreadyDescribed
                    ? message
                    : message + "（" + cause.getClass().getSimpleName() + "）";
        }
        return "连接测试失败";
    }
}
