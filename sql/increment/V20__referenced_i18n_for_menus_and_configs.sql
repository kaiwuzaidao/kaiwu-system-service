-- ADR 0013：菜单与参数配置引用国际化资源。
--
-- 只增加一个可空 key 列，不引入布尔开关列：非空即启用。界面上的「启用国际化」勾选框
-- 由 key 是否为空推导，数据库里因此不可能出现「勾了没填」「填了没勾」这类自相矛盾的行。

-- MySQL 的 ADD COLUMN 不支持 IF NOT EXISTS，用 information_schema 判定保证可重跑。
SET @menu_key_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_project_menu'
      AND COLUMN_NAME = 'menu_name_key'
);
SET @menu_key_sql = IF(
    @menu_key_exists = 0,
    'ALTER TABLE sys_project_menu ADD COLUMN menu_name_key VARCHAR(160) NULL'
        ' COMMENT ''引用的国际化资源 key；非空即启用引用式国际化'' AFTER menu_name_i18n',
    'SELECT 1'
);
PREPARE menu_key_stmt FROM @menu_key_sql;
EXECUTE menu_key_stmt;
DEALLOCATE PREPARE menu_key_stmt;

SET @config_key_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_app_config'
      AND COLUMN_NAME = 'value_i18n_key'
);
SET @config_key_sql = IF(
    @config_key_exists = 0,
    'ALTER TABLE sys_app_config ADD COLUMN value_i18n_key VARCHAR(160) NULL'
        ' COMMENT ''展示型配置引用的国际化资源 key；非空即启用'' AFTER config_value',
    'SELECT 1'
);
PREPARE config_key_stmt FROM @config_key_sql;
EXECUTE config_key_stmt;
DEALLOCATE PREPARE config_key_stmt;

-- 内置菜单指向**已存在**的 menu.system.* 资源，不新建资源。
--
-- V11 早就把 14 条内置菜单名回填进了资源目录，`check:i18n` 也按同一套约定校验
-- （`/` → menu.system.home，`/a/b` → menu.system.a.b）。这里只是让菜单去引用它们——
-- 另造一套 key 会凭空产生两份同义资源，翻译工作量直接翻倍。
--
-- 只处理有 route_path 的菜单：DIRECTORY 没有路由，其 key 无法从数据推导，
-- 由 SystemProjectBootstrap 按已知的目录 ID 显式赋值（那里才知道哪个目录是哪个）。
-- 少数菜单（如 V10 的国际化资源）当初只带内联 menu_name_i18n，没有对应资源——
-- check:i18n 两种来源都接受，所以一直没暴露。统一到 key 引用时把它们的译文提升进目录，
-- 让用户已经录入的译文不至于白扔。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT 9100000000000002000 + ROW_NUMBER() OVER (ORDER BY source.id),
       source.message_key, source.menu_name, source.menu_name_i18n, 'menu', 0, 1, 'ENABLED',
       '内置菜单名称，由 ADR 0013 从 menu_name_i18n 提升', 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT menu.id, menu.menu_name, menu.menu_name_i18n,
           CONCAT('menu.system.',
                  CASE WHEN menu.route_path = '/' THEN 'home'
                       ELSE REPLACE(TRIM(LEADING '/' FROM menu.route_path), '/', '.')
                  END) AS message_key
    FROM sys_project_menu menu
    JOIN sys_project project ON project.id = menu.project_id
    WHERE project.project_code = 'system'
      AND menu.menu_type = 'MENU'
      AND menu.route_path IS NOT NULL
      AND menu.menu_name_key IS NULL
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = source.message_key
);

UPDATE sys_project_menu menu
JOIN sys_project project ON project.id = menu.project_id
SET menu.menu_name_key = CONCAT(
        'menu.system.',
        CASE WHEN menu.route_path = '/' THEN 'home'
             ELSE REPLACE(TRIM(LEADING '/' FROM menu.route_path), '/', '.')
        END),
    menu.updated_at = CURRENT_TIMESTAMP
WHERE project.project_code = 'system'
  AND menu.menu_type = 'MENU'
  AND menu.route_path IS NOT NULL
  AND menu.menu_name_key IS NULL;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';

-- 引用式国际化的界面文案。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000002101, 'i18nKey.enable', '启用国际化', JSON_OBJECT('en-US', 'Enable localization'), 'i18n', 0, 1, 'ENABLED', '引用式国际化开关', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002102, 'i18nKey.change', '更换资源', JSON_OBJECT('en-US', 'Change resource'), 'i18n', 0, 1, 'ENABLED', '更换引用的资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002103, 'i18nKey.pickTitle', '选择国际化资源', JSON_OBJECT('en-US', 'Select a localization resource'), 'i18n', 0, 1, 'ENABLED', '资源选择弹窗标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002104, 'i18nKey.key', '资源 key', JSON_OBJECT('en-US', 'Resource key'), 'i18n', 0, 1, 'ENABLED', '资源 key 列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002105, 'i18nKey.defaultText', '默认文案', JSON_OBJECT('en-US', 'Default text'), 'i18n', 0, 1, 'ENABLED', '默认文案列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002106, 'i18nKey.module', '模块', JSON_OBJECT('en-US', 'Module'), 'i18n', 0, 1, 'ENABLED', '模块列与筛选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002107, 'i18nKey.searchPlaceholder', '搜索 key 或文案', JSON_OBJECT('en-US', 'Search key or text'), 'i18n', 0, 1, 'ENABLED', '资源搜索占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002108, 'i18nKey.create', '新建资源', JSON_OBJECT('en-US', 'New resource'), 'i18n', 0, 1, 'ENABLED', '就地新建资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002109, 'i18nKey.created', '资源已创建', JSON_OBJECT('en-US', 'Resource created'), 'i18n', 0, 1, 'ENABLED', '新建成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002110, 'i18nKey.cancel', '取消', JSON_OBJECT('en-US', 'Cancel'), 'i18n', 0, 1, 'ENABLED', '弹窗取消', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002111, 'i18nKey.loadFailed', '国际化资源加载失败', JSON_OBJECT('en-US', 'Failed to load localization resources'), 'i18n', 0, 1, 'ENABLED', '资源加载失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002112, 'configs.i18nKey', '国际化文案', JSON_OBJECT('en-US', 'Localized text'), 'configs', 0, 1, 'ENABLED', '配置引用资源字段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002113, 'configs.i18nKeyHint', '只对直接展示给用户的文案有效；限额、阈值、开关等参与后端校验的值不要启用。', JSON_OBJECT('en-US', 'Only for text shown to users. Do not enable it for limits, thresholds or switches validated on the server.'), 'configs', 0, 1, 'ENABLED', '配置国际化适用范围说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002114, 'menus.i18nKey', '国际化文案', JSON_OBJECT('en-US', 'Localized text'), 'menus', 0, 1, 'ENABLED', '菜单引用资源字段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002115, 'menus.i18nKeyHint', '内置菜单的译文统一在国际化资源里维护，不在这里逐语言填写。', JSON_OBJECT('en-US', 'Built-in menu translations are maintained in localization resources, not filled in per language here.'), 'menus', 0, 1, 'ENABLED', '菜单国际化说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
