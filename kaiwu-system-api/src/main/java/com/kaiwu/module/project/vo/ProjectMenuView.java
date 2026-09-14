package com.kaiwu.module.project.vo;

import java.time.LocalDateTime;
import java.util.List;

public record ProjectMenuView(
        String id,
        String projectId,
        String parentId,
        String menuName,
        /** 引用的国际化资源 key；非空即启用引用式国际化（ADR 0013） */
        String menuNameKey,
        String menuType,
        String routePath,
        String componentPath,
        String permissionCode,
        String icon,
        int sortNo,
        boolean visible,
        String status,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        List<ProjectMenuView> children) {}
