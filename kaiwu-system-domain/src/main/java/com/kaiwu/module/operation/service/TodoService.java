package com.kaiwu.module.operation.service;

import com.kaiwu.common.PageResult;
import com.kaiwu.module.operation.dto.TodoCloseRequest;
import com.kaiwu.module.operation.dto.TodoOpenRequest;
import com.kaiwu.module.operation.vo.TodoSummaryView;
import com.kaiwu.module.operation.vo.TodoView;

/**
 * 统一待办用例（ADR 0034）：业务服务写入「打开 / 关闭」，当前用户只读自己的待办。
 */
public interface TodoService {

    /**
     * 当前用户的待办分页；收件人由调用方从会话取得，而非请求参数。
     *
     * @param userId 当前用户 ID
     * @param current 页码，从 1 开始
     * @param size 页大小
     * @param status 状态筛选，空则为 OPEN
     * @param projectCode 来源项目筛选，可空
     * @return 待办分页
     */
    PageResult<TodoView> myTodos(String userId, long current, long size, String status, String projectCode);

    /**
     * 当前用户的待办概览：未处理数、逾期数与最近若干条。
     *
     * @param userId 当前用户 ID
     * @return 概览
     */
    TodoSummaryView summary(String userId);

    /**
     * 业务服务打开（新建或重新打开）一条待办。
     *
     * @param request 打开请求
     */
    void open(TodoOpenRequest request);

    /**
     * 业务服务关闭待办，幂等。
     *
     * @param request 关闭请求
     * @return 实际关闭的待办条数，目标已关闭或不存在时为 0
     */
    long close(TodoCloseRequest request);
}
