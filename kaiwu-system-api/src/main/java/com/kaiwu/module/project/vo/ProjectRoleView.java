package com.kaiwu.module.project.vo;

import java.time.LocalDateTime;
import java.util.Set;

public record ProjectRoleView(
        String id,
        String projectId,
        String roleCode,
        String roleName,
        String description,
        String status,
        boolean builtIn,
        Set<String> menuIds,
        LocalDateTime createdAt,
        LocalDateTime updatedAt) {}
