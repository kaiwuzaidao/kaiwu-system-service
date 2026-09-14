-- 译文导出/导入（三 Sheet 工作簿）引入的稳定 messageKey。
-- 缺这几条时前端只能显示后端兼容中文，切到其它语言后仍是中文，
-- 且 scripts/tests/check-i18n-contract.sh 会失败。
-- 行数上限用 {limit} 占位符，与 api.user.export.tooManyRows 的既有约定一致：
-- 拼进句子里的话译文要么写死数字要么丢掉它，用户就看不出该缩到多少行。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000940, 'api.i18n.defaultLocaleNotTranslatable', '默认语言使用原文，无需导入译文', JSON_OBJECT('en-US', 'The default language uses the source text and needs no translation import'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000941, 'api.i18n.exportFailed', '导出译文失败', JSON_OBJECT('en-US', 'Failed to export translations'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000942, 'api.i18n.importFileInvalid', '无法解析该 Excel 文件，请确认文件未损坏且大小在 10MB 以内', JSON_OBJECT('en-US', 'The Excel file could not be parsed. Check that it is not corrupted and is under 10MB.'), 'api', 0, 1, 'ENABLED', '同时用于文件大小超限和解析失败', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000943, 'api.i18n.importSheetMissing', '文件中没有可识别的工作表，请使用导出的模板填写', JSON_OBJECT('en-US', 'The file contains no recognizable sheet. Fill in the exported template instead.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000944, 'api.i18n.importTooManyRows', '单个工作表不能超过 {limit} 行，请拆分后分批导入', JSON_OBJECT('en-US', 'A single sheet cannot exceed {limit} rows. Split the file and import in batches.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text),
    translations_json = JSON_MERGE_PATCH(
        COALESCE(translations_json, JSON_OBJECT()), VALUES(translations_json)),
    module_code = VALUES(module_code), required_resource = 1,
    status = 'ENABLED', version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
