-- 补齐已在 platform.locale 中配置为可选的 ja-JP 必需资源译文。
-- 仅写入当前缺失的 ja-JP，保留管理员已维护的译文与其它语言。
UPDATE sys_i18n_message message
JOIN (
    SELECT 'api.i18n.keyNotFound' AS message_key, '国際化リソースが存在しません：{key}' AS translated_text
    UNION ALL SELECT 'api.projectHealth.disabled', 'このプロジェクトでは読み取り専用ヘルスチェックが無効です'
    UNION ALL SELECT 'dict.common.tag_color.cyan', 'シアン（カテゴリ）'
    UNION ALL SELECT 'dict.common.tag_color.default', 'デフォルト（グレー）'
    UNION ALL SELECT 'dict.common.tag_color.error', 'エラー（赤）'
    UNION ALL SELECT 'dict.common.tag_color.processing', '処理中（青）'
    UNION ALL SELECT 'dict.common.tag_color.purple', 'パープル（カテゴリ）'
    UNION ALL SELECT 'dict.common.tag_color.success', '成功（緑）'
    UNION ALL SELECT 'dict.common.tag_color.warning', '警告（オレンジ）'
    UNION ALL SELECT 'dict.project.health.verdict.FAIL', '契約違反'
    UNION ALL SELECT 'dict.project.health.verdict.PASS', '合格'
    UNION ALL SELECT 'dict.project.health.verdict.UNKNOWN', '確認不可'
    UNION ALL SELECT 'dict.project.health.verdict.WARN', '要改善'
    UNION ALL SELECT 'dicts.extraAdd', '項目を追加'
    UNION ALL SELECT 'dicts.extraKey', 'キー'
    UNION ALL SELECT 'dicts.extraValue', '値'
    UNION ALL SELECT 'localizedName.cancel', 'キャンセル'
    UNION ALL SELECT 'localizedName.change', 'リソースを変更'
    UNION ALL SELECT 'localizedName.createDone', 'リソースを作成しました'
    UNION ALL SELECT 'localizedName.createFailed', 'リソースの作成に失敗しました'
    UNION ALL SELECT 'localizedName.createKeyPlaceholder', '例：module.subject.usage'
    UNION ALL SELECT 'localizedName.createResource', 'リソースを作成'
    UNION ALL SELECT 'localizedName.defaultPreview', '既定'
    UNION ALL SELECT 'localizedName.fallbackRequired', 'デフォルトのテキストを入力してください'
    UNION ALL SELECT 'localizedName.loadFailed', '国際化リソースの読み込みに失敗しました'
    UNION ALL SELECT 'localizedName.modeFixed', '直接入力'
    UNION ALL SELECT 'localizedName.modeReferenced', '国際化リソースを参照'
    UNION ALL SELECT 'localizedName.pickDefault', 'デフォルトのテキスト'
    UNION ALL SELECT 'localizedName.pickKey', 'リソースキー'
    UNION ALL SELECT 'localizedName.pickModule', 'モジュール'
    UNION ALL SELECT 'localizedName.pickResource', 'リソースを選択'
    UNION ALL SELECT 'localizedName.pickSearchPlaceholder', 'キーまたはテキストを検索'
    UNION ALL SELECT 'localizedName.pickTitle', '国際化リソースを選択'
    UNION ALL SELECT 'localizedName.referenced', '参照中'
    UNION ALL SELECT 'localizedName.translationsPreview', '他の言語'
    UNION ALL SELECT 'projectHealth.checkedAt', 'チェック日時'
    UNION ALL SELECT 'projectHealth.detail', '詳細'
    UNION ALL SELECT 'projectHealth.done', 'ヘルスチェックが完了しました'
    UNION ALL SELECT 'projectHealth.empty', 'まだチェックされていません。プラットフォームはリポジトリ内の契約ファイルのみを読み取り、書き込みは行いません。'
    UNION ALL SELECT 'projectHealth.enabled', '読み取り専用ヘルスチェックを許可'
    UNION ALL SELECT 'projectHealth.entry', 'ヘルスチェック'
    UNION ALL SELECT 'projectHealth.failed', 'ヘルスチェックに失敗しました'
    UNION ALL SELECT 'projectHealth.item', 'チェック項目'
    UNION ALL SELECT 'projectHealth.readOnlyHint', 'チェックは報告のみで、フローをブロックしたりビジネスリポジトリを変更したりしません。'
    UNION ALL SELECT 'projectHealth.result', '結果'
    UNION ALL SELECT 'projectHealth.run', '再チェック'
    UNION ALL SELECT 'projectHealth.switchUpdated', 'ヘルスチェックの設定を更新しました'
    UNION ALL SELECT 'projectHealth.title', 'ヘルスチェック：{project}'
    UNION ALL SELECT 'projectHealth.verdict', '総合判定'
) source ON source.message_key = message.message_key
SET message.translations_json = JSON_SET(
        COALESCE(message.translations_json, JSON_OBJECT()),
        '$."ja-JP"', source.translated_text),
    message.version = message.version + 1,
    message.updated_at = CURRENT_TIMESTAMP
WHERE message.status = 'ENABLED'
  AND NULLIF(JSON_UNQUOTE(JSON_EXTRACT(message.translations_json, '$."ja-JP"')), '') IS NULL;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
