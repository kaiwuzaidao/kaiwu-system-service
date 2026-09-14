-- 纠正历史界面允许录入的错误日语代码 jp；BCP 47/ISO 639 正确标签为 ja-JP。
UPDATE sys_i18n_message
SET translations_json = JSON_SET(
        JSON_REMOVE(translations_json, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(translations_json, '$."ja-JP"'),
            JSON_EXTRACT(translations_json, '$."jp"')
        )
    ),
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(translations_json, 'one', '$."jp"');

UPDATE sys_project_menu
SET menu_name_i18n = JSON_SET(
        JSON_REMOVE(menu_name_i18n, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(menu_name_i18n, '$."ja-JP"'),
            JSON_EXTRACT(menu_name_i18n, '$."jp"')
        )
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(menu_name_i18n, 'one', '$."jp"');

UPDATE sys_dict_item
SET label_i18n = JSON_SET(
        JSON_REMOVE(label_i18n, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(label_i18n, '$."ja-JP"'),
            JSON_EXTRACT(label_i18n, '$."jp"')
        )
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(label_i18n, 'one', '$."jp"');

UPDATE sys_user SET locale = 'ja-JP', updated_at = CURRENT_TIMESTAMP WHERE locale = 'jp';

UPDATE sys_dict_item legacy
JOIN sys_dict_type type ON type.id = legacy.dict_type_id
LEFT JOIN sys_dict_item canonical
  ON canonical.dict_type_id = legacy.dict_type_id
 AND canonical.item_value = 'ja-JP'
SET legacy.item_value = 'ja-JP',
    legacy.extra_json = JSON_SET(
        COALESCE(legacy.extra_json, JSON_OBJECT()),
        '$.selectable', false,
        '$.antdLocale', 'ja-JP',
        '$.dateLocale', 'ja-JP'
    ),
    legacy.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND legacy.item_value = 'jp'
  AND canonical.id IS NULL;

UPDATE sys_dict_item legacy
JOIN sys_dict_type type ON type.id = legacy.dict_type_id
SET legacy.status = 'DISABLED', legacy.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND legacy.item_value = 'jp';

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
