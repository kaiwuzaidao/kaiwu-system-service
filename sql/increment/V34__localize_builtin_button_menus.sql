-- 内置 BUTTON 也会在 system 权限中心展示，不能只国际化侧边栏的目录和 MENU。
-- key 由稳定权限码确定性推导：system:project:list -> menu.system.permission.system.project.list。

SET @builtin_button_i18n_id_base := (
    SELECT GREATEST(COALESCE(MAX(id), 0), 9100000000000102920)
    FROM sys_i18n_message
);

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT @builtin_button_i18n_id_base + source.sort_no,
       CONCAT('menu.system.permission.', REPLACE(source.permission_code, ':', '.')),
       source.default_text, source.translations_json, 'menu', 0, 1, 'ENABLED',
       CONCAT('内置按钮菜单名称：', source.permission_code), 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT 1 AS sort_no, 'system:platform:read' AS permission_code, '验证平台访问' AS default_text, JSON_OBJECT('en-US', 'Validate platform access', 'ja-JP', 'プラットフォームアクセスを検証') AS translations_json
    UNION ALL SELECT 2, 'system:user:list', '查询用户', JSON_OBJECT('en-US', 'View users', 'ja-JP', 'ユーザーを表示')
    UNION ALL SELECT 3, 'system:user:create', '创建用户', JSON_OBJECT('en-US', 'Create user', 'ja-JP', 'ユーザーを作成')
    UNION ALL SELECT 4, 'system:user:update', '编辑用户', JSON_OBJECT('en-US', 'Edit user', 'ja-JP', 'ユーザーを編集')
    UNION ALL SELECT 5, 'system:user:status', '启停用户', JSON_OBJECT('en-US', 'Enable or disable user', 'ja-JP', 'ユーザーを有効または無効にする')
    UNION ALL SELECT 6, 'system:user:reset-password', '重置密码', JSON_OBJECT('en-US', 'Reset password', 'ja-JP', 'パスワードをリセット')
    UNION ALL SELECT 7, 'system:project:list', '查询项目', JSON_OBJECT('en-US', 'View projects', 'ja-JP', 'プロジェクトを表示')
    UNION ALL SELECT 8, 'system:project:create', '创建项目', JSON_OBJECT('en-US', 'Create project', 'ja-JP', 'プロジェクトを作成')
    UNION ALL SELECT 9, 'system:project:update', '编辑项目', JSON_OBJECT('en-US', 'Edit project', 'ja-JP', 'プロジェクトを編集')
    UNION ALL SELECT 10, 'system:project:status', '变更项目状态', JSON_OBJECT('en-US', 'Change project status', 'ja-JP', 'プロジェクト状態を変更')
    UNION ALL SELECT 11, 'system:project:member', '管理项目成员', JSON_OBJECT('en-US', 'Manage project members', 'ja-JP', 'プロジェクトメンバーを管理')
    UNION ALL SELECT 12, 'system:project:role', '管理项目角色', JSON_OBJECT('en-US', 'Manage project roles', 'ja-JP', 'プロジェクトロールを管理')
    UNION ALL SELECT 13, 'system:project:menu', '管理项目菜单', JSON_OBJECT('en-US', 'Manage project menus', 'ja-JP', 'プロジェクトメニューを管理')
    UNION ALL SELECT 14, 'system:config:list', '查询配置', JSON_OBJECT('en-US', 'View configurations', 'ja-JP', '設定を表示')
    UNION ALL SELECT 15, 'system:config:save', '保存配置', JSON_OBJECT('en-US', 'Save configuration', 'ja-JP', '設定を保存')
    UNION ALL SELECT 16, 'system:config:delete', '删除配置', JSON_OBJECT('en-US', 'Delete configuration', 'ja-JP', '設定を削除')
    UNION ALL SELECT 17, 'system:dict:list', '查询字典', JSON_OBJECT('en-US', 'View dictionaries', 'ja-JP', '辞書を表示')
    UNION ALL SELECT 18, 'system:dict:save', '保存字典', JSON_OBJECT('en-US', 'Save dictionary', 'ja-JP', '辞書を保存')
    UNION ALL SELECT 19, 'system:dict:delete', '删除字典', JSON_OBJECT('en-US', 'Delete dictionary', 'ja-JP', '辞書を削除')
    UNION ALL SELECT 20, 'system:project-factory:list', '查看项目生成', JSON_OBJECT('en-US', 'View project generations', 'ja-JP', 'プロジェクト生成を表示')
    UNION ALL SELECT 21, 'system:project-factory:generate', '生成项目', JSON_OBJECT('en-US', 'Generate project', 'ja-JP', 'プロジェクトを生成')
    UNION ALL SELECT 22, 'system:project-factory:download', '下载项目制品', JSON_OBJECT('en-US', 'Download project artifact', 'ja-JP', 'プロジェクト成果物をダウンロード')
    UNION ALL SELECT 23, 'system:project-factory:push', '初始推送 GitLab', JSON_OBJECT('en-US', 'Initial GitLab push', 'ja-JP', 'GitLab へ初回プッシュ')
    UNION ALL SELECT 24, 'system:ai:list', '查看大模型配置', JSON_OBJECT('en-US', 'View AI provider configuration', 'ja-JP', 'AI プロバイダー設定を表示')
    UNION ALL SELECT 25, 'system:ai:save', '保存大模型配置', JSON_OBJECT('en-US', 'Save AI provider configuration', 'ja-JP', 'AI プロバイダー設定を保存')
    UNION ALL SELECT 26, 'system:ai:test', '测试大模型连接', JSON_OBJECT('en-US', 'Test AI provider connection', 'ja-JP', 'AI プロバイダー接続をテスト')
    UNION ALL SELECT 27, 'system:git:list', '查看 GitLab 配置', JSON_OBJECT('en-US', 'View GitLab configuration', 'ja-JP', 'GitLab 設定を表示')
    UNION ALL SELECT 28, 'system:git:save', '保存 GitLab 配置', JSON_OBJECT('en-US', 'Save GitLab configuration', 'ja-JP', 'GitLab 設定を保存')
    UNION ALL SELECT 29, 'system:git:test', '测试 GitLab 连接', JSON_OBJECT('en-US', 'Test GitLab connection', 'ja-JP', 'GitLab 接続をテスト')
    UNION ALL SELECT 30, 'system:scheduler:list', '查看定时任务', JSON_OBJECT('en-US', 'View scheduled tasks', 'ja-JP', '定期タスクを表示')
    UNION ALL SELECT 31, 'system:scheduler:save', '保存定时任务', JSON_OBJECT('en-US', 'Save scheduled task', 'ja-JP', '定期タスクを保存')
    UNION ALL SELECT 32, 'system:scheduler:credential', '轮换项目调度凭据', JSON_OBJECT('en-US', 'Rotate project scheduler credential', 'ja-JP', 'プロジェクトスケジューラー認証情報をローテーション')
    UNION ALL SELECT 33, 'system:audit:list', '查看审计日志', JSON_OBJECT('en-US', 'View audit logs', 'ja-JP', '監査ログを表示')
    UNION ALL SELECT 34, 'system:session:list', '查看在线会话', JSON_OBJECT('en-US', 'View online sessions', 'ja-JP', 'オンラインセッションを表示')
    UNION ALL SELECT 35, 'system:session:force-offline', '强制用户下线', JSON_OBJECT('en-US', 'Force user sign-out', 'ja-JP', 'ユーザーを強制ログアウト')
    UNION ALL SELECT 36, 'system:org:list', '查看组织架构', JSON_OBJECT('en-US', 'View organization', 'ja-JP', '組織を表示')
    UNION ALL SELECT 37, 'system:org:save', '维护部门', JSON_OBJECT('en-US', 'Maintain department', 'ja-JP', '部門を管理')
    UNION ALL SELECT 38, 'system:org:delete', '删除部门', JSON_OBJECT('en-US', 'Delete department', 'ja-JP', '部門を削除')
    UNION ALL SELECT 39, 'system:org:assign', '分配用户部门', JSON_OBJECT('en-US', 'Assign users to department', 'ja-JP', 'ユーザーを部門に割り当て')
    UNION ALL SELECT 40, 'system:i18n:list', '查询国际化资源', JSON_OBJECT('en-US', 'View internationalization resources', 'ja-JP', '国際化リソースを表示')
    UNION ALL SELECT 41, 'system:i18n:save', '保存国际化资源', JSON_OBJECT('en-US', 'Save internationalization resources', 'ja-JP', '国際化リソースを保存')
    UNION ALL SELECT 42, 'system:i18n:delete', '删除国际化资源', JSON_OBJECT('en-US', 'Delete internationalization resources', 'ja-JP', '国際化リソースを削除')
    UNION ALL SELECT 43, 'system:project:health', '项目体检', JSON_OBJECT('en-US', 'Project health check', 'ja-JP', 'プロジェクト健全性チェック')
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = CONCAT('menu.system.permission.', REPLACE(source.permission_code, ':', '.'))
);

UPDATE sys_project_menu menu
JOIN sys_project project ON project.id = menu.project_id
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('menu.system.permission.', REPLACE(menu.permission_code, ':', '.'))
 AND resource.status = 'ENABLED'
SET menu.menu_name_key = resource.message_key,
    menu.updated_at = CURRENT_TIMESTAMP
WHERE project.project_code = 'system'
  AND menu.menu_type = 'BUTTON'
  AND menu.permission_code IS NOT NULL;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
