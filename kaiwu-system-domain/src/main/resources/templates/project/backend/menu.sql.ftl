-- ${moduleNameSql} / ${table.entityName} 项目菜单。
-- 权限三端同码：menu BUTTON、后端 @RequirePermission、前端 PermissionButton。

INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_type, route_path,
     component_path, permission_code, sort_no, visible, status,
     created_at, updated_at)
VALUES
    (${menuId}, ${projectId}, NULL, '${moduleNameSql}', 'MENU',
     '/${moduleCode}', '${modulePageName}',
     NULL, 0, 1, 'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (${listMenuId}, ${projectId}, ${menuId}, '查询', 'BUTTON',
     NULL, NULL, '${permissionPrefix}:list', 10, 1, 'ACTIVE',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (${saveMenuId}, ${projectId}, ${menuId}, '新增/编辑', 'BUTTON',
     NULL, NULL, '${permissionPrefix}:save', 20, 1, 'ACTIVE',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (${deleteMenuId}, ${projectId}, ${menuId}, '删除', 'BUTTON',
     NULL, NULL, '${permissionPrefix}:delete', 30, 1, 'ACTIVE',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id),
    menu_name = VALUES(menu_name),
    menu_type = VALUES(menu_type),
    route_path = VALUES(route_path),
    component_path = VALUES(component_path),
    sort_no = VALUES(sort_no),
    visible = 1,
    status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;
