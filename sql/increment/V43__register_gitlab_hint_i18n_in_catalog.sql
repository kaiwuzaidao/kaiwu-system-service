-- 把 V42 种下的五个 GitLab 配置指引资源补登进"可被目录校验解析"的形式。
--
-- 背景：V42 用 `SET @base = MAX(id)` + `SELECT ... UNION ALL` 动态分配 ID，
-- 而前端的 check:i18n 门禁（kaiwu-system-web/scripts/i18n/i18n-sql.mjs）
-- 只解析 `INSERT ... VALUES (<字面量 ID>, '<key>', ...)` 这一种形式，
-- 因此它读不出 V42 种了哪些 key。加上 V42 当初只写进了
-- deploy/helm/kaiwu/files/migrations/、没有同步到 sql/increment/，
-- 结果是：UI 已经在用 gitlab.baseUrlHint 等 key，目录里却"查无此 key"，
-- kaiwu-system-web 的 pnpm verify 因此长期失败。
--
-- 本迁移是幂等的补偿步骤（README 允许 seed/补偿步骤幂等）：ID 与 key 都取
-- 真实库中 V42 实际落下的值（2026-09-11 查 test 库确认为 …4015~…4019），
-- 因此 INSERT IGNORE 在已执行过 V42 的库上是空操作，在全新库上则由 V42 先种、
-- 本条同样空转。两种情况结果一致。

INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code,
     public_visible, required_resource, status, description, version, created_at, updated_at)
VALUES
    (9200000000000004015, 'gitlab.baseUrlHint', 'GitLab 站点根地址，不含项目或组路径。例：https://gitlab.example.com', JSON_OBJECT('en-US', 'Root URL of the GitLab site, without any group or project path. Example: https://gitlab.example.com'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004016, 'gitlab.groupHint', '新仓库的归属组。填数值 ID 而非组名；留空则在每次推送时指定。', JSON_OBJECT('en-US', 'Group that will own the new repositories. Use the numeric ID, not the group name. Leave empty to choose it at push time.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004017, 'gitlab.groupExtra', '在 GitLab 打开目标组首页，组名下方即显示「群组 ID」；或访问 /api/v4/groups?search=组名 查询。', JSON_OBJECT('en-US', 'Open the group page in GitLab — the group ID appears under the group name. You can also query /api/v4/groups?search=<name>.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004018, 'gitlab.tokenHint', '用于创建仓库并推送初始代码，需要 api 权限。', JSON_OBJECT('en-US', 'Used to create repositories and push the initial code. Requires the api scope.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004019, 'gitlab.tokenExtra', '建议用目标组的 Group Access Token（角色 Maintainer、勾选 api），权限范围仅限该组；也可用个人访问令牌。', JSON_OBJECT('en-US', 'Prefer a Group Access Token on the target group (Maintainer role, api scope) so the token is scoped to that group only. A personal access token also works.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
