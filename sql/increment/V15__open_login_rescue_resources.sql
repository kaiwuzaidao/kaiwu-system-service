-- 登录页文案此前只有 public_visible=0 的库行，匿名 catalog 返回不了，页面实际全部落回
-- Web 静态救援包：后台编辑登录文案不生效，新增语言也永远翻不了登录页。
-- 这里把 Web 救援包覆盖的 key 全部开放为匿名可见，让数据库重新成为事实源，
-- 救援包退回纯兜底。开放范围严格等于 ADR 0011 的最小救援边界：
-- 登录表单与其说明文案、服务不可用、资源加载失败、会话失效、语言名称。
-- 这些文案本来就随 Web bundle 明文下发，开放匿名读取不新增任何信息暴露。
UPDATE sys_i18n_message
SET public_visible = 1, version = version + 1, updated_at = CURRENT_TIMESTAMP
WHERE public_visible = 0
  AND (message_key LIKE 'login.%'
       OR message_key IN (
           'client.sessionExpired',
           'client.catalogFailed',
           'common.language.updated',
           'common.language.updateFailed'
       ));

-- 必需资源缺译时不再让整门语言静默下线，而是在保存阶段直接拒绝；错误文案需要稳定 key。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000939, 'api.i18n.requiredTranslationMissing', '覆盖必需资源必须为已开放语言 {locales} 提供译文', JSON_OBJECT('en-US', 'A required resource must provide translations for the available languages: {locales}'), 'api', 0, 1, 'ENABLED', '阻止管理员用一条缺译资源让整门语言不可选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text),
    translations_json = JSON_MERGE_PATCH(
        COALESCE(translations_json, JSON_OBJECT()), VALUES(translations_json)),
    module_code = VALUES(module_code), required_resource = 1,
    status = 'ENABLED', version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
