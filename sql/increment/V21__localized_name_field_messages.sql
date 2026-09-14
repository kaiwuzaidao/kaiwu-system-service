-- 「本地化名称」双模式字段的 UI 文案。
--
-- V20 引入的 `i18nKey.*` / `configs.i18nKey*` / `menus.i18nKey*` 系列文案对应的是「勾选启用
-- 国际化 + 手填 key」的旧界面。方案 A 把菜单名与国际化资源合成一个概念（单选二选一），
-- 旧文案不再被引用，转为 DISABLED——不物理删除，避免破坏可能已录入的其他语言译文。

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000002200, 'localizedName.modeFixed', '固定文案', JSON_OBJECT('en-US', 'Fixed text'), 'i18n', 0, 1, 'ENABLED', '录入模式：固定文案', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002201, 'localizedName.modeReferenced', '引用国际化资源', JSON_OBJECT('en-US', 'Reference a localization resource'), 'i18n', 0, 1, 'ENABLED', '录入模式：引用资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002202, 'localizedName.fallbackRequired', '请填写默认文案', JSON_OBJECT('en-US', 'Please provide the default text'), 'i18n', 0, 1, 'ENABLED', '兜底文案必填校验', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002203, 'localizedName.referenced', '已引用', JSON_OBJECT('en-US', 'Referenced'), 'i18n', 0, 1, 'ENABLED', '引用状态标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002204, 'localizedName.change', '更换资源', JSON_OBJECT('en-US', 'Change resource'), 'i18n', 0, 1, 'ENABLED', '更换引用的资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002205, 'localizedName.pickResource', '选择资源', JSON_OBJECT('en-US', 'Select a resource'), 'i18n', 0, 1, 'ENABLED', '空态：打开选择器', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002206, 'localizedName.createResource', '新建资源', JSON_OBJECT('en-US', 'New resource'), 'i18n', 0, 1, 'ENABLED', '就地新建资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002207, 'localizedName.pickTitle', '选择国际化资源', JSON_OBJECT('en-US', 'Select a localization resource'), 'i18n', 0, 1, 'ENABLED', '资源选择弹窗标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002208, 'localizedName.pickKey', '资源 key', JSON_OBJECT('en-US', 'Resource key'), 'i18n', 0, 1, 'ENABLED', '资源 key 列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002209, 'localizedName.pickDefault', '默认文案', JSON_OBJECT('en-US', 'Default text'), 'i18n', 0, 1, 'ENABLED', '默认文案列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002210, 'localizedName.pickModule', '模块', JSON_OBJECT('en-US', 'Module'), 'i18n', 0, 1, 'ENABLED', '模块列与筛选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002211, 'localizedName.pickSearchPlaceholder', '搜索 key 或文案', JSON_OBJECT('en-US', 'Search key or text'), 'i18n', 0, 1, 'ENABLED', '资源搜索占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002212, 'localizedName.cancel', '取消', JSON_OBJECT('en-US', 'Cancel'), 'i18n', 0, 1, 'ENABLED', '弹窗取消', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002213, 'localizedName.defaultPreview', '默认显示', JSON_OBJECT('en-US', 'Default'), 'i18n', 0, 1, 'ENABLED', '默认文案预览标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002214, 'localizedName.translationsPreview', '其他语言', JSON_OBJECT('en-US', 'Other languages'), 'i18n', 0, 1, 'ENABLED', '其他语言译文预览标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002215, 'localizedName.loadFailed', '国际化资源加载失败', JSON_OBJECT('en-US', 'Failed to load localization resources'), 'i18n', 0, 1, 'ENABLED', '资源加载失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002216, 'localizedName.createDone', '资源已创建', JSON_OBJECT('en-US', 'Resource created'), 'i18n', 0, 1, 'ENABLED', '新建成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002217, 'localizedName.createFailed', '资源创建失败', JSON_OBJECT('en-US', 'Failed to create resource'), 'i18n', 0, 1, 'ENABLED', '新建失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002218, 'localizedName.createKeyPlaceholder', '例如：module.subject.usage', JSON_OBJECT('en-US', 'e.g. module.subject.usage'), 'i18n', 0, 1, 'ENABLED', '新建资源 key 输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

-- 停用旧的「勾选启用国际化」界面文案：改为 DISABLED 而非删除，
-- 保留历史录入的译文，将来若要复活字段无需重翻译。
UPDATE sys_i18n_message
SET status = 'DISABLED', required_resource = 0,
    version = version + 1, updated_at = CURRENT_TIMESTAMP
WHERE message_key IN (
    'i18nKey.enable', 'i18nKey.change', 'i18nKey.pickTitle',
    'i18nKey.key', 'i18nKey.defaultText', 'i18nKey.module',
    'i18nKey.searchPlaceholder', 'i18nKey.create', 'i18nKey.created',
    'i18nKey.cancel', 'i18nKey.loadFailed',
    'configs.i18nKey', 'menus.i18nKey'
);

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
