-- 项目完成双仓初始推送后，用确定性的 clone 命令把开发者交接到本地 AI Coding。
-- 这是新增 seed，使用独立 92 段 ID；INSERT IGNORE 保留运行库可能已提前维护的同 key 文案。
INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code,
     public_visible, required_resource, status, description, version,
     created_at, updated_at)
VALUES
    (9200000000000003900, 'projects.localAiCoding', '开始本地 AI Coding', JSON_OBJECT('en-US', 'Start local AI coding', 'ja-JP', 'ローカル AI Coding を開始'), 'projects', 0, 1, 'ENABLED', '双仓交付后的本地开发入口', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003901, 'projects.localAiCodingTitle', '本地 AI Coding：{name}', JSON_OBJECT('en-US', 'Local AI coding: {name}', 'ja-JP', 'ローカル AI Coding：{name}'), 'projects', 0, 1, 'ENABLED', '本地开发交接弹窗标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003902, 'projects.localAiCodingReady', '创建同级工作区并克隆两个独立仓库', JSON_OBJECT('en-US', 'Create a workspace with two sibling repositories', 'ja-JP', '2 つの独立リポジトリを同じワークスペースに clone'), 'projects', 0, 1, 'ENABLED', '本地开发工作区说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003903, 'projects.localAiCodingDescription', '执行下方命令后，在工作区根目录打开团队使用的 AI 编程工具；后端和前端仍分别提交、构建和发布。', JSON_OBJECT('en-US', 'Run the command, then open your AI coding tool at the workspace root. Backend and frontend remain independently committed, built, and released.', 'ja-JP', '次のコマンドを実行し、ワークスペース直下で AI Coding ツールを開いてください。バックエンドとフロントエンドは引き続き別々に commit・build・release します。'), 'projects', 0, 1, 'ENABLED', '双仓边界说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003904, 'projects.localAiCodingSsh', 'SSH', JSON_OBJECT('en-US', 'SSH', 'ja-JP', 'SSH'), 'projects', 0, 1, 'ENABLED', 'clone 协议', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003905, 'projects.localAiCodingHttps', 'HTTPS', JSON_OBJECT('en-US', 'HTTPS', 'ja-JP', 'HTTPS'), 'projects', 0, 1, 'ENABLED', 'clone 协议', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003906, 'projects.localAiCodingCommand', '复制工作区初始化命令', JSON_OBJECT('en-US', 'Copy the workspace initialization command', 'ja-JP', 'ワークスペース初期化コマンドをコピー'), 'projects', 0, 1, 'ENABLED', 'clone 命令标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003907, 'projects.localAiCodingCopied', '初始化命令已复制', JSON_OBJECT('en-US', 'Initialization command copied', 'ja-JP', '初期化コマンドをコピーしました'), 'projects', 0, 1, 'ENABLED', '复制成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003908, 'projects.localAiCodingCloneMissing', '仓库 clone 地址尚未就绪，请刷新任务状态后重试。', JSON_OBJECT('en-US', 'Repository clone URLs are not ready. Refresh the task and retry.', 'ja-JP', 'リポジトリの clone URL がまだ準備できていません。状態を更新して再試行してください。'), 'projects', 0, 1, 'ENABLED', 'clone 地址缺失提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003909, 'projects.localAiCodingNextTitle', '本地启动', JSON_OBJECT('en-US', 'Start locally', 'ja-JP', 'ローカル起動'), 'projects', 0, 1, 'ENABLED', '本地启动说明标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003910, 'projects.localAiCodingNext', '进入后端执行 bash scripts/dev.sh；进入前端执行 bash scripts/dev.sh。两个仓库都已包含 AGENTS.md、CLAUDE.md 和工程门禁。', JSON_OBJECT('en-US', 'Run bash scripts/dev.sh in the backend and then in the frontend. Both repositories include AGENTS.md, CLAUDE.md, and engineering gates.', 'ja-JP', 'バックエンドとフロントエンドでそれぞれ bash scripts/dev.sh を実行します。両リポジトリには AGENTS.md、CLAUDE.md、工程ゲートが含まれます。'), 'projects', 0, 1, 'ENABLED', '本地启动命令说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000003911, 'projects.localAiCodingBoundary', 'Kaiwu 只完成这一次初始化交接，不会再次写入业务仓库，也不会在线执行 AI 生成的源码或命令。', JSON_OBJECT('en-US', 'Kaiwu performs this initialization handoff once. It never writes the business repositories again or executes AI-generated source or commands online.', 'ja-JP', 'Kaiwu が行うのはこの初回引き渡しだけです。以後ビジネスリポジトリへ書き込まず、AI が生成したソースやコマンドをオンライン実行しません。'), 'projects', 0, 1, 'ENABLED', '一次性生成与 AI 边界提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
