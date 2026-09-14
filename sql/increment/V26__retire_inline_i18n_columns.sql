-- ADR 0015：多语言只走引用式国际化，内联多语言列退役。
--
-- 两列保留在表结构中但不再读写：删列不可逆，而保留空列的成本只是一点表宽度，
-- 一旦迁移有遗漏，数据还在可以补救。

-- 0) 语言名的译文资源显式种入。
--    下面的通用迁移会按 dict.{code}.{value} 动态生成 key，但那样 key 不是字面量，
--    check:i18n 无法从 SQL 里静态识别，会判定「快照多出增量没有的 key」。
--    平台自带的这两条语言名写成字面量，让增量与快照对称、门禁可静态校验。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000003001, 'dict.platform.locale.zh-CN', '简体中文', JSON_OBJECT('en-US', 'Simplified Chinese'), 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000003002, 'dict.platform.locale.en-US', '英语（美国）', JSON_OBJECT('en-US', 'English (US)'), 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    translations_json = VALUES(translations_json),
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

-- 1) 有内联译文但还没引用资源的字典项：按 dict.{dictCode}.{itemValue} 建资源。
--    实测存量只有 platform.locale 的两条语言名，但规则按通用写，兜住其它环境的数据。
--    required_resource = 0：这些资源来自运行期数据，不该让某门语言因为它们缺译文
--    而掉出「可选择」（沿用 ADR 0013 第 5 节）。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT 9100000000000003200 + ROW_NUMBER() OVER (ORDER BY source.id),
       source.message_key, source.item_label, source.label_i18n, 'dict', 0, 0, 'ENABLED',
       '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT item.id, item.item_label, item.label_i18n,
           CONCAT('dict.', type.dict_code, '.', item.item_value) AS message_key
    FROM sys_dict_item item
    JOIN sys_dict_type type ON type.id = item.dict_type_id
    WHERE item.label_i18n IS NOT NULL
      AND item.label_i18n_key IS NULL
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = source.message_key
);

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dict.', type.dict_code, '.', item.item_value)
SET item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE item.label_i18n IS NOT NULL
  AND item.label_i18n_key IS NULL;

-- 2) 业务项目菜单同理。实测存量为 0（内置菜单已在 V20 全部迁走），
--    这里为将来可能存在的业务项目菜单兜底。key 用 route_path 推导，
--    没有路由的分组节点回退菜单 id，保证唯一。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT 9100000000000003100 + ROW_NUMBER() OVER (ORDER BY source.id),
       source.message_key, source.menu_name, source.menu_name_i18n, 'menu', 0, 0, 'ENABLED',
       '项目菜单名称，由 ADR 0015 从 menu_name_i18n 迁移', 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT menu.id, menu.menu_name, menu.menu_name_i18n,
           CONCAT('menu.project.', menu.project_id, '.', COALESCE(
               NULLIF(REPLACE(TRIM(LEADING '/' FROM menu.route_path), '/', '.'), ''),
               CONCAT('n', menu.id))) AS message_key
    FROM sys_project_menu menu
    WHERE menu.menu_name_i18n IS NOT NULL
      AND menu.menu_name_key IS NULL
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = source.message_key
);

UPDATE sys_project_menu menu
SET menu.menu_name_key = CONCAT('menu.project.', menu.project_id, '.', COALESCE(
        NULLIF(REPLACE(TRIM(LEADING '/' FROM menu.route_path), '/', '.'), ''),
        CONCAT('n', menu.id))),
    menu.updated_at = CURRENT_TIMESTAMP
WHERE menu.menu_name_i18n IS NOT NULL
  AND menu.menu_name_key IS NULL;

-- 3) 译文已全部进入资源目录，清空内联列。
--    实测 47 条字典项的内联译文与所引用资源完全一致（差异数 0），清空不会丢任何译文。
UPDATE sys_dict_item
SET label_i18n = NULL, updated_at = CURRENT_TIMESTAMP
WHERE label_i18n IS NOT NULL;

UPDATE sys_project_menu
SET menu_name_i18n = NULL, updated_at = CURRENT_TIMESTAMP
WHERE menu_name_i18n IS NOT NULL;

-- 4) 界面措辞：「固定文案」改为「独立填写」，说明两种模式的差别是译文存在哪。
UPDATE sys_i18n_message
SET default_text = '独立填写',
    translations_json = JSON_OBJECT('en-US', 'Enter directly'),
    version = version + 1, updated_at = CURRENT_TIMESTAMP
WHERE message_key = 'localizedName.modeFixed';

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
