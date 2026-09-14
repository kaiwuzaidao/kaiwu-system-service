-- 权限三端同码：后端 @RequirePermission、前端 AuthButton、本文件 BUTTON。
INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code)
VALUES (1, NULL, '验证平台访问', 'BUTTON', 'system:platform:read');

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code) VALUES
    (100, NULL, '用户管理', 'MENU', NULL),
    (101, 100, '查询用户', 'BUTTON', 'system:user:list'),
    (102, 100, '创建用户', 'BUTTON', 'system:user:create'),
    (103, 100, '编辑用户', 'BUTTON', 'system:user:update'),
    (104, 100, '启停用户', 'BUTTON', 'system:user:status'),
    (105, 100, '重置密码', 'BUTTON', 'system:user:reset-password');

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code) VALUES
    (106, 100, '分配用户角色', 'BUTTON', 'system:user:assign-role'),
    (200, NULL, '角色管理', 'MENU', NULL),
    (201, 200, '查询角色', 'BUTTON', 'system:role:list'),
    (202, 200, '创建角色', 'BUTTON', 'system:role:create'),
    (203, 200, '编辑角色', 'BUTTON', 'system:role:update'),
    (204, 200, '启停角色', 'BUTTON', 'system:role:status'),
    (205, 200, '角色授权', 'BUTTON', 'system:role:grant');

UPDATE sys_menu SET route_path = '/users', icon = 'UserOutlined', sort_no = 10 WHERE id = 100;
UPDATE sys_menu SET route_path = '/roles', icon = 'TeamOutlined', sort_no = 20 WHERE id = 200;

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (300, NULL, '平台菜单', 'MENU', '/menus', 'MenuOutlined', 30, NULL),
    (301, 300, '查询菜单', 'BUTTON', NULL, NULL, 10, 'system:menu:list'),
    (302, 300, '创建菜单', 'BUTTON', NULL, NULL, 20, 'system:menu:create'),
    (303, 300, '编辑菜单', 'BUTTON', NULL, NULL, 30, 'system:menu:update'),
    (304, 300, '启停菜单', 'BUTTON', NULL, NULL, 40, 'system:menu:status'),
    (305, 300, '删除菜单', 'BUTTON', NULL, NULL, 50, 'system:menu:delete');

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (400, NULL, '项目管理', 'MENU', '/projects', 'AppstoreOutlined', 40, NULL),
    (401, 400, '查询项目', 'BUTTON', NULL, NULL, 10, 'system:project:list'),
    (402, 400, '创建项目', 'BUTTON', NULL, NULL, 20, 'system:project:create'),
    (403, 400, '编辑项目', 'BUTTON', NULL, NULL, 30, 'system:project:update'),
    (404, 400, '变更项目状态', 'BUTTON', NULL, NULL, 40, 'system:project:status'),
    (405, 400, '管理项目成员', 'BUTTON', NULL, NULL, 50, 'system:project:member'),
    (406, 400, '管理项目角色', 'BUTTON', NULL, NULL, 60, 'system:project:role'),
    (407, 400, '管理项目菜单', 'BUTTON', NULL, NULL, 70, 'system:project:menu');

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (500, NULL, '参数配置', 'MENU', '/configs', 'SettingOutlined', 50, NULL),
    (501, 500, '查询配置', 'BUTTON', NULL, NULL, 10, 'system:config:list'),
    (502, 500, '保存配置', 'BUTTON', NULL, NULL, 20, 'system:config:save'),
    (503, 500, '删除配置', 'BUTTON', NULL, NULL, 30, 'system:config:delete'),
    (600, NULL, '字典管理', 'MENU', '/dictionaries', 'BookOutlined', 60, NULL),
    (601, 600, '查询字典', 'BUTTON', NULL, NULL, 10, 'system:dict:list'),
    (602, 600, '保存字典', 'BUTTON', NULL, NULL, 20, 'system:dict:save'),
    (603, 600, '删除字典', 'BUTTON', NULL, NULL, 30, 'system:dict:delete');

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (700, NULL, '代码生成', 'MENU', '/codegen', 'CodeOutlined', 70, NULL),
    (701, 700, '查询生成任务', 'BUTTON', NULL, NULL, 10, 'system:codegen:list'),
    (702, 700, '生成 CRUD', 'BUTTON', NULL, NULL, 20, 'system:codegen:generate'),
    (703, 700, '下载 ZIP', 'BUTTON', NULL, NULL, 30, 'system:codegen:download'),
    (704, 700, '创建 GitLab MR', 'BUTTON', NULL, NULL, 40, 'system:codegen:push');
