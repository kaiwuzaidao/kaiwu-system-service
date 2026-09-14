-- 修复 V27 的主键 ID 撞号事故。
--
-- 事故经过：V27 用字面量 ID 9100000000000003101 / 3102 种入两条错误码资源，
-- 但 V26 分配项目菜单资源用的是 `9100000000000003100 + ROW_NUMBER()`——**运行时计算**，
-- 占用范围随库里项目菜单数量增长，无法从 SQL 文件里读出来。挑号时只扫描了文件中的
-- 字面量 ID（最大 9100000000000003002），正好挑进 V26 的动态段。
--
-- 后果：`ON DUPLICATE KEY UPDATE` 命中主键冲突走了更新分支，把两条项目菜单名资源的
-- default_text / translations_json / module_code / description 覆盖成了错误码文案，
-- 而 message_key 不在更新列表里，所以两条错误码资源根本没有种进去——
-- 既丢了数据，也没达成目的，且 V27 记录为执行成功，从迁移历史上看不出任何异常。
--
-- V27 已在环境中执行过，按 CLAUDE.md「已发布的 V 脚本一律不可修改」只能追加修正。

-- 1) 复原被覆盖的两条项目菜单名资源。
--    default_text 从 sys_project_menu.menu_name 取（key 与菜单是确定性对应关系）；
--    译文取自 V10 的原始 seed——V26 迁移后 menu_name_i18n 已被清空，库里恢复不出来。
UPDATE sys_i18n_message
SET default_text = (
        SELECT menu.menu_name FROM sys_project_menu menu
        WHERE menu.menu_name_key = sys_i18n_message.message_key
        LIMIT 1
    ),
    translations_json = JSON_OBJECT('en-US', 'View internationalization resources'),
    module_code = 'menu',
    public_visible = 0,
    required_resource = 0,
    description = '项目菜单名称，由 ADR 0015 从 menu_name_i18n 迁移',
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE message_key = 'menu.project.9000000000000000001.n9000000000000015001'
  AND module_code = 'api';

UPDATE sys_i18n_message
SET default_text = (
        SELECT menu.menu_name FROM sys_project_menu menu
        WHERE menu.menu_name_key = sys_i18n_message.message_key
        LIMIT 1
    ),
    translations_json = JSON_OBJECT('en-US', 'Save internationalization resources'),
    module_code = 'menu',
    public_visible = 0,
    required_resource = 0,
    description = '项目菜单名称，由 ADR 0015 从 menu_name_i18n 迁移',
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE message_key = 'menu.project.9000000000000000001.n9000000000000015002'
  AND module_code = 'api';

-- 2) 把 V27 本该种入的两条错误码资源补上。
--
--    ID 改到 91000000000000041xx 段，并且**按 message_key 判重而不是靠主键冲突兜底**：
--    主键撞号时 ON DUPLICATE KEY UPDATE 会静默改写别人的行，这正是本次事故的成因。
--    NOT EXISTS 判重在撞号时选择「不插入」，失败方式是可见的。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT * FROM (
    SELECT 9100000000000004101 AS id, 'api.i18n.keyNotFound' AS message_key,
           '国际化资源不存在：{key}' AS default_text,
           JSON_OBJECT('en-US', 'The internationalization resource does not exist: {key}')
               AS translations_json,
           'api' AS module_code, 0 AS public_visible, 1 AS required_resource,
           'ENABLED' AS status, NULL AS description, 1 AS version,
           CURRENT_TIMESTAMP AS created_at, CURRENT_TIMESTAMP AS updated_at
    UNION ALL
    SELECT 9100000000000004102, 'api.projectHealth.disabled',
           '该项目已关闭只读体检',
           JSON_OBJECT('en-US', 'Read-only health check is disabled for this project'),
           'api', 0, 1, 'ENABLED', NULL, 1,
           CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
) AS seed
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = seed.message_key
       OR existing.id = seed.id
);

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
