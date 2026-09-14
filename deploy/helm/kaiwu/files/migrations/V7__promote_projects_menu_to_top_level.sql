-- 「项目管理」从「平台管理」目录提升为顶层菜单。
-- 平台管理目录下的其余条目（用户、安全运营、组织架构、参数配置、字典管理）都是平台自身
-- 配置；项目管理面向的是业务项目本身，是平台的核心业务入口，层级上不应与它们并列。
-- V1 基线里 sys_menu(id=400) 的 parent_id 本就是 NULL，是 SystemProjectBootstrap 的
-- 全新库初始分组把它归入了平台管理目录；该分组逻辑已同步调整，本迁移负责校正存量库。
--
-- 只做一次性校正：Flyway 不会重复执行，管理员之后在「项目菜单」里的调整不会被覆盖，
-- 与 SystemProjectBootstrap 保留既有菜单层级的约定一致。
-- 子按钮的 parent_id 指向本菜单，不受影响，无需调整。

UPDATE sys_project_menu menu
JOIN sys_project project
  ON project.id = menu.project_id
 AND project.project_code = 'system'
SET menu.parent_id = NULL,
    -- 顶层顺序：工作台 10、项目管理 12、消息中心 15、平台管理 20、研发交付 60。
    menu.sort_no = 12,
    menu.updated_at = CURRENT_TIMESTAMP
WHERE menu.menu_type = 'MENU'
  AND menu.route_path = '/projects';
