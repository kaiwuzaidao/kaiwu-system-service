-- 操作审计的「模块」列此前把裸 code（metadata / project-factory）直接端到界面上，
-- 既没有字典也没有映射，违反 CLAUDE.md「所有枚举和状态通过统一字典组件展示」。
--
-- 只做 module，不做 operation：module 是 12 个稳定取值，而 operation 有 79 个且随每个新
-- 接口增长——给 operation 建字典意味着每加一个操作码都要同步加字典项，忘了就静默退回
-- 显示 code，等于把今天这个问题变成会反复发生的问题。operation 本身是可读的英文动宾
-- （SAVE_CONFIG / DELETE_DICT_ITEM），对排查够用。
--
-- 取值来自代码里 recordOperation 的实参全集，不是猜的；未来新增模块必须同批加字典项，
-- 否则界面按「未知值原样显示」退回 code。

INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, dict_name_key, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8331, 0, 'security.audit.module', '审计模块', 'dictType.security.audit.module', 0, 'ENABLED',
     '操作审计日志的来源模块；取值为 AuditService.recordOperation 的 module 实参',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, label_i18n_key, status, created_at, updated_at)
VALUES
    (8541, 8331, '用户管理', 'user', 10, 0, 'processing', NULL, NULL,
     'dict.security.audit.module.user', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8542, 8331, '角色管理', 'role', 20, 0, 'processing', NULL, NULL,
     'dict.security.audit.module.role', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8543, 8331, '菜单管理', 'menu', 30, 0, 'processing', NULL, NULL,
     'dict.security.audit.module.menu', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8544, 8331, '组织架构', 'org', 40, 0, 'processing', NULL, NULL,
     'dict.security.audit.module.org', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8545, 8331, '配置与字典', 'metadata', 50, 0, 'purple', NULL, NULL,
     'dict.security.audit.module.metadata', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8546, 8331, '国际化资源', 'i18n', 60, 0, 'purple', NULL, NULL,
     'dict.security.audit.module.i18n', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8547, 8331, '项目管理', 'project', 70, 0, 'cyan', NULL, NULL,
     'dict.security.audit.module.project', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8548, 8331, '项目工厂', 'project-factory', 80, 0, 'cyan', NULL, NULL,
     'dict.security.audit.module.project-factory', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8549, 8331, '定时任务', 'scheduler', 90, 0, 'cyan', NULL, NULL,
     'dict.security.audit.module.scheduler', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8550, 8331, 'GitLab 配置', 'gitlab', 100, 0, 'default', NULL, NULL,
     'dict.security.audit.module.gitlab', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8551, 8331, '大模型配置', 'ai', 110, 0, 'default', NULL, NULL,
     'dict.security.audit.module.ai', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8552, 8331, '安全运营', 'security', 120, 0, 'warning', NULL, NULL,
     'dict.security.audit.module.security', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 内置字典的类型名与标签都走资源目录（check:i18n 的 checkDictionaryCoverage 要求中英齐全）。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000103000, 'dictType.security.audit.module', '审计模块', JSON_OBJECT('en-US', 'Audit module', 'ja-JP', '監査モジュール'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.audit.module', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103001, 'dict.security.audit.module.user', '用户管理', JSON_OBJECT('en-US', 'Users', 'ja-JP', 'ユーザー管理'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103002, 'dict.security.audit.module.role', '角色管理', JSON_OBJECT('en-US', 'Roles', 'ja-JP', 'ロール管理'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103003, 'dict.security.audit.module.menu', '菜单管理', JSON_OBJECT('en-US', 'Menus', 'ja-JP', 'メニュー管理'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103004, 'dict.security.audit.module.org', '组织架构', JSON_OBJECT('en-US', 'Organization', 'ja-JP', '組織構成'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103005, 'dict.security.audit.module.metadata', '配置与字典', JSON_OBJECT('en-US', 'Configuration and dictionaries', 'ja-JP', '設定と辞書'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103006, 'dict.security.audit.module.i18n', '国际化资源', JSON_OBJECT('en-US', 'Localization resources', 'ja-JP', '多言語リソース'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103007, 'dict.security.audit.module.project', '项目管理', JSON_OBJECT('en-US', 'Projects', 'ja-JP', 'プロジェクト管理'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103008, 'dict.security.audit.module.project-factory', '项目工厂', JSON_OBJECT('en-US', 'Project factory', 'ja-JP', 'プロジェクトファクトリ'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103009, 'dict.security.audit.module.scheduler', '定时任务', JSON_OBJECT('en-US', 'Scheduled tasks', 'ja-JP', '定期タスク'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103010, 'dict.security.audit.module.gitlab', 'GitLab 配置', JSON_OBJECT('en-US', 'GitLab configuration', 'ja-JP', 'GitLab 設定'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103011, 'dict.security.audit.module.ai', '大模型配置', JSON_OBJECT('en-US', 'AI provider configuration', 'ja-JP', 'AI プロバイダー設定'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000103012, 'dict.security.audit.module.security', '安全运营', JSON_OBJECT('en-US', 'Security operations', 'ja-JP', 'セキュリティ運用'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
