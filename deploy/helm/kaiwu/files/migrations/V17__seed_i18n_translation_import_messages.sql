-- 译文批量导入导出的界面文案。
--
-- 开放一门新语言要求资源、菜单与字典译文全部补齐，平台侧近千条无法逐条手填；
-- 国际化资源页新增整表导出与导回能力，这里种入其界面文案。

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000961, 'i18n.selectLocale', '选择语言', JSON_OBJECT('en-US', 'Select a language'), 'i18n', 0, 1, 'ENABLED', '译文导入导出的目标语言选择', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000962, 'i18n.exportTranslations', '导出译文', JSON_OBJECT('en-US', 'Export translations'), 'i18n', 0, 1, 'ENABLED', '导出待翻译内容', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000963, 'i18n.importTranslations', '导入译文', JSON_OBJECT('en-US', 'Import translations'), 'i18n', 0, 1, 'ENABLED', '导入已翻译内容', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000964, 'i18n.importDone', '已导入 {applied} 条译文', JSON_OBJECT('en-US', 'Imported {applied} translations'), 'i18n', 0, 1, 'ENABLED', '导入成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
