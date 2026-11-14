package com.kaiwu.module.project.agent;

/** Shared ID and nullable preview-field normalization for project-menu actions. */
final class ProjectMenuWriteIds {
    private ProjectMenuWriteIds() {}

    static String id(Object raw) {
        if (!(raw instanceof String id) || !id.matches("[1-9][0-9]{0,18}"))
            throw new IllegalArgumentException("项目菜单编号不合法");
        try {
            Long.parseLong(id);
            return id;
        } catch (NumberFormatException invalid) {
            throw new IllegalArgumentException("项目菜单编号不合法", invalid);
        }
    }

    static String empty(String value) {
        return value == null ? "" : value;
    }

    static String nullIfEmpty(String value) {
        return value == null || value.isEmpty() ? null : value;
    }
}
