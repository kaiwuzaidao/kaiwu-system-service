-- 修复：System 项目缺失全部按钮级菜单，导致 project-admin 无任何操作权限。
--
-- 根因在 SystemBootstrapMapper.importLegacyMenus 的过滤条件：
--
--     WHERE menu.route_path NOT IN ('/roles', '/menus')
--
-- BUTTON 类型的菜单 route_path 均为 NULL，而 SQL 三值逻辑下
-- NULL NOT IN (...) 求值为 NULL 而非 TRUE，整个 WHERE 判定为假。
-- 结果 sys_menu 的 28 条里，23 条 route_path 为 NULL 的按钮全被静默过滤，
-- 只有 5 个带路径的目录节点被导入。
--
-- 症状：全新部署后用初始 admin 登录，用户管理、项目管理、参数配置、
--       字典管理等页面的操作接口一律返回
--       403 {"messageKey":"starter.permissionDenied"}。
--
-- Mapper 侧的条件已改为 (route_path IS NULL OR route_path NOT IN (...))，
-- 但 importLegacyMenus 带有「项目已有菜单则整体跳过」的守卫，既有实例
-- 不会自愈，因此这里补齐历史数据。
--
-- ID 沿用自举时的偏移规则：sys_project_menu.id = 9000000000000010000 + sys_menu.id。

INSERT IGNORE INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_type, route_path,
     component_path, permission_code, sort_no, visible, status,
     created_at, updated_at)
SELECT 9000000000000010000 + menu.id,
       project.id,
       CASE WHEN menu.parent_id IS NULL
            THEN NULL ELSE 9000000000000010000 + menu.parent_id END,
       menu.menu_name, menu.menu_type, menu.route_path, menu.component_path,
       menu.permission_code, menu.sort_no, menu.visible,
       CASE WHEN menu.status = 'ENABLED' THEN 'ACTIVE' ELSE 'DISABLED' END,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_menu menu
JOIN sys_project project ON project.project_code = 'system'
WHERE (menu.route_path IS NULL
       OR menu.route_path NOT IN ('/roles', '/menus'))
  AND (menu.permission_code IS NULL
       OR (menu.permission_code <> 'system:user:assign-role'
           AND menu.permission_code NOT LIKE 'system:role:%'
           AND menu.permission_code NOT LIKE 'system:menu:%'))
  -- 只补缺失的，不动已存在的（避免覆盖后续 upsert 对菜单的调整）
  AND NOT EXISTS (
      SELECT 1 FROM sys_project_menu existing
      WHERE existing.id = 9000000000000010000 + menu.id
  )
  -- 父节点必须已存在，否则外键约束会失败
  AND (menu.parent_id IS NULL
       OR EXISTS (
           SELECT 1 FROM sys_project_menu parent
           WHERE parent.id = 9000000000000010000 + menu.parent_id
       ));

-- 把补齐的菜单授予系统项目管理员。
-- 该角色的语义是「拥有项目内全部菜单」，与自举时 grantAllMenusToAdminRole 一致。
INSERT IGNORE INTO sys_project_role_menu (project_id, role_id, menu_id, created_at)
SELECT menu.project_id, role.id, menu.id, CURRENT_TIMESTAMP
FROM sys_project_menu menu
JOIN sys_project_role role
  ON role.project_id = menu.project_id
 AND role.role_code = 'project-admin'
WHERE NOT EXISTS (
    SELECT 1 FROM sys_project_role_menu existing
    WHERE existing.project_id = menu.project_id
      AND existing.role_id = role.id
      AND existing.menu_id = menu.id
);
