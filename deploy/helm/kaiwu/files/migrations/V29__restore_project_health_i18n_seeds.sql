-- 修复历史 V18 在部分已升级数据库中仅留下体检表/菜单、遗漏字典和资源目录的状态。
-- 前向补偿：不改写 V18，也不覆盖管理员已经编辑过的同名译文。

INSERT INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
SELECT 8320, 0, 'project.health.verdict', '项目体检结论', 0, 'ENABLED',
       '只读项目体检的检查结论；UNKNOWN 表示平台无法确认，不等于不合格',
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM sys_dict_type
    WHERE scope_id = 0 AND dict_code = 'project.health.verdict'
);

-- V26 的运行期资源 ID 会随库内菜单数量增长；从现有最大 ID 之后分配，避免重演 V27 的冲突。
SET @project_health_i18n_id_base := (
    SELECT GREATEST(COALESCE(MAX(id), 0), 9100000000000102800)
    FROM sys_i18n_message
);

INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT @project_health_i18n_id_base + source.sort_no,
       source.message_key, source.default_text, source.translations_json,
       source.module_code, 0, 1, 'ENABLED', source.description, 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT 1 AS sort_no, 'projectHealth.entry' AS message_key, '项目体检' AS default_text, JSON_OBJECT('en-US', 'Health check') AS translations_json, 'projects' AS module_code, '项目列表的体检入口按钮' AS description
    UNION ALL SELECT 2, 'projectHealth.title', '项目体检：{project}', JSON_OBJECT('en-US', 'Health check: {project}'), 'projects', '体检抽屉标题'
    UNION ALL SELECT 3, 'projectHealth.run', '重新体检', JSON_OBJECT('en-US', 'Run check'), 'projects', '触发一次体检'
    UNION ALL SELECT 4, 'projectHealth.verdict', '总体结论', JSON_OBJECT('en-US', 'Overall verdict'), 'projects', '体检汇总结论标签'
    UNION ALL SELECT 5, 'projectHealth.checkedAt', '体检时间', JSON_OBJECT('en-US', 'Checked at'), 'projects', '最近一次体检时间'
    UNION ALL SELECT 6, 'projectHealth.item', '检查项', JSON_OBJECT('en-US', 'Check'), 'projects', '检查项列名'
    UNION ALL SELECT 7, 'projectHealth.result', '结论', JSON_OBJECT('en-US', 'Result'), 'projects', '单项结论列名'
    UNION ALL SELECT 8, 'projectHealth.detail', '说明', JSON_OBJECT('en-US', 'Detail'), 'projects', '单项说明列名'
    UNION ALL SELECT 9, 'projectHealth.empty', '尚未体检。平台只读取仓库的契约面文件，不会写入任何内容。', JSON_OBJECT('en-US', 'Not checked yet. The platform only reads contract files and never writes to the repository.'), 'projects', '未体检时的空状态引导'
    UNION ALL SELECT 10, 'projectHealth.enabled', '允许平台只读体检', JSON_OBJECT('en-US', 'Allow read-only health check'), 'projects', '体检开关标签'
    UNION ALL SELECT 11, 'projectHealth.done', '体检完成', JSON_OBJECT('en-US', 'Health check finished'), 'projects', '体检成功提示'
    UNION ALL SELECT 12, 'projectHealth.failed', '体检失败', JSON_OBJECT('en-US', 'Health check failed'), 'projects', '体检失败提示'
    UNION ALL SELECT 13, 'projectHealth.switchUpdated', '体检开关已更新', JSON_OBJECT('en-US', 'Health check switch updated'), 'projects', '体检开关切换成功提示'
    UNION ALL SELECT 14, 'projectHealth.readOnlyHint', '体检只报告，不阻断任何流程，也不会修改业务仓库。', JSON_OBJECT('en-US', 'The check only reports. It never blocks any flow or modifies the repository.'), 'projects', '体检边界说明'
    UNION ALL SELECT 15, 'dict.project.health.verdict.PASS', '通过', JSON_OBJECT('en-US', 'Pass'), 'dict', NULL
    UNION ALL SELECT 16, 'dict.project.health.verdict.WARN', '待改进', JSON_OBJECT('en-US', 'Warning'), 'dict', NULL
    UNION ALL SELECT 17, 'dict.project.health.verdict.FAIL', '契约破坏', JSON_OBJECT('en-US', 'Failed'), 'dict', NULL
    UNION ALL SELECT 18, 'dict.project.health.verdict.UNKNOWN', '无法确认', JSON_OBJECT('en-US', 'Unknown'), 'dict', NULL
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = source.message_key
);

-- 已存在同名资源也必须重新纳入运行期目录，但默认文案与译文属于可运营数据，不能覆盖。
UPDATE sys_i18n_message
SET required_resource = 1,
    status = 'ENABLED',
    updated_at = CURRENT_TIMESTAMP
WHERE message_key IN (
    'projectHealth.entry', 'projectHealth.title', 'projectHealth.run',
    'projectHealth.verdict', 'projectHealth.checkedAt', 'projectHealth.item',
    'projectHealth.result', 'projectHealth.detail', 'projectHealth.empty',
    'projectHealth.enabled', 'projectHealth.done', 'projectHealth.failed',
    'projectHealth.switchUpdated', 'projectHealth.readOnlyHint',
    'dict.project.health.verdict.PASS', 'dict.project.health.verdict.WARN',
    'dict.project.health.verdict.FAIL', 'dict.project.health.verdict.UNKNOWN'
);

INSERT INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, label_i18n_key, status, created_at, updated_at)
SELECT source.id, type.id, source.item_label, source.item_value, source.sort_no,
       source.default_item, source.color, NULL, NULL,
       CONCAT('dict.project.health.verdict.', source.item_value), 'ENABLED',
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT 8521 AS id, '通过' AS item_label, 'PASS' AS item_value, 10 AS sort_no, 1 AS default_item, 'success' AS color
    UNION ALL SELECT 8522, '待改进', 'WARN', 20, 0, 'warning'
    UNION ALL SELECT 8523, '契约破坏', 'FAIL', 30, 0, 'error'
    UNION ALL SELECT 8524, '无法确认', 'UNKNOWN', 40, 0, 'default'
) source
JOIN sys_dict_type type
  ON type.scope_id = 0 AND type.dict_code = 'project.health.verdict'
WHERE NOT EXISTS (
    SELECT 1 FROM sys_dict_item existing
    WHERE existing.dict_type_id = type.id
      AND existing.item_value = source.item_value
);

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
SET item.label_i18n = NULL,
    item.label_i18n_key = CONCAT('dict.project.health.verdict.', item.item_value),
    item.status = 'ENABLED',
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'project.health.verdict'
  AND item.item_value IN ('PASS', 'WARN', 'FAIL', 'UNKNOWN');

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
