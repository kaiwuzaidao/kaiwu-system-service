package com.kaiwu.module.operation.controller;

import com.kaiwu.common.Result;
import com.kaiwu.module.operation.dto.ManagedTodoRequest;
import com.kaiwu.module.operation.service.ManagedTodoService;
import com.kaiwu.module.operation.vo.ManagedTodoReceipt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** 仅内网可达的受管投影接口，服务层按 C5 凭据限制项目、生产者和 scope。 */
@RestController
public class ManagedTodoController {
    private final ManagedTodoService service;
    /** 注入负责认证和事务的受管投递服务。 */
    public ManagedTodoController(ManagedTodoService service) {
        this.service = service;
    }

    /** 应用单收件人版本，返回服务端已存状态及摘要。 */
    @PutMapping("/api/internal/managed-todos")
    public Result<ManagedTodoReceipt> put(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody ManagedTodoRequest request) {
        return Result.ok(service.put(authorization, request));
    }

    /** 查询凭据所绑定项目与生产者自己的回执。 */
    @GetMapping("/api/internal/managed-todos/receipt")
    public Result<ManagedTodoReceipt> receipt(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestParam String bizKey,
            @RequestParam String recipientUserId) {
        return Result.ok(service.receipt(authorization, bizKey, recipientUserId));
    }
}
