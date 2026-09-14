package com.kaiwu.module.audit.vo;

import java.time.LocalDateTime;

/**
 * 平台写操作审计记录。
 * <p>targetType / targetId 用于按目标资源检索历史变更；changeJson 是
 * [{"field","before","after"}] JSON 数组字符串，前端解析后展示字段级 diff；
 * 未迁移到 diff 的旧调用点这三个字段为 null，前端按 detail 字符串 fallback 展示。</p>
 */
public record OperationLogView(
        String id,
        String userId,
        String username,
        String module,
        String operation,
        String requestMethod,
        String requestPath,
        int responseStatus,
        String detail,
        String targetType,
        String targetId,
        String changeJson,
        String clientIp,
        String traceId,
        LocalDateTime createdAt) {}
