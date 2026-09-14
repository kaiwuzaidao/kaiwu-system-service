-- ADR 0012：只读项目体检。
-- 只存检查结论与版本号，不存被读取的文件内容——体检记录不得成为业务代码的副本。

CREATE TABLE IF NOT EXISTS sys_project_health_report (
    project_id BIGINT NOT NULL,
    verdict VARCHAR(16) NOT NULL,
    checks_json JSON NOT NULL,
    checked_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (project_id),
    CONSTRAINT fk_sys_project_health_report_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 项目 owner 可以关闭体检；关闭后平台不再访问该仓库（ADR 0012 第 3 节）。
-- 默认开启：体检只读四个契约面文件、只报告不阻断，默认关闭会让绝大多数项目永远不体检。
-- MySQL 的 ADD COLUMN 不支持 IF NOT EXISTS，用 information_schema 判定保证可重跑。
SET @health_flag_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_project'
      AND COLUMN_NAME = 'health_check_enabled'
);
SET @health_flag_sql = IF(
    @health_flag_exists = 0,
    'ALTER TABLE sys_project ADD COLUMN health_check_enabled TINYINT NOT NULL DEFAULT 1'
        ' COMMENT ''是否允许平台只读体检''',
    'SELECT 1'
);
PREPARE health_flag_stmt FROM @health_flag_sql;
EXECUTE health_flag_stmt;
DEALLOCATE PREPARE health_flag_stmt;

-- 体检结论是枚举，必须走统一字典组件展示，页面不得自行硬编码映射。
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8320, 0, 'project.health.verdict', '项目体检结论', 0, 'ENABLED',
     '只读项目体检的检查结论；UNKNOWN 表示平台无法确认，不等于不合格',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, status, created_at, updated_at)
VALUES
    (8521, 8320, '通过', 'PASS', 10, 1, 'success', NULL,
     '{"en-US":"Pass"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8522, 8320, '待改进', 'WARN', 20, 0, 'warning', NULL,
     '{"en-US":"Warning"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8523, 8320, '契约破坏', 'FAIL', 30, 0, 'error', NULL,
     '{"en-US":"Failed"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8524, 8320, '无法确认', 'UNKNOWN', 40, 0, 'default', NULL,
     '{"en-US":"Unknown"}', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 权限三端同码：后端 @RequirePermission、前端按钮、这里的菜单 seed 用同一个权限码。
-- 挂在内置 system 项目的「项目管理」菜单下；父节点按 route_path 定位，
-- 不写死 ID——该菜单由 SystemProjectBootstrap 从 legacy sys_menu 迁移而来，ID 不稳定。
INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT 9000000000000018000, parent.project_id, parent.id,
       '项目体检', '{"en-US":"Project health check"}', 'BUTTON',
       NULL, NULL, 'system:project:health', NULL, 80, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project_menu parent
JOIN sys_project project ON project.id = parent.project_id
WHERE project.project_code = 'system'
  AND parent.menu_type = 'MENU'
  AND parent.route_path = '/projects'
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id),
    menu_name = VALUES(menu_name),
    menu_name_i18n = VALUES(menu_name_i18n),
    permission_code = VALUES(permission_code),
    sort_no = VALUES(sort_no),
    visible = 1,
    status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;

-- 只读项目体检的界面文案（ADR 0010 的平台 i18n 目录）。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000981, 'projectHealth.entry', '项目体检', JSON_OBJECT('en-US', 'Health check'), 'projects', 0, 1, 'ENABLED', '项目列表的体检入口按钮', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000982, 'projectHealth.title', '项目体检：{project}', JSON_OBJECT('en-US', 'Health check: {project}'), 'projects', 0, 1, 'ENABLED', '体检抽屉标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000983, 'projectHealth.run', '重新体检', JSON_OBJECT('en-US', 'Run check'), 'projects', 0, 1, 'ENABLED', '触发一次体检', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000984, 'projectHealth.verdict', '总体结论', JSON_OBJECT('en-US', 'Overall verdict'), 'projects', 0, 1, 'ENABLED', '体检汇总结论标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000985, 'projectHealth.checkedAt', '体检时间', JSON_OBJECT('en-US', 'Checked at'), 'projects', 0, 1, 'ENABLED', '最近一次体检时间', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000986, 'projectHealth.item', '检查项', JSON_OBJECT('en-US', 'Check'), 'projects', 0, 1, 'ENABLED', '检查项列名', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000987, 'projectHealth.result', '结论', JSON_OBJECT('en-US', 'Result'), 'projects', 0, 1, 'ENABLED', '单项结论列名', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000988, 'projectHealth.detail', '说明', JSON_OBJECT('en-US', 'Detail'), 'projects', 0, 1, 'ENABLED', '单项说明列名', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000989, 'projectHealth.empty', '尚未体检。平台只读取仓库的契约面文件，不会写入任何内容。', JSON_OBJECT('en-US', 'Not checked yet. The platform only reads contract files and never writes to the repository.'), 'projects', 0, 1, 'ENABLED', '未体检时的空状态引导', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000990, 'projectHealth.enabled', '允许平台只读体检', JSON_OBJECT('en-US', 'Allow read-only health check'), 'projects', 0, 1, 'ENABLED', '体检开关标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000991, 'projectHealth.done', '体检完成', JSON_OBJECT('en-US', 'Health check finished'), 'projects', 0, 1, 'ENABLED', '体检成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000992, 'projectHealth.failed', '体检失败', JSON_OBJECT('en-US', 'Health check failed'), 'projects', 0, 1, 'ENABLED', '体检失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000993, 'projectHealth.switchUpdated', '体检开关已更新', JSON_OBJECT('en-US', 'Health check switch updated'), 'projects', 0, 1, 'ENABLED', '开关切换成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000995, 'dict.project.health.verdict.PASS', '通过', JSON_OBJECT('en-US', 'Pass'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000996, 'dict.project.health.verdict.WARN', '待改进', JSON_OBJECT('en-US', 'Warning'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000997, 'dict.project.health.verdict.FAIL', '契约破坏', JSON_OBJECT('en-US', 'Failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000998, 'dict.project.health.verdict.UNKNOWN', '无法确认', JSON_OBJECT('en-US', 'Unknown'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000994, 'projectHealth.readOnlyHint', '体检只报告，不阻断任何流程，也不会修改业务仓库。', JSON_OBJECT('en-US', 'The check only reports. It never blocks any flow or modifies the repository.'), 'projects', 0, 1, 'ENABLED', '体检边界说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
