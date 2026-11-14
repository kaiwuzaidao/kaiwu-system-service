package com.kaiwu.module.operation.vo;

import java.time.LocalDateTime;
import java.util.Set;

/** 项目服务凭据元数据，不包含凭据或哈希。 */
public record ServiceCredentialView(
        String credentialId,
        String serviceCode,
        Set<String> scopes,
        String status,
        LocalDateTime expiresAt,
        LocalDateTime lastUsedAt,
        LocalDateTime createdAt) {}
