package com.kaiwu.module.connector.controller;

import com.kaiwu.common.ApiException;
import com.kaiwu.common.RequestMetadata;
import com.kaiwu.common.Result;
import com.kaiwu.module.connector.dto.request.ProjectStorageBindRequest;
import com.kaiwu.module.connector.dto.request.ProjectStorageStatusRequest;
import com.kaiwu.module.connector.dto.request.StorageAccountSaveRequest;
import com.kaiwu.module.connector.service.StorageService;
import com.kaiwu.module.connector.vo.ProjectStorageBindingView;
import com.kaiwu.module.connector.vo.StorageAccountView;
import com.kaiwu.module.connector.vo.StorageConnectionTestView;
import com.kaiwu.module.identity.model.CliSessionScope;
import com.kaiwu.module.operation.service.AuditService;
import com.kaiwu.starter.KaiwuContext;
import com.kaiwu.starter.RequirePermission;
import com.kaiwu.starter.StarterContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 对象存储管理接口（ADR 0039 第 8 节）：存储账号与项目绑定，只开放给平台管理员。
 * 所有写操作记审计，审计内容不含 AccessKey。
 */
@RestController
@RequestMapping("/api/storage")
public class StorageController {

    private static final String MODULE = "storage";

    private final StorageService service;
    private final AuditService auditService;

    /**
     * 创建管理接口。
     *
     * @param service 管理服务
     * @param auditService 审计服务
     */
    public StorageController(StorageService service, AuditService auditService) {
        this.service = service;
        this.auditService = auditService;
    }

    /**
     * 列出存储账号。
     *
     * @return 脱敏后的账号
     */
    @GetMapping("/accounts")
    @RequirePermission("system:storage:list")
    public Result<List<StorageAccountView>> accounts() {
        return Result.ok(service.listAccounts());
    }

    /**
     * 新建存储账号。
     *
     * @param request 账号参数
     * @param servletRequest 用于审计的请求
     * @return 保存后的账号
     */
    @PostMapping("/accounts")
    @RequirePermission("system:storage:save")
    public Result<StorageAccountView> createAccount(
            @Valid @RequestBody StorageAccountSaveRequest request, HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        rejectCliAccountWrite(actor);
        StorageAccountView saved = service.saveAccount(null, request, actor.userId());
        audit(actor, "CREATE_ACCOUNT", "/api/storage/accounts", describe(saved), servletRequest);
        return Result.ok(saved);
    }

    /**
     * 修改存储账号。
     *
     * @param id 账号 ID
     * @param request 账号参数，Secret 留空表示沿用原值
     * @param servletRequest 用于审计的请求
     * @return 保存后的账号
     */
    @PutMapping("/accounts/{id}")
    @RequirePermission("system:storage:save")
    public Result<StorageAccountView> updateAccount(
            @PathVariable String id,
            @Valid @RequestBody StorageAccountSaveRequest request,
            HttpServletRequest servletRequest) {
        KaiwuContext actor = StarterContext.require();
        rejectCliAccountWrite(actor);
        StorageAccountView saved = service.saveAccount(id, request, actor.userId());
        audit(
                actor,
                "UPDATE_ACCOUNT",
                "/api/storage/accounts/" + id,
                describe(saved) + ",secretChanged="
                        + (request.accessKeySecret() != null
                                && !request.accessKeySecret().isBlank()),
                servletRequest);
        return Result.ok(saved);
    }

    /**
     * 测试存储账号：签发一次临时凭证并写删探测对象。
     *
     * @param id 账号 ID
     * @param servletRequest 用于审计的请求
     * @return 测试结果
     */
    @PostMapping("/accounts/{id}/test")
    @RequirePermission("system:storage:test")
    public Result<StorageConnectionTestView> test(@PathVariable String id, HttpServletRequest servletRequest) {
        StorageConnectionTestView result = service.testAccount(id);
        audit(
                StarterContext.require(),
                "TEST_ACCOUNT",
                "/api/storage/accounts/" + id + "/test",
                "accountId=" + id + ",success=" + result.success() + ",latencyMs=" + result.latencyMs(),
                servletRequest);
        return Result.ok(result);
    }

