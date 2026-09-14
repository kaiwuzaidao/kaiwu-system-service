-- Kaiwu 平台库完整结构与初始数据快照。
-- 全新数据库由 Flyway 执行 sql/increment/V1__kaiwu_baseline.sql 初始化。
-- 后续迁移继续使用 V2、V3……，并同步维护本快照。

CREATE TABLE IF NOT EXISTS sys_user (
    id BIGINT NOT NULL,
    username VARCHAR(64) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NULL,
    status VARCHAR(20) NOT NULL,
    locale VARCHAR(16) NOT NULL DEFAULT 'zh-CN',
    must_change_password TINYINT NOT NULL DEFAULT 0 COMMENT '1=登录后必须先改密码',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_user_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- sys_role / sys_permission / sys_user_role / sys_role_permission 已由 V36 删除：
-- 权限事实源统一为 sys_project_*，这四张表没有任何读写路径（详见 V36 脚本头注释）。
-- sys_menu 保留：它仍是 SystemProjectBootstrap.importLegacyMenus 的平台菜单种子来源。

CREATE TABLE IF NOT EXISTS sys_menu (
    id BIGINT NOT NULL,
    parent_id BIGINT NULL,
    menu_name VARCHAR(100) NOT NULL,
    menu_name_i18n JSON NULL,
    menu_type VARCHAR(20) NOT NULL,
    route_path VARCHAR(256) NULL,
    component_path VARCHAR(256) NULL,
    permission_code VARCHAR(128) NULL,
    icon VARCHAR(64) NULL,
    sort_no INT NOT NULL DEFAULT 0,
    visible TINYINT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'ENABLED',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_menu_permission (permission_code),
    KEY idx_sys_menu_parent_sort (parent_id, sort_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_online_session (
    id VARCHAR(36) NOT NULL,
    user_id BIGINT NOT NULL,
    refresh_token_hash VARCHAR(64) NOT NULL,
    session_status VARCHAR(20) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    last_seen_at DATETIME NOT NULL,
    revoked_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_sys_online_session_user_status (user_id, session_status),
    CONSTRAINT fk_sys_online_session_user FOREIGN KEY (user_id) REFERENCES sys_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_login_log (
    id BIGINT NOT NULL AUTO_INCREMENT,
    username VARCHAR(64) NULL,
    user_id BIGINT NULL,
    login_status VARCHAR(20) NOT NULL,
    message VARCHAR(255) NULL,
    client_ip VARCHAR(64) NULL,
    trace_id VARCHAR(64) NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_login_log_username_time (username, created_at),
    KEY idx_sys_login_log_status_time (login_status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_oper_log (
    id BIGINT NOT NULL AUTO_INCREMENT,
    user_id BIGINT NULL,
    username VARCHAR(64) NULL,
    module VARCHAR(64) NOT NULL,
    operation VARCHAR(100) NOT NULL,
    request_method VARCHAR(20) NOT NULL,
    request_path VARCHAR(255) NOT NULL,
    response_status INT NOT NULL,
    detail VARCHAR(1000) NULL,
    target_type VARCHAR(64) NULL COMMENT '目标资源类型',
    target_id VARCHAR(64) NULL COMMENT '目标资源 ID',
    change_json TEXT NULL COMMENT '字段级变更 JSON: [{field, before, after}]',
    client_ip VARCHAR(64) NULL,
    trace_id VARCHAR(64) NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_oper_log_user_time (user_id, created_at),
    KEY idx_sys_oper_log_module_time (module, created_at),
    KEY idx_sys_oper_log_target (target_type, target_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project (
    id BIGINT NOT NULL,
    project_code VARCHAR(64) NOT NULL,
    project_name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NULL,
    status VARCHAR(20) NOT NULL,
    built_in TINYINT NOT NULL DEFAULT 0,
    created_by BIGINT NOT NULL,
    package_name VARCHAR(128) NOT NULL,
    repository_url VARCHAR(512) NULL,
    gitlab_project_id VARCHAR(256) NULL,
    default_branch VARCHAR(64) NOT NULL DEFAULT 'main',
    backend_url VARCHAR(512) NULL,
    backend_label VARCHAR(100) NULL,
    service_url VARCHAR(512) NULL COMMENT 'Gateway PROJECT 路由上游地址',
    health_check_enabled TINYINT NOT NULL DEFAULT 1 COMMENT '是否允许平台只读体检',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_project_code (project_code),
    CONSTRAINT fk_sys_project_creator FOREIGN KEY (created_by) REFERENCES sys_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_role (
    id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    role_code VARCHAR(64) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    status VARCHAR(20) NOT NULL,
    built_in TINYINT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_project_role_code (project_id, role_code),
    CONSTRAINT fk_sys_project_role_project FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_member (
    project_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (project_id, user_id),
    CONSTRAINT fk_sys_project_member_project FOREIGN KEY (project_id) REFERENCES sys_project (id),
    CONSTRAINT fk_sys_project_member_user FOREIGN KEY (user_id) REFERENCES sys_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_member_role (
    project_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (project_id, user_id, role_id),
    CONSTRAINT fk_sys_project_member_role_member FOREIGN KEY (project_id, user_id)
        REFERENCES sys_project_member (project_id, user_id),
    CONSTRAINT fk_sys_project_member_role_role FOREIGN KEY (role_id) REFERENCES sys_project_role (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_menu (
    id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    parent_id BIGINT NULL,
    menu_name VARCHAR(100) NOT NULL,
    menu_name_i18n JSON NULL COMMENT '业务项目菜单的内联译文；内置菜单改用 menu_name_key',
    menu_name_key VARCHAR(160) NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
    menu_type VARCHAR(20) NOT NULL,
    route_path VARCHAR(256) NULL,
    component_path VARCHAR(256) NULL,
    permission_code VARCHAR(128) NULL,
    icon VARCHAR(64) NULL COMMENT 'antd 图标组件名',
    sort_no INT NOT NULL DEFAULT 0,
    visible TINYINT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_project_menu_permission (project_id, permission_code),
    KEY idx_sys_project_menu_parent_sort (project_id, parent_id, sort_no),
    CONSTRAINT fk_sys_project_menu_project FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_role_menu (
    project_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    menu_id BIGINT NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (project_id, role_id, menu_id),
    CONSTRAINT fk_sys_project_role_menu_role FOREIGN KEY (role_id) REFERENCES sys_project_role (id),
    CONSTRAINT fk_sys_project_role_menu_menu FOREIGN KEY (menu_id) REFERENCES sys_project_menu (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_app_config (
    id BIGINT NOT NULL,
    scope_id BIGINT NOT NULL DEFAULT 0,
    config_key VARCHAR(128) NOT NULL,
    config_value TEXT NOT NULL,
    value_i18n_key VARCHAR(160) NULL COMMENT '展示型配置引用的国际化资源 key；非空即启用',
    value_type VARCHAR(16) NOT NULL,
    secret TINYINT NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL,
    description VARCHAR(512) NULL,
    sort_no INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_app_config_scope_key (scope_id, config_key),
    KEY idx_sys_app_config_scope_status (scope_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_dict_type (
    id BIGINT NOT NULL,
    scope_id BIGINT NOT NULL DEFAULT 0,
    dict_code VARCHAR(128) NOT NULL,
    dict_name VARCHAR(128) NOT NULL,
    dict_name_key VARCHAR(160) NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
    inherit_global TINYINT NOT NULL DEFAULT 1,
    sort_no INT NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL,
    description VARCHAR(512) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_dict_type_scope_code (scope_id, dict_code),
    KEY idx_sys_dict_type_scope_status (scope_id, status),
    KEY idx_sys_dict_type_scope_sort (scope_id, sort_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_dict_item (
    id BIGINT NOT NULL,
    dict_type_id BIGINT NOT NULL,
    item_label VARCHAR(128) NOT NULL,
    item_value VARCHAR(128) NOT NULL,
    sort_no INT NOT NULL DEFAULT 0,
    default_item TINYINT NOT NULL DEFAULT 0,
    color VARCHAR(32) NULL,
    extra_json TEXT NULL,
    label_i18n JSON NULL COMMENT '标签多语言：{"en-US":"Enabled"}，缺失回退 item_label',
    label_i18n_key VARCHAR(160) NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
    status VARCHAR(16) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_dict_item_type_value (dict_type_id, item_value),
    KEY idx_sys_dict_item_type_status_sort (dict_type_id, status, sort_no),
    CONSTRAINT fk_sys_dict_item_type
        FOREIGN KEY (dict_type_id) REFERENCES sys_dict_type (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_i18n_message (
    id BIGINT NOT NULL,
    message_key VARCHAR(160) NOT NULL,
    default_text VARCHAR(2000) NOT NULL,
    translations_json JSON NULL,
    module_code VARCHAR(64) NOT NULL,
    public_visible TINYINT NOT NULL DEFAULT 0,
    required_resource TINYINT NOT NULL DEFAULT 1,
    status VARCHAR(16) NOT NULL,
    description VARCHAR(512) NULL,
    version BIGINT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_i18n_message_key (message_key),
    KEY idx_sys_i18n_message_module_status (module_code, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_i18n_catalog_revision (
    catalog_code VARCHAR(32) NOT NULL,
    revision BIGINT NOT NULL DEFAULT 1,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (catalog_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO sys_i18n_catalog_revision (catalog_code, revision, updated_at)
VALUES ('platform', 1, CURRENT_TIMESTAMP);

CREATE TABLE IF NOT EXISTS sys_codegen_task (
    task_no VARCHAR(64) NOT NULL,
    project_id BIGINT NOT NULL,
    owner_user_id BIGINT NOT NULL,
    module_code VARCHAR(64) NOT NULL,
    module_name VARCHAR(100) NOT NULL,
    permission_prefix VARCHAR(128) NOT NULL,
    ddl_content MEDIUMTEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    artifact_name VARCHAR(128) NOT NULL,
    file_manifest TEXT NOT NULL,
    generation_mode VARCHAR(32) NOT NULL DEFAULT 'DETERMINISTIC',
    ai_model VARCHAR(128) NULL,
    design_summary VARCHAR(1000) NULL,
    source_branch VARCHAR(128) NULL,
    mr_url VARCHAR(512) NULL,
    last_error VARCHAR(1000) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (task_no),
    KEY idx_sys_codegen_owner_time (owner_user_id, created_at),
    KEY idx_sys_codegen_project_time (project_id, created_at),
    CONSTRAINT fk_sys_codegen_project FOREIGN KEY (project_id) REFERENCES sys_project (id),
    CONSTRAINT fk_sys_codegen_owner FOREIGN KEY (owner_user_id) REFERENCES sys_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_ai_provider_config (
    id BIGINT NOT NULL,
    provider_name VARCHAR(100) NOT NULL,
    base_url VARCHAR(512) NOT NULL,
    api_key_ciphertext TEXT NULL,
    model VARCHAR(128) NOT NULL,
    temperature DECIMAL(3,2) NOT NULL DEFAULT 0.20,
    timeout_seconds INT NOT NULL DEFAULT 60,
    enabled TINYINT NOT NULL DEFAULT 1,
    last_test_status VARCHAR(20) NULL,
    last_test_message VARCHAR(500) NULL,
    last_test_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_gitlab_config (
    id BIGINT NOT NULL,
    base_url VARCHAR(512) NOT NULL,
    token_ciphertext TEXT NULL,
    default_group_id VARCHAR(128) NULL,
    enabled TINYINT NOT NULL DEFAULT 1,
    last_test_status VARCHAR(20) NULL,
    last_test_message VARCHAR(500) NULL,
    last_test_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_generation (
    task_no VARCHAR(64) NOT NULL,
    project_id BIGINT NOT NULL,
    owner_user_id BIGINT NOT NULL,
    generation_mode VARCHAR(32) NOT NULL,
    business_description TEXT NULL,
    ddl_content LONGTEXT NULL,
    generation_status VARCHAR(20) NOT NULL,
    template_version VARCHAR(32) NOT NULL,
    blueprint_json LONGTEXT NULL,
    ai_model VARCHAR(128) NULL,
    design_summary VARCHAR(1000) NULL,
    backend_artifact_name VARCHAR(255) NULL,
    frontend_artifact_name VARCHAR(255) NULL,
    backend_file_manifest LONGTEXT NULL,
    frontend_file_manifest LONGTEXT NULL,
    last_error VARCHAR(2000) NULL,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (task_no),
    UNIQUE KEY uk_sys_project_generation_project (project_id),
    KEY idx_sys_project_generation_owner_time (owner_user_id, created_at),
    KEY idx_sys_project_generation_status (generation_status, updated_at),
    CONSTRAINT fk_sys_project_generation_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id),
    CONSTRAINT fk_sys_project_generation_owner
        FOREIGN KEY (owner_user_id) REFERENCES sys_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_project_repository (
    project_id BIGINT NOT NULL,
    repository_type VARCHAR(16) NOT NULL,
    gitlab_project_id VARCHAR(256) NULL,
    web_url VARCHAR(512) NULL,
    http_clone_url VARCHAR(512) NULL,
    ssh_clone_url VARCHAR(512) NULL,
    default_branch VARCHAR(64) NOT NULL DEFAULT 'main',
    push_status VARCHAR(20) NOT NULL DEFAULT 'NOT_CONFIGURED',
    commit_sha VARCHAR(64) NULL,
    last_error VARCHAR(1000) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (project_id, repository_type),
    CONSTRAINT fk_sys_project_repository_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_runtime_task (
    task_key VARCHAR(128) NOT NULL,
    task_status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL,
    completed_at DATETIME NULL,
    PRIMARY KEY (task_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_notification (
    id BIGINT NOT NULL,
    recipient_user_id BIGINT NOT NULL,
    project_id BIGINT NULL COMMENT '来源项目；平台自身产生的消息为 NULL',
    project_code VARCHAR(64) NULL,
    notification_type VARCHAR(32) NOT NULL COMMENT '字典 notification.type',
    title VARCHAR(200) NOT NULL,
    content VARCHAR(2000) NULL,
    link_url VARCHAR(512) NULL COMMENT '站内相对路径，点击后跳转',
    read_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_notification_recipient_read
        (recipient_user_id, read_at, created_at),
    KEY idx_sys_notification_project (project_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_department (
    id BIGINT NOT NULL,
    parent_id BIGINT NULL,
    dept_name VARCHAR(100) NOT NULL,
    dept_code VARCHAR(64) NOT NULL,
    sort_no INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ENABLED',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_department_code (dept_code),
    KEY idx_sys_department_parent_sort (parent_id, sort_no),
    CONSTRAINT fk_sys_department_parent
        FOREIGN KEY (parent_id) REFERENCES sys_department (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_user_department (
    user_id BIGINT NOT NULL,
    department_id BIGINT NOT NULL,
    primary_department TINYINT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (user_id, department_id),
    KEY idx_sys_user_department_department (department_id, primary_department),
    CONSTRAINT fk_sys_user_department_user
        FOREIGN KEY (user_id) REFERENCES sys_user (id),
    CONSTRAINT fk_sys_user_department_department
        FOREIGN KEY (department_id) REFERENCES sys_department (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code)
VALUES (1, NULL, '验证平台访问', 'BUTTON', 'system:platform:read');

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code) VALUES
    (100, NULL, '用户管理', 'MENU', NULL),
    (101, 100, '查询用户', 'BUTTON', 'system:user:list'),
    (102, 100, '创建用户', 'BUTTON', 'system:user:create'),
    (103, 100, '编辑用户', 'BUTTON', 'system:user:update'),
    (104, 100, '启停用户', 'BUTTON', 'system:user:status'),
    (105, 100, '重置密码', 'BUTTON', 'system:user:reset-password');

-- 106 / 200-205 / 300-305 三组 legacy 菜单（分配用户角色、/roles、/menus）已由 V36 删除，
-- 因此这里不再种。它们对应的接口已退役，importLegacyMenus 原本就把它们排除在迁入范围外。

UPDATE sys_menu SET route_path = '/users', icon = 'UserOutlined', sort_no = 10 WHERE id = 100;

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (400, NULL, '项目管理', 'MENU', '/projects', 'AppstoreOutlined', 40, NULL),
    (401, 400, '查询项目', 'BUTTON', NULL, NULL, 10, 'system:project:list'),
    (402, 400, '创建项目', 'BUTTON', NULL, NULL, 20, 'system:project:create'),
    (403, 400, '编辑项目', 'BUTTON', NULL, NULL, 30, 'system:project:update'),
    (404, 400, '变更项目状态', 'BUTTON', NULL, NULL, 40, 'system:project:status'),
    (405, 400, '管理项目成员', 'BUTTON', NULL, NULL, 50, 'system:project:member'),
    (406, 400, '管理项目角色', 'BUTTON', NULL, NULL, 60, 'system:project:role'),
    (407, 400, '管理项目菜单', 'BUTTON', NULL, NULL, 70, 'system:project:menu');

INSERT IGNORE INTO sys_app_config
    (id, scope_id, config_key, config_value, value_type, secret,
     status, description, sort_no, created_at, updated_at)
VALUES
    (8001, 0, 'app.admin.brand', 'Kaiwu', 'STRING', 0,
     'ENABLED', '业务管理端默认品牌名称', 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8002, 0, 'app.admin.label', '业务后台', 'STRING', 0,
     'ENABLED', '业务管理端默认应用名称', 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8003, 0, 'common.table.page_size', '20', 'NUMBER', 0,
     'ENABLED', '列表默认每页条数，业务端使用前应限制在 5-200', 30,
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8101, 0, 'common.status', '通用启停状态', 0, 'ENABLED',
     '平台和生成业务可复用的启停状态', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8102, 0, 'common.boolean_enabled', '是否启用', 0, 'ENABLED',
     '布尔启用选项', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, status, created_at, updated_at)
VALUES
    (8201, 8101, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8202, 8101, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8203, 8102, '是', 'true', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8204, 8102, '否', 'false', 20, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 平台管理前端页面共用的枚举字典
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8301, 0, 'user.status', '平台用户状态', 0, 'ENABLED',
     '平台身份账号是否可用', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8302, 0, 'project.status', '业务项目状态', 0, 'ENABLED',
     '业务项目生命周期：启用、停用、归档', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8303, 0, 'project.member.status', '项目成员状态', 0, 'ENABLED',
     '成员在项目内是否有效', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8304, 0, 'platform.menu.type', '平台菜单类型', 0, 'ENABLED',
     '菜单节点类型：目录、菜单、按钮', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8305, 0, 'config.value.type', '配置值类型', 0, 'ENABLED',
     '应用配置的值类型：STRING/NUMBER/BOOLEAN/JSON', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8306, 0, 'ai.test.status', '大模型连通测试状态', 0, 'ENABLED',
     '大模型 provider 最近一次连通测试结果', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8307, 0, 'gitlab.test.status', 'GitLab 连通测试状态', 0, 'ENABLED',
     '受管 GitLab 最近一次连通测试结果', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8308, 0, 'project.generation.mode', '项目生成方式', 0, 'ENABLED',
     '项目工厂生成方式：AI 项目 / 基础空脚手架', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8309, 0, 'project.generation.status', '项目生成状态', 0, 'ENABLED',
     '项目生成任务生命周期', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8310, 0, 'project.repository.push.status', '仓库推送状态', 0, 'ENABLED',
     'GitLab 初始推送生命周期', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8311, 0, 'codegen.status', 'CRUD 生成状态', 0, 'ENABLED',
     '确定性 CRUD 生成任务状态', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8312, 0, 'codegen.mode', 'CRUD 生成方式', 0, 'ENABLED',
     'CRUD 生成方式：确定性 / AI 字段增强 / AI 回退', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, status, created_at, updated_at)
VALUES
    (8401, 8301, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8402, 8301, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8403, 8302, '启用', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8404, 8302, '停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8405, 8302, '已归档', 'ARCHIVED', 30, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8406, 8303, '有效', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8407, 8303, '停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8408, 8304, '目录', 'DIR', 10, 0, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8409, 8304, '菜单', 'MENU', 20, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8410, 8304, '按钮', 'BUTTON', 30, 0, 'warning', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8411, 8305, '文本', 'STRING', 10, 1, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8412, 8305, '数值', 'NUMBER', 20, 0, 'cyan', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8413, 8305, '布尔值', 'BOOLEAN', 30, 0, 'purple', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8414, 8305, 'JSON', 'JSON', 40, 0, 'warning', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8415, 8306, '连接成功', 'SUCCESS', 10, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8416, 8306, '连接失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8417, 8307, '连接成功', 'SUCCESS', 10, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8418, 8307, '连接失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8419, 8308, 'AI 生成项目', 'AI_PROJECT', 10, 1, 'purple', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8420, 8308, '基础空脚手架', 'BASIC_SCAFFOLD', 20, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8421, 8309, '等待生成', 'PENDING', 10, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8422, 8309, '正在生成', 'RUNNING', 20, 0, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8423, 8309, '生成成功', 'SUCCESS', 30, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8424, 8309, '生成失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8425, 8310, '尚未推送', 'NOT_CONFIGURED', 10, 1, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8426, 8310, '正在推送', 'PUSHING', 20, 0, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8427, 8310, '已完成初始推送', 'PUSHED', 30, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8428, 8310, '推送失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8429, 8311, '已生成', 'GENERATED', 10, 0, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8430, 8311, '已创建 MR', 'PUSHED', 20, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8431, 8312, '确定性', 'DETERMINISTIC', 10, 1, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8432, 8312, 'AI 字段增强', 'AI_METADATA', 20, 0, 'purple', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8433, 8312, 'AI 回退', 'DETERMINISTIC_FALLBACK', 30, 0, 'warning', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 站内信分类字典
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8313, 0, 'notification.type', '站内信分类', 0, 'ENABLED',
     '站内信来源分类：系统、项目、任务', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, status, created_at, updated_at)
VALUES
    (8434, 8313, '系统通知', 'SYSTEM', 10, 1, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8435, 8313, '项目消息', 'PROJECT', 20, 0, 'purple', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8436, 8313, '任务提醒', 'TASK', 30, 0, 'warning', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 安全运营中心状态字典
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8314, 0, 'security.login.status', '登录日志状态', 0, 'ENABLED',
     '登录审计结果；当前后端只写入 SUCCESS 与 FAILED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8315, 0, 'security.session.status', '在线会话状态', 0, 'ENABLED',
     '在线会话生命周期：在线、已撤销', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, status, created_at, updated_at)
VALUES
    (8437, 8314, '成功', 'SUCCESS', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8438, 8314, '失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8441, 8314, '退出', 'LOGOUT', 30, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8439, 8315, '在线', 'ONLINE', 10, 1, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8440, 8315, '已撤销', 'REVOKED', 20, 0, 'default', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (500, NULL, '参数配置', 'MENU', '/configs', 'SettingOutlined', 50, NULL),
    (501, 500, '查询配置', 'BUTTON', NULL, NULL, 10, 'system:config:list'),
    (502, 500, '保存配置', 'BUTTON', NULL, NULL, 20, 'system:config:save'),
    (503, 500, '删除配置', 'BUTTON', NULL, NULL, 30, 'system:config:delete'),
    (600, NULL, '字典管理', 'MENU', '/dictionaries', 'BookOutlined', 60, NULL),
    (601, 600, '查询字典', 'BUTTON', NULL, NULL, 10, 'system:dict:list'),
    (602, 600, '保存字典', 'BUTTON', NULL, NULL, 20, 'system:dict:save'),
    (603, 600, '删除字典', 'BUTTON', NULL, NULL, 30, 'system:dict:delete');

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (700, NULL, '项目工厂', 'MENU', '/project-factory', 'CodeOutlined', 70, NULL),
    (701, 700, '查看项目生成', 'BUTTON', NULL, NULL, 10, 'system:project-factory:list'),
    (702, 700, '生成项目', 'BUTTON', NULL, NULL, 20, 'system:project-factory:generate'),
    (703, 700, '下载项目制品', 'BUTTON', NULL, NULL, 30, 'system:project-factory:download'),
    (704, 700, '初始推送 GitLab', 'BUTTON', NULL, NULL, 40, 'system:project-factory:push');

-- 项目级调度控制面
CREATE TABLE sys_scheduler_credential (
    id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    token_hash VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_scheduler_credential_project_status (project_id, status),
    CONSTRAINT fk_sys_scheduler_credential_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sys_scheduler_handler (
    project_id BIGINT NOT NULL,
    task_type VARCHAR(128) NOT NULL,
    task_name VARCHAR(128) NOT NULL,
    instance_id VARCHAR(128) NOT NULL,
    last_seen_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (project_id, task_type),
    KEY idx_sys_scheduler_handler_seen (last_seen_at),
    CONSTRAINT fk_sys_scheduler_handler_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sys_scheduler_job (
    id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    job_name VARCHAR(128) NOT NULL,
    task_type VARCHAR(128) NOT NULL,
    cron_expression VARCHAR(128) NOT NULL,
    zone_id VARCHAR(64) NOT NULL,
    request_payload TEXT NULL,
    enabled TINYINT NOT NULL DEFAULT 0,
    deleted TINYINT NOT NULL DEFAULT 0,
    config_version BIGINT NOT NULL DEFAULT 1,
    last_run_time DATETIME NULL,
    next_run_time DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_scheduler_job_project_enabled (project_id, enabled),
    CONSTRAINT fk_sys_scheduler_job_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sys_scheduler_execution (
    id BIGINT NOT NULL,
    job_id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    config_version BIGINT NOT NULL,
    scheduled_at DATETIME(3) NOT NULL,
    instance_id VARCHAR(128) NOT NULL,
    status VARCHAR(20) NOT NULL,
    lease_until DATETIME NULL,
    message VARCHAR(1000) NULL,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_scheduler_execution_fire (job_id, scheduled_at),
    KEY idx_sys_scheduler_execution_project_time (project_id, created_at),
    KEY idx_sys_scheduler_execution_lease (status, lease_until),
    CONSTRAINT fk_sys_scheduler_execution_job
        FOREIGN KEY (job_id) REFERENCES sys_scheduler_job (id),
    CONSTRAINT fk_sys_scheduler_execution_project
        FOREIGN KEY (project_id) REFERENCES sys_project (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8316, 0, 'scheduler.execution.status', '定时任务执行状态', 0, 'ENABLED',
     '项目定时任务执行生命周期', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, status, created_at, updated_at)
VALUES
    (8442, 8316, '执行中', 'RUNNING', 10, 0, 'processing', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8443, 8316, '成功', 'SUCCESS', 20, 0, 'success', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8444, 8316, '失败', 'FAILED', 30, 0, 'error', NULL, 'ENABLED',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 项目工厂属于“研发交付”主流程；已有 system 项目快照执行时收敛其父级。
UPDATE sys_project_menu factory
JOIN sys_project project
  ON project.id = factory.project_id
JOIN sys_project_menu delivery
  ON delivery.project_id = project.id
 AND delivery.id = 9000000000000014001
 AND delivery.menu_type = 'DIRECTORY'
SET factory.parent_id = delivery.id,
    factory.updated_at = CURRENT_TIMESTAMP
WHERE project.project_code = 'system'
  AND factory.menu_type = 'MENU'
  AND factory.route_path = '/project-factory'
  AND (factory.parent_id IS NULL OR factory.parent_id <> delivery.id);

-- 可扩展语言目录：字典项 label_i18n 的合法 key 由它决定。
-- 静态页面语言包仍随前端版本发布；本目录不自动把未发布语言开放给用户切换。
INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8317, 0, 'platform.locale', '平台语言', 0, 'ENABLED',
     '平台语言唯一目录；约束运行期所有多语言 JSON 的 locale key', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, label_i18n_key, status, created_at, updated_at)
VALUES
    (8501, 8317, '简体中文', 'zh-CN', 10, 1, NULL,
     NULL,
     NULL, 'dict.platform.locale.zh-CN', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8502, 8317, 'English (US)', 'en-US', 20, 0, NULL,
     NULL,
     NULL, 'dict.platform.locale.en-US', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 国际化资源管理入口与权限全部落在内置 system 项目。
INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT 9000000000000015000, project.id, 9000000000000014000,
       '国际化资源', NULL, 'MENU',
       '/i18n-resources', 'I18nResources', NULL, 'TranslationOutlined', 80, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project project
WHERE project.project_code = 'system'
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id), menu_name = VALUES(menu_name),
    menu_name_i18n = VALUES(menu_name_i18n), route_path = VALUES(route_path),
    component_path = VALUES(component_path), icon = VALUES(icon),
    sort_no = VALUES(sort_no), visible = 1, status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT seed.id, project.id, 9000000000000015000, seed.menu_name, seed.name_i18n,
       'BUTTON', NULL, NULL, seed.permission_code, NULL, seed.sort_no, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project project
CROSS JOIN (
    SELECT 9000000000000015001 AS id, '查询国际化资源' AS menu_name,
           NULL AS name_i18n,
           'system:i18n:list' AS permission_code, 10 AS sort_no
    UNION ALL
    SELECT 9000000000000015002, '保存国际化资源',
           NULL,
           'system:i18n:save', 20
    UNION ALL
    SELECT 9000000000000015003, '删除国际化资源',
           NULL,
           'system:i18n:delete', 30
) seed
WHERE project.project_code = 'system'
ON DUPLICATE KEY UPDATE
    parent_id = VALUES(parent_id), menu_name = VALUES(menu_name),
    menu_name_i18n = VALUES(menu_name_i18n), permission_code = VALUES(permission_code),
    sort_no = VALUES(sort_no), visible = 1, status = 'ACTIVE',
    updated_at = CURRENT_TIMESTAMP;

INSERT IGNORE INTO sys_project_role_menu (project_id, role_id, menu_id, created_at)
SELECT project.id, role.id, menu.id, CURRENT_TIMESTAMP
FROM sys_project project
JOIN sys_project_role role
  ON role.project_id = project.id AND role.role_code = 'project-admin'
JOIN sys_project_menu menu
  ON menu.project_id = project.id
 AND menu.id BETWEEN 9000000000000015000 AND 9000000000000015003
WHERE project.project_code = 'system';
-- 从最后一版静态 catalog 一次性校验并生成；运行期事实源迁移到本表。
-- 生成后 Web 静态完整语言包将退役；本迁移成为运行期事实源。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000001, 'ai.apiKey', 'API Key（{state}）', JSON_OBJECT('en-US', 'API key ({state})'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000002, 'ai.apiKeyPlaceholder', '留空保留原值；无鉴权的内网模型可不填', JSON_OBJECT('en-US', 'Leave empty to keep the current value; optional for internal providers without authentication'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000003, 'ai.apiKeyPlain', 'API Key', JSON_OBJECT('en-US', 'API key'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000004, 'ai.baseUrl', 'API Base URL', JSON_OBJECT('en-US', 'API Base URL'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000005, 'ai.baseUrlPlaceholder', 'https://api.openai.com/v1', JSON_OBJECT('en-US', 'https://api.openai.com/v1'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000006, 'ai.clearApiKey', '清除已保存的 API Key', JSON_OBJECT('en-US', 'Clear saved API key'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000007, 'ai.configured', '已配置', JSON_OBJECT('en-US', 'Configured'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000008, 'ai.currentModel', '当前模型', JSON_OBJECT('en-US', 'Current model'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000009, 'ai.enable', '启用 AI 项目生成', JSON_OBJECT('en-US', 'Enable AI project generation'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000010, 'ai.model', '模型', JSON_OBJECT('en-US', 'Model'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000011, 'ai.modelPlaceholder', '例如：gpt-4.1-mini', JSON_OBJECT('en-US', 'For example, gpt-4.1-mini'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000012, 'ai.name', '配置名称', JSON_OBJECT('en-US', 'Configuration name'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000013, 'ai.namePlaceholder', '例如：OpenAI、DeepSeek、本地兼容服务', JSON_OBJECT('en-US', 'For example, OpenAI, DeepSeek, or a local compatible service'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000014, 'ai.notConfigured', '未配置', JSON_OBJECT('en-US', 'Not configured'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000015, 'ai.provider', 'Provider', JSON_OBJECT('en-US', 'Provider'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000016, 'ai.saved', '大模型配置已加密保存', JSON_OBJECT('en-US', 'AI provider configuration saved securely'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000017, 'ai.subtitle', '只管理 OpenAI-compatible Provider；密钥加密保存且永不回传', JSON_OBJECT('en-US', 'Manage an OpenAI-compatible provider. Secrets are encrypted and never returned.'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000018, 'ai.temperature', 'Temperature', JSON_OBJECT('en-US', 'Temperature'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000019, 'ai.testFailed', '连接测试失败，详情见运行状态', JSON_OBJECT('en-US', 'Connection test failed. See Runtime status for details.'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000020, 'ai.testSaved', '测试已保存配置', JSON_OBJECT('en-US', 'Test saved configuration'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000021, 'ai.testSuccess', '连接成功 · {latency} ms', JSON_OBJECT('en-US', 'Connected · {latency} ms'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000022, 'ai.timeout', '请求超时（秒）', JSON_OBJECT('en-US', 'Request timeout (seconds)'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000023, 'ai.title', '大模型配置', JSON_OBJECT('en-US', 'AI provider'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000024, 'ai.urlRule', '请输入完整 HTTP(S) URL', JSON_OBJECT('en-US', 'Enter a complete HTTP(S) URL'), 'ai', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000025, 'api.auth.accountLocked', '登录失败次数过多，请 {minutes} 分钟后再试', JSON_OBJECT('en-US', 'Too many failed sign-in attempts. Try again in {minutes} minutes.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000026, 'api.auth.invalidCredentials', '用户名或密码错误', JSON_OBJECT('en-US', 'Incorrect username or password'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000027, 'api.auth.password.incorrect', '当前密码错误', JSON_OBJECT('en-US', 'The current password is incorrect'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000028, 'api.auth.password.mismatch', '两次输入的新密码不一致', JSON_OBJECT('en-US', 'The new passwords do not match'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000029, 'api.auth.password.tooLong', '新密码 UTF-8 编码后不能超过 72 字节', JSON_OBJECT('en-US', 'The new password cannot exceed 72 UTF-8 bytes'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000030, 'api.auth.password.unchanged', '新密码不能与当前密码相同', JSON_OBJECT('en-US', 'The new password must differ from the current password'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000031, 'api.auth.refreshInvalid', '刷新令牌无效或已过期', JSON_OBJECT('en-US', 'The refresh token is invalid or expired'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000032, 'api.locale.unsupported', '暂不支持该语言', JSON_OBJECT('en-US', 'This language is not supported'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000033, 'api.pagination.invalid', '分页参数超出允许范围', JSON_OBJECT('en-US', 'Pagination parameters are out of range'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000034, 'api.project.notFound', '项目不存在', JSON_OBJECT('en-US', 'Project not found'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000035, 'api.projectFactory.activeRequired', '只有启用项目可以生成', JSON_OBJECT('en-US', 'Only active projects can be generated'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000036, 'api.projectFactory.adminRequired', '只有目标项目的有效项目管理员可以使用项目工厂', JSON_OBJECT('en-US', 'Only an active project administrator for the target project can use Project factory'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000037, 'api.projectFactory.builtInForbidden', '内置 system 项目已有真实源码，不能通过项目工厂生成', JSON_OBJECT('en-US', 'The built-in system project already has real source and cannot be generated by Project factory'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000038, 'api.user.cannotDisableSelf', '不能停用当前登录用户', JSON_OBJECT('en-US', 'You cannot disable the currently signed-in user'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000039, 'api.user.changeOwnPassword', '请通过个人安全设置修改自己的密码', JSON_OBJECT('en-US', 'Change your own password in Profile security settings'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000040, 'api.user.export.tooManyRows', '导出结果超过 {limit} 条，请先用用户名或显示名筛选后再导出', JSON_OBJECT('en-US', 'The export exceeds {limit} rows. Filter by username or display name first.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000041, 'api.user.import.displayNameInvalid', '姓名不能为空且最多 100 字', JSON_OBJECT('en-US', 'Display name is required and cannot exceed 100 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000042, 'api.user.import.failed', '导入失败', JSON_OBJECT('en-US', 'Import failed'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000043, 'api.user.import.fileSize', 'Excel 文件大小必须在 1B 到 10MB 之间', JSON_OBJECT('en-US', 'The Excel file must be between 1 byte and 10 MB'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000044, 'api.user.import.invalidWorkbook', '无法读取 Excel，请使用平台模板', JSON_OBJECT('en-US', 'Cannot read the Excel workbook. Use the platform template.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000045, 'api.user.import.passwordInvalid', '初始密码长度必须为 12-72 位', JSON_OBJECT('en-US', 'The initial password must contain 12 to 72 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000046, 'api.user.import.statusInvalid', '状态只能是 ENABLED 或 DISABLED', JSON_OBJECT('en-US', 'Status must be ENABLED or DISABLED'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000047, 'api.user.import.tooManyRows', '单次最多导入 5000 行', JSON_OBJECT('en-US', 'A single import can contain at most 5,000 rows'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000048, 'api.user.import.unknownDepartment', '存在未知部门编码', JSON_OBJECT('en-US', 'One or more department codes are unknown'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000049, 'api.user.import.usernameInvalid', '用户名格式不正确', JSON_OBJECT('en-US', 'The username format is invalid'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000050, 'api.user.notFound', '用户不存在', JSON_OBJECT('en-US', 'User not found'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000051, 'api.user.usernameExists', '用户名已存在', JSON_OBJECT('en-US', 'The username already exists'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000052, 'api.user.workbook.generateFailed', '生成用户表格失败', JSON_OBJECT('en-US', 'Failed to generate the user workbook'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000053, 'api.validation.failed', '请求参数错误', JSON_OBJECT('en-US', 'Invalid request parameters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000054, 'client.catalogFailed', '语言资源加载失败，已保留当前界面语言', JSON_OBJECT('en-US', 'Language resources failed to load; the current language was kept'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000055, 'client.connectionFailed', '无法连接服务，请确认 Kaiwu 网关已启动', JSON_OBJECT('en-US', 'Cannot connect to the service. Confirm that the Kaiwu Gateway is running.'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000056, 'client.downloadFailed', '下载失败（HTTP {status}）', JSON_OBJECT('en-US', 'Download failed (HTTP {status})'), 'client', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000057, 'client.loginFailed', '登录失败（HTTP {status}）', JSON_OBJECT('en-US', 'Sign-in failed (HTTP {status})'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000058, 'client.refreshFailed', '刷新失败（HTTP {status}）', JSON_OBJECT('en-US', 'Token refresh failed (HTTP {status})'), 'client', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000059, 'client.refreshInvalid', '刷新令牌无效或已过期', JSON_OBJECT('en-US', 'The refresh token is invalid or expired'), 'client', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000060, 'client.refreshMissing', '缺少刷新令牌', JSON_OBJECT('en-US', 'Refresh token is missing'), 'client', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000061, 'client.requestFailed', '请求失败（HTTP {status}）', JSON_OBJECT('en-US', 'Request failed (HTTP {status})'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000062, 'client.serviceUnavailable', '服务暂时不可用，请检查 Gateway/Nacos 配置后重试', JSON_OBJECT('en-US', 'The service is temporarily unavailable. Check Gateway/Nacos and try again.'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000063, 'client.sessionExpired', '会话已失效', JSON_OBJECT('en-US', 'Your session has expired'), 'client', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000064, 'common.clearSelection', '取消选择', JSON_OBJECT('en-US', 'Clear selection'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000065, 'common.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000066, 'common.deleted', '已删除', JSON_OBJECT('en-US', 'Deleted'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000067, 'common.disable', '停用', JSON_OBJECT('en-US', 'Disable'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000068, 'common.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000069, 'common.enable', '启用', JSON_OBJECT('en-US', 'Enable'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000070, 'common.language', '语言', JSON_OBJECT('en-US', 'Language'), 'common', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000071, 'common.language.enUS', 'English', JSON_OBJECT('en-US', 'English'), 'common', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000072, 'common.language.updateFailed', '保存语言设置失败', JSON_OBJECT('en-US', 'Failed to save language preference'), 'common', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000073, 'common.language.updated', '语言设置已保存', JSON_OBJECT('en-US', 'Language preference saved'), 'common', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000074, 'common.language.zhCN', '简体中文', JSON_OBJECT('en-US', '简体中文'), 'common', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000075, 'common.operationFailed', '操作失败', JSON_OBJECT('en-US', 'Operation failed'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000076, 'common.refresh', '刷新', JSON_OBJECT('en-US', 'Refresh'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000077, 'common.saved', '已保存', JSON_OBJECT('en-US', 'Saved'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000078, 'common.selectedCount', '已选择 {count} 项', JSON_OBJECT('en-US', '{count} selected'), 'common', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000079, 'config.enabled', '是否启用', JSON_OBJECT('en-US', 'Enabled'), 'config', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000080, 'config.recentTest', '最近测试', JSON_OBJECT('en-US', 'Latest test'), 'config', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000081, 'config.runtime', '运行状态', JSON_OBJECT('en-US', 'Runtime status'), 'config', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000082, 'config.testTime', '测试时间', JSON_OBJECT('en-US', 'Test time'), 'config', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000083, 'configs.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000084, 'configs.create', '新增配置', JSON_OBJECT('en-US', 'Create configuration'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000085, 'configs.createTitle', '新增配置', JSON_OBJECT('en-US', 'Create configuration'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000086, 'configs.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000087, 'configs.deleteConfirm', '确认删除该配置？', JSON_OBJECT('en-US', 'Delete this configuration?'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000088, 'configs.deleted', '配置已删除', JSON_OBJECT('en-US', 'Configuration deleted'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000089, 'configs.description', '说明', JSON_OBJECT('en-US', 'Description'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000090, 'configs.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000091, 'configs.editTitle', '编辑配置', JSON_OBJECT('en-US', 'Edit configuration'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000092, 'configs.empty', '当前范围暂无配置，点击右上角新增', JSON_OBJECT('en-US', 'No configuration in this scope. Use Create in the upper right.'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000093, 'configs.encrypted', '已加密', JSON_OBJECT('en-US', 'Encrypted'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000094, 'configs.key', '配置键', JSON_OBJECT('en-US', 'Key'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000095, 'configs.keyRule', '配置键格式不正确', JSON_OBJECT('en-US', 'The key format is invalid'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000096, 'configs.saved', '配置已保存', JSON_OBJECT('en-US', 'Configuration saved'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000097, 'configs.secret', '敏感配置', JSON_OBJECT('en-US', 'Secret'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000098, 'configs.secretPlaceholder', '保留 ****** 或留空表示不修改密文', JSON_OBJECT('en-US', 'Keep ****** or leave empty to retain the encrypted value'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000099, 'configs.secretTooltip', 'AES-GCM 加密保存，且不会通过 effective config API 下发', JSON_OBJECT('en-US', 'Encrypted with AES-GCM and never returned by the effective configuration API'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000100, 'configs.sort', '排序', JSON_OBJECT('en-US', 'Sort order'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000101, 'configs.status', '状态', JSON_OBJECT('en-US', 'Status'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000102, 'configs.subtitle', '全局默认可被项目同名配置覆盖，敏感配置永不下发业务前端', JSON_OBJECT('en-US', 'Project settings override global defaults with the same key. Secrets are never sent to business frontends.'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000103, 'configs.title', '参数配置', JSON_OBJECT('en-US', 'Configuration'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000104, 'configs.value', '配置值', JSON_OBJECT('en-US', 'Value'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000105, 'configs.valueType', '值类型', JSON_OBJECT('en-US', 'Value type'), 'configs', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000106, 'dict.ai.test.status.FAILED', '失败', JSON_OBJECT('en-US', 'Failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000107, 'dict.ai.test.status.SUCCESS', '成功', JSON_OBJECT('en-US', 'Success'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000108, 'dict.common.boolean_enabled.false', '否', JSON_OBJECT('en-US', 'No'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000109, 'dict.common.boolean_enabled.true', '是', JSON_OBJECT('en-US', 'Yes'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000110, 'dict.common.status.DISABLED', '停用', JSON_OBJECT('en-US', 'Disabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000111, 'dict.common.status.ENABLED', '启用', JSON_OBJECT('en-US', 'Enabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000112, 'dict.config.value.type.BOOLEAN', '布尔值', JSON_OBJECT('en-US', 'Boolean'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000113, 'dict.config.value.type.JSON', 'JSON', JSON_OBJECT('en-US', 'JSON'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000114, 'dict.config.value.type.NUMBER', '数值', JSON_OBJECT('en-US', 'Number'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000115, 'dict.config.value.type.STRING', '文本', JSON_OBJECT('en-US', 'Text'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000116, 'dict.gitlab.test.status.FAILED', '连接失败', JSON_OBJECT('en-US', 'Connection failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000117, 'dict.gitlab.test.status.SUCCESS', '连接成功', JSON_OBJECT('en-US', 'Connected'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000118, 'dict.notification.type.PROJECT', '项目消息', JSON_OBJECT('en-US', 'Project message'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000119, 'dict.notification.type.SYSTEM', '系统通知', JSON_OBJECT('en-US', 'System notification'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000120, 'dict.notification.type.TASK', '任务提醒', JSON_OBJECT('en-US', 'Task reminder'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000121, 'dict.platform.menu.type.BUTTON', '按钮', JSON_OBJECT('en-US', 'Button'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000122, 'dict.platform.menu.type.DIR', '目录', JSON_OBJECT('en-US', 'Directory'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000123, 'dict.platform.menu.type.DIRECTORY', '目录', JSON_OBJECT('en-US', 'Directory'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000124, 'dict.platform.menu.type.MENU', '菜单', JSON_OBJECT('en-US', 'Menu'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000125, 'dict.project.generation.mode.AI_PROJECT', 'AI 生成项目', JSON_OBJECT('en-US', 'AI-generated project'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000126, 'dict.project.generation.mode.BASIC_SCAFFOLD', '基础空脚手架', JSON_OBJECT('en-US', 'Basic empty scaffold'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000127, 'dict.project.generation.status.FAILED', '生成失败', JSON_OBJECT('en-US', 'Generation failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000128, 'dict.project.generation.status.PENDING', '等待生成', JSON_OBJECT('en-US', 'Waiting'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000129, 'dict.project.generation.status.RUNNING', '正在生成', JSON_OBJECT('en-US', 'Generating'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000130, 'dict.project.generation.status.SUCCESS', '生成成功', JSON_OBJECT('en-US', 'Generated'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000131, 'dict.project.member.status.ACTIVE', '有效', JSON_OBJECT('en-US', 'Active'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000132, 'dict.project.member.status.DISABLED', '停用', JSON_OBJECT('en-US', 'Disabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000133, 'dict.project.repository.push.status.FAILED', '推送失败', JSON_OBJECT('en-US', 'Push failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000134, 'dict.project.repository.push.status.NOT_CONFIGURED', '尚未推送', JSON_OBJECT('en-US', 'Not pushed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000135, 'dict.project.repository.push.status.PUSHED', '已完成初始推送', JSON_OBJECT('en-US', 'Initial push complete'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000136, 'dict.project.repository.push.status.PUSHING', '正在推送', JSON_OBJECT('en-US', 'Pushing'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000137, 'dict.project.status.ACTIVE', '启用', JSON_OBJECT('en-US', 'Active'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000138, 'dict.project.status.ARCHIVED', '已归档', JSON_OBJECT('en-US', 'Archived'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000139, 'dict.project.status.DISABLED', '停用', JSON_OBJECT('en-US', 'Disabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000140, 'dict.scheduler.execution.status.FAILED', '失败', JSON_OBJECT('en-US', 'Failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000141, 'dict.scheduler.execution.status.RUNNING', '执行中', JSON_OBJECT('en-US', 'Running'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000142, 'dict.scheduler.execution.status.SUCCESS', '成功', JSON_OBJECT('en-US', 'Success'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000143, 'dict.security.login.status.FAILED', '失败', JSON_OBJECT('en-US', 'Failed'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000144, 'dict.security.login.status.LOGOUT', '退出', JSON_OBJECT('en-US', 'Signed out'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000145, 'dict.security.login.status.SUCCESS', '成功', JSON_OBJECT('en-US', 'Success'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000146, 'dict.security.session.status.ONLINE', '在线', JSON_OBJECT('en-US', 'Online'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000147, 'dict.security.session.status.REVOKED', '已撤销', JSON_OBJECT('en-US', 'Revoked'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000148, 'dict.user.status.DISABLED', '停用', JSON_OBJECT('en-US', 'Disabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000149, 'dict.user.status.ENABLED', '启用', JSON_OBJECT('en-US', 'Enabled'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000150, 'dicts.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000151, 'dicts.code', '字典编码', JSON_OBJECT('en-US', 'Dictionary code'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000152, 'dicts.codeRule', '字典编码格式不正确', JSON_OBJECT('en-US', 'The dictionary code format is invalid'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000153, 'dicts.color', '颜色', JSON_OBJECT('en-US', 'Color'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000154, 'dicts.create', '新增字典', JSON_OBJECT('en-US', 'Create dictionary'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000155, 'dicts.createItem', '新增字典项', JSON_OBJECT('en-US', 'Create entry'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000156, 'dicts.createItemTitle', '新增字典项', JSON_OBJECT('en-US', 'Create dictionary entry'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000157, 'dicts.createTitle', '新增字典', JSON_OBJECT('en-US', 'Create dictionary'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000158, 'dicts.default', '默认', JSON_OBJECT('en-US', 'Default'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000159, 'dicts.defaultItem', '默认项', JSON_OBJECT('en-US', 'Default entry'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000160, 'dicts.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000161, 'dicts.deleteItemConfirm', '确认删除该字典项？', JSON_OBJECT('en-US', 'Delete this dictionary entry?'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000162, 'dicts.deleteTypeConfirm', '删除字典及全部字典项？', JSON_OBJECT('en-US', 'Delete this dictionary and all its entries?'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000163, 'dicts.deleted', '字典已删除', JSON_OBJECT('en-US', 'Dictionary deleted'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000164, 'dicts.description', '说明', JSON_OBJECT('en-US', 'Description'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000165, 'dicts.dictionary', '字典', JSON_OBJECT('en-US', 'Dictionary'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000166, 'dicts.displayColor', '展示颜色', JSON_OBJECT('en-US', 'Display color'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000167, 'dicts.displayLabel', '显示标签', JSON_OBJECT('en-US', 'Display label'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000168, 'dicts.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000169, 'dicts.editItemTitle', '编辑字典项', JSON_OBJECT('en-US', 'Edit dictionary entry'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000170, 'dicts.editTitle', '编辑字典', JSON_OBJECT('en-US', 'Edit dictionary'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000171, 'dicts.extraJson', '扩展 JSON', JSON_OBJECT('en-US', 'Extra JSON'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000172, 'dicts.extraJsonPlaceholder', '例如 {"icon":"check"}', JSON_OBJECT('en-US', 'For example, {"icon":"check"}'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000173, 'dicts.independent', '项目独立，不继承全局', JSON_OBJECT('en-US', 'Project-only; does not inherit global entries'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000174, 'dicts.inherit', '继承全局，同值由项目覆盖', JSON_OBJECT('en-US', 'Inherits global entries; project values override matches'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000175, 'dicts.inheritGlobal', '继承全局字典', JSON_OBJECT('en-US', 'Inherit global dictionary'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000176, 'dicts.itemDeleted', '字典项已删除', JSON_OBJECT('en-US', 'Dictionary entry deleted'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000177, 'dicts.itemSaved', '字典项已保存', JSON_OBJECT('en-US', 'Dictionary entry saved'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000178, 'dicts.label', '标签', JSON_OBJECT('en-US', 'Label'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000179, 'dicts.labelEnUs', '英文标签', JSON_OBJECT('en-US', 'English label'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000180, 'dicts.labelEnUsTip', '英文界面下显示的标签；留空则显示上面的原文', JSON_OBJECT('en-US', 'Shown when the UI is in English. Leave empty to fall back to the text above.'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000181, 'dicts.loadFailed', '加载字典失败', JSON_OBJECT('en-US', 'Failed to load dictionaries'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000182, 'dicts.loadItemsFailed', '加载字典项失败', JSON_OBJECT('en-US', 'Failed to load dictionary entries'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000183, 'dicts.loadLocalesFailed', '加载已启用语言失败', JSON_OBJECT('en-US', 'Failed to load enabled languages'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000184, 'dicts.name', '字典名称', JSON_OBJECT('en-US', 'Dictionary name'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000185, 'dicts.saved', '字典已保存', JSON_OBJECT('en-US', 'Dictionary saved'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000186, 'dicts.selectFirst', '请先新增或选择字典', JSON_OBJECT('en-US', 'Create or select a dictionary first'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000187, 'dicts.sort', '排序', JSON_OBJECT('en-US', 'Sort'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000188, 'dicts.status', '状态', JSON_OBJECT('en-US', 'Status'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000189, 'dicts.subtitle', '项目字典可继承全局字典，同值项目项覆盖全局项', JSON_OBJECT('en-US', 'Project dictionaries can inherit global entries; project entries override equal global values.'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000190, 'dicts.title', '字典管理', JSON_OBJECT('en-US', 'Dictionaries'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000191, 'dicts.translation', '{locale} 标签', JSON_OBJECT('en-US', '{locale} label'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000192, 'dicts.translationTip', '已启用语言中的译文；留空时显示默认标签。新增语言后会自动出现对应输入项。', JSON_OBJECT('en-US', 'A translation for an enabled language. Leave empty to use the default label; new languages appear here automatically.'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000193, 'dicts.value', '字典值', JSON_OBJECT('en-US', 'Value'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000194, 'factory.action.backendZip', '后端 ZIP', JSON_OBJECT('en-US', 'Backend ZIP'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000195, 'factory.action.details', '详情', JSON_OBJECT('en-US', 'Details'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000196, 'factory.action.frontendZip', '前端 ZIP', JSON_OBJECT('en-US', 'Frontend ZIP'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000197, 'factory.action.push', '初始推送', JSON_OBJECT('en-US', 'Initial push'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000198, 'factory.action.retry', '修改后重试', JSON_OBJECT('en-US', 'Edit and retry'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000199, 'factory.column.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000200, 'factory.column.createdAt', '创建时间', JSON_OBJECT('en-US', 'Created at'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000201, 'factory.column.failure', '失败原因', JSON_OBJECT('en-US', 'Failure reason'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000202, 'factory.column.mode', '生成方式', JSON_OBJECT('en-US', 'Generation mode'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000203, 'factory.column.project', '项目', JSON_OBJECT('en-US', 'Project'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000204, 'factory.column.readiness', '交付就绪度', JSON_OBJECT('en-US', 'Delivery readiness'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000205, 'factory.column.repositories', '仓库交付', JSON_OBJECT('en-US', 'Repository delivery'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000206, 'factory.column.status', '生成状态', JSON_OBJECT('en-US', 'Generation status'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000207, 'factory.description', '在脚手架约束内一次生成后端与前端仓库；两份 ZIP 始终可下载，GitLab 只向项目配置分支做一次初始提交，后续 CI/CD 与分支策略由业务仓库接管。', JSON_OBJECT('en-US', 'Generate backend and frontend repositories once within the scaffold boundary. Both ZIP files remain downloadable. GitLab receives one initial commit on the configured project branch; the business repositories own later CI/CD and branch strategy.', 'ja-JP', 'スキャフォールドの制約内でバックエンドとフロントエンドのリポジトリを一度だけ生成します。2 つの ZIP は常にダウンロードでき、GitLab への初回コミット後の CI/CD とブランチ戦略は業務リポジトリが管理します。'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000208, 'factory.empty', '还没有生成任务；请在项目管理里开通项目，或对已有项目使用「生成第一版」', JSON_OBJECT('en-US', 'No generation tasks yet. Set up a project or use Generate first version for an existing project.'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000209, 'factory.failure.unknown', '未记录具体失败原因', JSON_OBJECT('en-US', 'No specific failure reason was recorded'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000210, 'factory.gitlab', 'GitLab 配置', JSON_OBJECT('en-US', 'GitLab configuration'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000211, 'factory.myTasks', '我的项目生成', JSON_OBJECT('en-US', 'My generation tasks'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000212, 'factory.newProject', '开通新项目', JSON_OBJECT('en-US', 'Set up a project'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000213, 'factory.preview.backendFiles', '后端文件 · {count}', JSON_OBJECT('en-US', 'Backend files · {count}'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000214, 'factory.preview.close', '关闭', JSON_OBJECT('en-US', 'Close'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000215, 'factory.preview.completedAt', '完成时间', JSON_OBJECT('en-US', 'Completed at'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000216, 'factory.preview.error', '任务错误', JSON_OBJECT('en-US', 'Task error'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000217, 'factory.preview.frontendFiles', '前端文件 · {count}', JSON_OBJECT('en-US', 'Frontend files · {count}'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000218, 'factory.preview.model', 'AI 模型', JSON_OBJECT('en-US', 'AI model'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000219, 'factory.preview.noFiles', '暂无生成文件', JSON_OBJECT('en-US', 'No generated files'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000220, 'factory.preview.overview', '概览', JSON_OBJECT('en-US', 'Overview'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000221, 'factory.preview.projectTitle', '生成详情：{project}', JSON_OBJECT('en-US', 'Generation details: {project}'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000222, 'factory.preview.summary', '设计摘要', JSON_OBJECT('en-US', 'Design summary'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000223, 'factory.preview.taskNo', '任务号', JSON_OBJECT('en-US', 'Task number'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000224, 'factory.preview.template', '脚手架版本', JSON_OBJECT('en-US', 'Scaffold version'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000225, 'factory.preview.title', '生成详情', JSON_OBJECT('en-US', 'Generation details'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000226, 'factory.push.alertDescription', '两个仓库地址都留空时，在下方 Group（留空则平台默认 Group）创建 private 仓库；填写时必须同时提供两个已存在的空仓库。推送完成后 Kaiwu 永不再次写入。', JSON_OBJECT('en-US', 'Leave both repository URLs empty to create private repositories in the Group below, or provide both existing empty repositories. Kaiwu never writes again after the push.'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000227, 'factory.push.alertTitle', '两种交付方式二选一', JSON_OBJECT('en-US', 'Choose one delivery method'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000228, 'factory.push.backendUrl', '后端空仓库 URL', JSON_OBJECT('en-US', 'Empty backend repository URL'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000229, 'factory.push.backendUrlPlaceholder', 'https://gitlab.example.com/group/kaiwu-demo-service', JSON_OBJECT('en-US', 'https://gitlab.example.com/group/kaiwu-demo-service'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000230, 'factory.push.frontendUrl', '前端空仓库 URL', JSON_OBJECT('en-US', 'Empty frontend repository URL'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000231, 'factory.push.frontendUrlPlaceholder', 'https://gitlab.example.com/group/kaiwu-demo-web', JSON_OBJECT('en-US', 'https://gitlab.example.com/group/kaiwu-demo-web'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000232, 'factory.push.group', 'GitLab Group ID（可选）', JSON_OBJECT('en-US', 'GitLab Group ID (optional)'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000233, 'factory.push.groupPlaceholder', '留空使用平台默认 Group', JSON_OBJECT('en-US', 'Leave empty to use the platform default Group'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000234, 'factory.push.orExisting', '或绑定已有空仓库', JSON_OBJECT('en-US', 'Or bind existing empty repositories'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000235, 'factory.push.submit', '确认一次性推送', JSON_OBJECT('en-US', 'Confirm one-time push'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000236, 'factory.push.success', 'GitLab 初始推送已进入后台执行', JSON_OBJECT('en-US', 'The initial GitLab push is running in the background'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000237, 'factory.push.title', '初始推送：{project}', JSON_OBJECT('en-US', 'Initial push: {project}'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000238, 'factory.readiness.tooltip', '生成成功、后端制品、前端制品、后端推送、前端推送', JSON_OBJECT('en-US', 'Generation, backend artifact, frontend artifact, backend push, frontend push'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000239, 'factory.refresh', '刷新', JSON_OBJECT('en-US', 'Refresh'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000240, 'factory.repository.backend', '后端', JSON_OBJECT('en-US', 'Backend'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000241, 'factory.repository.frontend', '前端', JSON_OBJECT('en-US', 'Frontend'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000242, 'factory.repository.link', '仓库', JSON_OBJECT('en-US', 'Repository'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000243, 'factory.repository.retry', '待重试', JSON_OBJECT('en-US', 'Retry needed'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000244, 'factory.retry.basic', '基础脚手架没有业务描述和 DDL，可直接重新生成', JSON_OBJECT('en-US', 'Basic scaffolds have no business description or DDL and can be regenerated directly'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000245, 'factory.retry.businessDescription', '业务描述', JSON_OBJECT('en-US', 'Business description'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000246, 'factory.retry.businessRequired', '请描述要生成的项目', JSON_OBJECT('en-US', 'Describe the project to generate'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000247, 'factory.retry.ddl', 'MySQL DDL（可选）', JSON_OBJECT('en-US', 'MySQL DDL (optional)'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000248, 'factory.retry.ddlExtra', '支持 CREATE TABLE 以及对应的独立 CREATE INDEX 语句', JSON_OBJECT('en-US', 'Supports CREATE TABLE and corresponding standalone CREATE INDEX statements'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000249, 'factory.retry.description', '可修改业务描述和 DDL 后重新生成；原失败任务会保留任务号并使用本次输入。', JSON_OBJECT('en-US', 'Edit the business description and DDL before regenerating. The failed task keeps its task number and uses the updated input.'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000250, 'factory.retry.lastFailed', '上次生成失败', JSON_OBJECT('en-US', 'The previous generation failed'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000251, 'factory.retry.submit', '保存输入并重新生成', JSON_OBJECT('en-US', 'Save input and regenerate'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000252, 'factory.retry.success', '修改后的任务已重新排队', JSON_OBJECT('en-US', 'The updated task has been queued again'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000253, 'factory.retry.title', '修改后重试：{project}', JSON_OBJECT('en-US', 'Edit and retry: {project}'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000254, 'factory.stat.failed', '失败', JSON_OBJECT('en-US', 'Failed'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000255, 'factory.stat.noFailure', '暂无失败', JSON_OBJECT('en-US', 'No failures'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000256, 'factory.stat.pendingPush', '{count} 待推送', JSON_OBJECT('en-US', '{count} awaiting push'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000257, 'factory.stat.ready', '全部已就绪', JSON_OBJECT('en-US', 'Everything is ready'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000258, 'factory.stat.retry', '可在下方重试', JSON_OBJECT('en-US', 'Retry from the list below'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000259, 'factory.stat.running', '进行中', JSON_OBJECT('en-US', 'In progress'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000260, 'factory.stat.runningHint', '每 2.5s 自动刷新', JSON_OBJECT('en-US', 'Refreshes every 2.5 seconds'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000261, 'factory.stat.success', '已成功', JSON_OBJECT('en-US', 'Successful'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000262, 'factory.stat.total', '全部任务', JSON_OBJECT('en-US', 'All tasks'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000263, 'factory.stat.totalHint', '按当前用户过滤', JSON_OBJECT('en-US', 'Filtered for the current user'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000264, 'factory.taskCount', '共 {count} 个任务', JSON_OBJECT('en-US', '{count} tasks'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000265, 'factory.title', '项目工厂', JSON_OBJECT('en-US', 'Project factory'), 'factory', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000266, 'gateway.authenticationRequired', '未登录或登录已过期', JSON_OBJECT('en-US', 'Sign-in is required or has expired'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000267, 'gateway.projectAuthUnavailable', '项目鉴权尚未启用', JSON_OBJECT('en-US', 'Project authentication is not enabled'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000268, 'gateway.resourceNotFound', '资源不存在', JSON_OBJECT('en-US', 'Resource not found'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000269, 'gateway.routePolicyInvalid', '未知路由访问模式', JSON_OBJECT('en-US', 'Unknown route access mode'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000270, 'gateway.routePolicyMissing', '路由安全元数据缺失', JSON_OBJECT('en-US', 'Route security metadata is missing'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000271, 'gateway.sessionExpired', '会话已失效，请重新登录', JSON_OBJECT('en-US', 'Your session has expired. Sign in again.'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000272, 'gateway.sessionVerificationUnavailable', '会话校验暂不可用', JSON_OBJECT('en-US', 'Session verification is temporarily unavailable'), 'gateway', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000273, 'gitlab.apiToken', 'API Token', JSON_OBJECT('en-US', 'API token'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000274, 'gitlab.baseUrl', 'GitLab Base URL', JSON_OBJECT('en-US', 'GitLab Base URL'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000275, 'gitlab.baseUrlPlaceholder', 'https://gitlab.example.com', JSON_OBJECT('en-US', 'https://gitlab.example.com'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000276, 'gitlab.clearToken', '清除已保存 Token', JSON_OBJECT('en-US', 'Clear saved token'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000277, 'gitlab.defaultGroup', '默认 Group', JSON_OBJECT('en-US', 'Default Group'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000278, 'gitlab.enable', '启用 GitLab 交付', JSON_OBJECT('en-US', 'Enable GitLab delivery'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000279, 'gitlab.group', '默认 Group ID', JSON_OBJECT('en-US', 'Default Group ID'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000280, 'gitlab.groupPlaceholder', 'GitLab 数值 Group ID；也可推送时填写', JSON_OBJECT('en-US', 'Numeric GitLab Group ID; it can also be entered when pushing'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000281, 'gitlab.managed', '受管 GitLab', JSON_OBJECT('en-US', 'Managed GitLab'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000282, 'gitlab.saved', 'GitLab 配置已加密保存', JSON_OBJECT('en-US', 'GitLab configuration saved securely'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000283, 'gitlab.subtitle', '项目工厂只向此受管实例创建或绑定空仓库；Token 加密保存且永不回传', JSON_OBJECT('en-US', 'Project factory only creates or binds empty repositories on this managed instance. The token is encrypted and never returned.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000284, 'gitlab.testSaved', '测试已保存配置', JSON_OBJECT('en-US', 'Test saved configuration'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000285, 'gitlab.title', 'GitLab 配置', JSON_OBJECT('en-US', 'GitLab configuration'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000286, 'gitlab.token', 'API Token（{state}）', JSON_OBJECT('en-US', 'API token ({state})'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000287, 'gitlab.tokenPlaceholder', '留空保留原值', JSON_OBJECT('en-US', 'Leave empty to keep the current value'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000288, 'gitlab.urlRule', '请输入完整 HTTP(S) URL', JSON_OBJECT('en-US', 'Enter a complete HTTP(S) URL'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000289, 'home.controlPlane', 'KAIWU CONTROL PLANE', JSON_OBJECT('en-US', 'KAIWU CONTROL PLANE'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000290, 'home.defaultUser', '管理员', JSON_OBJECT('en-US', 'Administrator'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000291, 'home.greeting.afternoon', '下午好', JSON_OBJECT('en-US', 'Good afternoon'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000292, 'home.greeting.evening', '晚上好', JSON_OBJECT('en-US', 'Good evening'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000293, 'home.greeting.lateNight', '夜深了', JSON_OBJECT('en-US', 'Working late'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000294, 'home.greeting.morning', '早上好', JSON_OBJECT('en-US', 'Good morning'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000295, 'home.greeting.noon', '中午好', JSON_OBJECT('en-US', 'Good afternoon'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000296, 'home.greeting.user', '{greeting}，{name}', JSON_OBJECT('en-US', '{greeting}, {name}'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000297, 'home.guide.aiOptional', '尚未配置 AI 也可以选择“基础脚手架”；配置 AI 后可根据业务描述生成第一版模块。', JSON_OBJECT('en-US', 'Without AI configuration, you can still choose Basic scaffold. Configure AI to generate initial modules from a business description.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000298, 'home.guide.aiReady', 'AI 已就绪，可直接从业务描述生成受校验蓝图。', JSON_OBJECT('en-US', 'AI is ready and can create a validated blueprint from a business description.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000299, 'home.guide.alertDescription', 'AI 辅助生成受约束的第一版，确定性脚手架交付独立源码；团队可在自己的 Git 仓库中接续 AI 开发、测试和发布。', JSON_OBJECT('en-US', 'AI helps create a constrained first version, while deterministic scaffolding delivers standalone source code. Your team can continue AI-assisted development, testing, and releases in its own Git repositories.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000300, 'home.guide.alertTitle', '在受控边界内，创建可维护的业务项目', JSON_OBJECT('en-US', 'Create maintainable business projects within clear boundaries'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000301, 'home.guide.deliver.desc', '拿到独立双仓库后按正常工程流程开发，Kaiwu 不会再次覆盖代码。', JSON_OBJECT('en-US', 'Continue normal development in the two independent repositories. Kaiwu will never overwrite them.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000302, 'home.guide.deliver.title', '下载或首次推送', JSON_OBJECT('en-US', 'Download or make the initial push'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000303, 'home.guide.generate.desc', '平台创建项目、成员基础角色，并用受约束蓝图生成前后端源码。', JSON_OBJECT('en-US', 'The platform creates the project and base member role, then generates frontend and backend source from a constrained blueprint.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000304, 'home.guide.generate.title', '开通并生成第一版', JSON_OBJECT('en-US', 'Initialize and generate'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000305, 'home.guide.gitlabOptional', ' GitLab 可稍后配置，生成成功后仍可下载两个 ZIP。', JSON_OBJECT('en-US', ' GitLab can be configured later; both ZIP files remain available after generation.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000306, 'home.guide.gitlabReady', ' GitLab 已就绪，生成成功后可选择一次初始推送。', JSON_OBJECT('en-US', ' GitLab is ready; you can make one initial push after generation.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000307, 'home.guide.scope.desc', '写清核心对象、查询方式和状态；已有库可直接粘贴 CREATE TABLE DDL。', JSON_OBJECT('en-US', 'Describe core entities, query patterns, and states. If a schema exists, paste its CREATE TABLE DDL.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000308, 'home.guide.scope.title', '准备业务范围', JSON_OBJECT('en-US', 'Define the business scope'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000309, 'home.guide.start', '开始开通项目', JSON_OBJECT('en-US', 'Set up a project'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000310, 'home.guide.title', '从第一个项目开始', JSON_OBJECT('en-US', 'Start with your first project'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000311, 'home.listSeparator', '、', JSON_OBJECT('en-US', ', '), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000312, 'home.load.failed', '加载失败', JSON_OBJECT('en-US', 'Failed to load'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000313, 'home.projects.empty', '你还没有加入任何项目，请联系管理员在项目权限中心分配角色。', JSON_OBJECT('en-US', 'You have not joined a project. Ask an administrator to assign a role in the project access center.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000314, 'home.projects.noEntry', '未配置入口', JSON_OBJECT('en-US', 'No entry URL'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000315, 'home.projects.noEntryMessage', '该项目尚未配置业务后台入口，请到项目管理里维护 backendUrl', JSON_OBJECT('en-US', 'This project has no administration URL. Configure backendUrl in Projects.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000316, 'home.projects.noMatch', '没有匹配的项目', JSON_OBJECT('en-US', 'No matching projects'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000317, 'home.projects.search', '按名称或编码搜索', JSON_OBJECT('en-US', 'Search by name or code'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000318, 'home.projects.title', '我参与的项目', JSON_OBJECT('en-US', 'My projects'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000319, 'home.projects.titleCount', '我参与的项目 · {count}', JSON_OBJECT('en-US', 'My projects · {count}'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000320, 'home.refresh', '刷新', JSON_OBJECT('en-US', 'Refresh'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000321, 'home.request.failed', '请求失败', JSON_OBJECT('en-US', 'Request failed'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000322, 'home.summary.clear', '当前没有待处理事项，一切正常', JSON_OBJECT('en-US', 'Everything is running normally. Nothing needs your attention.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000323, 'home.summary.pending', '有 {count} 项需要你处理', JSON_OBJECT('en-US', '{count} items need your attention'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000324, 'home.todo.aiNoKey', '尚未配置 API Key，AI 生成项目不可用', JSON_OBJECT('en-US', 'No API key is configured, so AI project generation is unavailable'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000325, 'home.todo.aiNotReady', '大模型未就绪', JSON_OBJECT('en-US', 'AI provider not ready'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000326, 'home.todo.configure', '去配置', JSON_OBJECT('en-US', 'Configure'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000327, 'home.todo.configuredDisabled', '已配置但未启用', JSON_OBJECT('en-US', 'Configured but disabled'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000328, 'home.todo.empty', '没有需要处理的事项，平台能力和生成任务都正常。', JSON_OBJECT('en-US', 'There are no outstanding items. Platform capabilities and generation tasks are healthy.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000329, 'home.todo.generating', '{project} 正在生成', JSON_OBJECT('en-US', 'Generating {project}'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000330, 'home.todo.generatingDesc', '任务在后台执行，完成后可下载或推送', JSON_OBJECT('en-US', 'The task is running in the background. Download or push it when complete.'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000331, 'home.todo.generationFailed', '{project} 生成失败', JSON_OBJECT('en-US', 'Generation failed for {project}'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000332, 'home.todo.generationFailedDesc', '可在项目工厂查看原因并重试', JSON_OBJECT('en-US', 'Open Project factory to review the cause and retry'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000333, 'home.todo.gitlabNoToken', '尚未配置 API Token，仓库推送不可用', JSON_OBJECT('en-US', 'No API token is configured, so repository push is unavailable'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000334, 'home.todo.gitlabNotReady', 'GitLab 未就绪', JSON_OBJECT('en-US', 'GitLab not ready'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000335, 'home.todo.handle', '去处理', JSON_OBJECT('en-US', 'Resolve'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000336, 'home.todo.lastTestFailed', '最近一次连通测试失败', JSON_OBJECT('en-US', 'The latest connectivity test failed'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000337, 'home.todo.open', '查看', JSON_OBJECT('en-US', 'View'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000338, 'home.todo.pendingPush', '{count} 个项目已生成待推送', JSON_OBJECT('en-US', '{count} generated projects awaiting push'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000339, 'home.todo.push', '去推送', JSON_OBJECT('en-US', 'Push'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000340, 'home.todo.title', '待处理', JSON_OBJECT('en-US', 'To do'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000341, 'home.todo.unread.default', '来自平台与业务项目的站内信', JSON_OBJECT('en-US', 'Messages from the platform and business projects'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000342, 'home.todo.unread.latest', '最新：{title}', JSON_OBJECT('en-US', 'Latest: {title}'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000343, 'home.todo.unread.title', '{count} 条未读消息', JSON_OBJECT('en-US', '{count} unread messages'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000344, 'home.todo.view', '去查看', JSON_OBJECT('en-US', 'View'), 'home', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000345, 'i18n.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000346, 'i18n.coverage', '译文', JSON_OBJECT('en-US', 'Translations'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000347, 'i18n.create', '新增资源', JSON_OBJECT('en-US', 'New resource'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000348, 'i18n.createTitle', '新增国际化资源', JSON_OBJECT('en-US', 'New internationalization resource'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000349, 'i18n.defaultText', '默认文案（zh-CN）', JSON_OBJECT('en-US', 'Default text (zh-CN)'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000350, 'i18n.deleteConfirm', '确定删除该资源？', JSON_OBJECT('en-US', 'Delete this resource?'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000351, 'i18n.description', '说明', JSON_OBJECT('en-US', 'Description'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000352, 'i18n.editTitle', '编辑国际化资源', JSON_OBJECT('en-US', 'Edit internationalization resource'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000353, 'i18n.key', '资源 key', JSON_OBJECT('en-US', 'Resource key'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000354, 'i18n.module', '模块', JSON_OBJECT('en-US', 'Module'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000355, 'i18n.public', '登录前公开', JSON_OBJECT('en-US', 'Public before sign-in'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000356, 'i18n.required', '覆盖必需', JSON_OBJECT('en-US', 'Required for coverage'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000357, 'i18n.status', '状态', JSON_OBJECT('en-US', 'Status'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000358, 'i18n.subtitle', '统一维护页面与 API 文案；语言是否可选由覆盖校验决定', JSON_OBJECT('en-US', 'Manage UI and API messages; coverage controls language availability'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000359, 'i18n.title', '国际化资源', JSON_OBJECT('en-US', 'Internationalization resources'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000360, 'layout.notification.empty', '没有未读消息', JSON_OBJECT('en-US', 'No unread messages'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000361, 'layout.notification.readAll', '全部已读', JSON_OBJECT('en-US', 'Mark all read'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000362, 'layout.notification.unread', '未读消息', JSON_OBJECT('en-US', 'Unread messages'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000363, 'layout.notification.viewAll', '查看全部消息', JSON_OBJECT('en-US', 'View all messages'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000364, 'layout.search.aria', '全局搜索', JSON_OBJECT('en-US', 'Global search'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000365, 'layout.search.empty', '没有匹配结果', JSON_OBJECT('en-US', 'No matching results'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000366, 'layout.search.placeholder', '搜索项目、用户、交付任务（至少 2 个字符）', JSON_OBJECT('en-US', 'Search projects, users, and delivery tasks (2+ characters)'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000367, 'layout.search.prompt', '输入关键词开始搜索', JSON_OBJECT('en-US', 'Enter a keyword to start searching'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000368, 'layout.search.short', '搜索', JSON_OBJECT('en-US', 'Search'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000369, 'layout.search.title', '全局搜索', JSON_OBJECT('en-US', 'Global search'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000370, 'layout.search.type.delivery', '交付', JSON_OBJECT('en-US', 'Delivery'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000371, 'layout.search.type.project', '项目', JSON_OBJECT('en-US', 'Project'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000372, 'layout.search.type.user', '用户', JSON_OBJECT('en-US', 'User'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000373, 'layout.user.logout', '退出登录', JSON_OBJECT('en-US', 'Sign out'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000374, 'layout.user.notLoggedIn', '未登录', JSON_OBJECT('en-US', 'Not signed in'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000375, 'layout.user.profile', '个人设置', JSON_OBJECT('en-US', 'Profile'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000376, 'layout.user.switchProject', '切换项目', JSON_OBJECT('en-US', 'Switch project'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000377, 'login.brand.subtitle', '面向 AI 时代受控开发的项目平台', JSON_OBJECT('en-US', 'A project platform for controlled AI-era development'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000378, 'login.failure', '登录失败', JSON_OBJECT('en-US', 'Sign-in failed'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000379, 'login.footer', '管理员密码由启动环境变量注入，仓库不保存默认密码。', JSON_OBJECT('en-US', 'The administrator password is injected by the runtime environment. No default password is stored in the repository.'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000380, 'login.form.submit', '登录', JSON_OBJECT('en-US', 'Sign in'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000381, 'login.form.subtitle', '请使用管理员账号继续', JSON_OBJECT('en-US', 'Continue with your administrator account'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000382, 'login.form.title', '登录管理后台', JSON_OBJECT('en-US', 'Sign in to Kaiwu'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000383, 'login.hero.description', '把 AI 放进受控蓝图与确定性脚手架：它加速生成第一版；权限、项目边界与代码归属仍由团队掌控，独立前后端交付到你的 Git 仓库。', JSON_OBJECT('en-US', 'Put AI inside controlled blueprints and deterministic scaffolding. It accelerates the first version, while your team retains control of access, project boundaries, and code ownership in your own Git repository.'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000384, 'login.hero.title.first', '让 AI 加速交付，', JSON_OBJECT('en-US', 'Let AI accelerate delivery,'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000385, 'login.hero.title.second', '让工程始终可控', JSON_OBJECT('en-US', 'keep engineering in control'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000386, 'login.highlight.isolation', '独立仓库、数据库与交付路径', JSON_OBJECT('en-US', 'Independent repositories, databases, and delivery paths'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000387, 'login.highlight.oneshot', '平台不再回写你的仓库', JSON_OBJECT('en-US', 'The platform never writes back to your repository'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000388, 'login.highlight.permission', 'AI 受控生成，工程边界清晰', JSON_OBJECT('en-US', 'Controlled AI generation, clear engineering boundaries'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000389, 'login.password.placeholder', '密码', JSON_OBJECT('en-US', 'Password'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000390, 'login.password.required', '请输入密码', JSON_OBJECT('en-US', 'Enter your password'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000391, 'login.sessionExit', '已退出登录：{reason}', JSON_OBJECT('en-US', 'Signed out: {reason}'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000392, 'login.steps.continue.description', '项目自带工程约束，交给团队常用的 AI 编程工具继续迭代', JSON_OBJECT('en-US', 'Built-in engineering constraints let your team continue with its preferred AI coding tools'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000393, 'login.steps.continue.title', '接续 AI 开发', JSON_OBJECT('en-US', 'Continue with AI development'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000394, 'login.steps.create.description', '登记业务项目，明确成员、角色与边界', JSON_OBJECT('en-US', 'Register the project and define members, roles, and boundaries'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000395, 'login.steps.create.title', '建项目', JSON_OBJECT('en-US', 'Create a project'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000396, 'login.steps.deliver.description', '下载 ZIP，或向空 GitLab 仓库一次性初始化', JSON_OBJECT('en-US', 'Download the ZIP, or initialize an empty GitLab repository once'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000397, 'login.steps.deliver.title', '交付到你的仓库', JSON_OBJECT('en-US', 'Deliver to your repository'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000398, 'login.steps.generate.description', '描述业务或导入建表 SQL，得到可维护的前后端', JSON_OBJECT('en-US', 'Describe the business or import DDL for maintainable frontends and backends'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000399, 'login.steps.generate.title', '生成第一版', JSON_OBJECT('en-US', 'Generate the first version'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000400, 'login.steps.title', '4 步，进入受控 AI 开发', JSON_OBJECT('en-US', 'Four steps to controlled AI development'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000401, 'login.username.placeholder', '用户名', JSON_OBJECT('en-US', 'Username'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000402, 'login.username.required', '请输入用户名', JSON_OBJECT('en-US', 'Enter your username'), 'login', 1, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000403, 'members.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000404, 'members.add', '添加成员', JSON_OBJECT('en-US', 'Add member'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000405, 'members.displayName', '显示名称', JSON_OBJECT('en-US', 'Display name'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000406, 'members.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000407, 'members.editTitle', '编辑成员：{username}', JSON_OBJECT('en-US', 'Edit member: {username}'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000408, 'members.memberStatus', '成员状态', JSON_OBJECT('en-US', 'Member status'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000409, 'members.platformUser', '平台用户', JSON_OBJECT('en-US', 'Platform user'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000410, 'members.projectRole', '项目角色', JSON_OBJECT('en-US', 'Project roles'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000411, 'members.remove', '移除', JSON_OBJECT('en-US', 'Remove'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000412, 'members.removeConfirm', '确认移除该项目成员？', JSON_OBJECT('en-US', 'Remove this project member?'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000413, 'members.removed', '成员已移除', JSON_OBJECT('en-US', 'Member removed'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000414, 'members.roles', '角色', JSON_OBJECT('en-US', 'Roles'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000415, 'members.saved', '成员配置已保存', JSON_OBJECT('en-US', 'Member configuration saved'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000416, 'members.status', '状态', JSON_OBJECT('en-US', 'Status'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000417, 'members.userOption', '{name}（{username}）', JSON_OBJECT('en-US', '{name} ({username})'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000418, 'members.username', '用户名', JSON_OBJECT('en-US', 'Username'), 'members', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000419, 'menu.system.ai-provider', '大模型配置', JSON_OBJECT('en-US', 'AI provider'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000420, 'menu.system.configs', '参数配置', JSON_OBJECT('en-US', 'Configuration'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000421, 'menu.system.dictionaries', '字典管理', JSON_OBJECT('en-US', 'Dictionaries'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000422, 'menu.system.directory.delivery', '研发交付', JSON_OBJECT('en-US', 'Development & delivery'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000423, 'menu.system.directory.platform', '平台管理', JSON_OBJECT('en-US', 'Platform'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000424, 'menu.system.gitlab-config', 'GitLab 配置', JSON_OBJECT('en-US', 'GitLab configuration'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000425, 'menu.system.home', '工作台', JSON_OBJECT('en-US', 'Workbench'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000426, 'menu.system.notifications', '消息中心', JSON_OBJECT('en-US', 'Messages'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000427, 'menu.system.organization', '组织架构', JSON_OBJECT('en-US', 'Organization'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000428, 'menu.system.project-factory', '项目工厂', JSON_OBJECT('en-US', 'Project factory'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000429, 'menu.system.projects', '项目管理', JSON_OBJECT('en-US', 'Projects'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000430, 'menu.system.scheduler', '定时任务', JSON_OBJECT('en-US', 'Scheduled tasks'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000431, 'menu.system.security', '安全运营', JSON_OBJECT('en-US', 'Security operations'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000432, 'menu.system.users', '用户管理', JSON_OBJECT('en-US', 'Users'), 'menu', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000433, 'menus.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000434, 'menus.addChild', '新增子节点', JSON_OBJECT('en-US', 'Add child'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000435, 'menus.componentPath', '组件路径', JSON_OBJECT('en-US', 'Component path'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000436, 'menus.createRoot', '新建根节点', JSON_OBJECT('en-US', 'Create root node'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000437, 'menus.createTitle', '新建项目菜单', JSON_OBJECT('en-US', 'Create project menu'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000438, 'menus.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000439, 'menus.deleteConfirm', '确认删除该项目菜单？仅叶子节点可删除。', JSON_OBJECT('en-US', 'Delete this project menu? Only leaf nodes can be deleted.'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000440, 'menus.deleted', '项目菜单已删除', JSON_OBJECT('en-US', 'Project menu deleted'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000441, 'menus.disableConfirm', '确认停用菜单？', JSON_OBJECT('en-US', 'Disable this menu?'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000442, 'menus.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000443, 'menus.editTitle', '编辑项目菜单：{name}', JSON_OBJECT('en-US', 'Edit project menu: {name}'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000444, 'menus.enableConfirm', '确认启用菜单？', JSON_OBJECT('en-US', 'Enable this menu?'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000445, 'menus.icon', '菜单图标', JSON_OBJECT('en-US', 'Menu icon'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000446, 'menus.iconExtra', '仅 DIRECTORY 和 MENU 会在侧栏显示图标；BUTTON 可留空', JSON_OBJECT('en-US', 'Only DIRECTORY and MENU appear in the sidebar; BUTTON can leave this empty'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000447, 'menus.iconPlaceholder', '可选，选择侧栏图标', JSON_OBJECT('en-US', 'Optional sidebar icon'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000448, 'menus.name', '菜单名称', JSON_OBJECT('en-US', 'Menu name'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000449, 'menus.order', '顺序', JSON_OBJECT('en-US', 'Order'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000450, 'menus.orderFailed', '排序失败', JSON_OBJECT('en-US', 'Failed to reorder'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000451, 'menus.orderUpdated', '顺序已更新', JSON_OBJECT('en-US', 'Order updated'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000452, 'menus.parent', '父节点', JSON_OBJECT('en-US', 'Parent'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000453, 'menus.permission', '权限码', JSON_OBJECT('en-US', 'Permission code'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000454, 'menus.permissionExtra', '必须与业务后端 @RequirePermission、前端 AuthButton 完全一致', JSON_OBJECT('en-US', 'Must exactly match backend @RequirePermission and frontend AuthButton'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000455, 'menus.permissionPlaceholder', 'BUTTON 必填，例如 order:record:list', JSON_OBJECT('en-US', 'Required for BUTTON, for example order:record:list'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000456, 'menus.root', '根节点', JSON_OBJECT('en-US', 'Root'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000457, 'menus.route', '路由', JSON_OBJECT('en-US', 'Route'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000458, 'menus.routePath', '路由路径', JSON_OBJECT('en-US', 'Route path'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000459, 'menus.routeRequired', 'MENU 必填', JSON_OBJECT('en-US', 'Required for MENU'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000460, 'menus.saved', '项目菜单已保存', JSON_OBJECT('en-US', 'Project menu saved'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000461, 'menus.sort', '排序', JSON_OBJECT('en-US', 'Sort order'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000462, 'menus.status', '状态', JSON_OBJECT('en-US', 'Status'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000463, 'menus.type', '菜单类型', JSON_OBJECT('en-US', 'Menu type'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000464, 'menus.visible', '是否显示', JSON_OBJECT('en-US', 'Visible'), 'menus', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000465, 'notifications.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000466, 'notifications.all', '全部', JSON_OBJECT('en-US', 'All'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000467, 'notifications.allTypes', '全部分类', JSON_OBJECT('en-US', 'All types'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000468, 'notifications.empty', '还没有收到任何消息', JSON_OBJECT('en-US', 'No messages yet'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000469, 'notifications.emptyFiltered', '没有符合条件的消息', JSON_OBJECT('en-US', 'No messages match the filters'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000470, 'notifications.markAll', '全部已读', JSON_OBJECT('en-US', 'Mark all read'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000471, 'notifications.markRead', '标记已读', JSON_OBJECT('en-US', 'Mark read'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000472, 'notifications.markedCount', '已将 {count} 条消息标记为已读', JSON_OBJECT('en-US', '{count} messages marked as read'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000473, 'notifications.message', '消息', JSON_OBJECT('en-US', 'Message'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000474, 'notifications.noUnread', '没有未读消息', JSON_OBJECT('en-US', 'No unread messages'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000475, 'notifications.platform', '平台', JSON_OBJECT('en-US', 'Platform'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000476, 'notifications.read', '已读', JSON_OBJECT('en-US', 'Read'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000477, 'notifications.source', '来源项目', JSON_OBJECT('en-US', 'Source project'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000478, 'notifications.status', '状态', JSON_OBJECT('en-US', 'Status'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000479, 'notifications.subtitle', '平台与业务项目产生的站内信；消息是事实记录，只能标记已读，不能编辑或撤回', JSON_OBJECT('en-US', 'Messages from the platform and business projects are factual records. They can be marked read but cannot be edited or recalled.'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000480, 'notifications.time', '时间', JSON_OBJECT('en-US', 'Time'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000481, 'notifications.title', '消息中心', JSON_OBJECT('en-US', 'Notifications'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000482, 'notifications.type', '分类', JSON_OBJECT('en-US', 'Type'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000483, 'notifications.unread', '未读', JSON_OBJECT('en-US', 'Unread'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000484, 'notifications.view', '查看', JSON_OBJECT('en-US', 'View'), 'notifications', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000485, 'onboarding.ai.description', '权限、路由、SQL、Docker 和 CI 均由版本化脚手架生成。已有表结构时，DDL 是字段边界，AI 不会改写它。', JSON_OBJECT('en-US', 'Permissions, routes, SQL, Docker, and CI are generated by versioned scaffolding. When DDL is supplied, it defines the field boundary and AI cannot rewrite it.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000486, 'onboarding.ai.title', 'AI 只参与业务蓝图，不直接写入任意源码', JSON_OBJECT('en-US', 'AI contributes only to the business blueprint; it never writes arbitrary source'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000487, 'onboarding.boundary.description', 'Kaiwu 不提供在线表单搭建或持续覆盖式生成。项目生成成功后，代码会交由独立仓库和开发团队维护。', JSON_OBJECT('en-US', 'Kaiwu does not provide online form building or repeated overwrite generation. After generation, independent repositories and the development team own the source.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000488, 'onboarding.boundary.title', '先定义项目边界，再生成第一版源码', JSON_OBJECT('en-US', 'Define the project boundary before generating the first source baseline'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000489, 'onboarding.businessDescription', '业务描述', JSON_OBJECT('en-US', 'Business description'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000490, 'onboarding.businessDescription.extra', '建议写清：管理哪些对象、常用查询条件、关键状态和对象之间的关系。', JSON_OBJECT('en-US', 'Describe managed entities, common queries, important states, and relationships.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000491, 'onboarding.businessDescription.placeholder', '例如：订单中心，管理客户、订单和支付记录；支持按订单号、客户和订单状态查询，订单需要记录支付状态和创建时间。', JSON_OBJECT('en-US', 'For example: an order center managing customers, orders, and payments, searchable by order number, customer, and order state, with payment state and creation time.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000492, 'onboarding.confirm.description', '生成成功后可下载后端和前端 ZIP；若 GitLab 已配置，可向项目配置分支显式执行一次初始推送。后续修改完全由业务仓库接管。', JSON_OBJECT('en-US', 'After success, download backend and frontend ZIP files or explicitly make one initial push to the configured project branch when GitLab is available. Business repositories own all later changes.', 'ja-JP', '生成後はバックエンドとフロントエンドの ZIP をダウンロードできます。GitLab が設定されている場合は、プロジェクトで設定したブランチへ一度だけ初回プッシュできます。その後の変更は業務リポジトリが管理します。'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000493, 'onboarding.confirm.title', '提交后会创建项目并提交唯一的一次第一版生成任务', JSON_OBJECT('en-US', 'Submitting creates the project and its one permitted initial generation task'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000494, 'onboarding.ddl', '数据库 DDL（可选）', JSON_OBJECT('en-US', 'Database DDL (optional)'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000495, 'onboarding.ddl.extra', '只接受 CREATE TABLE。已有 MySQL 库也可在项目创建后，从“生成第一版”中只读导入结构。', JSON_OBJECT('en-US', 'Only CREATE TABLE is accepted. After project creation, an existing MySQL schema can also be imported read-only from Generate first version.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000496, 'onboarding.ddl.placeholder', '可粘贴 CREATE TABLE 语句', JSON_OBJECT('en-US', 'Paste CREATE TABLE statements'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000497, 'onboarding.description', '项目说明（可选）', JSON_OBJECT('en-US', 'Project description (optional)'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000498, 'onboarding.description.placeholder', '例如：面向销售团队的客户资料与跟进记录管理后台', JSON_OBJECT('en-US', 'For example, a customer and sales follow-up administration system'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000499, 'onboarding.exit.button', '退出向导', JSON_OBJECT('en-US', 'Exit wizard'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000500, 'onboarding.exit.cancel', '继续填写', JSON_OBJECT('en-US', 'Continue editing'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000501, 'onboarding.exit.confirm', '退出', JSON_OBJECT('en-US', 'Exit'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000502, 'onboarding.exit.created', '项目已创建，退出后可在项目管理中继续配置成员与生成任务。', JSON_OBJECT('en-US', 'The project has been created. Continue member and generation setup from Projects.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000503, 'onboarding.exit.title', '退出项目开通向导？', JSON_OBJECT('en-US', 'Exit the project setup wizard?'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000504, 'onboarding.exit.unsubmitted', '尚未提交，已填写的内容不会保存。', JSON_OBJECT('en-US', 'Nothing has been submitted. Your entries will not be saved.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000505, 'onboarding.failure.default', '开通失败', JSON_OBJECT('en-US', 'Project setup failed'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000506, 'onboarding.failure.preserved', '项目已保留，可修正后继续：{detail}', JSON_OBJECT('en-US', 'The project was preserved. Correct the input and continue: {detail}'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000507, 'onboarding.member.option', '{displayName}（{username}）', JSON_OBJECT('en-US', '{displayName} ({username})'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000508, 'onboarding.members.description', '创建人会自动成为项目管理员。初始成员不是必填项；这里选择的用户会加入“项目成员”基础角色，后续可在项目权限中心细分权限。', JSON_OBJECT('en-US', 'The creator automatically becomes project administrator. Initial members are optional; selected users join the base Project member role and can receive finer access later.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000509, 'onboarding.members.label', '初始成员（可选）', JSON_OBJECT('en-US', 'Initial members (optional)'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000510, 'onboarding.mode.ai', 'AI 业务项目', JSON_OBJECT('en-US', 'AI business project'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000511, 'onboarding.mode.basic', '基础脚手架', JSON_OBJECT('en-US', 'Basic scaffold'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000512, 'onboarding.mode.label', '生成方式', JSON_OBJECT('en-US', 'Generation mode'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000513, 'onboarding.next', '下一步', JSON_OBJECT('en-US', 'Next'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000514, 'onboarding.packageName', 'Java 包名', JSON_OBJECT('en-US', 'Java package'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000515, 'onboarding.packageName.extra', '用于生成后端的基础包路径；使用团队已有的 Java 命名空间即可。', JSON_OBJECT('en-US', 'Base package for the generated backend. Use your team’s existing Java namespace.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000516, 'onboarding.packageName.placeholder', '例如 com.example.app', JSON_OBJECT('en-US', 'For example, com.example.app'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000517, 'onboarding.permission.warning', '当前账号缺少项目生成权限，无法完成最后一步', JSON_OBJECT('en-US', 'Your account lacks project generation permission, so the final step is unavailable'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000518, 'onboarding.previous', '上一步', JSON_OBJECT('en-US', 'Previous'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000519, 'onboarding.projectCode', '项目编码', JSON_OBJECT('en-US', 'Project code'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000520, 'onboarding.projectCode.placeholder', '例如 crm-center', JSON_OBJECT('en-US', 'For example, crm-center'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000521, 'onboarding.projectCode.rule', '小写字母开头，仅小写字母、数字和连字符', JSON_OBJECT('en-US', 'Start with a lowercase letter and use only lowercase letters, numbers, and hyphens'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000522, 'onboarding.projectName', '项目名称', JSON_OBJECT('en-US', 'Project name'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000523, 'onboarding.projectName.placeholder', '例如 客户管理中心', JSON_OBJECT('en-US', 'For example, Customer management'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000524, 'onboarding.result.factory', '查看项目工厂', JSON_OBJECT('en-US', 'View Project factory'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000525, 'onboarding.result.projects', '管理项目', JSON_OBJECT('en-US', 'Manage projects'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000526, 'onboarding.result.subtitle', '{project} 的生成任务 {taskNo} 已创建，可在项目工厂持续查看。', JSON_OBJECT('en-US', 'Generation task {taskNo} was created for {project}. Track it in Project factory.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000527, 'onboarding.result.title', '项目开通流程已提交', JSON_OBJECT('en-US', 'Project setup submitted'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000528, 'onboarding.resume.info', '检测到本人创建的未完成项目，已从中断步骤继续', JSON_OBJECT('en-US', 'Your unfinished project was found. Setup has resumed from the interrupted step.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000529, 'onboarding.step.confirm', '确认开通', JSON_OBJECT('en-US', 'Confirm setup'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000530, 'onboarding.step.generation', '生成方式', JSON_OBJECT('en-US', 'Generation mode'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000531, 'onboarding.step.members', '项目成员', JSON_OBJECT('en-US', 'Project members'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000532, 'onboarding.step.project', '项目信息', JSON_OBJECT('en-US', 'Project details'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000533, 'onboarding.submit', '创建并生成', JSON_OBJECT('en-US', 'Create and generate'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000534, 'onboarding.subtitle', '一次完成项目、基础成员角色和代码生成任务的初始化', JSON_OBJECT('en-US', 'Initialize a project, its base member role, and its source generation task in one flow'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000535, 'onboarding.success.created', '项目已创建并提交生成', JSON_OBJECT('en-US', 'Project created and generation submitted'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000536, 'onboarding.success.restored', '项目已有生成任务，已恢复开通结果', JSON_OBJECT('en-US', 'The project already has a generation task. Its setup result has been restored.'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000537, 'onboarding.title', '项目开通向导', JSON_OBJECT('en-US', 'Project setup wizard'), 'onboarding', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000538, 'org.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000539, 'org.additional', '兼任部门', JSON_OBJECT('en-US', 'Additional departments'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000540, 'org.adjust', '调整归属', JSON_OBJECT('en-US', 'Adjust membership'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000541, 'org.allUsers', '全部用户', JSON_OBJECT('en-US', 'All users'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000542, 'org.assignTitle', '分配部门：{name}', JSON_OBJECT('en-US', 'Assign departments: {name}'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000543, 'org.assignmentFailed', '部门归属更新失败', JSON_OBJECT('en-US', 'Failed to update department membership'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000544, 'org.assignmentHint', '主部门用于默认数据归属；兼任部门用于跨部门协作。清空主部门会将用户设为未分配。', JSON_OBJECT('en-US', 'The primary department owns data by default; additional departments support cross-team collaboration. Clearing primary leaves the user unassigned.'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000545, 'org.assignmentUpdated', '用户部门归属已更新', JSON_OBJECT('en-US', 'User department membership updated'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000546, 'org.code', '部门编码', JSON_OBJECT('en-US', 'Department code'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000547, 'org.codeRule', '小写字母开头，仅小写字母、数字和连字符', JSON_OBJECT('en-US', 'Start with a lowercase letter and use only lowercase letters, numbers, and hyphens'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000548, 'org.create', '新建部门', JSON_OBJECT('en-US', 'Create department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000549, 'org.createTitle', '新建部门', JSON_OBJECT('en-US', 'Create department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000550, 'org.created', '部门已创建', JSON_OBJECT('en-US', 'Department created'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000551, 'org.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000552, 'org.deleteConfirm', '确认删除该部门？', JSON_OBJECT('en-US', 'Delete this department?'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000553, 'org.deleteHint', '存在下级部门或用户归属时会拒绝删除。', JSON_OBJECT('en-US', 'Departments with children or assigned users cannot be deleted.'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000554, 'org.deleted', '部门已删除', JSON_OBJECT('en-US', 'Department deleted'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000555, 'org.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000556, 'org.editTitle', '编辑部门', JSON_OBJECT('en-US', 'Edit department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000557, 'org.loadFailed', '组织架构加载失败', JSON_OBJECT('en-US', 'Failed to load the organization'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000558, 'org.membership', '部门归属', JSON_OBJECT('en-US', 'Department membership'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000559, 'org.name', '部门名称', JSON_OBJECT('en-US', 'Department name'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000560, 'org.option', '{name}（{code}）', JSON_OBJECT('en-US', '{name} ({code})'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000561, 'org.parent', '上级部门', JSON_OBJECT('en-US', 'Parent department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000562, 'org.peopleCount', '{count} 人', JSON_OBJECT('en-US', '{count} people'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000563, 'org.primary', '主部门', JSON_OBJECT('en-US', 'Primary department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000564, 'org.primaryTag', '主部门 · {name}', JSON_OBJECT('en-US', 'Primary · {name}'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000565, 'org.saveFailed', '部门保存失败', JSON_OBJECT('en-US', 'Failed to save department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000566, 'org.searchUsers', '搜索姓名或账号', JSON_OBJECT('en-US', 'Search name or account'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000567, 'org.selectAdditional', '可选择多个兼任部门', JSON_OBJECT('en-US', 'Select one or more additional departments'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000568, 'org.selectPrimary', '选择主部门', JSON_OBJECT('en-US', 'Select a primary department'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000569, 'org.selectPrimaryFirst', '请先选择主部门', JSON_OBJECT('en-US', 'Select a primary department first'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000570, 'org.sort', '排序', JSON_OBJECT('en-US', 'Sort order'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000571, 'org.status', '状态', JSON_OBJECT('en-US', 'Status'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000572, 'org.subtitle', '维护部门树和用户归属；一个用户可归属多个部门，首项为主部门', JSON_OBJECT('en-US', 'Maintain the department tree and user membership. A user can belong to multiple departments; the first is primary.'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000573, 'org.title', '组织架构', JSON_OBJECT('en-US', 'Organization'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000574, 'org.totalUsers', '共 {total} 位用户', JSON_OBJECT('en-US', '{total} users'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000575, 'org.tree', '部门树', JSON_OBJECT('en-US', 'Department tree'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000576, 'org.treeHint', '点击部门筛选右侧用户', JSON_OBJECT('en-US', 'Select a department to filter users'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000577, 'org.unassigned', '未分配', JSON_OBJECT('en-US', 'Unassigned'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000578, 'org.unknown', '未知部门 {id}', JSON_OBJECT('en-US', 'Unknown department {id}'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000579, 'org.updated', '部门已更新', JSON_OBJECT('en-US', 'Department updated'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000580, 'org.user', '用户', JSON_OBJECT('en-US', 'User'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000581, 'org.userMembership', '用户归属 · {scope}', JSON_OBJECT('en-US', 'User membership · {scope}'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000582, 'org.viewAll', '查看全部用户', JSON_OBJECT('en-US', 'View all users'), 'org', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000583, 'password.confirm', '确认新密码', JSON_OBJECT('en-US', 'Confirm new password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000584, 'password.confirm.mismatch', '两次输入的新密码不一致', JSON_OBJECT('en-US', 'The two passwords do not match'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000585, 'password.confirm.required', '请再次输入新密码', JSON_OBJECT('en-US', 'Enter the new password again'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000586, 'password.current', '当前密码', JSON_OBJECT('en-US', 'Current password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000587, 'password.current.required', '请输入当前密码', JSON_OBJECT('en-US', 'Enter your current password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000588, 'password.force.alertDescription', '为保证账号安全，请设置只有你本人知道的新密码后再继续使用。', JSON_OBJECT('en-US', 'Set a new password known only to you before continuing.'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000589, 'password.force.alertTitle', '当前密码由管理员设定', JSON_OBJECT('en-US', 'Your current password was set by an administrator'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000590, 'password.force.failure', '修改密码失败', JSON_OBJECT('en-US', 'Failed to update password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000591, 'password.force.submit', '设置新密码', JSON_OBJECT('en-US', 'Set new password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000592, 'password.force.success', '密码已更新，现在可以正常使用平台', JSON_OBJECT('en-US', 'Password updated. You can now use the platform.'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000593, 'password.force.title', '请先修改初始密码', JSON_OBJECT('en-US', 'Change your initial password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000594, 'password.new', '新密码', JSON_OBJECT('en-US', 'New password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000595, 'password.new.extra', '8 到 72 个字符，中文按 UTF-8 字节计算', JSON_OBJECT('en-US', '8–72 characters; non-ASCII text is counted as UTF-8 bytes'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000596, 'password.new.length', '密码长度必须为8到72个字符', JSON_OBJECT('en-US', 'Password must be 8–72 characters'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000597, 'password.new.required', '请输入新密码', JSON_OBJECT('en-US', 'Enter a new password'), 'password', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000598, 'profile.account', '账号信息', JSON_OBJECT('en-US', 'Account information'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000599, 'profile.changePassword', '修改密码', JSON_OBJECT('en-US', 'Change password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000600, 'profile.confirmPassword', '确认新密码', JSON_OBJECT('en-US', 'Confirm new password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000601, 'profile.confirmPasswordRequired', '请再次输入新密码', JSON_OBJECT('en-US', 'Enter the new password again'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000602, 'profile.currentPassword', '当前密码', JSON_OBJECT('en-US', 'Current password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000603, 'profile.currentPasswordRequired', '请输入当前密码', JSON_OBJECT('en-US', 'Enter your current password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000604, 'profile.displayName', '显示名称', JSON_OBJECT('en-US', 'Display name'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000605, 'profile.editHint', '修改显示名或邮箱请联系管理员，在用户管理里操作', JSON_OBJECT('en-US', 'Contact an administrator to change your display name or email in Users.'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000606, 'profile.group.other', '其它', JSON_OBJECT('en-US', 'Other'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000607, 'profile.group.system', '平台', JSON_OBJECT('en-US', 'Platform'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000608, 'profile.newPassword', '新密码', JSON_OBJECT('en-US', 'New password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000609, 'profile.newPasswordExtra', '8 到 72 个字符，中文按 UTF-8 字节计算', JSON_OBJECT('en-US', '8 to 72 characters; non-ASCII characters are counted as UTF-8 bytes'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000610, 'profile.newPasswordRequired', '请输入新密码', JSON_OBJECT('en-US', 'Enter a new password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000611, 'profile.noPermissions', '当前账号没有任何权限码，请联系管理员在项目权限中心分配角色。', JSON_OBJECT('en-US', 'This account has no permission codes. Ask an administrator to assign a role in the project access center.'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000612, 'profile.openUsers', '前往用户管理 →', JSON_OBJECT('en-US', 'Open Users →'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000613, 'profile.passwordChanged', '密码已更新，其它设备上的登录已被下线', JSON_OBJECT('en-US', 'Password updated. Sessions on other devices have been revoked.'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000614, 'profile.passwordFailed', '修改密码失败', JSON_OBJECT('en-US', 'Failed to change password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000615, 'profile.passwordHint', '密码更新后，其它设备上的登录会被立即下线；当前页面无需重新登录。', JSON_OBJECT('en-US', 'Updating your password immediately signs out other devices. This page stays signed in.'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000616, 'profile.passwordLength', '密码长度必须为 8 到 72 个字符', JSON_OBJECT('en-US', 'The password must contain 8 to 72 characters'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000617, 'profile.passwordMismatch', '两次输入的新密码不一致', JSON_OBJECT('en-US', 'The new passwords do not match'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000618, 'profile.passwordSubmit', '更新密码', JSON_OBJECT('en-US', 'Update password'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000619, 'profile.permissionCount', '共 {count} 个权限码', JSON_OBJECT('en-US', '{count} permission codes'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000620, 'profile.permissions', '权限码', JSON_OBJECT('en-US', 'Permission codes'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000621, 'profile.permissionsHint', '按前缀分组，与后端注解、menu.sql 三端同码', JSON_OBJECT('en-US', 'Grouped by prefix; codes match backend annotations and menu.sql'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000622, 'profile.userId', '用户 ID', JSON_OBJECT('en-US', 'User ID'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000623, 'profile.username', '用户名', JSON_OBJECT('en-US', 'Username'), 'profile', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000624, 'projects.accessCenter', '权限中心', JSON_OBJECT('en-US', 'Access center'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000625, 'projects.accessTitle', '{name}：项目权限中心', JSON_OBJECT('en-US', '{name}: Project access center'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000626, 'projects.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000627, 'projects.archive', '归档', JSON_OBJECT('en-US', 'Archive'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000628, 'projects.archiveConfirm', '确认归档项目？归档后当前成员不可再进入。', JSON_OBJECT('en-US', 'Archive this project? Current members will no longer be able to enter.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000629, 'projects.archived', '项目已归档', JSON_OBJECT('en-US', 'Project archived'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000630, 'projects.backend', '业务后台', JSON_OBJECT('en-US', 'Administration site'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000631, 'projects.backendLabel', '业务后台入口名称', JSON_OBJECT('en-US', 'Administration link label'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000632, 'projects.backendRepo', '后端仓库', JSON_OBJECT('en-US', 'Backend repository'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000633, 'projects.backendRepoPlaceholder', 'https://gitlab.example.com/group/project-service', JSON_OBJECT('en-US', 'https://gitlab.example.com/group/project-service'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000634, 'projects.backendRepoUrl', '后端空仓库 URL', JSON_OBJECT('en-US', 'Empty backend repository URL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000635, 'projects.backendUrl', '业务后台入口', JSON_OBJECT('en-US', 'Administration URL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004001, 'projects.serviceUrl', '服务地址', JSON_OBJECT('en-US', 'Service URL', 'ja-JP', 'サービス URL'), 'projects', 0, 1, 'ENABLED', 'Gateway PROJECT 路由上游', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004010, 'projects.gatewayRoute', '网关路由', JSON_OBJECT('en-US', 'Gateway route', 'ja-JP', 'ゲートウェイルート'), 'projects', 0, 1, 'ENABLED', '查看该项目的显式路由片段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004011, 'projects.gatewayRoute.hint', '把下面的片段放进受管 Gateway 配置的 routes 下。服务注册不等于对外发布，没有这段显式路由的服务不能从外部访问。', JSON_OBJECT('en-US', 'Add the snippet below to the routes of the managed Gateway config. Registering a service does not publish it; without an explicit route it stays unreachable from outside.', 'ja-JP', '以下の断片を管理対象 Gateway 設定の routes に追加してください。'), 'projects', 0, 1, 'ENABLED', '路由片段说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004012, 'projects.gatewayRoute.copy', '复制片段', JSON_OBJECT('en-US', 'Copy snippet', 'ja-JP', '断片をコピー'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004013, 'projects.gatewayRoute.copied', '已复制到剪贴板', JSON_OBJECT('en-US', 'Copied to clipboard', 'ja-JP', 'クリップボードにコピーしました'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004014, 'projects.gatewayRoute.copyFailed', '复制失败，请手动选中复制', JSON_OBJECT('en-US', 'Copy failed, please select and copy manually', 'ja-JP', 'コピーに失敗しました'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004003, 'api.project.serviceUrlRequired', '请先登记项目的服务地址', JSON_OBJECT('en-US', 'Register the project service URL first', 'ja-JP', '先にサービス URL を登録してください'), 'api', 0, 1, 'ENABLED', '生成 Gateway 路由前置校验', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004002, 'projects.serviceUrlHelp', '按部署形态填写：K8s/Compose 用服务名，单实例用 http://主机:端口，Nacos 用 lb://服务名', JSON_OBJECT('en-US', 'Depends on deployment: service DNS for K8s/Compose, http://host:port for a single instance, lb://name for Nacos', 'ja-JP', 'デプロイ形態に応じて入力してください'), 'projects', 0, 1, 'ENABLED', '服务地址填写说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004015, 'gitlab.baseUrlHint', 'GitLab 站点根地址，不含项目或组路径。例：https://gitlab.example.com', JSON_OBJECT('en-US', 'Root URL of the GitLab site, without any group or project path. Example: https://gitlab.example.com'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004016, 'gitlab.groupHint', '新仓库的归属组。填数值 ID 而非组名；留空则在每次推送时指定。', JSON_OBJECT('en-US', 'Group that will own the new repositories. Use the numeric ID, not the group name. Leave empty to choose it at push time.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004017, 'gitlab.groupExtra', '在 GitLab 打开目标组首页，组名下方即显示「群组 ID」；或访问 /api/v4/groups?search=组名 查询。', JSON_OBJECT('en-US', 'Open the group page in GitLab — the group ID appears under the group name. You can also query /api/v4/groups?search=<name>.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004018, 'gitlab.tokenHint', '用于创建仓库并推送初始代码，需要 api 权限。', JSON_OBJECT('en-US', 'Used to create repositories and push the initial code. Requires the api scope.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004019, 'gitlab.tokenExtra', '建议用目标组的 Group Access Token（角色 Maintainer、勾选 api），权限范围仅限该组；也可用个人访问令牌。', JSON_OBJECT('en-US', 'Prefer a Group Access Token on the target group (Maintainer role, api scope) so the token is scoped to that group only. A personal access token also works.'), 'gitlab', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004020, 'layout.project.openMode.inline', '当前页面', JSON_OBJECT('en-US', 'Current page'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004021, 'layout.project.openMode.newTab', '新标签页', JSON_OBJECT('en-US', 'New tab'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004022, 'layout.project.loadingEntry', '正在进入项目后台…', JSON_OBJECT('en-US', 'Opening the project console…'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004023, 'layout.project.entryUnavailable', '该项目暂无可用的后台入口', JSON_OBJECT('en-US', 'This project has no console entry yet'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000004024, 'layout.project.backToPlatform', '返回 Kaiwu 平台', JSON_OBJECT('en-US', 'Back to the Kaiwu platform'), 'layout', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000636, 'projects.basicDescription', '适合先拿到可启动仓库结构，再由开发者自行实现业务。', JSON_OBJECT('en-US', 'Use it to obtain runnable repository structure, then implement the business manually.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000637, 'projects.basicTitle', '基础空脚手架不调用 AI，也不生成业务表和 CRUD', JSON_OBJECT('en-US', 'Basic scaffold does not call AI or generate business tables and CRUD'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000638, 'projects.builtIn', '内置', JSON_OBJECT('en-US', 'Built-in'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000639, 'projects.businessDescription', '业务描述', JSON_OBJECT('en-US', 'Business description'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000640, 'projects.businessMenus', '业务菜单', JSON_OBJECT('en-US', 'Business menus'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000641, 'projects.businessPlaceholder', '描述业务对象、主要流程、需要管理的字段和第一版后台页面。例如：订单中心，管理客户、订单、支付记录，支持按订单号和状态查询。', JSON_OBJECT('en-US', 'Describe business entities, main flows, managed fields, and initial administration pages. For example, an order center managing customers, orders, and payments with order number and status search.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000642, 'projects.businessRequired', '请描述要生成的项目', JSON_OBJECT('en-US', 'Describe the project to generate'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000643, 'projects.businessScope', '这里的成员、角色、业务菜单和权限码只属于当前项目，不会影响 system 或其他项目。', JSON_OBJECT('en-US', 'Members, roles, business menus, and permission codes here belong only to this project and do not affect system or other projects.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000644, 'projects.createdAt', '创建时间', JSON_OBJECT('en-US', 'Created at'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000645, 'projects.currentScope', '当前范围：{name}（{code}）', JSON_OBJECT('en-US', 'Current scope: {name} ({code})'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000646, 'projects.database', '数据库', JSON_OBJECT('en-US', 'Database'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000647, 'projects.ddl', '已有 MySQL DDL（可选）', JSON_OBJECT('en-US', 'Existing MySQL DDL (optional)'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000648, 'projects.ddlExtra', '留空时 AI 设计第一版表结构；已有库可粘贴 CREATE TABLE，或使用下方只读导入', JSON_OBJECT('en-US', 'Leave empty for AI to design the initial schema; paste CREATE TABLE DDL or use read-only import below for an existing database.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000649, 'projects.defaultBranch', '默认目标分支', JSON_OBJECT('en-US', 'Default target branch'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000650, 'projects.delivery', '仓库交付', JSON_OBJECT('en-US', 'Repository delivery'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000651, 'projects.deliveryChoice', '两种交付方式二选一', JSON_OBJECT('en-US', 'Choose one delivery method'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000652, 'projects.deliveryChoiceHint', '两个仓库地址都留空时创建 private 仓库；绑定已有仓库时必须同时填写两个空仓库。', JSON_OBJECT('en-US', 'Leave both URLs empty to create private repositories, or provide both existing empty repositories.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000653, 'projects.deliveryLoadFailed', '仓库交付信息加载失败', JSON_OBJECT('en-US', 'Failed to load repository delivery information'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000654, 'projects.deliveryTitle', '仓库交付：{name}', JSON_OBJECT('en-US', 'Repository delivery: {name}'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000655, 'projects.description', '描述', JSON_OBJECT('en-US', 'Description'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000656, 'projects.disable', '停用', JSON_OBJECT('en-US', 'Disable'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000657, 'projects.disableConfirm', '确认停用项目？', JSON_OBJECT('en-US', 'Disable this project?'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000658, 'projects.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000659, 'projects.editTitle', '编辑项目{suffix}', JSON_OBJECT('en-US', 'Edit project{suffix}'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000660, 'projects.enable', '启用', JSON_OBJECT('en-US', 'Enable'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000661, 'projects.enableConfirm', '确认启用项目？', JSON_OBJECT('en-US', 'Enable this project?'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000662, 'projects.frontendRepo', '前端仓库', JSON_OBJECT('en-US', 'Frontend repository'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000663, 'projects.frontendRepoPlaceholder', 'https://gitlab.example.com/group/project-web', JSON_OBJECT('en-US', 'https://gitlab.example.com/group/project-web'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000664, 'projects.frontendRepoUrl', '前端空仓库 URL', JSON_OBJECT('en-US', 'Empty frontend repository URL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000665, 'projects.generateFirst', '生成第一版', JSON_OBJECT('en-US', 'Generate first version'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000666, 'projects.generateTitle', '生成第一版：{name}', JSON_OBJECT('en-US', 'Generate first version: {name}'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000667, 'projects.generating', '项目正在生成，完成后才能配置仓库', JSON_OBJECT('en-US', 'The project is being generated; configure repositories after completion'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000668, 'projects.generationFailed', '项目生成失败，暂时不能配置仓库', JSON_OBJECT('en-US', 'Project generation failed; repositories cannot be configured yet'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000669, 'projects.generationMode', '生成方式', JSON_OBJECT('en-US', 'Generation mode'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000670, 'projects.generationQueued', '生成任务已进入队列，可在项目工厂查看进度', JSON_OBJECT('en-US', 'Generation queued. Track progress in Project factory.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000671, 'projects.gitlabId', 'GitLab 项目标识', JSON_OBJECT('en-US', 'GitLab project identifier'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000672, 'projects.gitlabIdPlaceholder', '数字 ID 或 group/project', JSON_OBJECT('en-US', 'Numeric ID or group/project'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000673, 'projects.groupId', 'GitLab Group ID（可选）', JSON_OBJECT('en-US', 'GitLab Group ID (optional)'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000674, 'projects.groupPlaceholder', '留空使用平台默认 Group', JSON_OBJECT('en-US', 'Leave empty to use the platform default Group'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000675, 'projects.host', '主机', JSON_OBJECT('en-US', 'Host'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000676, 'projects.hostPlaceholder', '只填主机名或 IPv4，不填 jdbc:mysql:// 和端口', JSON_OBJECT('en-US', 'Enter only a hostname or IPv4 address, without jdbc:mysql:// or a port'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000677, 'projects.importSchema', '从 MySQL 只读导入结构', JSON_OBJECT('en-US', 'Import schema read-only from MySQL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000678, 'projects.importTitle', '从 MySQL 只读导入表结构', JSON_OBJECT('en-US', 'Import table schema read-only from MySQL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000679, 'projects.importedSchema', '已只读导入 {tables} 张表、{columns} 个字段；密码未保存', JSON_OBJECT('en-US', 'Imported {tables} tables and {columns} columns read-only; the password was not saved'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000680, 'projects.keyword', '关键词', JSON_OBJECT('en-US', 'Keyword'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000681, 'projects.keywordPlaceholder', '项目编码或名称', JSON_OBJECT('en-US', 'Project code or name'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000682, 'projects.legacyRepo', '单仓代码生成', JSON_OBJECT('en-US', 'Legacy single repository'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000683, 'projects.legacyRepoPlaceholder', '旧版单仓代码生成使用', JSON_OBJECT('en-US', 'Used by legacy single-repository generation'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000684, 'projects.legacyRepoTooltip', '仅供旧版代码生成与 MR 使用；新项目的后端、前端双仓库请使用项目列表中的“仓库交付”', JSON_OBJECT('en-US', 'Used only by the legacy generator and merge requests. Use Repository delivery for new separate backend and frontend repositories.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000685, 'projects.legacyRepoUrl', '单仓代码生成仓库地址', JSON_OBJECT('en-US', 'Legacy repository URL'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000686, 'projects.name', '项目名称', JSON_OBJECT('en-US', 'Project name'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000687, 'projects.noFailure', '未记录具体失败原因', JSON_OBJECT('en-US', 'No specific failure reason was recorded'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000688, 'projects.noGeneration', '该项目还没有生成任务', JSON_OBJECT('en-US', 'This project has no generation task'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000689, 'projects.open', '开通项目', JSON_OBJECT('en-US', 'Set up project'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000690, 'projects.openBackend', '打开后台', JSON_OBJECT('en-US', 'Open administration site'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000691, 'projects.openRepo', '打开仓库', JSON_OBJECT('en-US', 'Open repository'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000692, 'projects.orExisting', '或绑定已有空仓库', JSON_OBJECT('en-US', 'Or bind existing empty repositories'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000693, 'projects.package', '基础包名', JSON_OBJECT('en-US', 'Base package'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000694, 'projects.packageRule', '请输入合法 Java 包名', JSON_OBJECT('en-US', 'Enter a valid Java package name'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000695, 'projects.password', '密码', JSON_OBJECT('en-US', 'Password'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000696, 'projects.passwordOnce', '密码只用于这一次请求', JSON_OBJECT('en-US', 'The password is used for this request only'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000697, 'projects.permissionMenus', '权限菜单', JSON_OBJECT('en-US', 'Permission menus'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000698, 'projects.platformMenus', '平台菜单', JSON_OBJECT('en-US', 'Platform menus'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000699, 'projects.port', '端口', JSON_OBJECT('en-US', 'Port'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000700, 'projects.project', '项目', JSON_OBJECT('en-US', 'Project'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000701, 'projects.projectDescription', '项目描述', JSON_OBJECT('en-US', 'Project description'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000702, 'projects.projectMembers', '项目成员', JSON_OBJECT('en-US', 'Project members'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000703, 'projects.pushComplete', '前后端仓库均已完成初始推送', JSON_OBJECT('en-US', 'Initial push completed for both repositories'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000704, 'projects.pushCompleteHint', 'Kaiwu 只执行一次初始化，此后代码由各业务仓库自行维护。', JSON_OBJECT('en-US', 'Kaiwu initializes repositories once. Each business repository owns all later code.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000705, 'projects.pushConfirm', '确认一次性推送', JSON_OBJECT('en-US', 'Confirm one-time push'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000706, 'projects.pushQueued', 'GitLab 初始推送已进入后台执行', JSON_OBJECT('en-US', 'Initial GitLab push started in the background'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000707, 'projects.readSchema', '读取表结构', JSON_OBJECT('en-US', 'Read schema'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000708, 'projects.readonlyUser', '只读账号', JSON_OBJECT('en-US', 'Read-only username'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000709, 'projects.retryInFactory', '前往项目工厂修改并重试', JSON_OBJECT('en-US', 'Edit and retry in Project factory'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000710, 'projects.roleGrant', '角色授权', JSON_OBJECT('en-US', 'Role grants'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000711, 'projects.schemaSafety', 'System 只查询 information_schema 和 SHOW CREATE TABLE，不读取业务行；地址、账号、密码不会写入数据库、日志或生成任务。建议使用只读账号。', JSON_OBJECT('en-US', 'System queries only information_schema and SHOW CREATE TABLE, never business rows. Address, username, and password are not stored in the database, logs, or generation task. Use a read-only account.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000712, 'projects.status', '状态', JSON_OBJECT('en-US', 'Status'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000713, 'projects.statusUpdated', '项目状态已更新', JSON_OBJECT('en-US', 'Project status updated'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000714, 'projects.submitGeneration', '提交生成', JSON_OBJECT('en-US', 'Submit generation'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000715, 'projects.subtitle', '前后端双仓库通过每个项目的“仓库交付”配置；system 是不可停用、不可归档的内置项目', JSON_OBJECT('en-US', 'Configure separate frontend and backend repositories through Repository delivery. system is a built-in project that cannot be disabled or archived.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000716, 'projects.systemMembers', '系统成员', JSON_OBJECT('en-US', 'System members'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000717, 'projects.systemRoleGrant', '系统角色授权', JSON_OBJECT('en-US', 'System role grants'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000718, 'projects.systemScope', '这是不可停用、不可归档的 system 内置项目。Kaiwu 平台成员、系统角色、平台菜单和登录权限全部在这里管理；权限变更会撤销受影响用户的现有会话。', JSON_OBJECT('en-US', 'This is the built-in system project and cannot be disabled or archived. Manage Kaiwu platform members, system roles, platform menus, and sign-in permissions here. Permission changes revoke affected sessions.'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000719, 'projects.title', '项目管理', JSON_OBJECT('en-US', 'Projects'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000720, 'projects.titleSuffix', '：{name}', JSON_OBJECT('en-US', ': {name}'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000721, 'projects.updated', '项目已更新', JSON_OBJECT('en-US', 'Project updated'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000722, 'projects.viewProgress', '查看生成进度', JSON_OBJECT('en-US', 'View generation progress'), 'projects', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000723, 'roles.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000724, 'roles.assignMenus', '分配菜单', JSON_OBJECT('en-US', 'Assign menus'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000725, 'roles.assignTitle', '分配业务菜单{suffix}', JSON_OBJECT('en-US', 'Assign business menus{suffix}'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000726, 'roles.code', '角色编码', JSON_OBJECT('en-US', 'Role code'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000727, 'roles.create', '新建项目角色', JSON_OBJECT('en-US', 'Create project role'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000728, 'roles.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000729, 'roles.deleteConfirm', '确认删除该项目角色？', JSON_OBJECT('en-US', 'Delete this project role?'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000730, 'roles.deleted', '项目角色已删除', JSON_OBJECT('en-US', 'Project role deleted'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000731, 'roles.description', '描述', JSON_OBJECT('en-US', 'Description'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000732, 'roles.disableConfirm', '确认停用角色？', JSON_OBJECT('en-US', 'Disable this role?'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000733, 'roles.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000734, 'roles.editTitle', '编辑角色：{name}', JSON_OBJECT('en-US', 'Edit role: {name}'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000735, 'roles.enableConfirm', '确认启用角色？', JSON_OBJECT('en-US', 'Enable this role?'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000736, 'roles.grantUpdated', '项目角色授权已更新，父节点会自动补齐', JSON_OBJECT('en-US', 'Project role grants updated; parent nodes were added automatically'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000737, 'roles.menuCount', '菜单数', JSON_OBJECT('en-US', 'Menu count'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000738, 'roles.menuOption', '{name}（{code}）', JSON_OBJECT('en-US', '{name} ({code})'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000739, 'roles.name', '角色名称', JSON_OBJECT('en-US', 'Role name'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000740, 'roles.roleDescription', '角色描述', JSON_OBJECT('en-US', 'Role description'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000741, 'roles.saved', '项目角色已保存', JSON_OBJECT('en-US', 'Project role saved'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000742, 'roles.status', '状态', JSON_OBJECT('en-US', 'Status'), 'roles', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000743, 'scheduler.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000744, 'scheduler.completedAt', '完成时间', JSON_OBJECT('en-US', 'Completed at'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000745, 'scheduler.create', '新建任务', JSON_OBJECT('en-US', 'Create job'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000746, 'scheduler.createTitle', '新建定时任务', JSON_OBJECT('en-US', 'Create scheduled job'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000747, 'scheduler.credentialEnv', '将它以 KAIWU_SCHEDULER_CREDENTIAL 环境变量注入该项目服务；定时任务与读取平台参数配置共用这一个凭据。', JSON_OBJECT('en-US', 'Inject it into the project service as the KAIWU_SCHEDULER_CREDENTIAL environment variable. Scheduled tasks and platform configuration reads share this one credential.'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000748, 'scheduler.credentialOnce', '凭据只显示这一次；再次生成会立即撤销旧凭据。', JSON_OBJECT('en-US', 'The credential is shown only once. Generating another immediately revokes the old one.'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000749, 'scheduler.credentialSaved', '我已保存', JSON_OBJECT('en-US', 'I saved it'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000750, 'scheduler.credentialTitle', '请立即保存项目服务凭据', JSON_OBJECT('en-US', 'Save the project service credential now'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000751, 'scheduler.cron', 'Cron 表达式', JSON_OBJECT('en-US', 'Cron expression'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000752, 'scheduler.cronTooltip', 'Spring 六段 Cron：秒 分 时 日 月 星期', JSON_OBJECT('en-US', 'Spring six-field Cron: second minute hour day month weekday'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000753, 'scheduler.cronZone', 'Cron / 时区', JSON_OBJECT('en-US', 'Cron / time zone'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000754, 'scheduler.delete', '删除', JSON_OBJECT('en-US', 'Delete'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000755, 'scheduler.deleteConfirm', '删除后不再产生新的触发，历史执行记录会保留。确认删除？', JSON_OBJECT('en-US', 'Deleting stops future triggers and preserves execution history. Delete this job?'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000756, 'scheduler.deleted', '定时任务已删除', JSON_OBJECT('en-US', 'Scheduled job deleted'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000757, 'scheduler.edit', '编辑', JSON_OBJECT('en-US', 'Edit'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000758, 'scheduler.editTitle', '编辑定时任务', JSON_OBJECT('en-US', 'Edit scheduled job'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000759, 'scheduler.emptyExecutions', '当前项目暂无执行记录', JSON_OBJECT('en-US', 'No execution records for this project'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000760, 'scheduler.emptyJobs', '当前项目暂无定时任务', JSON_OBJECT('en-US', 'No scheduled jobs for this project'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000761, 'scheduler.enabled', '启用', JSON_OBJECT('en-US', 'Enabled'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000762, 'scheduler.enabledTooltip', '建议先保存为停用，确认项目实例在线后再启用', JSON_OBJECT('en-US', 'Save disabled first, then enable after confirming a project instance is online'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000763, 'scheduler.executions', '执行记录', JSON_OBJECT('en-US', 'Execution records'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000764, 'scheduler.generateCredential', '生成项目凭据', JSON_OBJECT('en-US', 'Generate project credential'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000765, 'scheduler.handler', '任务处理器', JSON_OBJECT('en-US', 'Task handler'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000766, 'scheduler.handlerOption', '{name}（{type}）', JSON_OBJECT('en-US', '{name} ({type})'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000767, 'scheduler.handlerRequired', '请选择项目已注册的任务处理器', JSON_OBJECT('en-US', 'Select a handler registered by the project'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000768, 'scheduler.handlerTooltip', '只能选择项目服务主动上报的 Handler', JSON_OBJECT('en-US', 'Only handlers reported by the project service can be selected'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000769, 'scheduler.instance', '执行实例', JSON_OBJECT('en-US', 'Execution instance'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000770, 'scheduler.job', '任务', JSON_OBJECT('en-US', 'Job'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000771, 'scheduler.jobs', '任务配置', JSON_OBJECT('en-US', 'Job configuration'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000772, 'scheduler.lastRun', '最近执行', JSON_OBJECT('en-US', 'Last run'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000773, 'scheduler.name', '任务名称', JSON_OBJECT('en-US', 'Job name'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000774, 'scheduler.nameRequired', '请输入任务名称', JSON_OBJECT('en-US', 'Enter a job name'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000775, 'scheduler.noHandlers', '当前项目还没有在线任务处理器', JSON_OBJECT('en-US', 'This project has no online task handlers'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000776, 'scheduler.noHandlersHint', '请先部署已接入 scheduler starter 且配置了项目凭据的服务实例；实例同步后才能创建任务。', JSON_OBJECT('en-US', 'Deploy a service using scheduler starter with a project credential before creating jobs.'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000777, 'scheduler.payload', '任务参数（JSON 对象）', JSON_OBJECT('en-US', 'Job payload (JSON object)'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000778, 'scheduler.payloadInvalid', '任务参数不是合法 JSON', JSON_OBJECT('en-US', 'Job payload is not valid JSON'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000779, 'scheduler.payloadJson', '任务参数必须是合法 JSON', JSON_OBJECT('en-US', 'Job payload must be valid JSON'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000780, 'scheduler.payloadObject', '任务参数必须是 JSON 对象', JSON_OBJECT('en-US', 'Job payload must be a JSON object'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000781, 'scheduler.payloadTooltip', '留空等同于 {}；必须是 JSON 对象，不能是数组或标量', JSON_OBJECT('en-US', 'Empty is equivalent to {}; the value must be a JSON object, not an array or scalar'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000782, 'scheduler.project', '项目', JSON_OBJECT('en-US', 'Project'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000783, 'scheduler.projectOption', '{name}（{code}）', JSON_OBJECT('en-US', '{name} ({code})'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000784, 'scheduler.refresh', '刷新', JSON_OBJECT('en-US', 'Refresh'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000785, 'scheduler.result', '结果 / 失败原因', JSON_OBJECT('en-US', 'Result / failure reason'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000786, 'scheduler.saved', '定时任务已保存', JSON_OBJECT('en-US', 'Scheduled job saved'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000787, 'scheduler.scheduledAt', '计划触发', JSON_OBJECT('en-US', 'Scheduled at'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000788, 'scheduler.securityDescription', '项目服务只会上报本地已注册的任务类型；System 不能下发 Java 类、Shell 或任意 URL。多实例会先向 System 抢占同一触发时间的执行租约。', JSON_OBJECT('en-US', 'Project services report only locally registered task types. System cannot send Java classes, shell commands, or arbitrary URLs. Multiple instances first claim a lease for the same trigger time.'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000789, 'scheduler.securityTitle', '安全执行模型', JSON_OBJECT('en-US', 'Secure execution model'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000790, 'scheduler.selectProject', '选择项目', JSON_OBJECT('en-US', 'Select a project'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000791, 'scheduler.status', '状态', JSON_OBJECT('en-US', 'Status'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000792, 'scheduler.subtitle', 'System 统一管理调度配置与执行记录，任务代码在对应项目服务内精准执行', JSON_OBJECT('en-US', 'System manages schedules and execution records; task code runs precisely inside each project service.'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000793, 'scheduler.title', '项目定时任务', JSON_OBJECT('en-US', 'Project scheduler'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000794, 'scheduler.version', '版本', JSON_OBJECT('en-US', 'Version'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000795, 'scheduler.zone', '时区', JSON_OBJECT('en-US', 'Time zone'), 'scheduler', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000796, 'scope.global', '全局默认', JSON_OBJECT('en-US', 'Global defaults'), 'scope', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000797, 'scope.label', '作用范围', JSON_OBJECT('en-US', 'Scope'), 'scope', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000798, 'scope.project', '{name}（{code}）', JSON_OBJECT('en-US', '{name} ({code})'), 'scope', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000799, 'security.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000800, 'security.after', '修改后', JSON_OBJECT('en-US', 'After'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000801, 'security.before', '修改前', JSON_OBJECT('en-US', 'Before'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000802, 'security.changes', '变更', JSON_OBJECT('en-US', 'Changes'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000803, 'security.clientIp', '客户端 IP', JSON_OBJECT('en-US', 'Client IP'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000804, 'security.description', '说明', JSON_OBJECT('en-US', 'Description'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000805, 'security.detail', '详情', JSON_OBJECT('en-US', 'Details'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000806, 'security.diffOperationTitle', '变更详情 · {operation}', JSON_OBJECT('en-US', 'Change details · {operation}'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000807, 'security.diffTitle', '变更详情', JSON_OBJECT('en-US', 'Change details'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000808, 'security.emptyValue', '（空）', JSON_OBJECT('en-US', '(empty)'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000809, 'security.field', '字段', JSON_OBJECT('en-US', 'Field'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000810, 'security.forceOffline', '强制下线', JSON_OBJECT('en-US', 'Force sign-out'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000811, 'security.lastSeen', '最后访问', JSON_OBJECT('en-US', 'Last seen'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000812, 'security.loginTime', '登录时间', JSON_OBJECT('en-US', 'Signed in at'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000813, 'security.logins', '登录日志', JSON_OBJECT('en-US', 'Sign-in logs'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000814, 'security.module', '模块', JSON_OBJECT('en-US', 'Module'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000815, 'security.noDiff', '本次操作未解析到字段级变更；如有需要参考“详情”列摘要。', JSON_OBJECT('en-US', 'No field-level change could be parsed. Refer to the Details summary if needed.'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000816, 'security.nullValue', 'null', JSON_OBJECT('en-US', 'null'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000817, 'security.offlineConfirm', '确认下线', JSON_OBJECT('en-US', 'Confirm sign-out'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000818, 'security.offlineHint', '下线后该设备的 Access Token 会在下一次请求时立即被 Gateway 拒绝。', JSON_OBJECT('en-US', 'The Gateway will reject this device’s access token on its next request.'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000819, 'security.offlineSuccess', '会话已强制下线', JSON_OBJECT('en-US', 'Session signed out'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000820, 'security.offlineTitle', '强制下线：{username}', JSON_OBJECT('en-US', 'Force sign-out: {username}'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000821, 'security.operation', '操作', JSON_OBJECT('en-US', 'Operation'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000822, 'security.operations', '操作日志', JSON_OBJECT('en-US', 'Operation logs'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000823, 'security.operator', '操作人：{username}', JSON_OBJECT('en-US', 'Operator: {username}'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000824, 'security.reason', '处置原因（可选）', JSON_OBJECT('en-US', 'Reason (optional)'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000825, 'security.request', '请求', JSON_OBJECT('en-US', 'Request'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000826, 'security.sessionId', '会话 ID', JSON_OBJECT('en-US', 'Session ID'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000827, 'security.sessions', '在线会话', JSON_OBJECT('en-US', 'Online sessions'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000828, 'security.status', '状态', JSON_OBJECT('en-US', 'Status'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000829, 'security.subtitle', '统一查看登录、操作审计和在线会话；强制下线会立即撤销 Gateway 会话快照', JSON_OBJECT('en-US', 'Review sign-ins, audit operations, and online sessions. Forced sign-out immediately revokes the Gateway session snapshot.'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000830, 'security.summary', '摘要：{detail}', JSON_OBJECT('en-US', 'Summary: {detail}'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000831, 'security.targetId', '资源 ID：', JSON_OBJECT('en-US', 'Resource ID: '), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000832, 'security.targetType', '资源类型：', JSON_OBJECT('en-US', 'Resource type: '), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000833, 'security.time', '时间', JSON_OBJECT('en-US', 'Time'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000834, 'security.title', '安全运营中心', JSON_OBJECT('en-US', 'Security operations'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000835, 'security.traceId', 'Trace ID', JSON_OBJECT('en-US', 'Trace ID'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000836, 'security.user', '用户', JSON_OBJECT('en-US', 'User'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000837, 'security.view', '查看', JSON_OBJECT('en-US', 'View'), 'security', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000838, 'starter.authenticationRequired', '未认证或认证已过期', JSON_OBJECT('en-US', 'Authentication is missing or expired'), 'starter', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000839, 'starter.permissionDenied', '无操作权限', JSON_OBJECT('en-US', 'You do not have permission for this operation'), 'starter', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000840, 'users.actions', '操作', JSON_OBJECT('en-US', 'Actions'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000841, 'users.batchDisable', '批量停用', JSON_OBJECT('en-US', 'Disable selected'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000842, 'users.batchDisableConfirm', '确认批量停用所选用户？', JSON_OBJECT('en-US', 'Disable the selected users?'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000843, 'users.batchEnable', '批量启用', JSON_OBJECT('en-US', 'Enable selected'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000844, 'users.confirmPassword', '确认密码', JSON_OBJECT('en-US', 'Confirm password'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000845, 'users.create', '新建用户', JSON_OBJECT('en-US', 'Create user'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000846, 'users.created', '用户创建成功', JSON_OBJECT('en-US', 'User created'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000847, 'users.createdAt', '创建时间', JSON_OBJECT('en-US', 'Created at'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000848, 'users.disableConfirm', '确认停用该用户？', JSON_OBJECT('en-US', 'Disable this user?'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000849, 'users.disabled', '用户已停用', JSON_OBJECT('en-US', 'User disabled'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000850, 'users.displayName', '显示名称', JSON_OBJECT('en-US', 'Display name'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000851, 'users.downloadTemplate', '下载模板', JSON_OBJECT('en-US', 'Download template'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000852, 'users.editTitle', '编辑用户{suffix}', JSON_OBJECT('en-US', 'Edit user{suffix}'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000853, 'users.email', '邮箱', JSON_OBJECT('en-US', 'Email'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000854, 'users.empty', '暂无用户，点击右上角新建', JSON_OBJECT('en-US', 'No users. Use Create in the upper right.'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000855, 'users.enableConfirm', '确认启用该用户？', JSON_OBJECT('en-US', 'Enable this user?'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000856, 'users.enabled', '用户已启用', JSON_OBJECT('en-US', 'User enabled'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000857, 'users.excelImport', 'Excel 导入', JSON_OBJECT('en-US', 'Import Excel'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000858, 'users.export', '导出', JSON_OBJECT('en-US', 'Export'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000859, 'users.exportFailed', '导出失败', JSON_OBJECT('en-US', 'Export failed'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000860, 'users.importErrorRow', '第 {row} 行 {username}：{message}', JSON_OBJECT('en-US', 'Row {row}, {username}: {message}'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000861, 'users.importFailed', '导入失败', JSON_OBJECT('en-US', 'Import failed'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000862, 'users.importResult', '导入完成：成功 {succeeded}，失败 {failed}', JSON_OBJECT('en-US', 'Import completed: {succeeded} succeeded, {failed} failed'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000863, 'users.imported', '成功导入 {count} 个用户', JSON_OBJECT('en-US', '{count} users imported'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000864, 'users.initialPassword', '初始密码', JSON_OBJECT('en-US', 'Initial password'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000865, 'users.newPassword', '新密码', JSON_OBJECT('en-US', 'New password'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000866, 'users.passwordMismatch', '两次输入的密码不一致', JSON_OBJECT('en-US', 'The passwords do not match'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000867, 'users.passwordReset', '密码已重置，该用户现有会话已撤销', JSON_OBJECT('en-US', 'Password reset and the user’s existing sessions revoked'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000868, 'users.resetPassword', '重置密码', JSON_OBJECT('en-US', 'Reset password'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000869, 'users.resetTitle', '重置密码{suffix}', JSON_OBJECT('en-US', 'Reset password{suffix}'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000870, 'users.searchPlaceholder', '用户名或显示名称', JSON_OBJECT('en-US', 'Username or display name'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000871, 'users.selectedDisabled', '所选用户已停用', JSON_OBJECT('en-US', 'Selected users disabled'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000872, 'users.selectedEnabled', '所选用户已启用', JSON_OBJECT('en-US', 'Selected users enabled'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000873, 'users.status', '状态', JSON_OBJECT('en-US', 'Status'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000874, 'users.subtitle', '只管理全局身份；平台权限请到项目管理 → 内置 system 项目分配', JSON_OBJECT('en-US', 'Manage global identities only. Assign platform permissions in Projects → built-in system project.'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000875, 'users.title', '用户管理', JSON_OBJECT('en-US', 'Users'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000876, 'users.titleSuffix', '：{username}', JSON_OBJECT('en-US', ': {username}'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000877, 'users.updated', '用户信息已更新', JSON_OBJECT('en-US', 'User information updated'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000878, 'users.user', '用户', JSON_OBJECT('en-US', 'User'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000879, 'users.username', '用户名', JSON_OBJECT('en-US', 'Username'), 'users', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), public_visible = VALUES(public_visible),
    required_resource = 1, status = 'ENABLED', version = version + 1,
    updated_at = CURRENT_TIMESTAMP;

-- 登录页文案属于匿名恢复范围；其它资源默认不得由 PUBLIC catalog 暴露。
UPDATE sys_i18n_message
SET public_visible = CASE
        WHEN message_key LIKE 'login.%'
          OR message_key IN (
            'common.language', 'common.language.zhCN', 'common.language.enUS',
            'client.connectionFailed', 'client.serviceUnavailable',
            'client.requestFailed', 'client.loginFailed'
          ) THEN 1 ELSE 0 END,
    updated_at = CURRENT_TIMESTAMP;

-- 内置字典沿用自身业务表，只把最后一版代码语言包的译文迁回 JSON。
UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message message
  ON message.message_key = CONCAT('dict.', type.dict_code, '.', item.item_value)
SET item.label_i18n = JSON_SET(COALESCE(item.label_i18n, JSON_OBJECT()),
                               '$."en-US"',
                               JSON_UNQUOTE(JSON_EXTRACT(message.translations_json, '$."en-US"'))),
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0;

-- 菜单仍以 sys_project_menu 为事实源；这里只迁移旧路径推导曾覆盖的内置节点。
UPDATE sys_project_menu menu
JOIN sys_project project ON project.id = menu.project_id AND project.project_code = 'system'
JOIN sys_i18n_message message ON message.message_key = CASE
    WHEN menu.id = 9000000000000014000 THEN 'menu.system.directory.platform'
    WHEN menu.id = 9000000000000014001 THEN 'menu.system.directory.delivery'
    WHEN menu.route_path = '/' THEN 'menu.system.home'
    WHEN menu.route_path IS NOT NULL THEN CONCAT('menu.system.', SUBSTRING(menu.route_path, 2))
    ELSE NULL END
SET menu.menu_name_i18n = JSON_SET(COALESCE(menu.menu_name_i18n, JSON_OBJECT()),
                                   '$."en-US"',
                                   JSON_UNQUOTE(JSON_EXTRACT(message.translations_json, '$."en-US"'))),
    menu.updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
-- 纠正历史界面允许录入的错误日语代码 jp；BCP 47/ISO 639 正确标签为 ja-JP。
UPDATE sys_i18n_message
SET translations_json = JSON_SET(
        JSON_REMOVE(translations_json, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(translations_json, '$."ja-JP"'),
            JSON_EXTRACT(translations_json, '$."jp"')
        )
    ),
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(translations_json, 'one', '$."jp"');

UPDATE sys_project_menu
SET menu_name_i18n = JSON_SET(
        JSON_REMOVE(menu_name_i18n, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(menu_name_i18n, '$."ja-JP"'),
            JSON_EXTRACT(menu_name_i18n, '$."jp"')
        )
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(menu_name_i18n, 'one', '$."jp"');

UPDATE sys_dict_item
SET label_i18n = JSON_SET(
        JSON_REMOVE(label_i18n, '$."jp"'),
        '$."ja-JP"',
        COALESCE(
            JSON_EXTRACT(label_i18n, '$."ja-JP"'),
            JSON_EXTRACT(label_i18n, '$."jp"')
        )
    ),
    updated_at = CURRENT_TIMESTAMP
WHERE JSON_CONTAINS_PATH(label_i18n, 'one', '$."jp"');

UPDATE sys_user SET locale = 'ja-JP', updated_at = CURRENT_TIMESTAMP WHERE locale = 'jp';

UPDATE sys_dict_item legacy
JOIN sys_dict_type type ON type.id = legacy.dict_type_id
LEFT JOIN sys_dict_item canonical
  ON canonical.dict_type_id = legacy.dict_type_id
 AND canonical.item_value = 'ja-JP'
SET legacy.item_value = 'ja-JP',
    legacy.extra_json = JSON_SET(
        COALESCE(legacy.extra_json, JSON_OBJECT()),
        '$.selectable', false,
        '$.antdLocale', 'ja-JP',
        '$.dateLocale', 'ja-JP'
    ),
    legacy.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND legacy.item_value = 'jp'
  AND canonical.id IS NULL;

UPDATE sys_dict_item legacy
JOIN sys_dict_type type ON type.id = legacy.dict_type_id
SET legacy.status = 'DISABLED', legacy.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND legacy.item_value = 'jp';

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';

-- 所有跨服务异常必须携带稳定 messageKey；详细中文仅作为兼容信息和审计事实。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000901, 'api.common.badRequest', '请求参数错误', JSON_OBJECT('en-US', 'Invalid request parameters'), 'api', 0, 1, 'ENABLED', '未细分的参数校验安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000902, 'api.common.notFound', '请求的资源不存在', JSON_OBJECT('en-US', 'The requested resource was not found'), 'api', 0, 1, 'ENABLED', '未细分的资源不存在安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000903, 'api.common.conflict', '当前操作与资源状态冲突', JSON_OBJECT('en-US', 'The operation conflicts with the current resource state'), 'api', 0, 1, 'ENABLED', '未细分的状态冲突安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000904, 'api.common.internalError', '服务处理失败，请稍后重试', JSON_OBJECT('en-US', 'The service could not process the request. Try again later.'), 'api', 0, 1, 'ENABLED', '内部错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000905, 'api.common.unauthorized', '未登录或登录已过期', JSON_OBJECT('en-US', 'Sign-in is required or has expired'), 'api', 0, 1, 'ENABLED', '认证失败安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000906, 'api.common.upstreamFailed', '上游服务响应异常', JSON_OBJECT('en-US', 'An upstream service returned an invalid response'), 'api', 0, 1, 'ENABLED', '上游错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000907, 'api.common.serviceUnavailable', '服务暂时不可用，请稍后重试', JSON_OBJECT('en-US', 'The service is temporarily unavailable. Try again later.'), 'api', 0, 1, 'ENABLED', '服务不可用安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000908, 'api.common.forbidden', '无操作权限', JSON_OBJECT('en-US', 'You do not have permission for this operation'), 'api', 0, 1, 'ENABLED', '授权失败安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000909, 'api.common.operationFailed', '操作失败，请稍后重试', JSON_OBJECT('en-US', 'The operation failed. Try again later.'), 'api', 0, 1, 'ENABLED', '未知业务错误安全回退', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000951, 'dicts.localeCodeTip', '使用 BCP 47 标签，例如 zh-CN、en-US、ko-KR', JSON_OBJECT('en-US', 'Use a BCP 47 tag, for example zh-CN, en-US, or ko-KR'), 'dicts', 0, 1, 'ENABLED', '语言字典取值输入提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000952, 'dicts.localeCodeInvalid', '语言代码必须是规范 BCP 47 标签，例如 ko-KR', JSON_OBJECT('en-US', 'The locale code must be a canonical BCP 47 tag, for example ko-KR'), 'dicts', 0, 1, 'ENABLED', '语言字典取值前端校验提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000961, 'i18n.selectLocale', '选择语言', JSON_OBJECT('en-US', 'Select a language'), 'i18n', 0, 1, 'ENABLED', '译文导入导出的目标语言选择', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000962, 'i18n.exportTranslations', '导出译文', JSON_OBJECT('en-US', 'Export translations'), 'i18n', 0, 1, 'ENABLED', '导出待翻译内容', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000963, 'i18n.importTranslations', '导入译文', JSON_OBJECT('en-US', 'Import translations'), 'i18n', 0, 1, 'ENABLED', '导入已翻译内容', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000964, 'i18n.importDone', '已导入 {applied} 条译文', JSON_OBJECT('en-US', 'Imported {applied} translations'), 'i18n', 0, 1, 'ENABLED', '导入成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
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
    (9100000000000000994, 'projectHealth.readOnlyHint', '体检只报告，不阻断任何流程，也不会修改业务仓库。', JSON_OBJECT('en-US', 'The check only reports. It never blocks any flow or modifies the repository.'), 'projects', 0, 1, 'ENABLED', '体检边界说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002101, 'i18nKey.enable', '启用国际化', JSON_OBJECT('en-US', 'Enable localization'), 'i18n', 0, 1, 'DISABLED', '引用式国际化开关', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002102, 'i18nKey.change', '更换资源', JSON_OBJECT('en-US', 'Change resource'), 'i18n', 0, 1, 'DISABLED', '更换引用的资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002103, 'i18nKey.pickTitle', '选择国际化资源', JSON_OBJECT('en-US', 'Select a localization resource'), 'i18n', 0, 1, 'DISABLED', '资源选择弹窗标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002104, 'i18nKey.key', '资源 key', JSON_OBJECT('en-US', 'Resource key'), 'i18n', 0, 1, 'DISABLED', '资源 key 列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002105, 'i18nKey.defaultText', '默认文案', JSON_OBJECT('en-US', 'Default text'), 'i18n', 0, 1, 'DISABLED', '默认文案列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002106, 'i18nKey.module', '模块', JSON_OBJECT('en-US', 'Module'), 'i18n', 0, 1, 'DISABLED', '模块列与筛选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002107, 'i18nKey.searchPlaceholder', '搜索 key 或文案', JSON_OBJECT('en-US', 'Search key or text'), 'i18n', 0, 1, 'DISABLED', '资源搜索占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002108, 'i18nKey.create', '新建资源', JSON_OBJECT('en-US', 'New resource'), 'i18n', 0, 1, 'DISABLED', '就地新建资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002109, 'i18nKey.created', '资源已创建', JSON_OBJECT('en-US', 'Resource created'), 'i18n', 0, 1, 'DISABLED', '新建成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002110, 'i18nKey.cancel', '取消', JSON_OBJECT('en-US', 'Cancel'), 'i18n', 0, 1, 'DISABLED', '弹窗取消', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002111, 'i18nKey.loadFailed', '国际化资源加载失败', JSON_OBJECT('en-US', 'Failed to load localization resources'), 'i18n', 0, 1, 'DISABLED', '资源加载失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002112, 'configs.i18nKey', '国际化文案', JSON_OBJECT('en-US', 'Localized text'), 'configs', 0, 1, 'DISABLED', '配置引用资源字段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002113, 'configs.i18nKeyHint', '只对直接展示给用户的文案有效；限额、阈值、开关等参与后端校验的值不要启用。', JSON_OBJECT('en-US', 'Only for text shown to users. Do not enable it for limits, thresholds or switches validated on the server.'), 'configs', 0, 1, 'ENABLED', '配置国际化适用范围说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002114, 'menus.i18nKey', '国际化文案', JSON_OBJECT('en-US', 'Localized text'), 'menus', 0, 1, 'DISABLED', '菜单引用资源字段', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002115, 'menus.i18nKeyHint', '内置菜单的译文统一在国际化资源里维护，不在这里逐语言填写。', JSON_OBJECT('en-US', 'Built-in menu translations are maintained in localization resources, not filled in per language here.'), 'menus', 0, 1, 'ENABLED', '菜单国际化说明', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002200, 'localizedName.modeFixed', '独立填写', JSON_OBJECT('en-US', 'Enter directly'), 'i18n', 0, 1, 'ENABLED', '录入模式：固定文案', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002201, 'localizedName.modeReferenced', '引用国际化资源', JSON_OBJECT('en-US', 'Reference a localization resource'), 'i18n', 0, 1, 'ENABLED', '录入模式：引用资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002202, 'localizedName.fallbackRequired', '请填写默认文案', JSON_OBJECT('en-US', 'Please provide the default text'), 'i18n', 0, 1, 'ENABLED', '兜底文案必填校验', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002203, 'localizedName.referenced', '已引用', JSON_OBJECT('en-US', 'Referenced'), 'i18n', 0, 1, 'ENABLED', '引用状态标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002204, 'localizedName.change', '更换资源', JSON_OBJECT('en-US', 'Change resource'), 'i18n', 0, 1, 'ENABLED', '更换引用的资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002205, 'localizedName.pickResource', '选择资源', JSON_OBJECT('en-US', 'Select a resource'), 'i18n', 0, 1, 'ENABLED', '空态：打开选择器', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002206, 'localizedName.createResource', '新建资源', JSON_OBJECT('en-US', 'New resource'), 'i18n', 0, 1, 'ENABLED', '就地新建资源', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002207, 'localizedName.pickTitle', '选择国际化资源', JSON_OBJECT('en-US', 'Select a localization resource'), 'i18n', 0, 1, 'ENABLED', '资源选择弹窗标题', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002208, 'localizedName.pickKey', '资源 key', JSON_OBJECT('en-US', 'Resource key'), 'i18n', 0, 1, 'ENABLED', '资源 key 列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002209, 'localizedName.pickDefault', '默认文案', JSON_OBJECT('en-US', 'Default text'), 'i18n', 0, 1, 'ENABLED', '默认文案列', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002210, 'localizedName.pickModule', '模块', JSON_OBJECT('en-US', 'Module'), 'i18n', 0, 1, 'ENABLED', '模块列与筛选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002211, 'localizedName.pickSearchPlaceholder', '搜索 key 或文案', JSON_OBJECT('en-US', 'Search key or text'), 'i18n', 0, 1, 'ENABLED', '资源搜索占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002212, 'localizedName.cancel', '取消', JSON_OBJECT('en-US', 'Cancel'), 'i18n', 0, 1, 'ENABLED', '弹窗取消', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002213, 'localizedName.defaultPreview', '默认显示', JSON_OBJECT('en-US', 'Default'), 'i18n', 0, 1, 'ENABLED', '默认文案预览标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002214, 'localizedName.translationsPreview', '其他语言', JSON_OBJECT('en-US', 'Other languages'), 'i18n', 0, 1, 'ENABLED', '其他语言译文预览标签', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002215, 'localizedName.loadFailed', '国际化资源加载失败', JSON_OBJECT('en-US', 'Failed to load localization resources'), 'i18n', 0, 1, 'ENABLED', '资源加载失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002216, 'localizedName.createDone', '资源已创建', JSON_OBJECT('en-US', 'Resource created'), 'i18n', 0, 1, 'ENABLED', '新建成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002217, 'localizedName.createFailed', '资源创建失败', JSON_OBJECT('en-US', 'Failed to create resource'), 'i18n', 0, 1, 'ENABLED', '新建失败提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002218, 'localizedName.createKeyPlaceholder', '例如：module.subject.usage', JSON_OBJECT('en-US', 'e.g. module.subject.usage'), 'i18n', 0, 1, 'ENABLED', '新建资源 key 输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002300, 'dict.common.tag_color.success', '成功（绿）', JSON_OBJECT('en-US', 'Success (green)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002301, 'dict.common.tag_color.processing', '处理中（蓝）', JSON_OBJECT('en-US', 'Processing (blue)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002302, 'dict.common.tag_color.warning', '警告（橙）', JSON_OBJECT('en-US', 'Warning (orange)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002303, 'dict.common.tag_color.error', '失败（红）', JSON_OBJECT('en-US', 'Error (red)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002304, 'dict.common.tag_color.default', '默认（灰）', JSON_OBJECT('en-US', 'Default (grey)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002305, 'dict.common.tag_color.purple', '紫（类别）', JSON_OBJECT('en-US', 'Purple (category)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002306, 'dict.common.tag_color.cyan', '青（类别）', JSON_OBJECT('en-US', 'Cyan (category)'), 'dict', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002310, 'dicts.extraKey', '键', JSON_OBJECT('en-US', 'Key'), 'dicts', 0, 1, 'ENABLED', '扩展配置键输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002311, 'dicts.extraValue', '值', JSON_OBJECT('en-US', 'Value'), 'dicts', 0, 1, 'ENABLED', '扩展配置值输入占位', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000002312, 'dicts.extraAdd', '添加一项', JSON_OBJECT('en-US', 'Add entry'), 'dicts', 0, 1, 'ENABLED', '扩展配置新增按钮', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';

-- 补齐语言覆盖状态文案，并让历史日语目录项具备至少一份可识别的英文名称。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000000913, 'i18n.localeCoverage', '语言开放状态', JSON_OBJECT('en-US', 'Language availability'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000914, 'i18n.available', '可选择', JSON_OBJECT('en-US', 'Available'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000915, 'i18n.notConfigured', '目录未开放', JSON_OBJECT('en-US', 'Not enabled in directory'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000916, 'i18n.missingResources', '资源 {count}', JSON_OBJECT('en-US', 'Resources {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000917, 'i18n.missingMenus', '菜单 {count}', JSON_OBJECT('en-US', 'Menus {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000918, 'i18n.missingDictionaries', '字典 {count}', JSON_OBJECT('en-US', 'Dictionary items {count}'), 'i18n', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000919, 'api.i18n.htmlForbidden', '国际化资源只允许纯文本', JSON_OBJECT('en-US', 'Internationalization resources must be plain text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000920, 'api.i18n.jsonInvalid', '多语言译文必须是合法 JSON 对象', JSON_OBJECT('en-US', 'Translations must be a valid JSON object'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000921, 'api.i18n.keyExists', '国际化资源 key 已存在', JSON_OBJECT('en-US', 'The internationalization resource key already exists'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000922, 'api.i18n.keyImmutable', '国际化资源 key 创建后不可修改', JSON_OBJECT('en-US', 'The internationalization resource key cannot be changed after creation'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000923, 'api.i18n.localeInvalid', '包含未启用或重复默认语言', JSON_OBJECT('en-US', 'Translations contain an unavailable locale or duplicate the default locale'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000924, 'api.i18n.notFound', '国际化资源不存在', JSON_OBJECT('en-US', 'The internationalization resource was not found'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000925, 'api.i18n.placeholderMismatch', '译文占位符与默认文案不一致', JSON_OBJECT('en-US', 'Translation placeholders do not match the default text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000926, 'api.i18n.publicKeyInvalid', '该资源不允许匿名公开', JSON_OBJECT('en-US', 'This resource cannot be exposed anonymously'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000927, 'api.i18n.translationInvalid', '译文必须是非空文本', JSON_OBJECT('en-US', 'A translation must be non-empty text'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000928, 'api.i18n.versionConflict', '资源已被其他人修改，请刷新后重试', JSON_OBJECT('en-US', 'The resource was changed by someone else. Refresh and try again'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000929, 'api.i18n.versionRequired', '更新资源必须携带版本', JSON_OBJECT('en-US', 'Updating a resource requires its version'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000930, 'api.locale.codeInvalid', '语言代码必须是规范 BCP 47 标签', JSON_OBJECT('en-US', 'The locale must be a canonical BCP 47 language tag'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000931, 'api.i18n.defaultTextTooLong', '默认文案不能超过 2000 个字符', JSON_OBJECT('en-US', 'Default text cannot exceed 2000 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000932, 'api.i18n.descriptionTooLong', '说明不能超过 512 个字符', JSON_OBJECT('en-US', 'Description cannot exceed 512 characters'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000933, 'api.i18n.keyInvalid', '资源 key 格式不正确', JSON_OBJECT('en-US', 'The resource key format is invalid'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000934, 'api.i18n.moduleInvalid', '模块代码格式不正确', JSON_OBJECT('en-US', 'The module code format is invalid'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000935, 'api.i18n.statusInvalid', '资源状态必须是 ENABLED 或 DISABLED', JSON_OBJECT('en-US', 'Resource status must be ENABLED or DISABLED'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000936, 'api.validation.required', '必填项不能为空', JSON_OBJECT('en-US', 'This field is required'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000937, 'dicts.localeSelectable', '覆盖完整后允许用户选择', JSON_OBJECT('en-US', 'Allow users to select after coverage is complete'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000938, 'dicts.localeSelectableTip', '即使开启，也只有在资源、菜单和字典译文全部补齐后才会出现在语言选择器', JSON_OBJECT('en-US', 'Even when enabled, the language appears only after resource, menu, and dictionary translations are complete'), 'dicts', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000939, 'api.i18n.requiredTranslationMissing', '覆盖必需资源必须为已开放语言 {locales} 提供译文', JSON_OBJECT('en-US', 'A required resource must provide translations for the available languages: {locales}'), 'api', 0, 1, 'ENABLED', '阻止管理员用一条缺译资源让整门语言不可选', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000940, 'api.i18n.defaultLocaleNotTranslatable', '默认语言使用原文，无需导入译文', JSON_OBJECT('en-US', 'The default language uses the source text and needs no translation import'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000941, 'api.i18n.exportFailed', '导出译文失败', JSON_OBJECT('en-US', 'Failed to export translations'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000942, 'api.i18n.importFileInvalid', '无法解析该 Excel 文件，请确认文件未损坏且大小在 10MB 以内', JSON_OBJECT('en-US', 'The Excel file could not be parsed. Check that it is not corrupted and is under 10MB.'), 'api', 0, 1, 'ENABLED', '同时用于文件大小超限和解析失败', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000943, 'api.i18n.importSheetMissing', '文件中没有可识别的工作表，请使用导出的模板填写', JSON_OBJECT('en-US', 'The file contains no recognizable sheet. Fill in the exported template instead.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000000944, 'api.i18n.importTooManyRows', '单个工作表不能超过 {limit} 行，请拆分后分批导入', JSON_OBJECT('en-US', 'A single sheet cannot exceed {limit} rows. Split the file and import in batches.'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text),
    translations_json = JSON_MERGE_PATCH(
        COALESCE(translations_json, JSON_OBJECT()), VALUES(translations_json)),
    module_code = VALUES(module_code), required_resource = 1,
    status = 'ENABLED', version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
SET item.label_i18n = JSON_SET(
        COALESCE(item.label_i18n, JSON_OBJECT()),
        '$."en-US"',
        COALESCE(
            JSON_UNQUOTE(JSON_EXTRACT(item.label_i18n, '$."en-US"')),
            'Japanese'
        )
    ),
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'platform.locale'
  AND item.item_value = 'ja-JP';

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';

-- ADR 0012：只读项目体检。健康开关已折进 sys_project 定义，快照不保留 ALTER。
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

INSERT IGNORE INTO sys_dict_type
    (id, scope_id, dict_code, dict_name, inherit_global, status,
     description, created_at, updated_at)
VALUES
    (8320, 0, 'project.health.verdict', '项目体检结论', 0, 'ENABLED',
     '只读项目体检的检查结论；UNKNOWN 表示平台无法确认，不等于不合格',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8321, 0, 'common.tag_color', '标签颜色', 0, 'ENABLED',
     '字典项 Tag 的展示颜色；状态类优先用语义色，类别类可用 purple/cyan',
     CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_dict_item
    (id, dict_type_id, item_label, item_value, sort_no, default_item,
     color, extra_json, label_i18n, label_i18n_key, status, created_at, updated_at)
VALUES
    (8521, 8320, '通过', 'PASS', 10, 1, 'success', NULL,
     NULL, NULL, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8522, 8320, '待改进', 'WARN', 20, 0, 'warning', NULL,
     NULL, NULL, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8523, 8320, '契约破坏', 'FAIL', 30, 0, 'error', NULL,
     NULL, NULL, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8524, 8320, '无法确认', 'UNKNOWN', 40, 0, 'default', NULL,
     NULL, NULL, 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8531, 8321, '成功（绿）', 'success', 10, 0, 'success', NULL, NULL,
     'dict.common.tag_color.success', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8532, 8321, '处理中（蓝）', 'processing', 20, 0, 'processing', NULL, NULL,
     'dict.common.tag_color.processing', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8533, 8321, '警告（橙）', 'warning', 30, 0, 'warning', NULL, NULL,
     'dict.common.tag_color.warning', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8534, 8321, '失败（红）', 'error', 40, 0, 'error', NULL, NULL,
     'dict.common.tag_color.error', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8535, 8321, '默认（灰）', 'default', 50, 1, 'default', NULL, NULL,
     'dict.common.tag_color.default', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8536, 8321, '紫（类别）', 'purple', 60, 0, 'purple', NULL, NULL,
     'dict.common.tag_color.purple', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (8537, 8321, '青（类别）', 'cyan', 70, 0, 'cyan', NULL, NULL,
     'dict.common.tag_color.cyan', 'ENABLED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

INSERT IGNORE INTO sys_project_menu
    (id, project_id, parent_id, menu_name, menu_name_i18n, menu_type,
     route_path, component_path, permission_code, icon, sort_no, visible,
     status, created_at, updated_at)
SELECT 9000000000000018000, parent.project_id, parent.id,
       '项目体检', NULL, 'BUTTON',
       NULL, NULL, 'system:project:health', NULL, 80, 1,
       'ACTIVE', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM sys_project_menu parent
JOIN sys_project project ON project.id = parent.project_id
WHERE project.project_code = 'system'
  AND parent.menu_type = 'MENU'
  AND parent.route_path = '/projects';

-- ADR 0014：把已存在的 dict.{dictCode}.{itemValue} 约定 key 提升为显式引用。
-- 与 V23 增量同一条 JOIN UPDATE；快照按批量 INSERT 一次性建库，不像增量链有
-- 「先有字典项、后有该 UPDATE」的顺序保证，因此这里必须重复一遍，否则快照建库和
-- 增量建库的 sys_dict_item.label_i18n_key 会不一致。
UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dict.', type.dict_code, '.', item.item_value)
SET item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND item.label_i18n_key IS NULL;

-- 语言名的译文资源（ADR 0015 后语言名也走资源目录）。
-- required_resource = 0 与 V26 的迁移产物保持一致：它们来自运行期数据，
-- 不该让某门语言因为缺这两条译文而掉出「可选择」。
INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000003001, 'dict.platform.locale.zh-CN', '简体中文', JSON_OBJECT('en-US', 'Simplified Chinese'), 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000003002, 'dict.platform.locale.en-US', '英语（美国）', JSON_OBJECT('en-US', 'English (US)'), 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- V27/V28：后端抛出但资源目录缺失的错误码，由 `check:i18n` 的错误码校验扫出。
-- ID 用 91000000000000041xx 段：V26 的 91000000000000031xx 段是运行时按 ROW_NUMBER()
-- 动态分配给项目菜单资源的，长度取决于库里的菜单数量，不能被 seed 占用（见 V28）。
INSERT IGNORE INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000004101, 'api.i18n.keyNotFound', '国际化资源不存在：{key}', JSON_OBJECT('en-US', 'The internationalization resource does not exist: {key}'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000004102, 'api.projectHealth.disabled', '该项目已关闭只读体检', JSON_OBJECT('en-US', 'Read-only health check is disabled for this project'), 'api', 0, 1, 'ENABLED', NULL, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ADR 0015：内联多语言列退役。
-- 快照里前面几段（V11/V12/V14 的历史动作）仍会回填 label_i18n，这里按 V26 的规则
-- 把译文提升进资源目录再清空，否则「快照建库」与「增量建库」结果不一致。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
SELECT 9100000000000003000 + ROW_NUMBER() OVER (ORDER BY source.id),
       source.message_key, source.item_label, source.label_i18n, 'dict', 0, 0, 'ENABLED',
       '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1,
       CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM (
    SELECT item.id, item.item_label, item.label_i18n,
           CONCAT('dict.', type.dict_code, '.', item.item_value) AS message_key
    FROM sys_dict_item item
    JOIN sys_dict_type type ON type.id = item.dict_type_id
    WHERE item.label_i18n IS NOT NULL
      AND item.label_i18n_key IS NULL
) source
WHERE NOT EXISTS (
    SELECT 1 FROM sys_i18n_message existing
    WHERE existing.message_key = source.message_key
);

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dict.', type.dict_code, '.', item.item_value)
SET item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE item.label_i18n IS NOT NULL
  AND item.label_i18n_key IS NULL;

UPDATE sys_dict_item
SET label_i18n = NULL, updated_at = CURRENT_TIMESTAMP
WHERE label_i18n IS NOT NULL;

UPDATE sys_project_menu
SET menu_name_i18n = NULL, updated_at = CURRENT_TIMESTAMP
WHERE menu_name_i18n IS NOT NULL;

-- V29：历史 V18 已升级库可能遗漏项目体检的字典与资源目录。
-- 快照前文已包含资源和字典初始行；这里声明补偿后的最终引用式状态。
UPDATE sys_dict_type
SET status = 'ENABLED', updated_at = CURRENT_TIMESTAMP
WHERE scope_id = 0
  AND dict_code = 'project.health.verdict';

UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
SET item.label_i18n = NULL,
    item.label_i18n_key = CONCAT('dict.project.health.verdict.', item.item_value),
    item.status = 'ENABLED',
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'project.health.verdict'
  AND item.item_value IN ('PASS', 'WARN', 'FAIL', 'UNKNOWN');

-- V30：修复历史升级库遗漏的 GitLab SUCCESS 字典资源引用。
UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = 'dict.gitlab.test.status.SUCCESS'
 AND resource.status = 'ENABLED'
SET item.label_i18n = NULL,
    item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'gitlab.test.status'
  AND item.item_value = 'SUCCESS';

-- V31：ja-JP 已配置为候选语言；补齐其所有缺失的必需资源译文。
UPDATE sys_i18n_message message
JOIN (
    SELECT 'api.i18n.keyNotFound' AS message_key, '国際化リソースが存在しません：{key}' AS translated_text
    UNION ALL SELECT 'api.projectHealth.disabled', 'このプロジェクトでは読み取り専用ヘルスチェックが無効です'
    UNION ALL SELECT 'dict.common.tag_color.cyan', 'シアン（カテゴリ）'
    UNION ALL SELECT 'dict.common.tag_color.default', 'デフォルト（グレー）'
    UNION ALL SELECT 'dict.common.tag_color.error', 'エラー（赤）'
    UNION ALL SELECT 'dict.common.tag_color.processing', '処理中（青）'
    UNION ALL SELECT 'dict.common.tag_color.purple', 'パープル（カテゴリ）'
    UNION ALL SELECT 'dict.common.tag_color.success', '成功（緑）'
    UNION ALL SELECT 'dict.common.tag_color.warning', '警告（オレンジ）'
    UNION ALL SELECT 'dict.project.health.verdict.FAIL', '契約違反'
    UNION ALL SELECT 'dict.project.health.verdict.PASS', '合格'
    UNION ALL SELECT 'dict.project.health.verdict.UNKNOWN', '確認不可'
    UNION ALL SELECT 'dict.project.health.verdict.WARN', '要改善'
    UNION ALL SELECT 'dicts.extraAdd', '項目を追加'
    UNION ALL SELECT 'dicts.extraKey', 'キー'
    UNION ALL SELECT 'dicts.extraValue', '値'
    UNION ALL SELECT 'localizedName.cancel', 'キャンセル'
    UNION ALL SELECT 'localizedName.change', 'リソースを変更'
    UNION ALL SELECT 'localizedName.createDone', 'リソースを作成しました'
    UNION ALL SELECT 'localizedName.createFailed', 'リソースの作成に失敗しました'
    UNION ALL SELECT 'localizedName.createKeyPlaceholder', '例：module.subject.usage'
    UNION ALL SELECT 'localizedName.createResource', 'リソースを作成'
    UNION ALL SELECT 'localizedName.defaultPreview', '既定'
    UNION ALL SELECT 'localizedName.fallbackRequired', 'デフォルトのテキストを入力してください'
    UNION ALL SELECT 'localizedName.loadFailed', '国際化リソースの読み込みに失敗しました'
    UNION ALL SELECT 'localizedName.modeFixed', '直接入力'
    UNION ALL SELECT 'localizedName.modeReferenced', '国際化リソースを参照'
    UNION ALL SELECT 'localizedName.pickDefault', 'デフォルトのテキスト'
    UNION ALL SELECT 'localizedName.pickKey', 'リソースキー'
    UNION ALL SELECT 'localizedName.pickModule', 'モジュール'
    UNION ALL SELECT 'localizedName.pickResource', 'リソースを選択'
    UNION ALL SELECT 'localizedName.pickSearchPlaceholder', 'キーまたはテキストを検索'
    UNION ALL SELECT 'localizedName.pickTitle', '国際化リソースを選択'
    UNION ALL SELECT 'localizedName.referenced', '参照中'
    UNION ALL SELECT 'localizedName.translationsPreview', '他の言語'
    UNION ALL SELECT 'projectHealth.checkedAt', 'チェック日時'
    UNION ALL SELECT 'projectHealth.detail', '詳細'
    UNION ALL SELECT 'projectHealth.done', 'ヘルスチェックが完了しました'
    UNION ALL SELECT 'projectHealth.empty', 'まだチェックされていません。プラットフォームはリポジトリ内の契約ファイルのみを読み取り、書き込みは行いません。'
    UNION ALL SELECT 'projectHealth.enabled', '読み取り専用ヘルスチェックを許可'
    UNION ALL SELECT 'projectHealth.entry', 'ヘルスチェック'
    UNION ALL SELECT 'projectHealth.failed', 'ヘルスチェックに失敗しました'
    UNION ALL SELECT 'projectHealth.item', 'チェック項目'
    UNION ALL SELECT 'projectHealth.readOnlyHint', 'チェックは報告のみで、フローをブロックしたりビジネスリポジトリを変更したりしません。'
    UNION ALL SELECT 'projectHealth.result', '結果'
    UNION ALL SELECT 'projectHealth.run', '再チェック'
    UNION ALL SELECT 'projectHealth.switchUpdated', 'ヘルスチェックの設定を更新しました'
    UNION ALL SELECT 'projectHealth.title', 'ヘルスチェック：{project}'
    UNION ALL SELECT 'projectHealth.verdict', '総合判定'
) source ON source.message_key = message.message_key
SET message.translations_json = JSON_SET(
        COALESCE(message.translations_json, JSON_OBJECT()),
        '$."ja-JP"', source.translated_text),
    message.version = message.version + 1,
    message.updated_at = CURRENT_TIMESTAMP
WHERE message.status = 'ENABLED'
  AND NULLIF(JSON_UNQUOTE(JSON_EXTRACT(message.translations_json, '$."ja-JP"')), '') IS NULL;

-- 迁移历史由 Flyway 的 flyway_schema_history 表维护，不在快照内声明。
+-- 内置 BUTTON 也会在 system 权限中心展示，不能只国际化侧边栏的目录和 MENU。
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

-- V33：平台内置字典类型名称使用引用式国际化资源。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9100000000000102900, 'dictType.ai.test.status', '大模型连通测试状态', JSON_OBJECT('en-US', 'AI connectivity test status', 'ja-JP', 'AI 接続テスト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：ai.test.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102901, 'dictType.common.boolean_enabled', '是否启用', JSON_OBJECT('en-US', 'Enabled option', 'ja-JP', '有効化するか'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.boolean_enabled', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102902, 'dictType.common.status', '通用启停状态', JSON_OBJECT('en-US', 'General enablement status', 'ja-JP', '共通有効・無効状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102903, 'dictType.common.tag_color', '标签颜色', JSON_OBJECT('en-US', 'Tag color', 'ja-JP', 'タグの色'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.tag_color', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102904, 'dictType.config.value.type', '配置值类型', JSON_OBJECT('en-US', 'Configuration value type', 'ja-JP', '設定値の種類'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：config.value.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102905, 'dictType.gitlab.test.status', 'GitLab 连通测试状态', JSON_OBJECT('en-US', 'GitLab connectivity test status', 'ja-JP', 'GitLab 接続テスト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：gitlab.test.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102906, 'dictType.notification.type', '站内信分类', JSON_OBJECT('en-US', 'Notification type', 'ja-JP', '通知の種類'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：notification.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102907, 'dictType.platform.locale', '平台语言', JSON_OBJECT('en-US', 'Platform language', 'ja-JP', 'プラットフォーム言語'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.locale', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102908, 'dictType.platform.menu.type', '平台菜单类型', JSON_OBJECT('en-US', 'Platform menu type', 'ja-JP', 'プラットフォームメニュー種別'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.menu.type', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102909, 'dictType.project.generation.mode', '项目生成方式', JSON_OBJECT('en-US', 'Project generation mode', 'ja-JP', 'プロジェクト生成方式'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.mode', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102910, 'dictType.project.generation.status', '项目生成状态', JSON_OBJECT('en-US', 'Project generation status', 'ja-JP', 'プロジェクト生成状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102911, 'dictType.project.health.verdict', '项目体检结论', JSON_OBJECT('en-US', 'Project health verdict', 'ja-JP', 'プロジェクト健全性判定'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.health.verdict', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102912, 'dictType.project.member.status', '项目成员状态', JSON_OBJECT('en-US', 'Project member status', 'ja-JP', 'プロジェクトメンバー状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.member.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102913, 'dictType.project.repository.push.status', '仓库推送状态', JSON_OBJECT('en-US', 'Repository push status', 'ja-JP', 'リポジトリプッシュ状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.repository.push.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102914, 'dictType.project.status', '业务项目状态', JSON_OBJECT('en-US', 'Business project status', 'ja-JP', '業務プロジェクト状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102915, 'dictType.scheduler.execution.status', '定时任务执行状态', JSON_OBJECT('en-US', 'Scheduled task execution status', 'ja-JP', '定期タスク実行状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：scheduler.execution.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102916, 'dictType.security.login.status', '登录日志状态', JSON_OBJECT('en-US', 'Sign-in log status', 'ja-JP', 'ログイン履歴状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.login.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102917, 'dictType.security.session.status', '在线会话状态', JSON_OBJECT('en-US', 'Online session status', 'ja-JP', 'オンラインセッション状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.session.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9100000000000102918, 'dictType.user.status', '平台用户状态', JSON_OBJECT('en-US', 'Platform user status', 'ja-JP', 'プラットフォームユーザー状態'), 'dict', 0, 1, 'ENABLED', '内置字典类型名称：user.status', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

UPDATE sys_dict_type type
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dictType.', type.dict_code)
 AND resource.status = 'ENABLED'
SET type.dict_name_key = resource.message_key,
    type.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code IN (
    'ai.test.status', 'common.boolean_enabled', 'common.status', 'common.tag_color',
    'config.value.type', 'gitlab.test.status', 'notification.type', 'platform.locale',
    'platform.menu.type', 'project.generation.mode', 'project.generation.status',
    'project.health.verdict', 'project.member.status', 'project.repository.push.status',
    'project.status', 'scheduler.execution.status', 'security.login.status',
    'security.session.status', 'user.status'
  );

-- V35：操作审计模块字典（security.audit.module）。
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

-- 字典管理拖拽排序的界面文案（V37）。
INSERT INTO sys_i18n_message
    (id, message_key, default_text, translations_json, module_code, public_visible,
     required_resource, status, description, version, created_at, updated_at)
VALUES
    (9200000000000000001, 'dicts.dragSort', '拖动调整顺序', JSON_OBJECT('en-US', 'Drag to reorder', 'ja-JP', 'ドラッグして並べ替え'), 'dicts', 0, 1, 'ENABLED', '字典管理拖拽手柄的提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (9200000000000000002, 'dicts.sortSaved', '顺序已保存', JSON_OBJECT('en-US', 'Order saved', 'ja-JP', '並び順を保存しました'), 'dicts', 0, 1, 'ENABLED', '字典管理拖拽排序成功提示', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON DUPLICATE KEY UPDATE
    default_text = VALUES(default_text), translations_json = VALUES(translations_json),
    module_code = VALUES(module_code), required_resource = 1, status = 'ENABLED',
    version = version + 1, updated_at = CURRENT_TIMESTAMP;

-- 项目完成双仓初始推送后的本地 AI Coding 交接文案（V39）。
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
