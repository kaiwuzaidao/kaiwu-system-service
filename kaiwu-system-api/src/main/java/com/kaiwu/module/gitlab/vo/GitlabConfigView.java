package com.kaiwu.module.gitlab.vo;

import java.time.LocalDateTime;

/**
 * GitLab 配置脱敏视图。
 */
public record GitlabConfigView(
        String baseUrl,
        String defaultGroupId,
        boolean tokenConfigured,
        boolean enabled,
        String lastTestStatus,
        String lastTestMessage,
        LocalDateTime lastTestAt) {}
