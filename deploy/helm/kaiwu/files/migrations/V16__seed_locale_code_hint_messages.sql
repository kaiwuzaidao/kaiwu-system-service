-- 语言字典项的取值提示与前端预校验文案。
--
-- 平台语言字典（platform.locale）的 item_value 会被用于 antd locale、日期格式化与
-- Accept-Language，写成 `test` 这类非 BCP 47 值会让整套国际化静默错乱。后端已在
-- MetadataService 用 LocaleCode 校验并返回 api.locale.codeInvalid；这里补前端在提交前
-- 当场提示所需的两条文案，避免用户必须往返一次服务端才知道格式要求。

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000951, 'dicts.localeCodeTip', '使用 BCP 47 标签，例如 zh-CN、en-US、ko-KR', JSON_OBJECT('en-US', 'Use a BCP 47 tag, for example zh-CN, en-US, or ko-KR'), 'dicts', 0, 1, 'ENABLED', '语言字典取值输入提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000952, 'dicts.localeCodeInvalid', '语言代码必须是规范 BCP 47 标签，例如 ko-KR', JSON_OBJECT('en-US', 'The locale code must be a canonical BCP 47 tag, for example ko-KR'), 'dicts', 0, 1, 'ENABLED', '语言字典取值前端校验提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
