-- 项目工厂属于“研发交付”主流程。
-- 修复 V1 基线首次迁入 system 项目时遗留的顶层 parent_id；新库也由启动收敛逻辑保证。
UPDATE sys_project_menu factory
JOIN sys_project project
  ON project.id = factory.project_id
JOIN sys_project_menu delivery
  ON delivery.project_id = project.id
 AND delivery.id = 9000000000000014001
 AND delivery.menu_type = 'DIRECTORY'
SET factory.parent_id = delivery.id,
    factory.updated_at = CURRENT_TIMESTAMP
WHERE project.project_code = 'system'
  AND factory.menu_type = 'MENU'
  AND factory.route_path = '/project-factory'
  AND (factory.parent_id IS NULL OR factory.parent_id <> delivery.id);
