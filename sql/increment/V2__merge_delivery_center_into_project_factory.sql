-- 项目生成与交付验收统一收口到“项目工厂”。
-- 先删除角色授权关系，再删除已经废弃的独立“交付中心”菜单。
DELETE role_menu
FROM sys_project_role_menu role_menu
JOIN sys_project_menu menu
  ON menu.project_id = role_menu.project_id
 AND menu.id = role_menu.menu_id
JOIN sys_project project
  ON project.id = menu.project_id
WHERE project.project_code = 'system'
  AND menu.menu_type = 'MENU'
  AND menu.route_path = '/deliveries';

DELETE menu
FROM sys_project_menu menu
JOIN sys_project project ON project.id = menu.project_id
WHERE project.project_code = 'system'
  AND menu.menu_type = 'MENU'
  AND menu.route_path = '/deliveries';
