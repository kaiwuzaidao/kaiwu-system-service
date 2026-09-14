-- 展示颜色改为受管字典：此前是自由文本输入，写错了没有任何提示，
-- 页面上只表现为 Tag 掉回默认灰色，很难发现。
--
-- 取值范围按**库里实际在用**的 7 种确定，而不是只留语义色：
-- success/processing/warning/error/default 用于状态；purple/cyan 已被值类型、
-- 生成模式、消息类型等**类别型**枚举使用，删掉会让这些存量项在下拉里变成未知值。

INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8321, 0, 'common.tag_color', '标签颜色', 0, 'ENABLED',
     '字典项 Tag 的展示颜色；状态类优先用语义色，类别类可用 purple/cyan',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- label_i18n_key 直接指向下面种入的 dict.common.tag_color.* 资源。
-- V23 的存量映射只跑过一次，之后新增的字典项必须自己带上 key，否则会出现
-- 「新字典项没有引用、老字典项有引用」的不一致。
INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, label_i18n_key, status, created_at, updated_at)
VALUES
    (8531, 8321, '成功（绿）', 'success', 10, 0, 'success', NULL, NULL,
     'dict.common.tag_color.success', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8532, 8321, '处理中（蓝）', 'processing', 20, 0, 'processing', NULL, NULL,
     'dict.common.tag_color.processing', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8533, 8321, '警告（橙）', 'warning', 30, 0, 'warning', NULL, NULL,
     'dict.common.tag_color.warning', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8534, 8321, '失败（红）', 'error', 40, 0, 'error', NULL, NULL,
     'dict.common.tag_color.error', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8535, 8321, '默认（灰）', 'default', 50, 1, 'default', NULL, NULL,
     'dict.common.tag_color.default', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8536, 8321, '紫（类别）', 'purple', 60, 0, 'purple', NULL, NULL,
     'dict.common.tag_color.purple', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8537, 8321, '青（类别）', 'cyan', 70, 0, 'cyan', NULL, NULL,
     'dict.common.tag_color.cyan', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 内置字典的标签走资源目录（check:i18n 的 checkDictionaryCoverage 强制要求中英齐全）。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000002300, 'dict.common.tag_color.success', '成功（绿）', JSON_OBJECT('en-US', 'Success (green)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002301, 'dict.common.tag_color.processing', '处理中（蓝）', JSON_OBJECT('en-US', 'Processing (blue)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002302, 'dict.common.tag_color.warning', '警告（橙）', JSON_OBJECT('en-US', 'Warning (orange)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002303, 'dict.common.tag_color.error', '失败（红）', JSON_OBJECT('en-US', 'Error (red)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002304, 'dict.common.tag_color.default', '默认（灰）', JSON_OBJECT('en-US', 'Default (grey)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002305, 'dict.common.tag_color.purple', '紫（类别）', JSON_OBJECT('en-US', 'Purple (category)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002306, 'dict.common.tag_color.cyan', '青（类别）', JSON_OBJECT('en-US', 'Cyan (category)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

-- 扩展配置键值对编辑器的界面文案。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000002310, 'dicts.extraKey', '键', JSON_OBJECT('en-US', 'Key'), 'dicts', 0, 1, 'ENABLED', '扩展配置键输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002311, 'dicts.extraValue', '值', JSON_OBJECT('en-US', 'Value'), 'dicts', 0, 1, 'ENABLED', '扩展配置值输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002312, 'dicts.extraAdd', '添加一项', JSON_OBJECT('en-US', 'Add entry'), 'dicts', 0, 1, 'ENABLED', '扩展配置新增按钮', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
