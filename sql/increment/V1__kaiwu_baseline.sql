-- Kaiwu 平台库 Flyway V1 完整基线。
-- 仅用于初始化全新空数据库；不兼容旧项目数据库的原地升级。

CREATE TABLE IF NOT EXISTS sys_user (
    id BIGINT NOT NULL,
    username VARCHAR(64) NOT NULL,
    password_hash VARCHAR(100) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NULL,
    status VARCHAR(20) NOT NULL,
    must_change_password TINYINT NOT NULL DEFAULT 0 COMMENT '1=登录后必须先改密码',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_user_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_role (
    id BIGINT NOT NULL,
    role_code VARCHAR(64) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    description VARCHAR(255) NULL,
    status VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_permission (
    id BIGINT NOT NULL,
    permission_code VARCHAR(128) NOT NULL,
    permission_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_permission_code (permission_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_sys_user_role_user FOREIGN KEY (user_id) REFERENCES sys_user (id),
    CONSTRAINT fk_sys_user_role_role FOREIGN KEY (role_id) REFERENCES sys_role (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_role_permission (
    role_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_sys_role_permission_role FOREIGN KEY (role_id) REFERENCES sys_role (id),
    CONSTRAINT fk_sys_role_permission_permission FOREIGN KEY (permission_id) REFERENCES sys_permission (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sys_menu (
    id BIGINT NOT NULL,
    parent_id BIGINT NULL,
    menu_name VARCHAR(100) NOT NULL,
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
    client_ip VARCHAR(64) NULL,
    trace_id VARCHAR(64) NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    KEY idx_sys_oper_log_user_time (user_id, created_at),
    KEY idx_sys_oper_log_module_time (module, created_at)
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
    default_branch VARCHAR(64) NOT NULL DEFAULT 'dev-jarvis',
    backend_url VARCHAR(512) NULL,
    backend_label VARCHAR(100) NULL,
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
    inherit_global TINYINT NOT NULL DEFAULT 1,
    status VARCHAR(16) NOT NULL,
    description VARCHAR(512) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_dict_type_scope_code (scope_id, dict_code),
    KEY idx_sys_dict_type_scope_status (scope_id, status)
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
    status VARCHAR(16) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_sys_dict_item_type_value (dict_type_id, item_value),
    KEY idx_sys_dict_item_type_status_sort (dict_type_id, status, sort_no),
    CONSTRAINT fk_sys_dict_item_type
        FOREIGN KEY (dict_type_id) REFERENCES sys_dict_type (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

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
    default_branch VARCHAR(64) NOT NULL DEFAULT 'dev-jarvis',
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

INSERT IGNORE INTO sys_role (id, role_code, role_name, status)
VALUES (1, 'platform-admin', '平台管理员', 'ENABLED');

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name)
VALUES (1, 'system:platform:read', '访问平台工作台');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id)
VALUES (1, 1);

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code)
VALUES (1, NULL, '验证平台访问', 'BUTTON', 'system:platform:read');

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (2, 'system:user:list', '查询平台用户'),
    (3, 'system:user:create', '创建平台用户'),
    (4, 'system:user:update', '编辑平台用户'),
    (5, 'system:user:status', '启停平台用户'),
    (6, 'system:user:reset-password', '重置平台用户密码');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 2),
    (1, 3),
    (1, 4),
    (1, 5),
    (1, 6);

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code) VALUES
    (100, NULL, '用户管理', 'MENU', NULL),
    (101, 100, '查询用户', 'BUTTON', 'system:user:list'),
    (102, 100, '创建用户', 'BUTTON', 'system:user:create'),
    (103, 100, '编辑用户', 'BUTTON', 'system:user:update'),
    (104, 100, '启停用户', 'BUTTON', 'system:user:status'),
    (105, 100, '重置密码', 'BUTTON', 'system:user:reset-password');

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (7, 'system:role:list', '查询平台角色与权限'),
    (8, 'system:role:create', '创建平台角色'),
    (9, 'system:role:update', '编辑平台角色'),
    (10, 'system:role:status', '启停平台角色'),
    (11, 'system:role:grant', '授予平台角色权限'),
    (12, 'system:user:assign-role', '分配平台用户角色');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 7),
    (1, 8),
    (1, 9),
    (1, 10),
    (1, 11),
    (1, 12);

INSERT IGNORE INTO sys_menu (id, parent_id, menu_name, menu_type, permission_code) VALUES
    (106, 100, '分配用户角色', 'BUTTON', 'system:user:assign-role'),
    (200, NULL, '角色管理', 'MENU', NULL),
    (201, 200, '查询角色', 'BUTTON', 'system:role:list'),
    (202, 200, '创建角色', 'BUTTON', 'system:role:create'),
    (203, 200, '编辑角色', 'BUTTON', 'system:role:update'),
    (204, 200, '启停角色', 'BUTTON', 'system:role:status'),
    (205, 200, '角色授权', 'BUTTON', 'system:role:grant');

UPDATE sys_menu SET route_path = '/users', icon = 'UserOutlined', sort_no = 10 WHERE id = 100;
UPDATE sys_menu SET route_path = '/roles', icon = 'TeamOutlined', sort_no = 20 WHERE id = 200;

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (13, 'system:menu:list', '查询平台菜单'),
    (14, 'system:menu:create', '创建平台菜单'),
    (15, 'system:menu:update', '编辑平台菜单'),
    (16, 'system:menu:status', '启停平台菜单'),
    (17, 'system:menu:delete', '删除平台菜单');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 13),
    (1, 14),
    (1, 15),
    (1, 16),
    (1, 17);

INSERT IGNORE INTO sys_menu
    (id, parent_id, menu_name, menu_type, route_path, icon, sort_no, permission_code)
VALUES
    (300, NULL, '平台菜单', 'MENU', '/menus', 'MenuOutlined', 30, NULL),
    (301, 300, '查询菜单', 'BUTTON', NULL, NULL, 10, 'system:menu:list'),
    (302, 300, '创建菜单', 'BUTTON', NULL, NULL, 20, 'system:menu:create'),
    (303, 300, '编辑菜单', 'BUTTON', NULL, NULL, 30, 'system:menu:update'),
    (304, 300, '启停菜单', 'BUTTON', NULL, NULL, 40, 'system:menu:status'),
    (305, 300, '删除菜单', 'BUTTON', NULL, NULL, 50, 'system:menu:delete');

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (18, 'system:project:list', '查询项目'),
    (19, 'system:project:create', '创建项目'),
    (20, 'system:project:update', '编辑项目'),
    (21, 'system:project:status', '变更项目状态'),
    (22, 'system:project:member', '管理项目成员'),
    (23, 'system:project:role', '管理项目角色'),
    (24, 'system:project:menu', '管理项目菜单');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 18), (1, 19), (1, 20), (1, 21), (1, 22), (1, 23), (1, 24);

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

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (25, 'system:config:list', '查询应用配置'),
    (26, 'system:config:save', '保存应用配置'),
    (27, 'system:config:delete', '删除应用配置'),
    (28, 'system:dict:list', '查询字典'),
    (29, 'system:dict:save', '保存字典'),
    (30, 'system:dict:delete', '删除字典');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 25), (1, 26), (1, 27), (1, 28), (1, 29), (1, 30);

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

INSERT IGNORE INTO sys_permission (id, permission_code, permission_name) VALUES
    (31, 'system:project-factory:list', '查看项目生成'),
    (32, 'system:project-factory:generate', '生成项目'),
    (33, 'system:project-factory:download', '下载项目制品'),
    (34, 'system:project-factory:push', '初始推送 GitLab'),
    (35, 'system:git:list', '查看 GitLab 配置'),
    (36, 'system:git:save', '保存 GitLab 配置'),
    (37, 'system:git:test', '测试 GitLab 连接');

INSERT IGNORE INTO sys_role_permission (role_id, permission_id) VALUES
    (1, 31), (1, 32), (1, 33), (1, 34),
    (1, 35), (1, 36), (1, 37);

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

-- 迁移历史由 Flyway 的 flyway_schema_history 表维护，不在快照内声明。
