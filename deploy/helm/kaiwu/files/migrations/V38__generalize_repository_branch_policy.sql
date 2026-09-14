-- ADR 0020：新项目不再继承维护者个人的 dev-jarvis 分支偏好。
-- Flyway 对该版本只执行一次；这里有意不使用 IF EXISTS，表或列偏离基线时应失败并暴露漂移。
-- 仅修改列默认值，不回写既有项目或已绑定仓库的分支。
ALTER TABLE sys_project
    ALTER COLUMN default_branch SET DEFAULT 'main';

ALTER TABLE sys_project_repository
    ALTER COLUMN default_branch SET DEFAULT 'main';

UPDATE sys_i18n_message
SET default_text = '在脚手架约束内一次生成后端与前端仓库；两份 ZIP 始终可下载，GitLab 只向项目配置分支做一次初始提交，后续 CI/CD 与分支策略由业务仓库接管。',
    translations_json = JSON_OBJECT(
        'en-US', 'Generate backend and frontend repositories once within the scaffold boundary. Both ZIP files remain downloadable. GitLab receives one initial commit on the configured project branch; the business repositories own later CI/CD and branch strategy.',
        'ja-JP', 'スキャフォールドの制約内でバックエンドとフロントエンドのリポジトリを一度だけ生成します。2 つの ZIP は常にダウンロードでき、GitLab への初回コミット後の CI/CD とブランチ戦略は業務リポジトリが管理します。'),
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE message_key = 'factory.description';

UPDATE sys_i18n_message
SET default_text = '生成成功后可下载后端和前端 ZIP；若 GitLab 已配置，可向项目配置分支显式执行一次初始推送。后续修改完全由业务仓库接管。',
    translations_json = JSON_OBJECT(
        'en-US', 'After success, download backend and frontend ZIP files or explicitly make one initial push to the configured project branch when GitLab is available. Business repositories own all later changes.',
        'ja-JP', '生成後はバックエンドとフロントエンドの ZIP をダウンロードできます。GitLab が設定されている場合は、プロジェクトで設定したブランチへ一度だけ初回プッシュできます。その後の変更は業務リポジトリが管理します。'),
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE message_key = 'onboarding.confirm.description';
