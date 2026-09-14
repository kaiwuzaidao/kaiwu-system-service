-- 补齐后端抛出但资源目录里不存在的错误码。
--
-- `ApiException` 强制携带 messageKey，但没有任何门禁校验这个 key 真的有资源。
-- 缺资源时前端 `resolveApiMessage` 会静默回退到后端的中文 `message`——
-- 英文用户看到中文报错，且只在触发该错误时才暴露。本次由新增的 `check:i18n`
-- 错误码校验扫出这两条，其余 55 条已有资源。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000003101, 'api.i18n.keyNotFound', '国际化资源不存在：{key}', JSON_OBJECT('en-US', 'The internationalization resource does not exist: {key}'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000003102, 'api.projectHealth.disabled', '该项目已关闭只读体检', JSON_OBJECT('en-US', 'Read-only health check is disabled for this project'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
