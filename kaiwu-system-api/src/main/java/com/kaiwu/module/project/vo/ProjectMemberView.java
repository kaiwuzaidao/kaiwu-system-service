package com.kaiwu.module.project.vo;

import java.time.LocalDateTime;
import java.util.Set;

public record ProjectMemberView(
        String userId,
        String username,
        String displayName,
        String status,
        Set<String> roleIds,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
