package com.kaiwu.module.operation.dto;

import java.time.Instant;

/** 受管投递的原始业务事实；生产者和项目权威身份由服务凭据确定。 */
public record ManagedTodoRequest(
        String projectCode,
        String bizKey,
        String recipientUserId,
        Long sequence,
        String state,
        Boolean terminal,
        Instant operationCreatedAt,
        String title,
        String content,
        String linkUrl,
        Instant dueAt) {}
