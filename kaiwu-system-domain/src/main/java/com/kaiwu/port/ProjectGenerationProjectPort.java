package com.kaiwu.port;

import com.kaiwu.module.project.vo.ProjectView;

/** 项目工厂读取项目与注册生成菜单的边界。 */
public interface ProjectGenerationProjectPort {

    ProjectView requireProjectAdmin(String projectId, String userId);

    String upsertGeneratedMenu(
            String id,
            String projectId,
            String parentId,
            String name,
            String type,
            String path,
            String component,
            String permission,
            int sortNo);

    void grantMenuToAdmin(String projectId, String menuId);
}
