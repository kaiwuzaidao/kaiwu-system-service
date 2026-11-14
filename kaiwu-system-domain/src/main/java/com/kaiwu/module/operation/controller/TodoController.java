package com.kaiwu.module.operation.controller;

import com.kaiwu.common.PageResult;
import com.kaiwu.common.Result;
import com.kaiwu.module.operation.config.DeliveryTokenVerifier;
import com.kaiwu.module.operation.dto.TodoCloseRequest;
import com.kaiwu.module.operation.dto.TodoOpenRequest;
import com.kaiwu.module.operation.service.TodoService;
import com.kaiwu.module.operation.vo.TodoSummaryView;
import com.kaiwu.module.operation.vo.TodoView;
import com.kaiwu.starter.StarterContext;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 统一待办接口（ADR 0034）。
 *
 * <p>{@code /api/current/todos**} 只读取当前登录用户自己的待办，不接受 userId 参数，
 * 因此不需要额外权限码。{@code /api/internal/todos**} 是服务端到服务端的单向写入，
 * 由 Gateway 的 InternalEndpointBlockFilter 阻断外部访问，并与站内信投递共用同一个服务凭据校验。
 */
@RestController
public class TodoController {

    private final TodoService service;
    private final DeliveryTokenVerifier tokenVerifier;

    /**
     * 创建控制器。
     *
     * @param service 待办服务
     * @param tokenVerifier 投递凭据校验器
     */
    public TodoController(TodoService service, DeliveryTokenVerifier tokenVerifier) {
        this.service = service;
        this.tokenVerifier = tokenVerifier;
    }

    /**
     * 当前用户的待办分页，默认只返回未处理的。
     *
     * @param current 页码
     * @param size 页大小
     * @param status 状态筛选：OPEN（缺省）、DONE 或 CANCELLED
     * @param projectCode 来源项目筛选，可空
     * @return 待办分页
     */
    @GetMapping("/api/current/todos")
    public Result<PageResult<TodoView>> myTodos(
            @RequestParam(defaultValue = "1") long current,
            @RequestParam(defaultValue = "10") long size,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String projectCode) {
        return Result.ok(service.myTodos(StarterContext.require().userId(), current, size, status, projectCode));
    }

    /**
     * 当前用户的待办概览：未处理数、逾期数与最近若干条，供工作台使用。
     *
     * @return 概览
     */
    @GetMapping("/api/current/todos/summary")
    public Result<TodoSummaryView> summary() {
        return Result.ok(service.summary(StarterContext.require().userId()));
    }

    /**
     * 业务服务打开待办。凭据未配置时一律拒绝，不提供任何默认放行。
     *
     * @param token 请求头里的投递凭据
     * @param request 打开请求
     * @return 无数据的成功响应
     */
    @PostMapping("/api/internal/todos")
    public Result<Void> open(
            @RequestHeader(value = DeliveryTokenVerifier.HEADER, required = false) String token,
            @Valid @RequestBody TodoOpenRequest request) {
        tokenVerifier.require(token);
        service.open(request);
        return Result.ok(null);
    }

    /**
     * 业务服务关闭待办，幂等。
     *
     * @param token 请求头里的投递凭据
     * @param request 关闭请求
     * @return 实际关闭的条数
     */
    @PostMapping("/api/internal/todos/close")
    public Result<Long> close(
            @RequestHeader(value = DeliveryTokenVerifier.HEADER, required = false) String token,
            @Valid @RequestBody TodoCloseRequest request) {
        tokenVerifier.require(token);
        return Result.ok(service.close(request));
    }
}
