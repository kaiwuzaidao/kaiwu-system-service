-- ADR 0014 补偿：历史字典类型只有 dict_name 原文，未绑定 dict_name_key。
-- 平台内置类型在编译期可知，统一提升为资源引用；项目运行期新增的字典仍可保持固定文案。

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000102900, 'dictType.ai.test.status', '大模型连通测试状态', JSON_OBJECT('en-US', 'AI connectivity test status', 'ja-JP', 'AI 接続テスト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：ai.test.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102901, 'dictType.common.boolean_enabled', '是否启用', JSON_OBJECT('en-US', 'Enabled option', 'ja-JP', '有効化するか'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.boolean_enabled', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102902, 'dictType.common.status', '通用启停状态', JSON_OBJECT('en-US', 'General enablement status', 'ja-JP', '共通有効・無効状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102903, 'dictType.common.tag_color', '标签颜色', JSON_OBJECT('en-US', 'Tag color', 'ja-JP', 'タグの色'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.tag_color', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102904, 'dictType.config.value.type', '配置值类型', JSON_OBJECT('en-US', 'Configuration value type', 'ja-JP', '設定値の種類'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：config.value.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102905, 'dictType.gitlab.test.status', 'GitLab 连通测试状态', JSON_OBJECT('en-US', 'GitLab connectivity test status', 'ja-JP', 'GitLab 接続テスト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：gitlab.test.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102906, 'dictType.notification.type', '站内信分类', JSON_OBJECT('en-US', 'Notification type', 'ja-JP', '通知の種類'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：notification.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102907, 'dictType.platform.locale', '平台语言', JSON_OBJECT('en-US', 'Platform language', 'ja-JP', 'プラットフォーム言語'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.locale', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102908, 'dictType.platform.menu.type', '平台菜单类型', JSON_OBJECT('en-US', 'Platform menu type', 'ja-JP', 'プラットフォームメニュー種別'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.menu.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102909, 'dictType.project.generation.mode', '项目生成方式', JSON_OBJECT('en-US', 'Project generation mode', 'ja-JP', 'プロジェクト生成方式'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.mode', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102910, 'dictType.project.generation.status', '项目生成状态', JSON_OBJECT('en-US', 'Project generation status', 'ja-JP', 'プロジェクト生成状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102911, 'dictType.project.health.verdict', '项目体检结论', JSON_OBJECT('en-US', 'Project health verdict', 'ja-JP', 'プロジェクト健全性判定'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.health.verdict', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102912, 'dictType.project.member.status', '项目成员状态', JSON_OBJECT('en-US', 'Project member status', 'ja-JP', 'プロジェクトメンバー状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.member.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102913, 'dictType.project.repository.push.status', '仓库推送状态', JSON_OBJECT('en-US', 'Repository push status', 'ja-JP', 'リポジトリプッシュ状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.repository.push.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102914, 'dictType.project.status', '业务项目状态', JSON_OBJECT('en-US', 'Business project status', 'ja-JP', '業務プロジェクト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102915, 'dictType.scheduler.execution.status', '定时任务执行状态', JSON_OBJECT('en-US', 'Scheduled task execution status', 'ja-JP', '定期タスク実行状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：scheduler.execution.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102916, 'dictType.security.login.status', '登录日志状态', JSON_OBJECT('en-US', 'Sign-in log status', 'ja-JP', 'ログイン履歴状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.login.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102917, 'dictType.security.session.status', '在线会话状态', JSON_OBJECT('en-US', 'Online session status', 'ja-JP', 'オンラインセッション状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.session.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102918, 'dictType.user.status', '平台用户状态', JSON_OBJECT('en-US', 'Platform user status', 'ja-JP', 'プラットフォームユーザー状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：user.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_dict_type type
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dictType.', type.dict_code)
 AND resource.status = 'ENABLED'
SET type.dict_name_key = resource.message_key,
    type.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code IN (
    'ai.test.status', 'common.boolean_enabled', 'common.status', 'common.tag_color',
    'config.value.type', 'gitlab.test.status', 'notification.type', 'platform.locale',
    'platform.menu.type', 'project.generation.mode', 'project.generation.status',
    'project.health.verdict', 'project.member.status', 'project.repository.push.status',
    'project.status', 'scheduler.execution.status', 'security.login.status',
    'security.session.status', 'user.status'
  );

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
