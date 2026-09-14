package com.kaiwu.module.metadata.vo;

import java.time.LocalDateTime;

public record ConfigView(
        String id,
        String scopeId,
        String configKey,
        String configValue,
        String valueI18nKey,
        String valueType,
        boolean secret,
        String status,
        String description,
        int sortNo,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
