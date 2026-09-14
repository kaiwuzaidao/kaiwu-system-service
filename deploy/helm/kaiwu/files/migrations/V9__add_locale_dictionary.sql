-- 可扩展语言目录：字典项 label_i18n 的合法 key 由它决定。
-- 静态页面语言包仍随前端版本发布；本目录不自动把未发布语言开放给用户切换。
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8317, 0, 'platform.locale', '平台语言', 0, 'ENABLED',
     '已启用语言；用于约束运行期字典标签翻译的 locale key', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, status, created_at, updated_at)
VALUES
    (8501, 8317, '简体中文', 'zh-CN', 10, 1, NULL, NULL,
     '{"en-US":"Simplified Chinese"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8502, 8317, 'English (US)', 'en-US', 20, 0, NULL, NULL,
     '{"zh-CN":"英语（美国）"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
