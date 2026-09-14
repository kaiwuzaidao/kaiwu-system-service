-- 「切换项目」弹窗新增打开方式偏好，以及业务后台宿主页 /workspace 的文案。
--
-- ID 接在 V43 之后（…4019）继续分配。沿用 INSERT ... VALUES 字面量形式，
-- 前端 check:i18n 门禁只解析这一种写法（V42 用动态 ID 导致过目录"查无此 key"）。

INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code,
     public_visible, required_resource, status, description, version, created_at, updated_at)
VALUES
    (9200000000000004020, 'layout.project.openMode.inline', '当前页面', JSON_OBJECT('en-US', 'Current page'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004021, 'layout.project.openMode.newTab', '新标签页', JSON_OBJECT('en-US', 'New tab'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004022, 'layout.project.loadingEntry', '正在进入项目后台…', JSON_OBJECT('en-US', 'Opening the project console…'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004023, 'layout.project.entryUnavailable', '该项目暂无可用的后台入口', JSON_OBJECT('en-US', 'This project has no console entry yet'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004024, 'layout.project.backToPlatform', '返回 Kaiwu 平台', JSON_OBJECT('en-US', 'Back to the Kaiwu platform'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
