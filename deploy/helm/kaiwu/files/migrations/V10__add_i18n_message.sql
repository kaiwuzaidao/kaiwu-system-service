-- 数据库国际化资源中心。default_text 固定为 zh-CN，其它语言存 translations_json。
CREATE TABLE IF NOT EXISTS sys_i18n_message (
    id BIGINT NOT NULL,
    message_key VARCHAR(160) NOT NULL,
    default_text VARCHAR(2000) NOT NULL,
    translations_json JSON NULL,
    module_code VARCHAR(64) NOT NULL,
    public_visible TINYINT NOT NULL DEFAULT 0,
    required_resource TINYINT NOT NULL DEFAULT 1,
    status VARCHAR(16) NOT NULL,
    description VARCHAR(512) NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_i18n_message_key (message_key),
    KEY idx_sys_i18n_message_module_status (module_code, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_i18n_catalog_revision (
    catalog_code VARCHAR(32) NOT NULL,
    revision BIGINT NOT NULL DEFAULT 1,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (catalog_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO sys_i18n_catalog_revision (catalog_code, revision, updated_at)
VALUES ('platform', 1, CURRENT_TIMESTAMP);

-- MySQL DDL 会自动提交；通过 information_schema 使局部失败后可安全重跑。
SET @menu_name_i18n_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_project_menu'
      AND COLUMN_NAME = 'menu_name_i18n'
);
SET @menu_name_i18n_sql = IF(
    @menu_name_i18n_exists = 0,
    'ALTER TABLE sys_project_menu ADD COLUMN menu_name_i18n JSON NULL AFTER menu_name',
    'SELECT 1'
);
PREPARE menu_name_i18n_stmt FROM @menu_name_i18n_sql;
EXECUTE menu_name_i18n_stmt;
DEALLOCATE PREPARE menu_name_i18n_stmt;

-- V9 只建立可维护语言目录；从 V10 起由覆盖门禁决定是否向用户开放。
UPDATE sys_dict_type
SET description = '平台语言唯一目录；约束运行期所有多语言 JSON 的 locale key',
    updated_at = CURRENT_TIMESTAMP
WHERE scope_id = 0 AND dict_code = 'platform.locale';

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
SET item.extra_json = CASE item.item_value
        WHEN 'zh-CN' THEN '{"selectable":true,"antdLocale":"zh-CN","dateLocale":"zh-CN"}'
        WHEN 'en-US' THEN '{"selectable":true,"antdLocale":"en-US","dateLocale":"en-US"}'
        ELSE item.extra_json
    END,
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0 AND type.dict_code = 'platform.locale'
  AND item.item_value IN ('zh-CN', 'en-US');

-- 国际化资源管理入口与权限全部落在内置 system 项目。
INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT 9000000000000015000, project.id, 9000000000000014000,
       '国际化资源', '{"en-US":"Internationalization resources"}', 'MENU',
       '/i18n-resources', 'I18nResources', NULL, 'TranslationOutlined', 80, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project project
WHERE project.project_code = 'system'
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id), menu_name = VALUES(menu_name),
    menu_name_i18n = VALUES(menu_name_i18n), route_path = VALUES(route_path),
    component_path = VALUES(component_path), icon = VALUES(icon),
    sort_no = VALUES(sort_no), visible = 1, status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT seed.id, project.id, 9000000000000015000, seed.menu_name, seed.name_i18n,
       'BUTTON', NULL, NULL, seed.permission_code, NULL, seed.sort_no, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project project
CROSS JOIN (
    SELECT 9000000000000015001 AS id, '查询国际化资源' AS menu_name,
           '{"en-US":"View internationalization resources"}' AS name_i18n,
           'system:i18n:list' AS permission_code, 10 AS sort_no
    UNION ALL
    SELECT 9000000000000015002, '保存国际化资源',
           '{"en-US":"Save internationalization resources"}',
           'system:i18n:save', 20
    UNION ALL
    SELECT 9000000000000015003, '删除国际化资源',
           '{"en-US":"Delete internationalization resources"}',
           'system:i18n:delete', 30
) seed
WHERE project.project_code = 'system'
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id), menu_name = VALUES(menu_name),
    menu_name_i18n = VALUES(menu_name_i18n), permission_code = VALUES(permission_code),
    sort_no = VALUES(sort_no), visible = 1, status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;

INSERT IGNORE INTO sys_project_role_menu (project_id, role_id, menu_id, created_at)
SELECT project.id, role.id, menu.id, CURRENT_TIMESTAMP
FROM sys_project project
JOIN sys_project_role role
  ON role.project_id = project.id AND role.role_code = 'project-admin'
JOIN sys_project_menu menu
  ON menu.project_id = project.id
 AND menu.id BETWEEN 9000000000000015000 AND 9000000000000015003
WHERE project.project_code = 'system';
