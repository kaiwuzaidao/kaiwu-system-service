-- 补齐语言覆盖状态文案，并让历史日语目录项具备至少一份可识别的英文名称。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000913, 'i18n.localeCoverage', '语言开放状态', JSON_OBJECT('en-US', 'Language availability'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000914, 'i18n.available', '可选择', JSON_OBJECT('en-US', 'Available'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000915, 'i18n.notConfigured', '目录未开放', JSON_OBJECT('en-US', 'Not enabled in directory'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000916, 'i18n.missingResources', '资源 {count}', JSON_OBJECT('en-US', 'Resources {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000917, 'i18n.missingMenus', '菜单 {count}', JSON_OBJECT('en-US', 'Menus {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000918, 'i18n.missingDictionaries', '字典 {count}', JSON_OBJECT('en-US', 'Dictionary items {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000919, 'api.i18n.htmlForbidden', '国际化资源只允许纯文本', JSON_OBJECT('en-US', 'Internationalization resources must be plain text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000920, 'api.i18n.jsonInvalid', '多语言译文必须是合法 JSON 对象', JSON_OBJECT('en-US', 'Translations must be a valid JSON object'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000921, 'api.i18n.keyExists', '国际化资源 key 已存在', JSON_OBJECT('en-US', 'The internationalization resource key already exists'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000922, 'api.i18n.keyImmutable', '国际化资源 key 创建后不可修改', JSON_OBJECT('en-US', 'The internationalization resource key cannot be changed after creation'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000923, 'api.i18n.localeInvalid', '包含未启用或重复默认语言', JSON_OBJECT('en-US', 'Translations contain an unavailable locale or duplicate the default locale'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000924, 'api.i18n.notFound', '国际化资源不存在', JSON_OBJECT('en-US', 'The internationalization resource was not found'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000925, 'api.i18n.placeholderMismatch', '译文占位符与默认文案不一致', JSON_OBJECT('en-US', 'Translation placeholders do not match the default text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000926, 'api.i18n.publicKeyInvalid', '该资源不允许匿名公开', JSON_OBJECT('en-US', 'This resource cannot be exposed anonymously'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000927, 'api.i18n.translationInvalid', '译文必须是非空文本', JSON_OBJECT('en-US', 'A translation must be non-empty text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000928, 'api.i18n.versionConflict', '资源已被其他人修改，请刷新后重试', JSON_OBJECT('en-US', 'The resource was changed by someone else. Refresh and try again'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000929, 'api.i18n.versionRequired', '更新资源必须携带版本', JSON_OBJECT('en-US', 'Updating a resource requires its version'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000930, 'api.locale.codeInvalid', '语言代码必须是规范 BCP 47 标签', JSON_OBJECT('en-US', 'The locale must be a canonical BCP 47 language tag'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000931, 'api.i18n.defaultTextTooLong', '默认文案不能超过 2000 个字符', JSON_OBJECT('en-US', 'Default text cannot exceed 2000 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000932, 'api.i18n.descriptionTooLong', '说明不能超过 512 个字符', JSON_OBJECT('en-US', 'Description cannot exceed 512 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000933, 'api.i18n.keyInvalid', '资源 key 格式不正确', JSON_OBJECT('en-US', 'The resource key format is invalid'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000934, 'api.i18n.moduleInvalid', '模块代码格式不正确', JSON_OBJECT('en-US', 'The module code format is invalid'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000935, 'api.i18n.statusInvalid', '资源状态必须是 ENABLED 或 DISABLED', JSON_OBJECT('en-US', 'Resource status must be ENABLED or DISABLED'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000936, 'api.validation.required', '必填项不能为空', JSON_OBJECT('en-US', 'This field is required'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000937, 'dicts.localeSelectable', '覆盖完整后允许用户选择', JSON_OBJECT('en-US', 'Allow users to select after coverage is complete'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000938, 'dicts.localeSelectableTip', '即使开启，也只有在资源、菜单和字典译文全部补齐后才会出现在语言选择器', JSON_OBJECT('en-US', 'Even when enabled, the language appears only after resource, menu, and dictionary translations are complete'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text),
    translations_json = JSON_MERGE_PATCH(
        COALESCE(translations_json, JSON_OBJECT()), VALUES(translations_json)),
    module_code = VALUES(module_code), required_resource = 1,
    status = 'ENABLED', version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
SET item.label_i18n = JSON_SET(
        COALESCE(item.label_i18n, JSON_OBJECT()),
        '$."en-US"',
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item.label_i18n, '$."en-US"')),
            'Japanese'
        )
    ),
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND item.item_value = 'ja-JP';

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
