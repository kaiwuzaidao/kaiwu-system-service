package com.kaiwu.module.org.vo;

import java.time.LocalDateTime;
import java.util.List;

/** 部门树节点。 */
public record DepartmentView(
        String id,
        String parentId,
        String name,
        String code,
        int sortNo,
        String status,
        LocalDateTime createdAt,
        LocalDateTime updatedAt,
        List<DepartmentView> children) {}
