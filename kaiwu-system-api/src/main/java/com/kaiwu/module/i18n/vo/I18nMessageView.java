package com.kaiwu.module.i18n.vo;

import java.time.LocalDateTime;

public record I18nMessageView(
        String id,
        String messageKey,
        String defaultText,
        String translationsJson,
        String moduleCode,
        boolean publicVisible,
        boolean requiredResource,
        String status,
        String description,
        long version,
        LocalDateTime updatedAt) {}