    /**
     * 列出项目存储绑定。
     *
     * @param projectId 只看某个项目时传入
     * @param projectCode 按项目编码过滤，供 CLI 使用（ADR 0040）；与 projectId 同时传入时两者都要满足
     * @return 绑定
     */
    @GetMapping("/bindings")
    @RequirePermission("system:storage:list")
    public Result<List<ProjectStorageBindingView>> bindings(
            @RequestParam(required = false) String projectId, @RequestParam(required = false) String projectCode) {
        List<ProjectStorageBindingView> bindings = service.listBindings(projectId);
        if (projectCode == null || projectCode.isBlank()) {
            return Result.ok(bindings);
        }
        String code = projectCode.trim();
        return Result.ok(bindings.stream()
                .filter(binding -> code.equals(binding.projectCode()))
                .toList());
    }

    /**
     * 绑定项目存储；已有生效绑定且账号不同时旧绑定转为只读。
     *
     * @param request 绑定参数
     * @param servletRequest 用于审计的请求
     * @return 当前生效的绑定
     */
    @PostMapping("/bindings")
    @RequirePermission("system:storage:save")
    public Result<ProjectStorageBindingView> bind(
            @Valid @RequestBody ProjectStorageBindRequest request, HttpServletRequest servletRequest) {
        ProjectStorageBindingView binding = service.bind(request);
        audit(
                StarterContext.require(),
                "BIND_PROJECT",
                "/api/storage/bindings",
                "project=" + binding.projectCode() + ",storageName=" + binding.storageName() + ",accountId="
                        + binding.accountId() + ",bindingId=" + binding.id(),
                servletRequest);
        return Result.ok(binding);
    }

    /**
     * 修改绑定状态。
     *
     * @param id 绑定 ID
     * @param request 目标状态
     * @param servletRequest 用于审计的请求
     * @return 修改后的绑定
     */
    @PutMapping("/bindings/{id}/status")
    @RequirePermission("system:storage:save")
    public Result<ProjectStorageBindingView> changeStatus(
            @PathVariable String id,
            @Valid @RequestBody ProjectStorageStatusRequest request,
            HttpServletRequest servletRequest) {
        ProjectStorageBindingView binding = service.changeBindingStatus(id, request.status());
        audit(
                StarterContext.require(),
                "CHANGE_BINDING_STATUS",
                "/api/storage/bindings/" + id + "/status",
                "project=" + binding.projectCode() + ",bindingId=" + id + ",status=" + binding.status(),
                servletRequest);
        return Result.ok(binding);
    }

    /**
     * 记录审计。
     *
     * @param actor 操作人
     * @param operation 操作码
     * @param path 请求路径
     * @param detail 不含密钥的摘要
     * @param servletRequest 请求
     */
    private void audit(
            KaiwuContext actor, String operation, String path, String detail, HttpServletRequest servletRequest) {
        auditService.recordOperation(actor, MODULE, operation, path, detail, RequestMetadata.from(servletRequest));
    }

    /**
     * 生成账号审计摘要，不含 AccessKey。
     *
     * @param account 账号视图
     * @return 摘要
     */
    private static String describe(StorageAccountView account) {
        return "accountId=" + account.id() + ",code=" + account.accountCode() + ",type=" + account.providerType()
                + ",bucket=" + account.bucket() + ",enabled=" + account.enabled();
    }

    /** 命令行会话持有 system:storage:save 只为绑定项目；账号（含 AccessKey）的创建与修改只允许网页会话（ADR 0040）。 */
    static void rejectCliAccountWrite(KaiwuContext actor) {
        if (actor.permissions().contains(CliSessionScope.MARKER)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "命令行会话不能创建或修改存储账号，请在网页完成", "api.common.forbidden");
        }
    }
}
