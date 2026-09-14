-- 为 GitLab 配置页的三个字段补充填写指引。
--
-- 该页原有 subtitle 只说明安全边界（「只创建或绑定空仓库；Token 加密保存且
-- 永不回传」），但没有任何一处告诉使用者这三个值从哪里获取：
--   - Group ID 是 GitLab 内部数值，不是组名，界面上不直接显示
--   - Token 需要哪种类型、哪些权限，直接影响能否创建仓库
-- 结果是首次配置的人只能看到三个空输入框，只能靠试。
--
-- 指引分两处呈现：tooltip 说明「是什么」，extra 说明「去哪找」。

-- ID 基于表内当前最大值递增：i18n 的 ID 段由多个迁移分别分配，
-- 硬编码一个「看起来空着」的号段会与其他模块碰撞（首版就撞上了 profile.*）。
SET @base = (SELECT COALESCE(MAX(id), 9100000000000000000) FROM sys_i18n_message);

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code,
     public_visible, required_resource, status, version, created_at, updated_at)
SELECT seed.id, seed.message_key, seed.default_text, seed.translations_json,
       'gitlab', 0, 1, 'ENABLED', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT @base + 1 AS id,
           'gitlab.baseUrlHint' AS message_key,
           'GitLab 站点根地址，不含项目或组路径。例：https://gitlab.example.com' AS default_text,
           JSON_OBJECT('en-US', 'Root URL of the GitLab site, without any group or project path. Example: https://gitlab.example.com') AS translations_json
    UNION ALL SELECT @base + 2,
           'gitlab.groupHint',
           '新仓库的归属组。填数值 ID 而非组名；留空则在每次推送时指定。',
           JSON_OBJECT('en-US', 'Group that will own the new repositories. Use the numeric ID, not the group name. Leave empty to choose it at push time.')
    UNION ALL SELECT @base + 3,
           'gitlab.groupExtra',
           '在 GitLab 打开目标组首页，组名下方即显示「群组 ID」；或访问 /api/v4/groups?search=组名 查询。',
           JSON_OBJECT('en-US', 'Open the group page in GitLab — the group ID appears under the group name. You can also query /api/v4/groups?search=<name>.')
    UNION ALL SELECT @base + 4,
           'gitlab.tokenHint',
           '用于创建仓库并推送初始代码，需要 api 权限。',
           JSON_OBJECT('en-US', 'Used to create repositories and push the initial code. Requires the api scope.')
    UNION ALL SELECT @base + 5,
           'gitlab.tokenExtra',
           '建议用目标组的 Group Access Token（角色 Maintainer、勾选 api），权限范围仅限该组；也可用个人访问令牌。',
           JSON_OBJECT('en-US', 'Prefer a Group Access Token on the target group (Maintainer role, api scope) so the token is scoped to that group only. A personal access token also works.')
) AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = seed.message_key
);
