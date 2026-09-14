package com.kaiwu.module.user.vo;

import java.time.LocalDateTime;

/**
 * 平台用户列表视图，绝不包含密码哈希。
 */
public record UserView(
        String id,
        String username,
        String displayName,
        String email,
        String status,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
