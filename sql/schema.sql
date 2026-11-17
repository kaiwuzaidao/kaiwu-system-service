CREATE TABLE `sys_agent_conversation` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `title` varchar(100) NOT NULL,
  `use_memory` tinyint(1) NOT NULL DEFAULT '1',
  `run_id` bigint DEFAULT NULL,
  `busy_until` datetime(6) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_agent_conversation_owner` (`user_id`,`updated_at`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_memory` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `content` varchar(500) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_agent_memory_owner` (`user_id`,`updated_at`,`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_message` (
  `id` bigint NOT NULL,
  `conversation_id` bigint NOT NULL,
  `request_id` varchar(64) NOT NULL,
  `question` varchar(500) NOT NULL,
  `answer` mediumtext,
  `completed` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_message_request` (`conversation_id`,`request_id`),
  KEY `idx_agent_message_conversation` (`conversation_id`,`created_at`,`id`),
  CONSTRAINT `fk_agent_message_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `sys_agent_conversation` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_ai_model_route` (
  `id` bigint NOT NULL,
  `plan_model_id` bigint DEFAULT NULL,
  `answer_model_id` bigint DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_ai_provider_config` (
  `id` bigint NOT NULL,
  `provider_name` varchar(100) NOT NULL,
  `base_url` varchar(512) NOT NULL,
  `api_key_ciphertext` text,
  `model` varchar(128) NOT NULL,
  `temperature` decimal(3,2) NOT NULL DEFAULT '0.20',
  `timeout_seconds` int NOT NULL DEFAULT '60',
  `enabled` tinyint NOT NULL DEFAULT '1',
  `last_test_status` varchar(20) DEFAULT NULL,
  `last_test_message` varchar(500) DEFAULT NULL,
  `last_test_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `config_revision` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_app_config` (
  `id` bigint NOT NULL,
  `scope_id` bigint NOT NULL DEFAULT '0',
  `config_key` varchar(128) NOT NULL,
  `config_value` text NOT NULL,
  `value_i18n_key` varchar(160) DEFAULT NULL COMMENT '展示型配置引用的国际化资源 key；非空即启用',
  `value_type` varchar(16) NOT NULL,
  `secret` tinyint NOT NULL DEFAULT '0',
  `status` varchar(16) NOT NULL,
  `description` varchar(512) DEFAULT NULL,
  `sort_no` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_app_config_scope_key` (`scope_id`,`config_key`),
  KEY `idx_sys_app_config_scope_status` (`scope_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_department` (
  `id` bigint NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `dept_name` varchar(100) NOT NULL,
  `dept_code` varchar(64) NOT NULL,
  `sort_no` int NOT NULL DEFAULT '0',
  `status` varchar(20) NOT NULL DEFAULT 'ENABLED',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_department_code` (`dept_code`),
  KEY `idx_sys_department_parent_sort` (`parent_id`,`sort_no`),
  CONSTRAINT `fk_sys_department_parent` FOREIGN KEY (`parent_id`) REFERENCES `sys_department` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_dict_type` (
  `id` bigint NOT NULL,
  `scope_id` bigint NOT NULL DEFAULT '0',
  `dict_code` varchar(128) NOT NULL,
  `dict_name` varchar(128) NOT NULL,
  `dict_name_key` varchar(160) DEFAULT NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
  `inherit_global` tinyint NOT NULL DEFAULT '1',
  `sort_no` int NOT NULL DEFAULT '0',
  `status` varchar(16) NOT NULL,
  `description` varchar(512) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_dict_type_scope_code` (`scope_id`,`dict_code`),
  KEY `idx_sys_dict_type_scope_status` (`scope_id`,`status`),
  KEY `idx_sys_dict_type_scope_sort` (`scope_id`,`sort_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_i18n_catalog_revision` (
  `catalog_code` varchar(32) NOT NULL,
  `revision` bigint NOT NULL DEFAULT '1',
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`catalog_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_i18n_message` (
  `id` bigint NOT NULL,
  `scope_id` bigint NOT NULL DEFAULT '0' COMMENT '0 为平台资源，其余为业务项目 ID',
  `message_key` varchar(160) NOT NULL,
  `default_text` varchar(2000) NOT NULL,
  `translations_json` json DEFAULT NULL,
  `module_code` varchar(64) NOT NULL,
  `public_visible` tinyint NOT NULL DEFAULT '0',
  `required_resource` tinyint NOT NULL DEFAULT '1',
  `status` varchar(16) NOT NULL,
  `description` varchar(512) DEFAULT NULL,
  `version` bigint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_i18n_message_scope_key` (`scope_id`,`message_key`),
  KEY `idx_sys_i18n_message_module_status` (`module_code`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_login_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `username` varchar(64) DEFAULT NULL,
  `user_id` bigint DEFAULT NULL,
  `login_status` varchar(20) NOT NULL,
  `message` varchar(255) DEFAULT NULL,
  `client_ip` varchar(64) DEFAULT NULL,
  `trace_id` varchar(64) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_login_log_username_time` (`username`,`created_at`),
  KEY `idx_sys_login_log_status_time` (`login_status`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_managed_todo` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `project_code` varchar(64) NOT NULL,
  `producer_service` varchar(16) NOT NULL,
  `biz_key` varchar(128) NOT NULL,
  `recipient_user_id` bigint NOT NULL,
  `operation_sequence` bigint NOT NULL,
  `state` varchar(16) NOT NULL,
  `terminal` tinyint(1) NOT NULL,
  `stale` tinyint(1) NOT NULL DEFAULT '0',
  `payload_digest` binary(32) NOT NULL,
  `operation_created_at` datetime(6) NOT NULL,
  `title` varchar(200) DEFAULT NULL,
  `content` varchar(2000) DEFAULT NULL,
  `link_url` varchar(512) DEFAULT NULL,
  `due_at` datetime(6) DEFAULT NULL,
  `last_seen_at` datetime(6) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_managed_todo` (`project_code`,`producer_service`,`biz_key`,`recipient_user_id`),
  KEY `idx_managed_recipient` (`recipient_user_id`,`state`,`updated_at`,`id`),
  KEY `idx_managed_cleanup` (`state`,`terminal`,`last_seen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_menu` (
  `id` bigint NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `menu_name` varchar(100) NOT NULL,
  `menu_type` varchar(20) NOT NULL,
  `route_path` varchar(256) DEFAULT NULL,
  `component_path` varchar(256) DEFAULT NULL,
  `permission_code` varchar(128) DEFAULT NULL,
  `icon` varchar(64) DEFAULT NULL,
  `sort_no` int NOT NULL DEFAULT '0',
  `visible` tinyint NOT NULL DEFAULT '1',
  `status` varchar(20) NOT NULL DEFAULT 'ENABLED',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_menu_permission` (`permission_code`),
  KEY `idx_sys_menu_parent_sort` (`parent_id`,`sort_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_notification` (
  `id` bigint NOT NULL,
  `recipient_user_id` bigint NOT NULL,
  `project_id` bigint DEFAULT NULL COMMENT '来源项目；平台自身产生的消息为 NULL',
  `project_code` varchar(64) DEFAULT NULL,
  `notification_type` varchar(32) NOT NULL COMMENT '字典 notification.type',
  `title` varchar(200) NOT NULL,
  `content` varchar(2000) DEFAULT NULL,
  `link_url` varchar(512) DEFAULT NULL COMMENT '站内相对路径，点击后跳转',
  `read_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_notification_recipient_read` (`recipient_user_id`,`read_at`,`created_at`),
  KEY `idx_sys_notification_project` (`project_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_oper_log` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint DEFAULT NULL,
  `username` varchar(64) DEFAULT NULL,
  `module` varchar(64) NOT NULL,
  `operation` varchar(100) NOT NULL,
  `request_method` varchar(20) NOT NULL,
  `request_path` varchar(255) NOT NULL,
  `response_status` int NOT NULL,
  `detail` varchar(1000) DEFAULT NULL,
  `client_ip` varchar(64) DEFAULT NULL,
  `trace_id` varchar(64) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `target_type` varchar(64) DEFAULT NULL COMMENT '目标资源类型',
  `target_id` varchar(64) DEFAULT NULL COMMENT '目标资源 ID',
  `change_json` text COMMENT '字段级变更 JSON: [{field, before, after}]',
  PRIMARY KEY (`id`),
  KEY `idx_sys_oper_log_user_time` (`user_id`,`created_at`),
  KEY `idx_sys_oper_log_module_time` (`module`,`created_at`),
  KEY `idx_sys_oper_log_target` (`target_type`,`target_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_runtime_task` (
  `task_key` varchar(128) NOT NULL,
  `task_status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`task_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_storage_account` (
  `id` bigint NOT NULL,
  `account_code` varchar(64) NOT NULL COMMENT '账号编码，创建后不可修改',
  `account_name` varchar(100) NOT NULL,
  `provider_type` varchar(32) NOT NULL COMMENT '字典 storage.provider.type',
  `endpoint` varchar(255) NOT NULL COMMENT '数据面 S3 兼容地址',
  `region` varchar(64) NOT NULL,
  `bucket` varchar(63) NOT NULL,
  `path_style` tinyint(1) NOT NULL DEFAULT '0',
  `sts_endpoint` varchar(255) NOT NULL,
  `role_arn` varchar(255) DEFAULT NULL COMMENT '阿里云必填；MinIO 可空',
  `access_key_id` varchar(128) NOT NULL,
  `access_key_secret_ciphertext` varchar(1024) NOT NULL COMMENT 'KAIWU_CONFIG_ENCRYPTION_KEY 加密后的 Secret',
  `credential_ttl_seconds` int NOT NULL DEFAULT '1800',
  `status` varchar(16) NOT NULL COMMENT '字典 common.status',
  `last_test_status` varchar(16) DEFAULT NULL COMMENT '字典 ai.test.status',
  `last_test_message` varchar(500) DEFAULT NULL,
  `last_test_at` datetime DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_storage_account_code` (`account_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_todo` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL COMMENT '来源项目',
  `project_code` varchar(64) NOT NULL,
  `biz_key` varchar(128) NOT NULL COMMENT '业务唯一键，由来源服务约定',
  `recipient_user_id` bigint NOT NULL COMMENT '处理人',
  `title` varchar(200) NOT NULL,
  `content` varchar(2000) DEFAULT NULL,
  `link_url` varchar(512) DEFAULT NULL COMMENT '平台内跳转路径',
  `status` varchar(16) NOT NULL COMMENT 'OPEN / DONE / CANCELLED',
  `due_at` datetime DEFAULT NULL,
  `opened_at` datetime NOT NULL COMMENT '打开或重新打开的时间',
  `closed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_todo_biz` (`project_code`,`biz_key`,`recipient_user_id`),
  KEY `idx_sys_todo_recipient` (`recipient_user_id`,`status`,`opened_at`),
  KEY `idx_sys_todo_stale` (`status`,`updated_at`),
  KEY `idx_sys_todo_closed` (`status`,`closed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_todo_biz_lock` (
  `project_code` varchar(64) NOT NULL,
  `biz_key` varchar(128) NOT NULL,
  PRIMARY KEY (`project_code`,`biz_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_todo_key_guard` (
  `project_code` varchar(64) NOT NULL,
  `biz_key` varchar(128) NOT NULL,
  `recipient_user_id` bigint NOT NULL,
  `kind` varchar(16) NOT NULL,
  PRIMARY KEY (`project_code`,`biz_key`,`recipient_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_todo_recipient_quota` (
  `project_code` varchar(64) NOT NULL,
  `recipient_user_id` bigint NOT NULL,
  `open_count` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`project_code`,`recipient_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_user` (
  `id` bigint NOT NULL,
  `username` varchar(64) NOT NULL,
  `password_hash` varchar(100) NOT NULL,
  `display_name` varchar(100) NOT NULL,
  `email` varchar(200) DEFAULT NULL,
  `status` varchar(20) NOT NULL,
  `locale` varchar(16) NOT NULL DEFAULT 'zh-CN',
  `must_change_password` tinyint NOT NULL DEFAULT '0' COMMENT '1=登录后必须先改密码',
  `agent_auto_open` tinyint NOT NULL DEFAULT '0' COMMENT '1=登录后默认进入 AI 助手聊天模式',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_user_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_user_department` (
  `user_id` bigint NOT NULL,
  `department_id` bigint NOT NULL,
  `primary_department` tinyint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`user_id`,`department_id`),
  KEY `idx_sys_user_department_department` (`department_id`,`primary_department`),
  CONSTRAINT `fk_sys_user_department_department` FOREIGN KEY (`department_id`) REFERENCES `sys_department` (`id`),
  CONSTRAINT `fk_sys_user_department_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_device_authorization` (
  `id` varchar(36) NOT NULL,
  `device_code_hash` varchar(64) NOT NULL COMMENT 'device_code 的 SHA-256 摘要，明文只返回给发起方一次',
  `user_code` varchar(16) NOT NULL COMMENT '供用户在 /device 页面核对的短码',
  `client_name` varchar(64) NOT NULL COMMENT 'CLI 声明的客户端名称，仅供展示',
  `request_ip` varchar(64) DEFAULT NULL,
  `auth_status` varchar(16) NOT NULL COMMENT 'PENDING / APPROVED / DENIED / CONSUMED',
  `user_id` bigint DEFAULT NULL COMMENT '允许或拒绝该请求的用户',
  `expires_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `decided_at` datetime DEFAULT NULL,
  `consumed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_device_authorization_device_code` (`device_code_hash`),
  KEY `idx_sys_device_authorization_user_code` (`user_code`,`auth_status`),
  KEY `fk_sys_device_authorization_user` (`user_id`),
  CONSTRAINT `fk_sys_device_authorization_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_dict_item` (
  `id` bigint NOT NULL,
  `dict_type_id` bigint NOT NULL,
  `item_label` varchar(128) NOT NULL,
  `item_value` varchar(128) NOT NULL,
  `sort_no` int NOT NULL DEFAULT '0',
  `default_item` tinyint NOT NULL DEFAULT '0',
  `color` varchar(32) DEFAULT NULL,
  `extra_json` text,
  `status` varchar(16) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `label_i18n` json DEFAULT NULL COMMENT '标签多语言：{"en-US":"Enabled"}，缺失回退 item_label',
  `label_i18n_key` varchar(160) DEFAULT NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_dict_item_type_value` (`dict_type_id`,`item_value`),
  KEY `idx_sys_dict_item_type_status_sort` (`dict_type_id`,`status`,`sort_no`),
  CONSTRAINT `fk_sys_dict_item_type` FOREIGN KEY (`dict_type_id`) REFERENCES `sys_dict_type` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_online_session` (
  `id` varchar(36) NOT NULL,
  `user_id` bigint NOT NULL,
  `refresh_token_hash` varchar(64) NOT NULL,
  `session_status` varchar(20) NOT NULL,
  `session_source` varchar(16) NOT NULL DEFAULT 'WEB' COMMENT '会话来源：WEB 网页登录，CLI 设备授权',
  `client_name` varchar(64) DEFAULT NULL COMMENT 'CLI 发起授权时声明的客户端名称，仅供展示',
  `expires_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `last_seen_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_online_session_user_status` (`user_id`,`session_status`),
  CONSTRAINT `fk_sys_online_session_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project` (
  `id` bigint NOT NULL,
  `project_code` varchar(64) NOT NULL,
  `project_name` varchar(100) NOT NULL,
  `description` varchar(500) DEFAULT NULL,
  `status` varchar(20) NOT NULL,
  `built_in` tinyint NOT NULL DEFAULT '0',
  `created_by` bigint NOT NULL,
  `package_name` varchar(128) NOT NULL,
  `repository_url` varchar(512) DEFAULT NULL,
  `gitlab_project_id` varchar(256) DEFAULT NULL,
  `default_branch` varchar(64) NOT NULL DEFAULT 'main',
  `backend_url` varchar(512) DEFAULT NULL,
  `backend_label` varchar(100) DEFAULT NULL,
  `service_url` varchar(512) DEFAULT NULL COMMENT 'Gateway PROJECT 路由上游地址',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `health_check_enabled` tinyint NOT NULL DEFAULT '1' COMMENT '是否允许平台只读体检',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_code` (`project_code`),
  KEY `fk_sys_project_creator` (`created_by`),
  CONSTRAINT `fk_sys_project_creator` FOREIGN KEY (`created_by`) REFERENCES `sys_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_backend_service` (
  `project_id` bigint NOT NULL,
  `service_code` varchar(16) NOT NULL,
  `service_url` varchar(512) DEFAULT NULL,
  `status` varchar(16) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`service_code`),
  CONSTRAINT `fk_backend_service_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_config_handover` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `status` varchar(16) NOT NULL COMMENT 'SUCCESS / FAILED',
  `package_digest` varchar(64) DEFAULT NULL COMMENT '移交包内容摘要；命令行同步清单时为空',
  `source_host` varchar(255) DEFAULT NULL COMMENT '导出请求到达的主机名，仅供人核对',
  `source_exported_by` varchar(64) DEFAULT NULL,
  `source_exported_at` varchar(40) DEFAULT NULL COMMENT 'ISO-8601 UTC 原文',
  `plan_hash` varchar(128) NOT NULL,
  `git_commit` varchar(64) DEFAULT NULL,
  `applied_access` tinyint(1) NOT NULL DEFAULT '0' COMMENT '是否勾选导入授权',
  `change_count` int NOT NULL DEFAULT '0' COMMENT '实际执行的新增与更新条数',
  `delete_count` int NOT NULL DEFAULT '0' COMMENT '实际执行的删除条数',
  `failure_reason` varchar(500) DEFAULT NULL,
  `changes_json` longtext COMMENT '本次计划的全部条目，供查看明细',
  `keys_json` longtext COMMENT '本次移交包内全部条目的业务键，下次比对的基线；失败记录为空',
  `operator_id` bigint NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_project_config_handover_project` (`project_id`,`status`,`created_at`),
  CONSTRAINT `fk_sys_project_config_handover_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_data_resource` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `resource_code` varchar(128) NOT NULL COMMENT '资源码，约定同权限前缀 模块:资源',
  `resource_name` varchar(100) NOT NULL,
  `allowed_scopes` varchar(255) NOT NULL COMMENT '逗号分隔的范围类型，必含 SELF',
  `status` varchar(20) NOT NULL COMMENT 'ENABLED / DISABLED',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_data_resource` (`project_id`,`resource_code`),
  CONSTRAINT `fk_sys_project_data_resource_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_generation` (
  `task_no` varchar(64) NOT NULL,
  `project_id` bigint NOT NULL,
  `owner_user_id` bigint NOT NULL,
  `generation_mode` varchar(32) NOT NULL,
  `business_description` text,
  `ddl_content` longtext,
  `generation_status` varchar(20) NOT NULL,
  `template_version` varchar(32) NOT NULL,
  `blueprint_json` longtext,
  `ai_model` varchar(128) DEFAULT NULL,
  `design_summary` varchar(1000) DEFAULT NULL,
  `backend_artifact_name` varchar(255) DEFAULT NULL,
  `frontend_artifact_name` varchar(255) DEFAULT NULL,
  `backend_file_manifest` longtext,
  `frontend_file_manifest` longtext,
  `last_error` varchar(2000) DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`task_no`),
  UNIQUE KEY `uk_sys_project_generation_project` (`project_id`),
  KEY `idx_sys_project_generation_owner_time` (`owner_user_id`,`created_at`),
  KEY `idx_sys_project_generation_status` (`generation_status`,`updated_at`),
  CONSTRAINT `fk_sys_project_generation_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `sys_user` (`id`),
  CONSTRAINT `fk_sys_project_generation_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_member` (
  `project_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`user_id`),
  KEY `fk_sys_project_member_user` (`user_id`),
  CONSTRAINT `fk_sys_project_member_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`),
  CONSTRAINT `fk_sys_project_member_user` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_menu` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `parent_id` bigint DEFAULT NULL,
  `menu_name` varchar(100) NOT NULL,
  `menu_name_i18n` json DEFAULT NULL,
  `menu_name_key` varchar(160) DEFAULT NULL COMMENT '引用的国际化资源 key；非空即启用引用式国际化',
  `menu_type` varchar(20) NOT NULL,
  `route_path` varchar(256) DEFAULT NULL,
  `component_path` varchar(256) DEFAULT NULL,
  `permission_code` varchar(128) DEFAULT NULL,
  `icon` varchar(64) DEFAULT NULL COMMENT 'antd 图标组件名',
  `sort_no` int NOT NULL DEFAULT '0',
  `visible` tinyint NOT NULL DEFAULT '1',
  `status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_menu_permission` (`project_id`,`permission_code`),
  KEY `idx_sys_project_menu_parent_sort` (`project_id`,`parent_id`,`sort_no`),
  CONSTRAINT `fk_sys_project_menu_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_repository` (
  `project_id` bigint NOT NULL,
  `repository_type` varchar(16) NOT NULL,
  `gitlab_project_id` varchar(256) DEFAULT NULL,
  `web_url` varchar(512) DEFAULT NULL,
  `http_clone_url` varchar(512) DEFAULT NULL,
  `ssh_clone_url` varchar(512) DEFAULT NULL,
  `default_branch` varchar(64) NOT NULL DEFAULT 'main',
  `push_status` varchar(20) NOT NULL DEFAULT 'NOT_CONFIGURED',
  `commit_sha` varchar(64) DEFAULT NULL,
  `last_error` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`repository_type`),
  CONSTRAINT `fk_sys_project_repository_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_role` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `role_code` varchar(64) NOT NULL,
  `role_name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `status` varchar(20) NOT NULL,
  `built_in` tinyint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_role_code` (`project_id`,`role_code`),
  CONSTRAINT `fk_sys_project_role_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_role_data_scope` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `role_id` bigint NOT NULL,
  `resource_code` varchar(128) NOT NULL,
  `scope_type` varchar(32) NOT NULL COMMENT 'ALL / DEPT_AND_CHILD / DEPT / SELF / CUSTOM_DEPT',
  `include_child` tinyint NOT NULL DEFAULT '0' COMMENT '仅 CUSTOM_DEPT 使用',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_role_data_scope` (`role_id`,`resource_code`),
  KEY `idx_sys_project_role_data_scope_project` (`project_id`,`resource_code`),
  CONSTRAINT `fk_sys_project_role_data_scope_role` FOREIGN KEY (`role_id`) REFERENCES `sys_project_role` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_role_data_scope_dept` (
  `scope_id` bigint NOT NULL,
  `department_id` bigint NOT NULL,
  PRIMARY KEY (`scope_id`,`department_id`),
  KEY `idx_sys_project_role_data_scope_dept_department` (`department_id`),
  CONSTRAINT `fk_sys_project_role_data_scope_dept_department` FOREIGN KEY (`department_id`) REFERENCES `sys_department` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_sys_project_role_data_scope_dept_scope` FOREIGN KEY (`scope_id`) REFERENCES `sys_project_role_data_scope` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_role_menu` (
  `project_id` bigint NOT NULL,
  `role_id` bigint NOT NULL,
  `menu_id` bigint NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`role_id`,`menu_id`),
  KEY `fk_sys_project_role_menu_role` (`role_id`),
  KEY `fk_sys_project_role_menu_menu` (`menu_id`),
  CONSTRAINT `fk_sys_project_role_menu_menu` FOREIGN KEY (`menu_id`) REFERENCES `sys_project_menu` (`id`),
  CONSTRAINT `fk_sys_project_role_menu_role` FOREIGN KEY (`role_id`) REFERENCES `sys_project_role` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_storage` (
  `id` bigint NOT NULL COMMENT '也是业务记录里的 storage_ref',
  `project_id` bigint NOT NULL,
  `storage_name` varchar(32) NOT NULL,
  `account_id` bigint NOT NULL,
  `status` varchar(16) NOT NULL COMMENT '字典 storage.binding.status',
  `max_object_bytes` bigint NOT NULL,
  `allowed_content_types` varchar(2000) DEFAULT NULL COMMENT '逗号分隔；空表示不限制',
  `active_marker` tinyint GENERATED ALWAYS AS (if((`status` = _utf8mb4'ACTIVE'),1,NULL)) STORED COMMENT '只在 ACTIVE 时为 1，配合唯一键保证每个存储名至多一条生效绑定',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_project_storage_active` (`project_id`,`storage_name`,`active_marker`),
  KEY `idx_sys_project_storage_account` (`account_id`),
  CONSTRAINT `fk_sys_project_storage_account` FOREIGN KEY (`account_id`) REFERENCES `sys_storage_account` (`id`),
  CONSTRAINT `fk_sys_project_storage_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_scheduler_credential` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `token_hash` varchar(100) NOT NULL,
  `status` varchar(20) NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `service_code` varchar(16) NOT NULL DEFAULT 'default',
  `expires_at` datetime DEFAULT NULL,
  `last_used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_scheduler_credential_project_status` (`project_id`,`status`),
  KEY `idx_credential_project_service` (`project_id`,`service_code`,`status`),
  CONSTRAINT `fk_sys_scheduler_credential_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_scheduler_handler` (
  `project_id` bigint NOT NULL,
  `task_type` varchar(128) NOT NULL,
  `task_name` varchar(128) NOT NULL,
  `instance_id` varchar(128) NOT NULL,
  `last_seen_at` datetime NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`task_type`),
  KEY `idx_sys_scheduler_handler_seen` (`last_seen_at`),
  CONSTRAINT `fk_sys_scheduler_handler_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_scheduler_job` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `job_name` varchar(128) NOT NULL,
  `task_type` varchar(128) NOT NULL,
  `cron_expression` varchar(128) NOT NULL,
  `zone_id` varchar(64) NOT NULL,
  `request_payload` text,
  `enabled` tinyint NOT NULL DEFAULT '0',
  `deleted` tinyint NOT NULL DEFAULT '0',
  `config_version` bigint NOT NULL DEFAULT '1',
  `last_run_time` datetime DEFAULT NULL,
  `next_run_time` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_scheduler_job_project_enabled` (`project_id`,`enabled`),
  CONSTRAINT `fk_sys_scheduler_job_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_service_credential_scope` (
  `credential_id` bigint NOT NULL,
  `scope_code` varchar(64) NOT NULL,
  PRIMARY KEY (`credential_id`,`scope_code`),
  CONSTRAINT `fk_service_credential_scope` FOREIGN KEY (`credential_id`) REFERENCES `sys_scheduler_credential` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_capability` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `capability_code` varchar(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `version` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `manifest_json` json NOT NULL,
  `manifest_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `status` varchar(16) NOT NULL DEFAULT 'PENDING',
  `last_seen_at` datetime(3) DEFAULT NULL,
  `created_at` datetime(3) NOT NULL,
  `updated_at` datetime(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_agent_capability_code` (`project_id`,`capability_code`),
  CONSTRAINT `fk_sys_agent_capability_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`),
  CONSTRAINT `ck_sys_agent_capability_status` CHECK ((`status` in (_utf8mb4'PENDING',_utf8mb4'APPROVED',_utf8mb4'REVOKED')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_credential` (
  `project_id` bigint NOT NULL,
  `credential_id` varchar(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `status` varchar(16) NOT NULL,
  `created_at` datetime(3) NOT NULL,
  `updated_at` datetime(3) NOT NULL,
  PRIMARY KEY (`project_id`),
  UNIQUE KEY `uk_sys_agent_credential_id` (`credential_id`),
  CONSTRAINT `fk_sys_agent_credential_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`),
  CONSTRAINT `ck_sys_agent_credential_status` CHECK ((`status` in (_utf8mb4'ACTIVE',_utf8mb4'REVOKED')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_registry_event` (
  `id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `capability_code` varchar(160) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `manifest_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `operation` varchar(32) NOT NULL,
  `actor_user_id` bigint DEFAULT NULL,
  `credential_id` varchar(36) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL,
  `occurred_at` datetime(3) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sys_agent_registry_event_project_time` (`project_id`,`occurred_at`),
  CONSTRAINT `fk_sys_agent_registry_event_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_agent_remote_action` (
  `action_id` char(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `project_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `session_id` varchar(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `capability_code` varchar(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `capability_version` varchar(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `manifest_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `params_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `preconditions_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `preview_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `frozen_ciphertext` mediumtext NOT NULL,
  `token_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `confirmation_mode` varchar(16) NOT NULL,
  `status` varchar(16) NOT NULL,
  `expires_at` datetime(3) NOT NULL,
  `started_at` datetime(3) DEFAULT NULL,
  `finished_at` datetime(3) DEFAULT NULL,
  `result_ciphertext` mediumtext,
  `reason_code` varchar(64) DEFAULT NULL,
  `revision` int NOT NULL DEFAULT '0',
  `created_at` datetime(3) NOT NULL,
  `updated_at` datetime(3) NOT NULL,
  PRIMARY KEY (`action_id`),
  KEY `idx_sys_agent_remote_action_owner` (`user_id`,`session_id`,`status`,`expires_at`),
  KEY `idx_sys_agent_remote_action_project` (`project_id`,`created_at`),
  CONSTRAINT `fk_sys_agent_remote_action_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`),
  CONSTRAINT `ck_sys_agent_remote_action_confirmation` CHECK ((`confirmation_mode` in (_utf8mb4'REQUIRED',_utf8mb4'STRONG'))),
  CONSTRAINT `ck_sys_agent_remote_action_status` CHECK ((`status` in (_utf8mb4'PENDING',_utf8mb4'EXECUTING',_utf8mb4'SUCCEEDED',_utf8mb4'REJECTED',_utf8mb4'FAILED',_utf8mb4'UNKNOWN',_utf8mb4'CANCELLED',_utf8mb4'EXPIRED')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_codegen_task` (
  `task_no` varchar(64) NOT NULL,
  `project_id` bigint NOT NULL,
  `owner_user_id` bigint NOT NULL,
  `module_code` varchar(64) NOT NULL,
  `module_name` varchar(100) NOT NULL,
  `permission_prefix` varchar(128) NOT NULL,
  `ddl_content` mediumtext NOT NULL,
  `status` varchar(20) NOT NULL,
  `artifact_name` varchar(128) NOT NULL,
  `file_manifest` text NOT NULL,
  `generation_mode` varchar(32) NOT NULL DEFAULT 'DETERMINISTIC',
  `ai_model` varchar(128) DEFAULT NULL,
  `design_summary` varchar(1000) DEFAULT NULL,
  `source_branch` varchar(128) DEFAULT NULL,
  `mr_url` varchar(512) DEFAULT NULL,
  `last_error` varchar(1000) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`task_no`),
  KEY `idx_sys_codegen_owner_time` (`owner_user_id`,`created_at`),
  KEY `idx_sys_codegen_project_time` (`project_id`,`created_at`),
  CONSTRAINT `fk_sys_codegen_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `sys_user` (`id`),
  CONSTRAINT `fk_sys_codegen_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_project_member_role` (
  `project_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `role_id` bigint NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`project_id`,`user_id`,`role_id`),
  KEY `fk_sys_project_member_role_role` (`role_id`),
  CONSTRAINT `fk_sys_project_member_role_member` FOREIGN KEY (`project_id`, `user_id`) REFERENCES `sys_project_member` (`project_id`, `user_id`),
  CONSTRAINT `fk_sys_project_member_role_role` FOREIGN KEY (`role_id`) REFERENCES `sys_project_role` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE `sys_scheduler_execution` (
  `id` bigint NOT NULL,
  `job_id` bigint NOT NULL,
  `project_id` bigint NOT NULL,
  `config_version` bigint NOT NULL,
  `scheduled_at` datetime(3) NOT NULL,
  `instance_id` varchar(128) NOT NULL,
  `status` varchar(20) NOT NULL,
  `lease_until` datetime DEFAULT NULL,
  `message` varchar(1000) DEFAULT NULL,
  `started_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sys_scheduler_execution_fire` (`job_id`,`scheduled_at`),
  KEY `idx_sys_scheduler_execution_project_time` (`project_id`,`created_at`),
  KEY `idx_sys_scheduler_execution_lease` (`status`,`lease_until`),
  CONSTRAINT `fk_sys_scheduler_execution_job` FOREIGN KEY (`job_id`) REFERENCES `sys_scheduler_job` (`id`),
  CONSTRAINT `fk_sys_scheduler_execution_project` FOREIGN KEY (`project_id`) REFERENCES `sys_project` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `sys_ai_model_route` (`id`, `plan_model_id`, `answer_model_id`) VALUES
(1, NULL, NULL);
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(8001, 0, 'app.admin.brand', 'Kaiwu', NULL, 'STRING', 0, 'ENABLED', '业务管理端默认品牌名称', 10, '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(8002, 0, 'app.admin.label', '业务后台', NULL, 'STRING', 0, 'ENABLED', '业务管理端默认应用名称', 20, '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(8003, 0, 'common.table.page_size', '20', NULL, 'NUMBER', 0, 'ENABLED', '列表默认每页条数，业务端使用前应限制在 5-200', 30, '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(9200000000000007500, 0, 'platform.notification.poll_seconds', '60', NULL, 'NUMBER', 0, 'ENABLED', '消息铃铛刷新间隔（秒，15-600）；在线时约一分钟内刷新', 40, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(9200000000000007501, 0, 'platform.factory.poll_seconds', '3', NULL, 'NUMBER', 0, 'ENABLED', '项目工厂运行中任务刷新间隔（秒，2-60）；在线时约一分钟内刷新', 50, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_app_config` (`id`, `scope_id`, `config_key`, `config_value`, `value_i18n_key`, `value_type`, `secret`, `status`, `description`, `sort_no`, `created_at`, `updated_at`) VALUES
(9200000000000007502, 0, 'platform.home.poll_seconds', '5', NULL, 'NUMBER', 0, 'ENABLED', '工作台运行中任务刷新间隔（秒，2-60）；在线时约一分钟内刷新', 60, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8101, 0, 'common.status', '通用启停状态', 'dictType.common.status', 0, 0, 'ENABLED', '平台和生成业务可复用的启停状态', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8102, 0, 'common.boolean_enabled', '是否启用', 'dictType.common.boolean_enabled', 0, 0, 'ENABLED', '布尔启用选项', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8301, 0, 'user.status', '平台用户状态', 'dictType.user.status', 0, 0, 'ENABLED', '平台身份账号是否可用', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8302, 0, 'project.status', '业务项目状态', 'dictType.project.status', 0, 0, 'ENABLED', '业务项目生命周期：启用、停用、归档', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8303, 0, 'project.member.status', '项目成员状态', 'dictType.project.member.status', 0, 0, 'ENABLED', '成员在项目内是否有效', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8304, 0, 'platform.menu.type', '平台菜单类型', 'dictType.platform.menu.type', 0, 0, 'ENABLED', '菜单节点类型：目录、菜单、按钮', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8305, 0, 'config.value.type', '配置值类型', 'dictType.config.value.type', 0, 0, 'ENABLED', '应用配置的值类型：STRING/NUMBER/BOOLEAN/JSON', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8306, 0, 'ai.test.status', '大模型连通测试状态', 'dictType.ai.test.status', 0, 0, 'ENABLED', '大模型 provider 最近一次连通测试结果', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8308, 0, 'project.generation.mode', '项目生成方式', 'dictType.project.generation.mode', 0, 0, 'ENABLED', '项目工厂生成方式：AI 项目 / 基础空脚手架', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8309, 0, 'project.generation.status', '项目生成状态', 'dictType.project.generation.status', 0, 0, 'ENABLED', '项目生成任务生命周期', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8313, 0, 'notification.type', '站内信分类', 'dictType.notification.type', 0, 0, 'ENABLED', '站内信来源分类：系统、项目、任务', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8314, 0, 'security.login.status', '登录日志状态', 'dictType.security.login.status', 0, 0, 'ENABLED', '登录审计结果；当前后端只写入 SUCCESS 与 FAILED', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8315, 0, 'security.session.status', '在线会话状态', 'dictType.security.session.status', 0, 0, 'ENABLED', '在线会话生命周期：在线、已撤销', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8316, 0, 'scheduler.execution.status', '定时任务执行状态', 'dictType.scheduler.execution.status', 0, 0, 'ENABLED', '项目定时任务执行生命周期', '2026-11-12 16:07:22', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8317, 0, 'platform.locale', '平台语言', 'dictType.platform.locale', 0, 0, 'ENABLED', '平台语言唯一目录；约束运行期所有多语言 JSON 的 locale key', '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8321, 0, 'common.tag_color', '标签颜色', 'dictType.common.tag_color', 0, 0, 'ENABLED', '字典项 Tag 的展示颜色；状态类优先用语义色，类别类可用 purple/cyan', '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8331, 0, 'security.audit.module', '审计模块', 'dictType.security.audit.module', 0, 0, 'ENABLED', '操作审计日志的来源模块；取值为 AuditService.recordOperation 的 module 实参', '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8340, 0, 'agent.capability.status', 'Agent 能力审批状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8341, 0, 'agent.capability.connection', 'Agent 能力连接状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8342, 0, 'agent.action.status', 'Agent 操作状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(8343, 0, 'security.session.source', '会话来源', 'dictType.security.session.source', 0, 0, 'ENABLED', '在线会话的签发方式；取值为 sys_online_session.session_source', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000004300, 0, 'agent.remote_action.status', 'Agent 子项目操作状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000007000, 0, 'storage.provider.type', '对象存储类型', 'dictType.storage.provider.type', 0, 0, 'ENABLED', '决定 System 使用哪种 STS 签发器，以及业务项目的访问风格', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000007001, 0, 'storage.binding.status', '项目存储绑定状态', 'dictType.storage.binding.status', 0, 0, 'ENABLED', 'ACTIVE 可读写；READ_ONLY 只签发读权限，用于切换存储后读取历史文件', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000007250, 0, 'project.handover.status', '配置移交记录状态', 'dictType.project.handover.status', 0, 0, 'ENABLED', '记录一次配置移交的结果', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000007253, 0, 'project.handover.action', '配置移交动作', 'dictType.project.handover.action', 0, 0, 'ENABLED', '计划里每个条目的处理方式', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000007258, 0, 'project.handover.resource', '配置移交资源类型', 'dictType.project.handover.resource', 0, 0, 'ENABLED', '计划条目所属的资源类型', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_dict_type` (`id`, `scope_id`, `dict_code`, `dict_name`, `dict_name_key`, `inherit_global`, `sort_no`, `status`, `description`, `created_at`, `updated_at`) VALUES
(9200000000000013000, 0, 'project.data_scope.type', '数据范围类型', 'dictType.project.data_scope.type', 0, 0, 'ENABLED', '角色在受控资源上的可见范围', '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_catalog_revision` (`catalog_code`, `revision`, `updated_at`) VALUES
('platform', 98, '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(7170, 0, 'storage.account.bucketHint', '在对象存储控制台的 Bucket 列表里复制名称，只填名称，不带域名。', '{"en-US": "Copy the name from the bucket list in your object storage console; the name only, without a domain.", "ja-JP": "コンソールのバケット一覧からバケット名のみをコピーします（ドメインは不要）。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(7171, 0, 'storage.account.stsEndpointHint', '阿里云无需查询，按区域拼写：https://sts.<区域>.aliyuncs.com；S3 兼容填该服务的 STS 接口地址。', '{"en-US": "For Alibaba Cloud, build it from the region: https://sts.<region>.aliyuncs.com. For S3-compatible services, use the service STS endpoint.", "ja-JP": "Alibaba Cloud ではリージョンから https://sts.<リージョン>.aliyuncs.com と組み立てます。S3 互換では当該サービスの STS エンドポイントを指定します。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(7172, 0, 'storage.account.regionHint', '填 Bucket 概览里的地域 ID（如 cn-hangzhou），不是中文名；须与存储地址里的区域一致。', '{"en-US": "Use the region ID from the bucket overview (e.g. cn-hangzhou), not the display name; it must match the region in the endpoint.", "ja-JP": "バケット概要のリージョン ID（例：cn-hangzhou）を入力します。表示名ではなく、エンドポイントのリージョンと一致させてください。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(7173, 0, 'storage.account.roleArnHint', '在 RAM 控制台 → 角色 → 基本信息里复制 ARN，形如 acs:ram::账号ID:role/角色名。阿里云必填，S3 兼容可留空。', '{"en-US": "Copy the ARN from RAM console → Roles → Basic information, e.g. acs:ram::<account-id>:role/<role-name>. Required for Alibaba Cloud; optional for S3-compatible services.", "ja-JP": "RAM コンソール → ロール → 基本情報から ARN（例：acs:ram::アカウントID:role/ロール名）をコピーします。Alibaba Cloud では必須、S3 互換では省略できます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000001, 0, 'ai.apiKey', 'API Key（{state}）', '{"en-US": "API key ({state})"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000002, 0, 'ai.apiKeyPlaceholder', '留空保留原值；无鉴权的内网模型可不填', '{"en-US": "Leave empty to keep the current value; optional for internal providers without authentication"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000003, 0, 'ai.apiKeyPlain', 'API Key', '{"en-US": "API key"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000004, 0, 'ai.baseUrl', 'API Base URL', '{"en-US": "API Base URL"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000005, 0, 'ai.baseUrlPlaceholder', 'https://api.openai.com/v1', '{"en-US": "https://api.openai.com/v1"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000006, 0, 'ai.clearApiKey', '清除已保存的 API Key', '{"en-US": "Clear saved API key"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000007, 0, 'ai.configured', '已配置', '{"en-US": "Configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000008, 0, 'ai.currentModel', '当前模型', '{"en-US": "Current model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000010, 0, 'ai.model', '模型', '{"en-US": "Model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000011, 0, 'ai.modelPlaceholder', '例如：gpt-4.1-mini', '{"en-US": "For example, gpt-4.1-mini"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000012, 0, 'ai.name', '配置名称', '{"en-US": "Configuration name"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000013, 0, 'ai.namePlaceholder', '例如：OpenAI、DeepSeek、本地兼容服务', '{"en-US": "For example, OpenAI, DeepSeek, or a local compatible service"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000014, 0, 'ai.notConfigured', '未配置', '{"en-US": "Not configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000015, 0, 'ai.provider', 'Provider', '{"en-US": "Provider"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000016, 0, 'ai.saved', '大模型配置已加密保存', '{"en-US": "AI provider configuration saved securely"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000017, 0, 'ai.subtitle', '只管理 OpenAI-compatible Provider；密钥加密保存且永不回传', '{"en-US": "Manage an OpenAI-compatible provider. Secrets are encrypted and never returned."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000018, 0, 'ai.temperature', 'Temperature', '{"en-US": "Temperature"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000019, 0, 'ai.testFailed', '连接测试失败，详情见运行状态', '{"en-US": "Connection test failed. See Runtime status for details."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000020, 0, 'ai.testSaved', '测试已保存配置', '{"en-US": "Test saved configuration"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000021, 0, 'ai.testSuccess', '连接成功 · {latency} ms', '{"en-US": "Connected · {latency} ms"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000022, 0, 'ai.timeout', '请求超时（秒）', '{"en-US": "Request timeout (seconds)"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000023, 0, 'ai.title', '大模型配置', '{"en-US": "AI provider"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000024, 0, 'ai.urlRule', '请输入完整 HTTP(S) URL', '{"en-US": "Enter a complete HTTP(S) URL"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000025, 0, 'api.auth.accountLocked', '登录失败次数过多，请 {minutes} 分钟后再试', '{"en-US": "Too many failed sign-in attempts. Try again in {minutes} minutes."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000026, 0, 'api.auth.invalidCredentials', '用户名或密码错误', '{"en-US": "Incorrect username or password"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000027, 0, 'api.auth.password.incorrect', '当前密码错误', '{"en-US": "The current password is incorrect"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000028, 0, 'api.auth.password.mismatch', '两次输入的新密码不一致', '{"en-US": "The new passwords do not match"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000029, 0, 'api.auth.password.tooLong', '新密码 UTF-8 编码后不能超过 72 字节', '{"en-US": "The new password cannot exceed 72 UTF-8 bytes"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000030, 0, 'api.auth.password.unchanged', '新密码不能与当前密码相同', '{"en-US": "The new password must differ from the current password"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000031, 0, 'api.auth.refreshInvalid', '刷新令牌无效或已过期', '{"en-US": "The refresh token is invalid or expired"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000032, 0, 'api.locale.unsupported', '暂不支持该语言', '{"en-US": "This language is not supported"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000033, 0, 'api.pagination.invalid', '分页参数超出允许范围', '{"en-US": "Pagination parameters are out of range"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000034, 0, 'api.project.notFound', '项目不存在', '{"en-US": "Project not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000035, 0, 'api.projectFactory.activeRequired', '只有启用项目可以生成', '{"en-US": "Only active projects can be generated"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000036, 0, 'api.projectFactory.adminRequired', '只有目标项目的有效项目管理员可以使用项目工厂', '{"en-US": "Only an active project administrator for the target project can use Project factory"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000037, 0, 'api.projectFactory.builtInForbidden', '内置 system 项目已有真实源码，不能通过项目工厂生成', '{"en-US": "The built-in system project already has real source and cannot be generated by Project factory"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000038, 0, 'api.user.cannotDisableSelf', '不能停用当前登录用户', '{"en-US": "You cannot disable the currently signed-in user"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000039, 0, 'api.user.changeOwnPassword', '请通过个人安全设置修改自己的密码', '{"en-US": "Change your own password in Profile security settings"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000040, 0, 'api.user.export.tooManyRows', '导出结果超过 {limit} 条，请先用用户名或显示名筛选后再导出', '{"en-US": "The export exceeds {limit} rows. Filter by username or display name first."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000041, 0, 'api.user.import.displayNameInvalid', '姓名不能为空且最多 100 字', '{"en-US": "Display name is required and cannot exceed 100 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000042, 0, 'api.user.import.failed', '导入失败', '{"en-US": "Import failed"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000043, 0, 'api.user.import.fileSize', 'Excel 文件大小必须在 1B 到 10MB 之间', '{"en-US": "The Excel file must be between 1 byte and 10 MB"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000044, 0, 'api.user.import.invalidWorkbook', '无法读取 Excel，请使用平台模板', '{"en-US": "Cannot read the Excel workbook. Use the platform template."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000045, 0, 'api.user.import.passwordInvalid', '初始密码长度必须为 12-72 位', '{"en-US": "The initial password must contain 12 to 72 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000046, 0, 'api.user.import.statusInvalid', '状态只能是 ENABLED 或 DISABLED', '{"en-US": "Status must be ENABLED or DISABLED"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000047, 0, 'api.user.import.tooManyRows', '单次最多导入 5000 行', '{"en-US": "A single import can contain at most 5,000 rows"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000048, 0, 'api.user.import.unknownDepartment', '存在未知部门编码', '{"en-US": "One or more department codes are unknown"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000049, 0, 'api.user.import.usernameInvalid', '用户名格式不正确', '{"en-US": "The username format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000050, 0, 'api.user.notFound', '用户不存在', '{"en-US": "User not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000051, 0, 'api.user.usernameExists', '用户名已存在', '{"en-US": "The username already exists"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000052, 0, 'api.user.workbook.generateFailed', '生成用户表格失败', '{"en-US": "Failed to generate the user workbook"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000053, 0, 'api.validation.failed', '请求参数错误', '{"en-US": "Invalid request parameters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000054, 0, 'client.catalogFailed', '语言资源加载失败，已保留当前界面语言', '{"en-US": "Language resources failed to load; the current language was kept"}', 'client', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000055, 0, 'client.connectionFailed', '无法连接服务，请确认 Kaiwu 网关已启动', '{"en-US": "Cannot connect to the service. Confirm that the Kaiwu Gateway is running."}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000056, 0, 'client.downloadFailed', '下载失败（HTTP {status}）', '{"en-US": "Download failed (HTTP {status})"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000057, 0, 'client.loginFailed', '登录失败（HTTP {status}）', '{"en-US": "Sign-in failed (HTTP {status})"}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000058, 0, 'client.refreshFailed', '刷新失败（HTTP {status}）', '{"en-US": "Token refresh failed (HTTP {status})"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000059, 0, 'client.refreshInvalid', '刷新令牌无效或已过期', '{"en-US": "The refresh token is invalid or expired"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000060, 0, 'client.refreshMissing', '缺少刷新令牌', '{"en-US": "Refresh token is missing"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000061, 0, 'client.requestFailed', '请求失败（HTTP {status}）', '{"en-US": "Request failed (HTTP {status})"}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000062, 0, 'client.serviceUnavailable', '服务暂时不可用，请检查 Gateway/Nacos 配置后重试', '{"en-US": "The service is temporarily unavailable. Check Gateway/Nacos and try again."}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000063, 0, 'client.sessionExpired', '会话已失效', '{"en-US": "Your session has expired"}', 'client', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000064, 0, 'common.clearSelection', '取消选择', '{"en-US": "Clear selection"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000065, 0, 'common.delete', '删除', '{"en-US": "Delete"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000066, 0, 'common.deleted', '已删除', '{"en-US": "Deleted"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000067, 0, 'common.disable', '停用', '{"en-US": "Disable"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000068, 0, 'common.edit', '编辑', '{"en-US": "Edit"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000069, 0, 'common.enable', '启用', '{"en-US": "Enable"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000070, 0, 'common.language', '语言', '{"en-US": "Language"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000071, 0, 'common.language.enUS', 'English', '{"en-US": "English"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000072, 0, 'common.language.updateFailed', '保存语言设置失败', '{"en-US": "Failed to save language preference"}', 'common', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000073, 0, 'common.language.updated', '语言设置已保存', '{"en-US": "Language preference saved"}', 'common', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000074, 0, 'common.language.zhCN', '简体中文', '{"en-US": "简体中文"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000075, 0, 'common.operationFailed', '操作失败', '{"en-US": "Operation failed"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000076, 0, 'common.refresh', '刷新', '{"en-US": "Refresh"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000077, 0, 'common.saved', '已保存', '{"en-US": "Saved"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000078, 0, 'common.selectedCount', '已选择 {count} 项', '{"en-US": "{count} selected"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000080, 0, 'config.recentTest', '最近测试', '{"en-US": "Latest test"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000081, 0, 'config.runtime', '运行状态', '{"en-US": "Runtime status"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000082, 0, 'config.testTime', '测试时间', '{"en-US": "Test time"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000083, 0, 'configs.actions', '操作', '{"en-US": "Actions"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000084, 0, 'configs.create', '新增配置', '{"en-US": "Create configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000085, 0, 'configs.createTitle', '新增配置', '{"en-US": "Create configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000086, 0, 'configs.delete', '删除', '{"en-US": "Delete"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000087, 0, 'configs.deleteConfirm', '确认删除该配置？', '{"en-US": "Delete this configuration?"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000088, 0, 'configs.deleted', '配置已删除', '{"en-US": "Configuration deleted"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000089, 0, 'configs.description', '说明', '{"en-US": "Description"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000090, 0, 'configs.edit', '编辑', '{"en-US": "Edit"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000091, 0, 'configs.editTitle', '编辑配置', '{"en-US": "Edit configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000092, 0, 'configs.empty', '当前范围暂无配置，点击右上角新增', '{"en-US": "No configuration in this scope. Use Create in the upper right."}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000093, 0, 'configs.encrypted', '已加密', '{"en-US": "Encrypted"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000094, 0, 'configs.key', '配置键', '{"en-US": "Key"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000095, 0, 'configs.keyRule', '配置键格式不正确', '{"en-US": "The key format is invalid"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000096, 0, 'configs.saved', '配置已保存', '{"en-US": "Configuration saved"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000097, 0, 'configs.secret', '敏感配置', '{"en-US": "Secret"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000098, 0, 'configs.secretPlaceholder', '保留 ****** 或留空表示不修改密文', '{"en-US": "Keep ****** or leave empty to retain the encrypted value"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000099, 0, 'configs.secretTooltip', 'AES-GCM 加密保存，且不会通过 effective config API 下发', '{"en-US": "Encrypted with AES-GCM and never returned by the effective configuration API"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000100, 0, 'configs.sort', '排序', '{"en-US": "Sort order"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000101, 0, 'configs.status', '状态', '{"en-US": "Status"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000102, 0, 'configs.subtitle', '全局默认可被项目同名配置覆盖，敏感配置永不下发业务前端', '{"en-US": "Project settings override global defaults with the same key. Secrets are never sent to business frontends."}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000103, 0, 'configs.title', '参数配置', '{"en-US": "Configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000104, 0, 'configs.value', '配置值', '{"en-US": "Value"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000105, 0, 'configs.valueType', '值类型', '{"en-US": "Value type"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000106, 0, 'dict.ai.test.status.FAILED', '失败', '{"en-US": "Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000107, 0, 'dict.ai.test.status.SUCCESS', '成功', '{"en-US": "Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000108, 0, 'dict.common.boolean_enabled.false', '否', '{"en-US": "No"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000109, 0, 'dict.common.boolean_enabled.true', '是', '{"en-US": "Yes"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000110, 0, 'dict.common.status.DISABLED', '停用', '{"en-US": "Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000111, 0, 'dict.common.status.ENABLED', '启用', '{"en-US": "Enabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000112, 0, 'dict.config.value.type.BOOLEAN', '布尔值', '{"en-US": "Boolean"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000113, 0, 'dict.config.value.type.JSON', 'JSON', '{"en-US": "JSON"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000114, 0, 'dict.config.value.type.NUMBER', '数值', '{"en-US": "Number"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000115, 0, 'dict.config.value.type.STRING', '文本', '{"en-US": "Text"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000118, 0, 'dict.notification.type.PROJECT', '项目消息', '{"en-US": "Project message"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000119, 0, 'dict.notification.type.SYSTEM', '系统通知', '{"en-US": "System notification"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000120, 0, 'dict.notification.type.TASK', '任务提醒', '{"en-US": "Task reminder"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000121, 0, 'dict.platform.menu.type.BUTTON', '按钮', '{"en-US": "Button"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000122, 0, 'dict.platform.menu.type.DIR', '目录', '{"en-US": "Directory"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000123, 0, 'dict.platform.menu.type.DIRECTORY', '目录', '{"en-US": "Directory"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000124, 0, 'dict.platform.menu.type.MENU', '菜单', '{"en-US": "Menu"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000125, 0, 'dict.project.generation.mode.AI_PROJECT', 'AI 生成项目', '{"en-US": "AI-generated project"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000126, 0, 'dict.project.generation.mode.BASIC_SCAFFOLD', '基础空脚手架', '{"en-US": "Basic empty scaffold"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000127, 0, 'dict.project.generation.status.FAILED', '生成失败', '{"en-US": "Generation failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000128, 0, 'dict.project.generation.status.PENDING', '等待生成', '{"en-US": "Waiting"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000129, 0, 'dict.project.generation.status.RUNNING', '正在生成', '{"en-US": "Generating"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000130, 0, 'dict.project.generation.status.SUCCESS', '生成成功', '{"en-US": "Generated"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000131, 0, 'dict.project.member.status.ACTIVE', '有效', '{"en-US": "Active"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000132, 0, 'dict.project.member.status.DISABLED', '停用', '{"en-US": "Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000137, 0, 'dict.project.status.ACTIVE', '已启用', '{"en-US": "Active"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000138, 0, 'dict.project.status.ARCHIVED', '已归档', '{"en-US": "Archived"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000139, 0, 'dict.project.status.DISABLED', '已停用', '{"en-US": "Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000140, 0, 'dict.scheduler.execution.status.FAILED', '失败', '{"en-US": "Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000141, 0, 'dict.scheduler.execution.status.RUNNING', '执行中', '{"en-US": "Running"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000142, 0, 'dict.scheduler.execution.status.SUCCESS', '成功', '{"en-US": "Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000143, 0, 'dict.security.login.status.FAILED', '失败', '{"en-US": "Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000144, 0, 'dict.security.login.status.LOGOUT', '退出', '{"en-US": "Signed out"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000145, 0, 'dict.security.login.status.SUCCESS', '成功', '{"en-US": "Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000146, 0, 'dict.security.session.status.ONLINE', '在线', '{"en-US": "Online"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000147, 0, 'dict.security.session.status.REVOKED', '已撤销', '{"en-US": "Revoked"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000148, 0, 'dict.user.status.DISABLED', '停用', '{"en-US": "Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000149, 0, 'dict.user.status.ENABLED', '启用', '{"en-US": "Enabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000150, 0, 'dicts.actions', '操作', '{"en-US": "Actions"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000151, 0, 'dicts.code', '字典编码', '{"en-US": "Dictionary code"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000152, 0, 'dicts.codeRule', '字典编码格式不正确', '{"en-US": "The dictionary code format is invalid"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000153, 0, 'dicts.color', '颜色', '{"en-US": "Color"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000154, 0, 'dicts.create', '新增字典', '{"en-US": "Create dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000155, 0, 'dicts.createItem', '新增字典项', '{"en-US": "Create entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000156, 0, 'dicts.createItemTitle', '新增字典项', '{"en-US": "Create dictionary entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000157, 0, 'dicts.createTitle', '新增字典', '{"en-US": "Create dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000158, 0, 'dicts.default', '默认', '{"en-US": "Default"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000159, 0, 'dicts.defaultItem', '默认项', '{"en-US": "Default entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000160, 0, 'dicts.delete', '删除', '{"en-US": "Delete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000161, 0, 'dicts.deleteItemConfirm', '确认删除该字典项？', '{"en-US": "Delete this dictionary entry?"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000162, 0, 'dicts.deleteTypeConfirm', '删除字典及全部字典项？', '{"en-US": "Delete this dictionary and all its entries?"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000163, 0, 'dicts.deleted', '字典已删除', '{"en-US": "Dictionary deleted"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000164, 0, 'dicts.description', '说明', '{"en-US": "Description"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000165, 0, 'dicts.dictionary', '字典', '{"en-US": "Dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000166, 0, 'dicts.displayColor', '展示颜色', '{"en-US": "Display color"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000167, 0, 'dicts.displayLabel', '显示标签', '{"en-US": "Display label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000168, 0, 'dicts.edit', '编辑', '{"en-US": "Edit"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000169, 0, 'dicts.editItemTitle', '编辑字典项', '{"en-US": "Edit dictionary entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000170, 0, 'dicts.editTitle', '编辑字典', '{"en-US": "Edit dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000171, 0, 'dicts.extraJson', '扩展 JSON', '{"en-US": "Extra JSON"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000172, 0, 'dicts.extraJsonPlaceholder', '例如 {"icon":"check"}', '{"en-US": "For example, {\\"icon\\":\\"check\\"}"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000173, 0, 'dicts.independent', '项目独立，不继承全局', '{"en-US": "Project-only; does not inherit global entries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000174, 0, 'dicts.inherit', '继承全局，同值由项目覆盖', '{"en-US": "Inherits global entries; project values override matches"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000175, 0, 'dicts.inheritGlobal', '继承全局字典', '{"en-US": "Inherit global dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000176, 0, 'dicts.itemDeleted', '字典项已删除', '{"en-US": "Dictionary entry deleted"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000177, 0, 'dicts.itemSaved', '字典项已保存', '{"en-US": "Dictionary entry saved"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000178, 0, 'dicts.label', '标签', '{"en-US": "Label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000179, 0, 'dicts.labelEnUs', '英文标签', '{"en-US": "English label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000180, 0, 'dicts.labelEnUsTip', '英文界面下显示的标签；留空则显示上面的原文', '{"en-US": "Shown when the UI is in English. Leave empty to fall back to the text above."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000181, 0, 'dicts.loadFailed', '加载字典失败', '{"en-US": "Failed to load dictionaries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000182, 0, 'dicts.loadItemsFailed', '加载字典项失败', '{"en-US": "Failed to load dictionary entries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000183, 0, 'dicts.loadLocalesFailed', '加载已启用语言失败', '{"en-US": "Failed to load enabled languages"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000184, 0, 'dicts.name', '字典名称', '{"en-US": "Dictionary name"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000185, 0, 'dicts.saved', '字典已保存', '{"en-US": "Dictionary saved"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000186, 0, 'dicts.selectFirst', '请先新增或选择字典', '{"en-US": "Create or select a dictionary first"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000187, 0, 'dicts.sort', '排序', '{"en-US": "Sort"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000188, 0, 'dicts.status', '状态', '{"en-US": "Status"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000189, 0, 'dicts.subtitle', '项目字典可继承全局字典，同值项目项覆盖全局项', '{"en-US": "Project dictionaries can inherit global entries; project entries override equal global values."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000190, 0, 'dicts.title', '字典管理', '{"en-US": "Dictionaries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000191, 0, 'dicts.translation', '{locale} 标签', '{"en-US": "{locale} label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000192, 0, 'dicts.translationTip', '已启用语言中的译文；留空时显示默认标签。新增语言后会自动出现对应输入项。', '{"en-US": "A translation for an enabled language. Leave empty to use the default label; new languages appear here automatically."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000193, 0, 'dicts.value', '字典值', '{"en-US": "Value"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000194, 0, 'factory.action.backendZip', '后端 ZIP', '{"en-US": "Backend ZIP"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000195, 0, 'factory.action.details', '详情', '{"en-US": "Details"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000196, 0, 'factory.action.frontendZip', '前端 ZIP', '{"en-US": "Frontend ZIP"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000198, 0, 'factory.action.retry', '修改后重试', '{"en-US": "Edit and retry"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000199, 0, 'factory.column.actions', '操作', '{"en-US": "Actions"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000200, 0, 'factory.column.createdAt', '创建时间', '{"en-US": "Created at"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000201, 0, 'factory.column.failure', '失败原因', '{"en-US": "Failure reason"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000202, 0, 'factory.column.mode', '生成方式', '{"en-US": "Generation mode"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000203, 0, 'factory.column.project', '项目', '{"en-US": "Project"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000204, 0, 'factory.column.readiness', '交付就绪度', '{"en-US": "Delivery readiness"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000206, 0, 'factory.column.status', '生成状态', '{"en-US": "Generation status"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000207, 0, 'factory.description', '在脚手架约束内一次生成后端与前端仓库；两份 ZIP 始终可下载，GitLab 只向项目配置分支做一次初始提交，后续 CI/CD 与分支策略由业务仓库接管。', '{"en-US": "Generate backend and frontend repositories once within the scaffold boundary. Both ZIP files remain downloadable. GitLab receives one initial commit on the configured project branch; the business repositories own later CI/CD and branch strategy.", "ja-JP": "スキャフォールドの制約内でバックエンドとフロントエンドのリポジトリを一度だけ生成します。2 つの ZIP は常にダウンロードでき、GitLab への初回コミット後の CI/CD とブランチ戦略は業務リポジトリが管理します。"}', 'factory', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000208, 0, 'factory.empty', '还没有生成任务；请在项目管理里开通项目，或对已有项目使用「生成第一版」', '{"en-US": "No generation tasks yet. Set up a project or use Generate first version for an existing project."}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000209, 0, 'factory.failure.unknown', '未记录具体失败原因', '{"en-US": "No specific failure reason was recorded"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000211, 0, 'factory.myTasks', '我的项目生成', '{"en-US": "My generation tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000212, 0, 'factory.newProject', '开通新项目', '{"en-US": "Set up a project"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000213, 0, 'factory.preview.backendFiles', '后端文件 · {count}', '{"en-US": "Backend files · {count}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000214, 0, 'factory.preview.close', '关闭', '{"en-US": "Close"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000215, 0, 'factory.preview.completedAt', '完成时间', '{"en-US": "Completed at"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000216, 0, 'factory.preview.error', '任务错误', '{"en-US": "Task error"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000217, 0, 'factory.preview.frontendFiles', '前端文件 · {count}', '{"en-US": "Frontend files · {count}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000218, 0, 'factory.preview.model', 'AI 模型', '{"en-US": "AI model"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000219, 0, 'factory.preview.noFiles', '暂无生成文件', '{"en-US": "No generated files"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000220, 0, 'factory.preview.overview', '概览', '{"en-US": "Overview"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000221, 0, 'factory.preview.projectTitle', '生成详情：{project}', '{"en-US": "Generation details: {project}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000222, 0, 'factory.preview.summary', '设计摘要', '{"en-US": "Design summary"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000223, 0, 'factory.preview.taskNo', '任务号', '{"en-US": "Task number"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000224, 0, 'factory.preview.template', '脚手架版本', '{"en-US": "Scaffold version"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000225, 0, 'factory.preview.title', '生成详情', '{"en-US": "Generation details"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000238, 0, 'factory.readiness.tooltip', '生成成功、后端制品、前端制品、后端推送、前端推送', '{"en-US": "Generation, backend artifact, frontend artifact, backend push, frontend push"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000239, 0, 'factory.refresh', '刷新', '{"en-US": "Refresh"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000244, 0, 'factory.retry.basic', '基础脚手架没有业务描述和 DDL，可直接重新生成', '{"en-US": "Basic scaffolds have no business description or DDL and can be regenerated directly"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000247, 0, 'factory.retry.ddl', 'MySQL DDL（可选）', '{"en-US": "MySQL DDL (optional)"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000248, 0, 'factory.retry.ddlExtra', '支持 CREATE TABLE 以及对应的独立 CREATE INDEX 语句', '{"en-US": "Supports CREATE TABLE and corresponding standalone CREATE INDEX statements"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000249, 0, 'factory.retry.description', '可修改业务描述和 DDL 后重新生成；原失败任务会保留任务号并使用本次输入。', '{"en-US": "Edit the business description and DDL before regenerating. The failed task keeps its task number and uses the updated input."}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000250, 0, 'factory.retry.lastFailed', '上次生成失败', '{"en-US": "The previous generation failed"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000251, 0, 'factory.retry.submit', '保存输入并重新生成', '{"en-US": "Save input and regenerate"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000252, 0, 'factory.retry.success', '修改后的任务已重新排队', '{"en-US": "The updated task has been queued again"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000253, 0, 'factory.retry.title', '修改后重试：{project}', '{"en-US": "Edit and retry: {project}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000254, 0, 'factory.stat.failed', '失败', '{"en-US": "Failed"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000255, 0, 'factory.stat.noFailure', '暂无失败', '{"en-US": "No failures"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000257, 0, 'factory.stat.ready', '全部已就绪', '{"en-US": "Everything is ready"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000258, 0, 'factory.stat.retry', '可在下方重试', '{"en-US": "Retry from the list below"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000259, 0, 'factory.stat.running', '进行中', '{"en-US": "In progress"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000260, 0, 'factory.stat.runningHint', '每 2.5s 自动刷新', '{"en-US": "Refreshes every 2.5 seconds"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000261, 0, 'factory.stat.success', '已成功', '{"en-US": "Successful"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000262, 0, 'factory.stat.total', '全部任务', '{"en-US": "All tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000263, 0, 'factory.stat.totalHint', '按当前用户过滤', '{"en-US": "Filtered for the current user"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000264, 0, 'factory.taskCount', '共 {count} 个任务', '{"en-US": "{count} tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000265, 0, 'factory.title', '项目工厂', '{"en-US": "Project factory"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000266, 0, 'gateway.authenticationRequired', '未登录或登录已过期', '{"en-US": "Sign-in is required or has expired"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000267, 0, 'gateway.projectAuthUnavailable', '项目鉴权尚未启用', '{"en-US": "Project authentication is not enabled"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000268, 0, 'gateway.resourceNotFound', '资源不存在', '{"en-US": "Resource not found"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000269, 0, 'gateway.routePolicyInvalid', '未知路由访问模式', '{"en-US": "Unknown route access mode"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000270, 0, 'gateway.routePolicyMissing', '路由安全元数据缺失', '{"en-US": "Route security metadata is missing"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000271, 0, 'gateway.sessionExpired', '会话已失效，请重新登录', '{"en-US": "Your session has expired. Sign in again."}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000272, 0, 'gateway.sessionVerificationUnavailable', '会话校验暂不可用', '{"en-US": "Session verification is temporarily unavailable"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000289, 0, 'home.controlPlane', 'KAIWU CONTROL PLANE', '{"en-US": "KAIWU CONTROL PLANE"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000290, 0, 'home.defaultUser', '管理员', '{"en-US": "Administrator"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000291, 0, 'home.greeting.afternoon', '下午好', '{"en-US": "Good afternoon"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000292, 0, 'home.greeting.evening', '晚上好', '{"en-US": "Good evening"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000293, 0, 'home.greeting.lateNight', '夜深了', '{"en-US": "Working late"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000294, 0, 'home.greeting.morning', '早上好', '{"en-US": "Good morning"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000295, 0, 'home.greeting.noon', '中午好', '{"en-US": "Good afternoon"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000296, 0, 'home.greeting.user', '{greeting}，{name}', '{"en-US": "{greeting}, {name}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000297, 0, 'home.guide.aiOptional', '尚未配置 AI 也可以选择“基础脚手架”；配置 AI 后可根据业务描述生成第一版模块。', '{"en-US": "Without AI configuration, you can still choose Basic scaffold. Configure AI to generate initial modules from a business description."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000298, 0, 'home.guide.aiReady', 'AI 已就绪，可直接从业务描述生成受校验蓝图。', '{"en-US": "AI is ready and can create a validated blueprint from a business description."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000299, 0, 'home.guide.alertDescription', 'AI 辅助生成受约束的第一版，确定性脚手架交付独立源码；团队可在自己的 Git 仓库中接续 AI 开发、测试和发布。', '{"en-US": "AI helps create a constrained first version, while deterministic scaffolding delivers standalone source code. Your team can continue AI-assisted development, testing, and releases in its own Git repositories."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000300, 0, 'home.guide.alertTitle', '在受控边界内，创建可维护的业务项目', '{"en-US": "Create maintainable business projects within clear boundaries"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000301, 0, 'home.guide.deliver.desc', '拿到独立双仓库后按正常工程流程开发，Kaiwu 不会再次覆盖代码。', '{"en-US": "Continue normal development in the two independent repositories. Kaiwu will never overwrite them."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000302, 0, 'home.guide.deliver.title', '下载或首次推送', '{"en-US": "Download or make the initial push"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000303, 0, 'home.guide.generate.desc', '平台创建项目、成员基础角色，并用受约束蓝图生成前后端源码。', '{"en-US": "The platform creates the project and base member role, then generates frontend and backend source from a constrained blueprint."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000304, 0, 'home.guide.generate.title', '开通并生成第一版', '{"en-US": "Initialize and generate"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000307, 0, 'home.guide.scope.desc', '写清核心对象、查询方式和状态；已有库可直接粘贴 CREATE TABLE DDL。', '{"en-US": "Describe core entities, query patterns, and states. If a schema exists, paste its CREATE TABLE DDL."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000308, 0, 'home.guide.scope.title', '准备业务范围', '{"en-US": "Define the business scope"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000309, 0, 'home.guide.start', '开始开通项目', '{"en-US": "Set up a project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000310, 0, 'home.guide.title', '从第一个项目开始', '{"en-US": "Start with your first project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000312, 0, 'home.load.failed', '加载失败', '{"en-US": "Failed to load"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000313, 0, 'home.projects.empty', '你还没有加入任何项目，请联系管理员在项目权限中心分配角色。', '{"en-US": "You have not joined a project. Ask an administrator to assign a role in the project access center."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000314, 0, 'home.projects.noEntry', '未配置入口', '{"en-US": "No entry URL"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000315, 0, 'home.projects.noEntryMessage', '该项目尚未配置业务后台入口，请到项目管理里维护 backendUrl', '{"en-US": "This project has no administration URL. Configure backendUrl in Projects."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000316, 0, 'home.projects.noMatch', '没有匹配的项目', '{"en-US": "No matching projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000317, 0, 'home.projects.search', '按名称或编码搜索', '{"en-US": "Search by name or code"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000318, 0, 'home.projects.title', '我参与的项目', '{"en-US": "My projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000319, 0, 'home.projects.titleCount', '我参与的项目 · {count}', '{"en-US": "My projects · {count}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000320, 0, 'home.refresh', '刷新', '{"en-US": "Refresh"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000321, 0, 'home.request.failed', '请求失败', '{"en-US": "Request failed"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000322, 0, 'home.summary.clear', '当前没有待处理事项，一切正常', '{"en-US": "Everything is running normally. Nothing needs your attention."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000323, 0, 'home.summary.pending', '有 {count} 项需要你处理', '{"en-US": "{count} items need your attention"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000324, 0, 'home.todo.aiNoKey', '尚未配置 API Key，AI 生成项目不可用', '{"en-US": "No API key is configured, so AI project generation is unavailable"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000325, 0, 'home.todo.aiNotReady', '大模型未就绪', '{"en-US": "AI provider not ready"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000326, 0, 'home.todo.configure', '去配置', '{"en-US": "Configure"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000328, 0, 'home.todo.empty', '没有需要处理的事项，平台能力和生成任务都正常。', '{"en-US": "There are no outstanding items. Platform capabilities and generation tasks are healthy."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000329, 0, 'home.todo.generating', '{project} 正在生成', '{"en-US": "Generating {project}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000330, 0, 'home.todo.generatingDesc', '任务在后台执行，完成后可下载或推送', '{"en-US": "The task is running in the background. Download or push it when complete."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000331, 0, 'home.todo.generationFailed', '{project} 生成失败', '{"en-US": "Generation failed for {project}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000332, 0, 'home.todo.generationFailedDesc', '可在项目工厂查看原因并重试', '{"en-US": "Open Project factory to review the cause and retry"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000335, 0, 'home.todo.handle', '去处理', '{"en-US": "Resolve"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000336, 0, 'home.todo.lastTestFailed', '最近一次连通测试失败', '{"en-US": "The latest connectivity test failed"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000337, 0, 'home.todo.open', '查看', '{"en-US": "View"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000340, 0, 'home.todo.title', '待处理', '{"en-US": "To do"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000341, 0, 'home.todo.unread.default', '来自平台与业务项目的站内信', '{"en-US": "Messages from the platform and business projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000342, 0, 'home.todo.unread.latest', '最新：{title}', '{"en-US": "Latest: {title}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000343, 0, 'home.todo.unread.title', '{count} 条未读消息', '{"en-US": "{count} unread messages"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000344, 0, 'home.todo.view', '去查看', '{"en-US": "View"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000345, 0, 'i18n.actions', '操作', '{"en-US": "Actions"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000346, 0, 'i18n.coverage', '译文', '{"en-US": "Translations"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000347, 0, 'i18n.create', '新增资源', '{"en-US": "New resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000348, 0, 'i18n.createTitle', '新增国际化资源', '{"en-US": "New internationalization resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000349, 0, 'i18n.defaultText', '默认文案（zh-CN）', '{"en-US": "Default text (zh-CN)"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000350, 0, 'i18n.deleteConfirm', '确定删除该资源？', '{"en-US": "Delete this resource?"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000351, 0, 'i18n.description', '说明', '{"en-US": "Description"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000352, 0, 'i18n.editTitle', '编辑国际化资源', '{"en-US": "Edit internationalization resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000353, 0, 'i18n.key', '资源 key', '{"en-US": "Resource key"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000354, 0, 'i18n.module', '模块', '{"en-US": "Module"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000355, 0, 'i18n.public', '登录前公开', '{"en-US": "Public before sign-in"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000356, 0, 'i18n.required', '覆盖必需', '{"en-US": "Required for coverage"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000357, 0, 'i18n.status', '状态', '{"en-US": "Status"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000358, 0, 'i18n.subtitle', '统一维护页面与 API 文案；语言是否可选由覆盖校验决定', '{"en-US": "Manage UI and API messages; coverage controls language availability"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000359, 0, 'i18n.title', '国际化资源', '{"en-US": "Internationalization resources"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000360, 0, 'layout.notification.empty', '没有未读消息', '{"en-US": "No unread messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000361, 0, 'layout.notification.readAll', '全部已读', '{"en-US": "Mark all read"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000362, 0, 'layout.notification.unread', '未读消息', '{"en-US": "Unread messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000363, 0, 'layout.notification.viewAll', '查看全部消息', '{"en-US": "View all messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000364, 0, 'layout.search.aria', '全局搜索', '{"en-US": "Global search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000365, 0, 'layout.search.empty', '没有匹配结果', '{"en-US": "No matching results"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000366, 0, 'layout.search.placeholder', '搜索项目、用户、交付任务（至少 2 个字符）', '{"en-US": "Search projects, users, and delivery tasks (2+ characters)"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000367, 0, 'layout.search.prompt', '输入关键词开始搜索', '{"en-US": "Enter a keyword to start searching"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000368, 0, 'layout.search.short', '搜索', '{"en-US": "Search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000369, 0, 'layout.search.title', '全局搜索', '{"en-US": "Global search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000370, 0, 'layout.search.type.delivery', '交付', '{"en-US": "Delivery"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000371, 0, 'layout.search.type.project', '项目', '{"en-US": "Project"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000372, 0, 'layout.search.type.user', '用户', '{"en-US": "User"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000373, 0, 'layout.user.logout', '退出登录', '{"en-US": "Sign out"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000374, 0, 'layout.user.notLoggedIn', '未登录', '{"en-US": "Not signed in"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000375, 0, 'layout.user.profile', '个人设置', '{"en-US": "Profile"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000376, 0, 'layout.user.switchProject', '切换项目', '{"en-US": "Switch project"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000377, 0, 'login.brand.subtitle', '面向 AI 时代受控开发的项目平台', '{"en-US": "A project platform for controlled AI-era development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000378, 0, 'login.failure', '登录失败', '{"en-US": "Sign-in failed"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000379, 0, 'login.footer', '管理员密码由启动环境变量注入，仓库不保存默认密码。', '{"en-US": "The administrator password is injected by the runtime environment. No default password is stored in the repository."}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000380, 0, 'login.form.submit', '登录', '{"en-US": "Sign in"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000381, 0, 'login.form.subtitle', '请使用管理员账号继续', '{"en-US": "Continue with your administrator account"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000382, 0, 'login.form.title', '登录管理后台', '{"en-US": "Sign in to Kaiwu"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000383, 0, 'login.hero.description', 'AI 负责写，平台负责守：受控蓝图生成独立前后端，权限、迁移与 CI 约束随仓库交付，团队用任意 AI 编程工具接着迭代。', '{"en-US": "AI writes, the platform guards: controlled blueprints generate independent frontend and backend repositories that ship with access, migration, and CI constraints, so your team keeps iterating with any AI coding tool."}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000384, 0, 'login.hero.title.first', '让 AI 加速交付，', '{"en-US": "Let AI accelerate delivery,"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000385, 0, 'login.hero.title.second', '让工程始终可控', '{"en-US": "keep engineering in control"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000386, 0, 'login.highlight.isolation', '独立仓库、数据库与交付路径', '{"en-US": "Independent repositories, databases, and delivery paths"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000387, 0, 'login.highlight.oneshot', '代码归你，平台不覆盖', '{"en-US": "Your code stays yours; the platform never overwrites it"}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000388, 0, 'login.highlight.permission', 'AI 受控生成，工程边界清晰', '{"en-US": "Controlled AI generation, clear engineering boundaries"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000389, 0, 'login.password.placeholder', '密码', '{"en-US": "Password"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000390, 0, 'login.password.required', '请输入密码', '{"en-US": "Enter your password"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000391, 0, 'login.sessionExit', '已退出登录：{reason}', '{"en-US": "Signed out: {reason}"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000392, 0, 'login.steps.continue.description', '项目自带工程约束，交给团队常用的 AI 编程工具继续迭代', '{"en-US": "Built-in engineering constraints let your team continue with its preferred AI coding tools"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000393, 0, 'login.steps.continue.title', '接续 AI 开发', '{"en-US": "Continue with AI development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000394, 0, 'login.steps.create.description', '登记业务项目，明确成员、角色与边界', '{"en-US": "Register the project and define members, roles, and boundaries"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000395, 0, 'login.steps.create.title', '建项目', '{"en-US": "Create a project"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000396, 0, 'login.steps.deliver.description', '下载 ZIP，或向空 GitLab 仓库一次性初始化', '{"en-US": "Download the ZIP, or initialize an empty GitLab repository once"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000397, 0, 'login.steps.deliver.title', '交付到你的仓库', '{"en-US": "Deliver to your repository"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000398, 0, 'login.steps.generate.description', '描述业务或导入建表 SQL，得到可维护的前后端', '{"en-US": "Describe the business or import DDL for maintainable frontends and backends"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000399, 0, 'login.steps.generate.title', '生成可交付的第一版', '{"en-US": "Generate a deliverable first version"}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000400, 0, 'login.steps.title', '4 步，进入受控 AI 开发', '{"en-US": "Four steps to controlled AI development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000401, 0, 'login.username.placeholder', '用户名', '{"en-US": "Username"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000402, 0, 'login.username.required', '请输入用户名', '{"en-US": "Enter your username"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000403, 0, 'members.actions', '操作', '{"en-US": "Actions"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000404, 0, 'members.add', '添加成员', '{"en-US": "Add member"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000405, 0, 'members.displayName', '显示名称', '{"en-US": "Display name"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000406, 0, 'members.edit', '编辑', '{"en-US": "Edit"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000407, 0, 'members.editTitle', '编辑成员：{username}', '{"en-US": "Edit member: {username}"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000408, 0, 'members.memberStatus', '成员状态', '{"en-US": "Member status"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000409, 0, 'members.platformUser', '平台用户', '{"en-US": "Platform user"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000410, 0, 'members.projectRole', '项目角色', '{"en-US": "Project roles"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000411, 0, 'members.remove', '移除', '{"en-US": "Remove"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000412, 0, 'members.removeConfirm', '确认移除该项目成员？', '{"en-US": "Remove this project member?"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000413, 0, 'members.removed', '成员已移除', '{"en-US": "Member removed"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000414, 0, 'members.roles', '角色', '{"en-US": "Roles"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000415, 0, 'members.saved', '成员配置已保存', '{"en-US": "Member configuration saved"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000416, 0, 'members.status', '状态', '{"en-US": "Status"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000417, 0, 'members.userOption', '{name}（{username}）', '{"en-US": "{name} ({username})"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000418, 0, 'members.username', '用户名', '{"en-US": "Username"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000419, 0, 'menu.system.ai-provider', '大模型配置', '{"en-US": "AI provider"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000420, 0, 'menu.system.configs', '参数配置', '{"en-US": "Configuration"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000421, 0, 'menu.system.dictionaries', '字典管理', '{"en-US": "Dictionaries"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000422, 0, 'menu.system.directory.delivery', '研发交付', '{"en-US": "Development & delivery"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000423, 0, 'menu.system.directory.platform', '平台管理', '{"en-US": "Platform"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000425, 0, 'menu.system.home', '工作台', '{"en-US": "Workbench"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000426, 0, 'menu.system.notifications', '消息中心', '{"en-US": "Messages"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000427, 0, 'menu.system.organization', '组织架构', '{"en-US": "Organization"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000428, 0, 'menu.system.project-factory', '项目工厂', '{"en-US": "Project factory"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000429, 0, 'menu.system.projects', '项目管理', '{"en-US": "Projects"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000430, 0, 'menu.system.scheduler', '定时任务', '{"en-US": "Scheduled tasks"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000431, 0, 'menu.system.security', '安全运营', '{"en-US": "Security operations"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000432, 0, 'menu.system.users', '用户管理', '{"en-US": "Users"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000433, 0, 'menus.actions', '操作', '{"en-US": "Actions"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000434, 0, 'menus.addChild', '新增子节点', '{"en-US": "Add child"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000435, 0, 'menus.componentPath', '组件路径', '{"en-US": "Component path"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000436, 0, 'menus.createRoot', '新建根节点', '{"en-US": "Create root node"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000437, 0, 'menus.createTitle', '新建项目菜单', '{"en-US": "Create project menu"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000438, 0, 'menus.delete', '删除', '{"en-US": "Delete"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000439, 0, 'menus.deleteConfirm', '确认删除该项目菜单？仅叶子节点可删除。', '{"en-US": "Delete this project menu? Only leaf nodes can be deleted."}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000440, 0, 'menus.deleted', '项目菜单已删除', '{"en-US": "Project menu deleted"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000441, 0, 'menus.disableConfirm', '确认停用菜单？', '{"en-US": "Disable this menu?"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000442, 0, 'menus.edit', '编辑', '{"en-US": "Edit"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000443, 0, 'menus.editTitle', '编辑项目菜单：{name}', '{"en-US": "Edit project menu: {name}"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000444, 0, 'menus.enableConfirm', '确认启用菜单？', '{"en-US": "Enable this menu?"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000445, 0, 'menus.icon', '菜单图标', '{"en-US": "Menu icon"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000446, 0, 'menus.iconExtra', '仅 DIRECTORY 和 MENU 会在侧栏显示图标；BUTTON 可留空', '{"en-US": "Only DIRECTORY and MENU appear in the sidebar; BUTTON can leave this empty"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000447, 0, 'menus.iconPlaceholder', '可选，选择侧栏图标', '{"en-US": "Optional sidebar icon"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000448, 0, 'menus.name', '菜单名称', '{"en-US": "Menu name"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000449, 0, 'menus.order', '顺序', '{"en-US": "Order"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000450, 0, 'menus.orderFailed', '排序失败', '{"en-US": "Failed to reorder"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000451, 0, 'menus.orderUpdated', '顺序已更新', '{"en-US": "Order updated"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000452, 0, 'menus.parent', '父节点', '{"en-US": "Parent"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000453, 0, 'menus.permission', '权限码', '{"en-US": "Permission code"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000454, 0, 'menus.permissionExtra', '必须与业务后端 @RequirePermission、前端 AuthButton 完全一致', '{"en-US": "Must exactly match backend @RequirePermission and frontend AuthButton"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000455, 0, 'menus.permissionPlaceholder', 'BUTTON 必填，例如 order:record:list', '{"en-US": "Required for BUTTON, for example order:record:list"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000456, 0, 'menus.root', '根节点', '{"en-US": "Root"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000457, 0, 'menus.route', '路由', '{"en-US": "Route"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000458, 0, 'menus.routePath', '路由路径', '{"en-US": "Route path"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000459, 0, 'menus.routeRequired', 'MENU 必填', '{"en-US": "Required for MENU"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000460, 0, 'menus.saved', '项目菜单已保存', '{"en-US": "Project menu saved"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000461, 0, 'menus.sort', '排序', '{"en-US": "Sort order"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000462, 0, 'menus.status', '状态', '{"en-US": "Status"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000463, 0, 'menus.type', '菜单类型', '{"en-US": "Menu type"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000464, 0, 'menus.visible', '是否显示', '{"en-US": "Visible"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000465, 0, 'notifications.actions', '操作', '{"en-US": "Actions"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000466, 0, 'notifications.all', '全部', '{"en-US": "All"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000467, 0, 'notifications.allTypes', '全部分类', '{"en-US": "All types"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000468, 0, 'notifications.empty', '还没有收到任何消息', '{"en-US": "No messages yet"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000469, 0, 'notifications.emptyFiltered', '没有符合条件的消息', '{"en-US": "No messages match the filters"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000470, 0, 'notifications.markAll', '全部已读', '{"en-US": "Mark all read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000471, 0, 'notifications.markRead', '标记已读', '{"en-US": "Mark read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000472, 0, 'notifications.markedCount', '已将 {count} 条消息标记为已读', '{"en-US": "{count} messages marked as read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000473, 0, 'notifications.message', '消息', '{"en-US": "Message"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000474, 0, 'notifications.noUnread', '没有未读消息', '{"en-US": "No unread messages"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000475, 0, 'notifications.platform', '平台', '{"en-US": "Platform"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000476, 0, 'notifications.read', '已读', '{"en-US": "Read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000477, 0, 'notifications.source', '来源项目', '{"en-US": "Source project"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000478, 0, 'notifications.status', '状态', '{"en-US": "Status"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000479, 0, 'notifications.subtitle', '平台与业务项目产生的站内信；消息是事实记录，只能标记已读，不能编辑或撤回', '{"en-US": "Messages from the platform and business projects are factual records. They can be marked read but cannot be edited or recalled."}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000480, 0, 'notifications.time', '时间', '{"en-US": "Time"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000481, 0, 'notifications.title', '消息中心', '{"en-US": "Notifications"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000482, 0, 'notifications.type', '分类', '{"en-US": "Type"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000483, 0, 'notifications.unread', '未读', '{"en-US": "Unread"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000484, 0, 'notifications.view', '查看', '{"en-US": "View"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000485, 0, 'onboarding.ai.description', '权限、路由、SQL、Docker 和 CI 均由版本化脚手架生成。生成后下载仓库，用 AI 工具按仓库里的 AGENTS.md 继续开发业务代码。', '{"en-US": "Permissions, routes, SQL, Docker, and CI are generated by versioned scaffolding. Download the repository and let your AI tool continue the business code following AGENTS.md.", "ja-JP": "権限・ルーティング・SQL・Docker・CI はバージョン管理されたスキャフォールドが生成します。生成後にリポジトリをダウンロードし、AI ツールが AGENTS.md に従って業務コードを続けます。"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000486, 0, 'onboarding.ai.title', '平台只生成确定性脚手架，业务代码由你的 AI 工具完成', '{"en-US": "The platform only generates a deterministic scaffold; your AI tool writes the business code", "ja-JP": "プラットフォームは確定的なスキャフォールドのみ生成し、業務コードは AI ツールが書きます"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000487, 0, 'onboarding.boundary.description', 'Kaiwu 不提供在线表单搭建或持续覆盖式生成。项目生成成功后，代码会交由独立仓库和开发团队维护。', '{"en-US": "Kaiwu does not provide online form building or repeated overwrite generation. After generation, independent repositories and the development team own the source."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000488, 0, 'onboarding.boundary.title', '先定义项目边界，再生成第一版源码', '{"en-US": "Define the project boundary before generating the first source baseline"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000492, 0, 'onboarding.confirm.description', '生成成功后可下载后端和前端 ZIP；若 GitLab 已配置，可向项目配置分支显式执行一次初始推送。后续修改完全由业务仓库接管。', '{"en-US": "After success, download backend and frontend ZIP files or explicitly make one initial push to the configured project branch when GitLab is available. Business repositories own all later changes.", "ja-JP": "生成後はバックエンドとフロントエンドの ZIP をダウンロードできます。GitLab が設定されている場合は、プロジェクトで設定したブランチへ一度だけ初回プッシュできます。その後の変更は業務リポジトリが管理します。"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000493, 0, 'onboarding.confirm.title', '提交后会创建项目并提交唯一的一次第一版生成任务', '{"en-US": "Submitting creates the project and its one permitted initial generation task"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000494, 0, 'onboarding.ddl', '数据库 DDL', '{"en-US": "Database DDL", "ja-JP": "データベース DDL"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000495, 0, 'onboarding.ddl.extra', '只接受 CREATE TABLE。已有 MySQL 库也可在项目创建后，从“生成第一版”中只读导入结构。', '{"en-US": "Only CREATE TABLE is accepted. After project creation, an existing MySQL schema can also be imported read-only from Generate first version."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000496, 0, 'onboarding.ddl.placeholder', '可粘贴 CREATE TABLE 语句', '{"en-US": "Paste CREATE TABLE statements"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000497, 0, 'onboarding.description', '项目说明（可选）', '{"en-US": "Project description (optional)"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000498, 0, 'onboarding.description.placeholder', '例如：面向销售团队的客户资料与跟进记录管理后台', '{"en-US": "For example, a customer and sales follow-up administration system"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000499, 0, 'onboarding.exit.button', '退出向导', '{"en-US": "Exit wizard"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000500, 0, 'onboarding.exit.cancel', '继续填写', '{"en-US": "Continue editing"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000501, 0, 'onboarding.exit.confirm', '退出', '{"en-US": "Exit"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000502, 0, 'onboarding.exit.created', '项目已创建，退出后可在项目管理中继续配置成员与生成任务。', '{"en-US": "The project has been created. Continue member and generation setup from Projects."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000503, 0, 'onboarding.exit.title', '退出项目开通向导？', '{"en-US": "Exit the project setup wizard?"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000504, 0, 'onboarding.exit.unsubmitted', '尚未提交，已填写的内容不会保存。', '{"en-US": "Nothing has been submitted. Your entries will not be saved."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000505, 0, 'onboarding.failure.default', '开通失败', '{"en-US": "Project setup failed"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000506, 0, 'onboarding.failure.preserved', '项目已保留，可修正后继续：{detail}', '{"en-US": "The project was preserved. Correct the input and continue: {detail}"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000507, 0, 'onboarding.member.option', '{displayName}（{username}）', '{"en-US": "{displayName} ({username})"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000508, 0, 'onboarding.members.description', '创建人会自动成为项目管理员。初始成员不是必填项；这里选择的用户会加入“项目成员”基础角色，后续可在项目权限中心细分权限。', '{"en-US": "The creator automatically becomes project administrator. Initial members are optional; selected users join the base Project member role and can receive finer access later."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000509, 0, 'onboarding.members.label', '初始成员（可选）', '{"en-US": "Initial members (optional)"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000511, 0, 'onboarding.mode.basic', '基础脚手架', '{"en-US": "Basic scaffold"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000512, 0, 'onboarding.mode.label', '生成方式', '{"en-US": "Generation mode"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000513, 0, 'onboarding.next', '下一步', '{"en-US": "Next"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000514, 0, 'onboarding.packageName', 'Java 包名', '{"en-US": "Java package"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000515, 0, 'onboarding.packageName.extra', '用于生成后端的基础包路径；使用团队已有的 Java 命名空间即可。', '{"en-US": "Base package for the generated backend. Use your team’s existing Java namespace."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000516, 0, 'onboarding.packageName.placeholder', '例如 com.example.app', '{"en-US": "For example, com.example.app"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000517, 0, 'onboarding.permission.warning', '当前账号缺少项目生成权限，无法完成最后一步', '{"en-US": "Your account lacks project generation permission, so the final step is unavailable"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000518, 0, 'onboarding.previous', '上一步', '{"en-US": "Previous"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000519, 0, 'onboarding.projectCode', '项目编码', '{"en-US": "Project code"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000520, 0, 'onboarding.projectCode.placeholder', '例如 crm-center', '{"en-US": "For example, crm-center"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000521, 0, 'onboarding.projectCode.rule', '小写字母开头，仅小写字母、数字和连字符', '{"en-US": "Start with a lowercase letter and use only lowercase letters, numbers, and hyphens"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000522, 0, 'onboarding.projectName', '项目名称', '{"en-US": "Project name"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000523, 0, 'onboarding.projectName.placeholder', '例如 客户管理中心', '{"en-US": "For example, Customer management"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000524, 0, 'onboarding.result.factory', '查看项目工厂', '{"en-US": "View Project factory"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000525, 0, 'onboarding.result.projects', '管理项目', '{"en-US": "Manage projects"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000526, 0, 'onboarding.result.subtitle', '{project} 的生成任务 {taskNo} 已创建，可在项目工厂持续查看。', '{"en-US": "Generation task {taskNo} was created for {project}. Track it in Project factory."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000527, 0, 'onboarding.result.title', '项目开通流程已提交', '{"en-US": "Project setup submitted"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000528, 0, 'onboarding.resume.info', '检测到本人创建的未完成项目，已从中断步骤继续', '{"en-US": "Your unfinished project was found. Setup has resumed from the interrupted step."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000529, 0, 'onboarding.step.confirm', '确认开通', '{"en-US": "Confirm setup"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000530, 0, 'onboarding.step.generation', '生成方式', '{"en-US": "Generation mode"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000531, 0, 'onboarding.step.members', '项目成员', '{"en-US": "Project members"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000532, 0, 'onboarding.step.project', '项目信息', '{"en-US": "Project details"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000533, 0, 'onboarding.submit', '创建并生成', '{"en-US": "Create and generate"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000534, 0, 'onboarding.subtitle', '一次完成项目、基础成员角色和代码生成任务的初始化', '{"en-US": "Initialize a project, its base member role, and its source generation task in one flow"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000535, 0, 'onboarding.success.created', '项目已创建并提交生成', '{"en-US": "Project created and generation submitted"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000536, 0, 'onboarding.success.restored', '项目已有生成任务，已恢复开通结果', '{"en-US": "The project already has a generation task. Its setup result has been restored."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000537, 0, 'onboarding.title', '项目开通向导', '{"en-US": "Project setup wizard"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000538, 0, 'org.actions', '操作', '{"en-US": "Actions"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000539, 0, 'org.additional', '兼任部门', '{"en-US": "Additional departments"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000540, 0, 'org.adjust', '调整归属', '{"en-US": "Adjust membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000541, 0, 'org.allUsers', '全部用户', '{"en-US": "All users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000542, 0, 'org.assignTitle', '分配部门：{name}', '{"en-US": "Assign departments: {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000543, 0, 'org.assignmentFailed', '部门归属更新失败', '{"en-US": "Failed to update department membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000544, 0, 'org.assignmentHint', '主部门用于默认数据归属；兼任部门用于跨部门协作。清空主部门会将用户设为未分配。', '{"en-US": "The primary department owns data by default; additional departments support cross-team collaboration. Clearing primary leaves the user unassigned."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000545, 0, 'org.assignmentUpdated', '用户部门归属已更新', '{"en-US": "User department membership updated"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000546, 0, 'org.code', '部门编码', '{"en-US": "Department code"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000547, 0, 'org.codeRule', '小写字母开头，仅小写字母、数字和连字符', '{"en-US": "Start with a lowercase letter and use only lowercase letters, numbers, and hyphens"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000548, 0, 'org.create', '新建部门', '{"en-US": "Create department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000549, 0, 'org.createTitle', '新建部门', '{"en-US": "Create department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000550, 0, 'org.created', '部门已创建', '{"en-US": "Department created"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000551, 0, 'org.delete', '删除', '{"en-US": "Delete"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000552, 0, 'org.deleteConfirm', '确认删除该部门？', '{"en-US": "Delete this department?"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000553, 0, 'org.deleteHint', '存在下级部门或用户归属时会拒绝删除。', '{"en-US": "Departments with children or assigned users cannot be deleted."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000554, 0, 'org.deleted', '部门已删除', '{"en-US": "Department deleted"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000555, 0, 'org.edit', '编辑', '{"en-US": "Edit"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000556, 0, 'org.editTitle', '编辑部门', '{"en-US": "Edit department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000557, 0, 'org.loadFailed', '组织架构加载失败', '{"en-US": "Failed to load the organization"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000558, 0, 'org.membership', '部门归属', '{"en-US": "Department membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000559, 0, 'org.name', '部门名称', '{"en-US": "Department name"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000560, 0, 'org.option', '{name}（{code}）', '{"en-US": "{name} ({code})"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000561, 0, 'org.parent', '上级部门', '{"en-US": "Parent department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000562, 0, 'org.peopleCount', '{count} 人', '{"en-US": "{count} people"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000563, 0, 'org.primary', '主部门', '{"en-US": "Primary department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000564, 0, 'org.primaryTag', '主部门 · {name}', '{"en-US": "Primary · {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000565, 0, 'org.saveFailed', '部门保存失败', '{"en-US": "Failed to save department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000566, 0, 'org.searchUsers', '搜索姓名或账号', '{"en-US": "Search name or account"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000567, 0, 'org.selectAdditional', '可选择多个兼任部门', '{"en-US": "Select one or more additional departments"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000568, 0, 'org.selectPrimary', '选择主部门', '{"en-US": "Select a primary department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000569, 0, 'org.selectPrimaryFirst', '请先选择主部门', '{"en-US": "Select a primary department first"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000570, 0, 'org.sort', '排序', '{"en-US": "Sort order"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000571, 0, 'org.status', '状态', '{"en-US": "Status"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000572, 0, 'org.subtitle', '维护部门树和用户归属；一个用户可归属多个部门，首项为主部门', '{"en-US": "Maintain the department tree and user membership. A user can belong to multiple departments; the first is primary."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000573, 0, 'org.title', '组织架构', '{"en-US": "Organization"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000574, 0, 'org.totalUsers', '共 {total} 位用户', '{"en-US": "{total} users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000575, 0, 'org.tree', '部门树', '{"en-US": "Department tree"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000576, 0, 'org.treeHint', '点击部门筛选右侧用户', '{"en-US": "Select a department to filter users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000577, 0, 'org.unassigned', '未分配', '{"en-US": "Unassigned"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000578, 0, 'org.unknown', '未知部门 {id}', '{"en-US": "Unknown department {id}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000579, 0, 'org.updated', '部门已更新', '{"en-US": "Department updated"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000580, 0, 'org.user', '用户', '{"en-US": "User"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000581, 0, 'org.userMembership', '用户归属 · {scope}', '{"en-US": "User membership · {scope}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000582, 0, 'org.viewAll', '查看全部用户', '{"en-US": "View all users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000583, 0, 'password.confirm', '确认新密码', '{"en-US": "Confirm new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000584, 0, 'password.confirm.mismatch', '两次输入的新密码不一致', '{"en-US": "The two passwords do not match"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000585, 0, 'password.confirm.required', '请再次输入新密码', '{"en-US": "Enter the new password again"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000586, 0, 'password.current', '当前密码', '{"en-US": "Current password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000587, 0, 'password.current.required', '请输入当前密码', '{"en-US": "Enter your current password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000588, 0, 'password.force.alertDescription', '为保证账号安全，请设置只有你本人知道的新密码后再继续使用。', '{"en-US": "Set a new password known only to you before continuing."}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000589, 0, 'password.force.alertTitle', '当前密码由管理员设定', '{"en-US": "Your current password was set by an administrator"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000590, 0, 'password.force.failure', '修改密码失败', '{"en-US": "Failed to update password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000591, 0, 'password.force.submit', '设置新密码', '{"en-US": "Set new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000592, 0, 'password.force.success', '密码已更新，现在可以正常使用平台', '{"en-US": "Password updated. You can now use the platform."}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000593, 0, 'password.force.title', '请先修改初始密码', '{"en-US": "Change your initial password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000594, 0, 'password.new', '新密码', '{"en-US": "New password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000595, 0, 'password.new.extra', '8 到 72 个字符，中文按 UTF-8 字节计算', '{"en-US": "8–72 characters; non-ASCII text is counted as UTF-8 bytes"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000596, 0, 'password.new.length', '密码长度必须为8到72个字符', '{"en-US": "Password must be 8–72 characters"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000597, 0, 'password.new.required', '请输入新密码', '{"en-US": "Enter a new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000598, 0, 'profile.account', '账号信息', '{"en-US": "Account information"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000599, 0, 'profile.changePassword', '修改密码', '{"en-US": "Change password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000600, 0, 'profile.confirmPassword', '确认新密码', '{"en-US": "Confirm new password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000601, 0, 'profile.confirmPasswordRequired', '请再次输入新密码', '{"en-US": "Enter the new password again"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000602, 0, 'profile.currentPassword', '当前密码', '{"en-US": "Current password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000603, 0, 'profile.currentPasswordRequired', '请输入当前密码', '{"en-US": "Enter your current password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000604, 0, 'profile.displayName', '显示名称', '{"en-US": "Display name"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000605, 0, 'profile.editHint', '修改显示名或邮箱请联系管理员，在用户管理里操作', '{"en-US": "Contact an administrator to change your display name or email in Users."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000606, 0, 'profile.group.other', '其它', '{"en-US": "Other"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000607, 0, 'profile.group.system', '平台', '{"en-US": "Platform"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000608, 0, 'profile.newPassword', '新密码', '{"en-US": "New password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000609, 0, 'profile.newPasswordExtra', '8 到 72 个字符，中文按 UTF-8 字节计算', '{"en-US": "8 to 72 characters; non-ASCII characters are counted as UTF-8 bytes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000610, 0, 'profile.newPasswordRequired', '请输入新密码', '{"en-US": "Enter a new password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000611, 0, 'profile.noPermissions', '当前账号没有任何权限码，请联系管理员在项目权限中心分配角色。', '{"en-US": "This account has no permission codes. Ask an administrator to assign a role in the project access center."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000612, 0, 'profile.openUsers', '前往用户管理 →', '{"en-US": "Open Users →"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000613, 0, 'profile.passwordChanged', '密码已更新，其它设备上的登录已被下线', '{"en-US": "Password updated. Sessions on other devices have been revoked."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000614, 0, 'profile.passwordFailed', '修改密码失败', '{"en-US": "Failed to change password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000615, 0, 'profile.passwordHint', '密码更新后，其它设备上的登录会被立即下线；当前页面无需重新登录。', '{"en-US": "Updating your password immediately signs out other devices. This page stays signed in."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000616, 0, 'profile.passwordLength', '密码长度必须为 8 到 72 个字符', '{"en-US": "The password must contain 8 to 72 characters"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000617, 0, 'profile.passwordMismatch', '两次输入的新密码不一致', '{"en-US": "The new passwords do not match"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000618, 0, 'profile.passwordSubmit', '更新密码', '{"en-US": "Update password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000619, 0, 'profile.permissionCount', '共 {count} 个权限码', '{"en-US": "{count} permission codes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000620, 0, 'profile.permissions', '权限码', '{"en-US": "Permission codes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000621, 0, 'profile.permissionsHint', '按前缀分组，与后端注解、menu.sql 三端同码', '{"en-US": "Grouped by prefix; codes match backend annotations and menu.sql"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000622, 0, 'profile.userId', '用户 ID', '{"en-US": "User ID"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000623, 0, 'profile.username', '用户名', '{"en-US": "Username"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000624, 0, 'projects.accessCenter', '权限中心', '{"en-US": "Access center"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000625, 0, 'projects.accessTitle', '{name}：项目权限中心', '{"en-US": "{name}: Project access center"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000626, 0, 'projects.actions', '操作', '{"en-US": "Actions"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000627, 0, 'projects.archive', '归档', '{"en-US": "Archive"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000628, 0, 'projects.archiveConfirm', '确认归档项目？归档后当前成员不可再进入。', '{"en-US": "Archive this project? Current members will no longer be able to enter."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000629, 0, 'projects.archived', '项目已归档', '{"en-US": "Project archived"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000630, 0, 'projects.backend', '业务后台', '{"en-US": "Administration site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000631, 0, 'projects.backendLabel', '业务后台入口名称', '{"en-US": "Administration link label"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000635, 0, 'projects.backendUrl', '业务后台入口', '{"en-US": "Administration URL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000636, 0, 'projects.basicDescription', '适合先拿到可启动仓库结构，再由开发者自行实现业务。', '{"en-US": "Use it to obtain runnable repository structure, then implement the business manually."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000637, 0, 'projects.basicTitle', '基础空脚手架不调用 AI，也不生成业务表和 CRUD', '{"en-US": "Basic scaffold does not call AI or generate business tables and CRUD"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000638, 0, 'projects.builtIn', '内置', '{"en-US": "Built-in"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000640, 0, 'projects.businessMenus', '业务菜单', '{"en-US": "Business menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000643, 0, 'projects.businessScope', '这里的成员、角色、业务菜单和权限码只属于当前项目，不会影响 system 或其他项目。', '{"en-US": "Members, roles, business menus, and permission codes here belong only to this project and do not affect system or other projects."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000644, 0, 'projects.createdAt', '创建时间', '{"en-US": "Created at"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000645, 0, 'projects.currentScope', '当前范围：{name}（{code}）', '{"en-US": "Current scope: {name} ({code})"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000646, 0, 'projects.database', '数据库', '{"en-US": "Database"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000647, 0, 'projects.ddl', 'MySQL DDL', '{"en-US": "MySQL DDL", "ja-JP": "MySQL DDL"}', 'projects', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000648, 0, 'projects.ddlExtra', '粘贴 CREATE TABLE，或使用下方只读导入已有库的结构', '{"en-US": "Paste CREATE TABLE DDL, or use the read-only import below to read an existing database schema.", "ja-JP": "CREATE TABLE を貼り付けるか、下の読み取り専用インポートで既存データベースの構造を取り込みます。"}', 'projects', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000649, 0, 'projects.defaultBranch', '默认目标分支', '{"en-US": "Default target branch"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000655, 0, 'projects.description', '描述', '{"en-US": "Description"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000656, 0, 'projects.disable', '停用', '{"en-US": "Disable"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000657, 0, 'projects.disableConfirm', '确认停用项目？', '{"en-US": "Disable this project?"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000658, 0, 'projects.edit', '编辑', '{"en-US": "Edit"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000659, 0, 'projects.editTitle', '编辑项目{suffix}', '{"en-US": "Edit project{suffix}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000660, 0, 'projects.enable', '启用', '{"en-US": "Enable"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000661, 0, 'projects.enableConfirm', '确认启用项目？', '{"en-US": "Enable this project?"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000665, 0, 'projects.generateFirst', '生成第一版', '{"en-US": "Generate first version"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000666, 0, 'projects.generateTitle', '生成第一版：{name}', '{"en-US": "Generate first version: {name}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000669, 0, 'projects.generationMode', '生成方式', '{"en-US": "Generation mode"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000670, 0, 'projects.generationQueued', '生成任务已进入队列，可在项目工厂查看进度', '{"en-US": "Generation queued. Track progress in Project factory."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000671, 0, 'projects.gitlabId', 'GitLab 项目标识', '{"en-US": "GitLab project identifier"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000672, 0, 'projects.gitlabIdPlaceholder', '数字 ID 或 group/project', '{"en-US": "Numeric ID or group/project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000675, 0, 'projects.host', '主机', '{"en-US": "Host"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000676, 0, 'projects.hostPlaceholder', '只填主机名或 IPv4，不填 jdbc:mysql:// 和端口', '{"en-US": "Enter only a hostname or IPv4 address, without jdbc:mysql:// or a port"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000677, 0, 'projects.importSchema', '从 MySQL 只读导入结构', '{"en-US": "Import schema read-only from MySQL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000678, 0, 'projects.importTitle', '从 MySQL 只读导入表结构', '{"en-US": "Import table schema read-only from MySQL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000679, 0, 'projects.importedSchema', '已只读导入 {tables} 张表、{columns} 个字段；密码未保存', '{"en-US": "Imported {tables} tables and {columns} columns read-only; the password was not saved"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000680, 0, 'projects.keyword', '关键词', '{"en-US": "Keyword"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000681, 0, 'projects.keywordPlaceholder', '项目编码或名称', '{"en-US": "Project code or name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000682, 0, 'projects.legacyRepo', '单仓代码生成', '{"en-US": "Legacy single repository"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000683, 0, 'projects.legacyRepoPlaceholder', '旧版单仓代码生成使用', '{"en-US": "Used by legacy single-repository generation"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000684, 0, 'projects.legacyRepoTooltip', '仅供旧版代码生成与 MR 使用；新项目的后端、前端双仓库请使用项目列表中的“仓库交付”', '{"en-US": "Used only by the legacy generator and merge requests. Use Repository delivery for new separate backend and frontend repositories."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000685, 0, 'projects.legacyRepoUrl', '单仓代码生成仓库地址', '{"en-US": "Legacy repository URL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000686, 0, 'projects.name', '项目名称', '{"en-US": "Project name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000689, 0, 'projects.open', '开通项目', '{"en-US": "Set up project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000690, 0, 'projects.openBackend', '打开后台', '{"en-US": "Open administration site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000693, 0, 'projects.package', '基础包名', '{"en-US": "Base package"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000694, 0, 'projects.packageRule', '请输入合法 Java 包名', '{"en-US": "Enter a valid Java package name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000695, 0, 'projects.password', '密码', '{"en-US": "Password"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000696, 0, 'projects.passwordOnce', '密码只用于这一次请求', '{"en-US": "The password is used for this request only"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000697, 0, 'projects.permissionMenus', '权限菜单', '{"en-US": "Permission menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000698, 0, 'projects.platformMenus', '平台菜单', '{"en-US": "Platform menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000699, 0, 'projects.port', '端口', '{"en-US": "Port"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000700, 0, 'projects.project', '项目', '{"en-US": "Project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000701, 0, 'projects.projectDescription', '项目描述', '{"en-US": "Project description"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000702, 0, 'projects.projectMembers', '项目成员', '{"en-US": "Project members"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000707, 0, 'projects.readSchema', '读取表结构', '{"en-US": "Read schema"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000708, 0, 'projects.readonlyUser', '只读账号', '{"en-US": "Read-only username"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000710, 0, 'projects.roleGrant', '角色授权', '{"en-US": "Role grants"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000711, 0, 'projects.schemaSafety', 'System 只查询 information_schema 和 SHOW CREATE TABLE，不读取业务行；地址、账号、密码不会写入数据库、日志或生成任务。建议使用只读账号。', '{"en-US": "System queries only information_schema and SHOW CREATE TABLE, never business rows. Address, username, and password are not stored in the database, logs, or generation task. Use a read-only account."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000712, 0, 'projects.status', '状态', '{"en-US": "Status"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000713, 0, 'projects.statusUpdated', '项目状态已更新', '{"en-US": "Project status updated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000714, 0, 'projects.submitGeneration', '提交生成', '{"en-US": "Submit generation"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000715, 0, 'projects.subtitle', '前后端双仓库通过每个项目的“仓库交付”配置；system 是不可停用、不可归档的内置项目', '{"en-US": "Configure separate frontend and backend repositories through Repository delivery. system is a built-in project that cannot be disabled or archived."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000716, 0, 'projects.systemMembers', '系统成员', '{"en-US": "System members"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000717, 0, 'projects.systemRoleGrant', '系统角色授权', '{"en-US": "System role grants"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000718, 0, 'projects.systemScope', '这是不可停用、不可归档的 system 内置项目。Kaiwu 平台成员、系统角色、平台菜单和登录权限全部在这里管理；权限变更会撤销受影响用户的现有会话。', '{"en-US": "This is the built-in system project and cannot be disabled or archived. Manage Kaiwu platform members, system roles, platform menus, and sign-in permissions here. Permission changes revoke affected sessions."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000719, 0, 'projects.title', '项目管理', '{"en-US": "Projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000720, 0, 'projects.titleSuffix', '：{name}', '{"en-US": ": {name}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000721, 0, 'projects.updated', '项目已更新', '{"en-US": "Project updated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000723, 0, 'roles.actions', '操作', '{"en-US": "Actions"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000724, 0, 'roles.assignMenus', '分配菜单', '{"en-US": "Assign menus"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000725, 0, 'roles.assignTitle', '分配业务菜单{suffix}', '{"en-US": "Assign business menus{suffix}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000726, 0, 'roles.code', '角色编码', '{"en-US": "Role code"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000727, 0, 'roles.create', '新建项目角色', '{"en-US": "Create project role"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000728, 0, 'roles.delete', '删除', '{"en-US": "Delete"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000729, 0, 'roles.deleteConfirm', '确认删除该项目角色？', '{"en-US": "Delete this project role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000730, 0, 'roles.deleted', '项目角色已删除', '{"en-US": "Project role deleted"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000731, 0, 'roles.description', '描述', '{"en-US": "Description"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000732, 0, 'roles.disableConfirm', '确认停用角色？', '{"en-US": "Disable this role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000733, 0, 'roles.edit', '编辑', '{"en-US": "Edit"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000734, 0, 'roles.editTitle', '编辑角色：{name}', '{"en-US": "Edit role: {name}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000735, 0, 'roles.enableConfirm', '确认启用角色？', '{"en-US": "Enable this role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000736, 0, 'roles.grantUpdated', '项目角色授权已更新，父节点会自动补齐', '{"en-US": "Project role grants updated; parent nodes were added automatically"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000737, 0, 'roles.menuCount', '菜单数', '{"en-US": "Menu count"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000738, 0, 'roles.menuOption', '{name}（{code}）', '{"en-US": "{name} ({code})"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000739, 0, 'roles.name', '角色名称', '{"en-US": "Role name"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000740, 0, 'roles.roleDescription', '角色描述', '{"en-US": "Role description"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000741, 0, 'roles.saved', '项目角色已保存', '{"en-US": "Project role saved"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000742, 0, 'roles.status', '状态', '{"en-US": "Status"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000743, 0, 'scheduler.actions', '操作', '{"en-US": "Actions"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000744, 0, 'scheduler.completedAt', '完成时间', '{"en-US": "Completed at"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000745, 0, 'scheduler.create', '新建任务', '{"en-US": "Create job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000746, 0, 'scheduler.createTitle', '新建定时任务', '{"en-US": "Create scheduled job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000747, 0, 'scheduler.credentialEnv', '将它以 KAIWU_SCHEDULER_CREDENTIAL 环境变量注入该项目服务；定时任务与读取平台参数配置共用这一个凭据。', '{"en-US": "Inject it into the project service as the KAIWU_SCHEDULER_CREDENTIAL environment variable. Scheduled tasks and platform configuration reads share this one credential."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000748, 0, 'scheduler.credentialOnce', '凭据只显示这一次；再次生成会立即撤销旧凭据。', '{"en-US": "The credential is shown only once. Generating another immediately revokes the old one."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000749, 0, 'scheduler.credentialSaved', '我已保存', '{"en-US": "I saved it"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000750, 0, 'scheduler.credentialTitle', '请立即保存项目服务凭据', '{"en-US": "Save the project service credential now"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000751, 0, 'scheduler.cron', 'Cron 表达式', '{"en-US": "Cron expression"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000752, 0, 'scheduler.cronTooltip', 'Spring 六段 Cron：秒 分 时 日 月 星期', '{"en-US": "Spring six-field Cron: second minute hour day month weekday"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000753, 0, 'scheduler.cronZone', 'Cron / 时区', '{"en-US": "Cron / time zone"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000754, 0, 'scheduler.delete', '删除', '{"en-US": "Delete"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000755, 0, 'scheduler.deleteConfirm', '删除后不再产生新的触发，历史执行记录会保留。确认删除？', '{"en-US": "Deleting stops future triggers and preserves execution history. Delete this job?"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000756, 0, 'scheduler.deleted', '定时任务已删除', '{"en-US": "Scheduled job deleted"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000757, 0, 'scheduler.edit', '编辑', '{"en-US": "Edit"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000758, 0, 'scheduler.editTitle', '编辑定时任务', '{"en-US": "Edit scheduled job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000759, 0, 'scheduler.emptyExecutions', '当前项目暂无执行记录', '{"en-US": "No execution records for this project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000760, 0, 'scheduler.emptyJobs', '当前项目暂无定时任务', '{"en-US": "No scheduled jobs for this project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000761, 0, 'scheduler.enabled', '启用', '{"en-US": "Enabled"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000762, 0, 'scheduler.enabledTooltip', '建议先保存为停用，确认项目实例在线后再启用', '{"en-US": "Save disabled first, then enable after confirming a project instance is online"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000763, 0, 'scheduler.executions', '执行记录', '{"en-US": "Execution records"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000764, 0, 'scheduler.generateCredential', '生成项目凭据', '{"en-US": "Generate project credential"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000765, 0, 'scheduler.handler', '任务处理器', '{"en-US": "Task handler"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000766, 0, 'scheduler.handlerOption', '{name}（{type}）', '{"en-US": "{name} ({type})"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000767, 0, 'scheduler.handlerRequired', '请选择项目已注册的任务处理器', '{"en-US": "Select a handler registered by the project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000768, 0, 'scheduler.handlerTooltip', '只能选择项目服务主动上报的 Handler', '{"en-US": "Only handlers reported by the project service can be selected"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000769, 0, 'scheduler.instance', '执行实例', '{"en-US": "Execution instance"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000770, 0, 'scheduler.job', '任务', '{"en-US": "Job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000771, 0, 'scheduler.jobs', '任务配置', '{"en-US": "Job configuration"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000772, 0, 'scheduler.lastRun', '最近执行', '{"en-US": "Last run"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000773, 0, 'scheduler.name', '任务名称', '{"en-US": "Job name"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000774, 0, 'scheduler.nameRequired', '请输入任务名称', '{"en-US": "Enter a job name"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000775, 0, 'scheduler.noHandlers', '当前项目还没有在线任务处理器', '{"en-US": "This project has no online task handlers"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000776, 0, 'scheduler.noHandlersHint', '请先部署已接入 scheduler starter 且配置了项目凭据的服务实例；实例同步后才能创建任务。', '{"en-US": "Deploy a service using scheduler starter with a project credential before creating jobs."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000777, 0, 'scheduler.payload', '任务参数（JSON 对象）', '{"en-US": "Job payload (JSON object)"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000778, 0, 'scheduler.payloadInvalid', '任务参数不是合法 JSON', '{"en-US": "Job payload is not valid JSON"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000779, 0, 'scheduler.payloadJson', '任务参数必须是合法 JSON', '{"en-US": "Job payload must be valid JSON"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000780, 0, 'scheduler.payloadObject', '任务参数必须是 JSON 对象', '{"en-US": "Job payload must be a JSON object"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000781, 0, 'scheduler.payloadTooltip', '留空等同于 {}；必须是 JSON 对象，不能是数组或标量', '{"en-US": "Empty is equivalent to {}; the value must be a JSON object, not an array or scalar"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000782, 0, 'scheduler.project', '项目', '{"en-US": "Project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000783, 0, 'scheduler.projectOption', '{name}（{code}）', '{"en-US": "{name} ({code})"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000784, 0, 'scheduler.refresh', '刷新', '{"en-US": "Refresh"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000785, 0, 'scheduler.result', '结果 / 失败原因', '{"en-US": "Result / failure reason"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000786, 0, 'scheduler.saved', '定时任务已保存', '{"en-US": "Scheduled job saved"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000787, 0, 'scheduler.scheduledAt', '计划触发', '{"en-US": "Scheduled at"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000788, 0, 'scheduler.securityDescription', '项目服务只会上报本地已注册的任务类型；System 不能下发 Java 类、Shell 或任意 URL。多实例会先向 System 抢占同一触发时间的执行租约。', '{"en-US": "Project services report only locally registered task types. System cannot send Java classes, shell commands, or arbitrary URLs. Multiple instances first claim a lease for the same trigger time."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000789, 0, 'scheduler.securityTitle', '安全执行模型', '{"en-US": "Secure execution model"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000790, 0, 'scheduler.selectProject', '选择项目', '{"en-US": "Select a project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000791, 0, 'scheduler.status', '状态', '{"en-US": "Status"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000792, 0, 'scheduler.subtitle', 'System 统一管理调度配置与执行记录，任务代码在对应项目服务内精准执行', '{"en-US": "System manages schedules and execution records; task code runs precisely inside each project service."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000793, 0, 'scheduler.title', '项目定时任务', '{"en-US": "Project scheduler"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000794, 0, 'scheduler.version', '版本', '{"en-US": "Version"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000795, 0, 'scheduler.zone', '时区', '{"en-US": "Time zone"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000796, 0, 'scope.global', '全局默认', '{"en-US": "Global defaults"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000797, 0, 'scope.label', '作用范围', '{"en-US": "Scope"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000798, 0, 'scope.project', '{name}（{code}）', '{"en-US": "{name} ({code})"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000799, 0, 'security.actions', '操作', '{"en-US": "Actions"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000800, 0, 'security.after', '修改后', '{"en-US": "After"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000801, 0, 'security.before', '修改前', '{"en-US": "Before"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000802, 0, 'security.changes', '变更', '{"en-US": "Changes"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000803, 0, 'security.clientIp', '客户端 IP', '{"en-US": "Client IP"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000804, 0, 'security.description', '说明', '{"en-US": "Description"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000805, 0, 'security.detail', '详情', '{"en-US": "Details"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000806, 0, 'security.diffOperationTitle', '变更详情 · {operation}', '{"en-US": "Change details · {operation}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000807, 0, 'security.diffTitle', '变更详情', '{"en-US": "Change details"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000808, 0, 'security.emptyValue', '（空）', '{"en-US": "(empty)"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000809, 0, 'security.field', '字段', '{"en-US": "Field"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000810, 0, 'security.forceOffline', '强制下线', '{"en-US": "Force sign-out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000811, 0, 'security.lastSeen', '最后访问', '{"en-US": "Last seen"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000812, 0, 'security.loginTime', '登录时间', '{"en-US": "Signed in at"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000813, 0, 'security.logins', '登录日志', '{"en-US": "Sign-in logs"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000814, 0, 'security.module', '模块', '{"en-US": "Module"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000815, 0, 'security.noDiff', '本次操作未解析到字段级变更；如有需要参考“详情”列摘要。', '{"en-US": "No field-level change could be parsed. Refer to the Details summary if needed."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000816, 0, 'security.nullValue', 'null', '{"en-US": "null"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000817, 0, 'security.offlineConfirm', '确认下线', '{"en-US": "Confirm sign-out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000818, 0, 'security.offlineHint', '下线后该设备的 Access Token 会在下一次请求时立即被 Gateway 拒绝。', '{"en-US": "The Gateway will reject this device’s access token on its next request."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000819, 0, 'security.offlineSuccess', '会话已强制下线', '{"en-US": "Session signed out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000820, 0, 'security.offlineTitle', '强制下线：{username}', '{"en-US": "Force sign-out: {username}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000821, 0, 'security.operation', '操作', '{"en-US": "Operation"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000822, 0, 'security.operations', '操作日志', '{"en-US": "Operation logs"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000823, 0, 'security.operator', '操作人：{username}', '{"en-US": "Operator: {username}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000824, 0, 'security.reason', '处置原因（可选）', '{"en-US": "Reason (optional)"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000825, 0, 'security.request', '请求', '{"en-US": "Request"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000826, 0, 'security.sessionId', '会话 ID', '{"en-US": "Session ID"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000827, 0, 'security.sessions', '在线会话', '{"en-US": "Online sessions"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000828, 0, 'security.status', '状态', '{"en-US": "Status"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000829, 0, 'security.subtitle', '统一查看登录、操作审计和在线会话；强制下线会立即撤销 Gateway 会话快照', '{"en-US": "Review sign-ins, audit operations, and online sessions. Forced sign-out immediately revokes the Gateway session snapshot."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000830, 0, 'security.summary', '摘要：{detail}', '{"en-US": "Summary: {detail}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000831, 0, 'security.targetId', '资源 ID：', '{"en-US": "Resource ID: "}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000832, 0, 'security.targetType', '资源类型：', '{"en-US": "Resource type: "}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000833, 0, 'security.time', '时间', '{"en-US": "Time"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000834, 0, 'security.title', '安全运营中心', '{"en-US": "Security operations"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000835, 0, 'security.traceId', 'Trace ID', '{"en-US": "Trace ID"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000836, 0, 'security.user', '用户', '{"en-US": "User"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000837, 0, 'security.view', '查看', '{"en-US": "View"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000838, 0, 'starter.authenticationRequired', '未认证或认证已过期', '{"en-US": "Authentication is missing or expired"}', 'starter', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000839, 0, 'starter.permissionDenied', '无操作权限', '{"en-US": "You do not have permission for this operation"}', 'starter', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000840, 0, 'users.actions', '操作', '{"en-US": "Actions"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000841, 0, 'users.batchDisable', '批量停用', '{"en-US": "Disable selected"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000842, 0, 'users.batchDisableConfirm', '确认批量停用所选用户？', '{"en-US": "Disable the selected users?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000843, 0, 'users.batchEnable', '批量启用', '{"en-US": "Enable selected"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000844, 0, 'users.confirmPassword', '确认密码', '{"en-US": "Confirm password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000845, 0, 'users.create', '新建用户', '{"en-US": "Create user"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000846, 0, 'users.created', '用户创建成功', '{"en-US": "User created"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000847, 0, 'users.createdAt', '创建时间', '{"en-US": "Created at"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000848, 0, 'users.disableConfirm', '确认停用该用户？', '{"en-US": "Disable this user?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000849, 0, 'users.disabled', '用户已停用', '{"en-US": "User disabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000850, 0, 'users.displayName', '显示名称', '{"en-US": "Display name"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000851, 0, 'users.downloadTemplate', '下载模板', '{"en-US": "Download template"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000852, 0, 'users.editTitle', '编辑用户{suffix}', '{"en-US": "Edit user{suffix}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000853, 0, 'users.email', '邮箱', '{"en-US": "Email"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000854, 0, 'users.empty', '暂无用户，点击右上角新建', '{"en-US": "No users. Use Create in the upper right."}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000855, 0, 'users.enableConfirm', '确认启用该用户？', '{"en-US": "Enable this user?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000856, 0, 'users.enabled', '用户已启用', '{"en-US": "User enabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000857, 0, 'users.excelImport', 'Excel 导入', '{"en-US": "Import Excel"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000858, 0, 'users.export', '导出', '{"en-US": "Export"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000859, 0, 'users.exportFailed', '导出失败', '{"en-US": "Export failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000860, 0, 'users.importErrorRow', '第 {row} 行 {username}：{message}', '{"en-US": "Row {row}, {username}: {message}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000861, 0, 'users.importFailed', '导入失败', '{"en-US": "Import failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000862, 0, 'users.importResult', '导入完成：成功 {succeeded}，失败 {failed}', '{"en-US": "Import completed: {succeeded} succeeded, {failed} failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000863, 0, 'users.imported', '成功导入 {count} 个用户', '{"en-US": "{count} users imported"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000864, 0, 'users.initialPassword', '初始密码', '{"en-US": "Initial password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000865, 0, 'users.newPassword', '新密码', '{"en-US": "New password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000866, 0, 'users.passwordMismatch', '两次输入的密码不一致', '{"en-US": "The passwords do not match"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000867, 0, 'users.passwordReset', '密码已重置，该用户现有会话已撤销', '{"en-US": "Password reset and the user’s existing sessions revoked"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000868, 0, 'users.resetPassword', '重置密码', '{"en-US": "Reset password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000869, 0, 'users.resetTitle', '重置密码{suffix}', '{"en-US": "Reset password{suffix}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000870, 0, 'users.searchPlaceholder', '用户名或显示名称', '{"en-US": "Username or display name"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000871, 0, 'users.selectedDisabled', '所选用户已停用', '{"en-US": "Selected users disabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000872, 0, 'users.selectedEnabled', '所选用户已启用', '{"en-US": "Selected users enabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000873, 0, 'users.status', '状态', '{"en-US": "Status"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000874, 0, 'users.subtitle', '只管理全局身份；平台权限请到项目管理 → 内置 system 项目分配', '{"en-US": "Manage global identities only. Assign platform permissions in Projects → built-in system project."}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000875, 0, 'users.title', '用户管理', '{"en-US": "Users"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000876, 0, 'users.titleSuffix', '：{username}', '{"en-US": ": {username}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000877, 0, 'users.updated', '用户信息已更新', '{"en-US": "User information updated"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000878, 0, 'users.user', '用户', '{"en-US": "User"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000879, 0, 'users.username', '用户名', '{"en-US": "Username"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000901, 0, 'api.common.badRequest', '请求参数错误', '{"en-US": "Invalid request parameters"}', 'api', 0, 1, 'ENABLED', '未细分的参数校验安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000902, 0, 'api.common.notFound', '请求的资源不存在', '{"en-US": "The requested resource was not found"}', 'api', 0, 1, 'ENABLED', '未细分的资源不存在安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000903, 0, 'api.common.conflict', '当前操作与资源状态冲突', '{"en-US": "The operation conflicts with the current resource state"}', 'api', 0, 1, 'ENABLED', '未细分的状态冲突安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000904, 0, 'api.common.internalError', '服务处理失败，请稍后重试', '{"en-US": "The service could not process the request. Try again later."}', 'api', 0, 1, 'ENABLED', '内部错误安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000905, 0, 'api.common.unauthorized', '未登录或登录已过期', '{"en-US": "Sign-in is required or has expired"}', 'api', 0, 1, 'ENABLED', '认证失败安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000906, 0, 'api.common.upstreamFailed', '上游服务响应异常', '{"en-US": "An upstream service returned an invalid response"}', 'api', 0, 1, 'ENABLED', '上游错误安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000907, 0, 'api.common.serviceUnavailable', '服务暂时不可用，请稍后重试', '{"en-US": "The service is temporarily unavailable. Try again later."}', 'api', 0, 1, 'ENABLED', '服务不可用安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000908, 0, 'api.common.forbidden', '无操作权限', '{"en-US": "You do not have permission for this operation"}', 'api', 0, 1, 'ENABLED', '授权失败安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000909, 0, 'api.common.operationFailed', '操作失败，请稍后重试', '{"en-US": "The operation failed. Try again later."}', 'api', 0, 1, 'ENABLED', '未知业务错误安全回退', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000913, 0, 'i18n.localeCoverage', '语言开放状态', '{"en-US": "Language availability"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000914, 0, 'i18n.available', '可选择', '{"en-US": "Available"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000915, 0, 'i18n.notConfigured', '目录未开放', '{"en-US": "Not enabled in directory"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000916, 0, 'i18n.missingResources', '资源 {count}', '{"en-US": "Resources {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000917, 0, 'i18n.missingMenus', '菜单 {count}', '{"en-US": "Menus {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000918, 0, 'i18n.missingDictionaries', '字典 {count}', '{"en-US": "Dictionary items {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000919, 0, 'api.i18n.htmlForbidden', '国际化资源只允许纯文本', '{"en-US": "Internationalization resources must be plain text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000920, 0, 'api.i18n.jsonInvalid', '多语言译文必须是合法 JSON 对象', '{"en-US": "Translations must be a valid JSON object"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000921, 0, 'api.i18n.keyExists', '国际化资源 key 已存在', '{"en-US": "The internationalization resource key already exists"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000922, 0, 'api.i18n.keyImmutable', '国际化资源 key 创建后不可修改', '{"en-US": "The internationalization resource key cannot be changed after creation"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000923, 0, 'api.i18n.localeInvalid', '包含未启用或重复默认语言', '{"en-US": "Translations contain an unavailable locale or duplicate the default locale"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000924, 0, 'api.i18n.notFound', '国际化资源不存在', '{"en-US": "The internationalization resource was not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000925, 0, 'api.i18n.placeholderMismatch', '译文占位符与默认文案不一致', '{"en-US": "Translation placeholders do not match the default text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000926, 0, 'api.i18n.publicKeyInvalid', '该资源不允许匿名公开', '{"en-US": "This resource cannot be exposed anonymously"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000927, 0, 'api.i18n.translationInvalid', '译文必须是非空文本', '{"en-US": "A translation must be non-empty text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000928, 0, 'api.i18n.versionConflict', '资源已被其他人修改，请刷新后重试', '{"en-US": "The resource was changed by someone else. Refresh and try again"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000929, 0, 'api.i18n.versionRequired', '更新资源必须携带版本', '{"en-US": "Updating a resource requires its version"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000930, 0, 'api.locale.codeInvalid', '语言代码必须是规范 BCP 47 标签', '{"en-US": "The locale must be a canonical BCP 47 language tag"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000931, 0, 'api.i18n.defaultTextTooLong', '默认文案不能超过 2000 个字符', '{"en-US": "Default text cannot exceed 2000 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000932, 0, 'api.i18n.descriptionTooLong', '说明不能超过 512 个字符', '{"en-US": "Description cannot exceed 512 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000933, 0, 'api.i18n.keyInvalid', '资源 key 格式不正确', '{"en-US": "The resource key format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000934, 0, 'api.i18n.moduleInvalid', '模块代码格式不正确', '{"en-US": "The module code format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000935, 0, 'api.i18n.statusInvalid', '资源状态必须是 ENABLED 或 DISABLED', '{"en-US": "Resource status must be ENABLED or DISABLED"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000936, 0, 'api.validation.required', '必填项不能为空', '{"en-US": "This field is required"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000937, 0, 'dicts.localeSelectable', '覆盖完整后允许用户选择', '{"en-US": "Allow users to select after coverage is complete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000938, 0, 'dicts.localeSelectableTip', '即使开启，也只有在资源、菜单和字典译文全部补齐后才会出现在语言选择器', '{"en-US": "Even when enabled, the language appears only after resource, menu, and dictionary translations are complete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000939, 0, 'api.i18n.requiredTranslationMissing', '覆盖必需资源必须为已开放语言 {locales} 提供译文', '{"en-US": "A required resource must provide translations for the available languages: {locales}"}', 'api', 0, 1, 'ENABLED', '阻止管理员用一条缺译资源让整门语言不可选', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000940, 0, 'api.i18n.defaultLocaleNotTranslatable', '默认语言使用原文，无需导入译文', '{"en-US": "The default language uses the source text and needs no translation import"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000941, 0, 'api.i18n.exportFailed', '导出译文失败', '{"en-US": "Failed to export translations"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000942, 0, 'api.i18n.importFileInvalid', '无法解析该 Excel 文件，请确认文件未损坏且大小在 10MB 以内', '{"en-US": "The Excel file could not be parsed. Check that it is not corrupted and is under 10MB."}', 'api', 0, 1, 'ENABLED', '同时用于文件大小超限和解析失败', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000943, 0, 'api.i18n.importSheetMissing', '文件中没有可识别的工作表，请使用导出的模板填写', '{"en-US": "The file contains no recognizable sheet. Fill in the exported template instead."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000944, 0, 'api.i18n.importTooManyRows', '单个工作表不能超过 {limit} 行，请拆分后分批导入', '{"en-US": "A single sheet cannot exceed {limit} rows. Split the file and import in batches."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000951, 0, 'dicts.localeCodeTip', '使用 BCP 47 标签，例如 zh-CN、en-US、ko-KR', '{"en-US": "Use a BCP 47 tag, for example zh-CN, en-US, or ko-KR"}', 'dicts', 0, 1, 'ENABLED', '语言字典取值输入提示', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000952, 0, 'dicts.localeCodeInvalid', '语言代码必须是规范 BCP 47 标签，例如 ko-KR', '{"en-US": "The locale code must be a canonical BCP 47 tag, for example ko-KR"}', 'dicts', 0, 1, 'ENABLED', '语言字典取值前端校验提示', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000961, 0, 'i18n.selectLocale', '选择语言', '{"en-US": "Select a language"}', 'i18n', 0, 1, 'ENABLED', '译文导入导出的目标语言选择', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000962, 0, 'i18n.exportTranslations', '导出译文', '{"en-US": "Export translations"}', 'i18n', 0, 1, 'ENABLED', '导出待翻译内容', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000963, 0, 'i18n.importTranslations', '导入译文', '{"en-US": "Import translations"}', 'i18n', 0, 1, 'ENABLED', '导入已翻译内容', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000000964, 0, 'i18n.importDone', '已导入 {applied} 条译文', '{"en-US": "Imported {applied} translations"}', 'i18n', 0, 1, 'ENABLED', '导入成功提示', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002101, 0, 'i18nKey.enable', '启用国际化', '{"en-US": "Enable localization"}', 'i18n', 0, 0, 'DISABLED', '引用式国际化开关', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002102, 0, 'i18nKey.change', '更换资源', '{"en-US": "Change resource"}', 'i18n', 0, 0, 'DISABLED', '更换引用的资源', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002103, 0, 'i18nKey.pickTitle', '选择国际化资源', '{"en-US": "Select a localization resource"}', 'i18n', 0, 0, 'DISABLED', '资源选择弹窗标题', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002104, 0, 'i18nKey.key', '资源 key', '{"en-US": "Resource key"}', 'i18n', 0, 0, 'DISABLED', '资源 key 列', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002105, 0, 'i18nKey.defaultText', '默认文案', '{"en-US": "Default text"}', 'i18n', 0, 0, 'DISABLED', '默认文案列', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002106, 0, 'i18nKey.module', '模块', '{"en-US": "Module"}', 'i18n', 0, 0, 'DISABLED', '模块列与筛选', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002107, 0, 'i18nKey.searchPlaceholder', '搜索 key 或文案', '{"en-US": "Search key or text"}', 'i18n', 0, 0, 'DISABLED', '资源搜索占位', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002108, 0, 'i18nKey.create', '新建资源', '{"en-US": "New resource"}', 'i18n', 0, 0, 'DISABLED', '就地新建资源', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002109, 0, 'i18nKey.created', '资源已创建', '{"en-US": "Resource created"}', 'i18n', 0, 0, 'DISABLED', '新建成功提示', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002110, 0, 'i18nKey.cancel', '取消', '{"en-US": "Cancel"}', 'i18n', 0, 0, 'DISABLED', '弹窗取消', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002111, 0, 'i18nKey.loadFailed', '国际化资源加载失败', '{"en-US": "Failed to load localization resources"}', 'i18n', 0, 0, 'DISABLED', '资源加载失败提示', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002112, 0, 'configs.i18nKey', '国际化文案', '{"en-US": "Localized text"}', 'configs', 0, 0, 'DISABLED', '配置引用资源字段', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002113, 0, 'configs.i18nKeyHint', '只对直接展示给用户的文案有效；限额、阈值、开关等参与后端校验的值不要启用。', '{"en-US": "Only for text shown to users. Do not enable it for limits, thresholds or switches validated on the server."}', 'configs', 0, 1, 'ENABLED', '配置国际化适用范围说明', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002114, 0, 'menus.i18nKey', '国际化文案', '{"en-US": "Localized text"}', 'menus', 0, 0, 'DISABLED', '菜单引用资源字段', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002115, 0, 'menus.i18nKeyHint', '内置菜单的译文统一在国际化资源里维护，不在这里逐语言填写。', '{"en-US": "Built-in menu translations are maintained in localization resources, not filled in per language here."}', 'menus', 0, 1, 'ENABLED', '菜单国际化说明', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002200, 0, 'localizedName.modeFixed', '独立填写', '{"en-US": "Enter directly", "ja-JP": "直接入力"}', 'i18n', 0, 1, 'ENABLED', '录入模式：固定文案', 3, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002201, 0, 'localizedName.modeReferenced', '引用国际化资源', '{"en-US": "Reference a localization resource", "ja-JP": "国際化リソースを参照"}', 'i18n', 0, 1, 'ENABLED', '录入模式：引用资源', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002202, 0, 'localizedName.fallbackRequired', '请填写默认文案', '{"en-US": "Please provide the default text", "ja-JP": "デフォルトのテキストを入力してください"}', 'i18n', 0, 1, 'ENABLED', '兜底文案必填校验', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002203, 0, 'localizedName.referenced', '已引用', '{"en-US": "Referenced", "ja-JP": "参照中"}', 'i18n', 0, 1, 'ENABLED', '引用状态标签', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002204, 0, 'localizedName.change', '更换资源', '{"en-US": "Change resource", "ja-JP": "リソースを変更"}', 'i18n', 0, 1, 'ENABLED', '更换引用的资源', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002205, 0, 'localizedName.pickResource', '选择资源', '{"en-US": "Select a resource", "ja-JP": "リソースを選択"}', 'i18n', 0, 1, 'ENABLED', '空态：打开选择器', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002206, 0, 'localizedName.createResource', '新建资源', '{"en-US": "New resource", "ja-JP": "リソースを作成"}', 'i18n', 0, 1, 'ENABLED', '就地新建资源', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002207, 0, 'localizedName.pickTitle', '选择国际化资源', '{"en-US": "Select a localization resource", "ja-JP": "国際化リソースを選択"}', 'i18n', 0, 1, 'ENABLED', '资源选择弹窗标题', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002208, 0, 'localizedName.pickKey', '资源 key', '{"en-US": "Resource key", "ja-JP": "リソースキー"}', 'i18n', 0, 1, 'ENABLED', '资源 key 列', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002209, 0, 'localizedName.pickDefault', '默认文案', '{"en-US": "Default text", "ja-JP": "デフォルトのテキスト"}', 'i18n', 0, 1, 'ENABLED', '默认文案列', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002210, 0, 'localizedName.pickModule', '模块', '{"en-US": "Module", "ja-JP": "モジュール"}', 'i18n', 0, 1, 'ENABLED', '模块列与筛选', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002211, 0, 'localizedName.pickSearchPlaceholder', '搜索 key 或文案', '{"en-US": "Search key or text", "ja-JP": "キーまたはテキストを検索"}', 'i18n', 0, 1, 'ENABLED', '资源搜索占位', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002212, 0, 'localizedName.cancel', '取消', '{"en-US": "Cancel", "ja-JP": "キャンセル"}', 'i18n', 0, 1, 'ENABLED', '弹窗取消', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002213, 0, 'localizedName.defaultPreview', '默认显示', '{"en-US": "Default", "ja-JP": "既定"}', 'i18n', 0, 1, 'ENABLED', '默认文案预览标签', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002214, 0, 'localizedName.translationsPreview', '其他语言', '{"en-US": "Other languages", "ja-JP": "他の言語"}', 'i18n', 0, 1, 'ENABLED', '其他语言译文预览标签', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002215, 0, 'localizedName.loadFailed', '国际化资源加载失败', '{"en-US": "Failed to load localization resources", "ja-JP": "国際化リソースの読み込みに失敗しました"}', 'i18n', 0, 1, 'ENABLED', '资源加载失败提示', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002216, 0, 'localizedName.createDone', '资源已创建', '{"en-US": "Resource created", "ja-JP": "リソースを作成しました"}', 'i18n', 0, 1, 'ENABLED', '新建成功提示', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002217, 0, 'localizedName.createFailed', '资源创建失败', '{"en-US": "Failed to create resource", "ja-JP": "リソースの作成に失敗しました"}', 'i18n', 0, 1, 'ENABLED', '新建失败提示', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002218, 0, 'localizedName.createKeyPlaceholder', '例如：module.subject.usage', '{"en-US": "e.g. module.subject.usage", "ja-JP": "例：module.subject.usage"}', 'i18n', 0, 1, 'ENABLED', '新建资源 key 输入占位', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002300, 0, 'dict.common.tag_color.success', '成功（绿）', '{"en-US": "Success (green)", "ja-JP": "成功（緑）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002301, 0, 'dict.common.tag_color.processing', '处理中（蓝）', '{"en-US": "Processing (blue)", "ja-JP": "処理中（青）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002302, 0, 'dict.common.tag_color.warning', '警告（橙）', '{"en-US": "Warning (orange)", "ja-JP": "警告（オレンジ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002303, 0, 'dict.common.tag_color.error', '失败（红）', '{"en-US": "Error (red)", "ja-JP": "エラー（赤）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002304, 0, 'dict.common.tag_color.default', '默认（灰）', '{"en-US": "Default (grey)", "ja-JP": "デフォルト（グレー）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002305, 0, 'dict.common.tag_color.purple', '紫（类别）', '{"en-US": "Purple (category)", "ja-JP": "パープル（カテゴリ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002306, 0, 'dict.common.tag_color.cyan', '青（类别）', '{"en-US": "Cyan (category)", "ja-JP": "シアン（カテゴリ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002310, 0, 'dicts.extraKey', '键', '{"en-US": "Key", "ja-JP": "キー"}', 'dicts', 0, 1, 'ENABLED', '扩展配置键输入占位', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002311, 0, 'dicts.extraValue', '值', '{"en-US": "Value", "ja-JP": "値"}', 'dicts', 0, 1, 'ENABLED', '扩展配置值输入占位', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000002312, 0, 'dicts.extraAdd', '添加一项', '{"en-US": "Add entry", "ja-JP": "項目を追加"}', 'dicts', 0, 1, 'ENABLED', '扩展配置新增按钮', 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000003001, 0, 'dict.platform.locale.zh-CN', '简体中文', '{"en-US": "Simplified Chinese"}', 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000003002, 0, 'dict.platform.locale.en-US', '英语（美国）', '{"en-US": "English (US)"}', 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000003101, 0, 'api.i18n.keyNotFound', '国际化资源不存在：{key}', '{"en-US": "The internationalization resource does not exist: {key}", "ja-JP": "国際化リソースが存在しません：{key}"}', 'api', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102900, 0, 'dictType.ai.test.status', '大模型连通测试状态', '{"en-US": "AI connectivity test status", "ja-JP": "AI 接続テスト状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：ai.test.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102901, 0, 'dictType.common.boolean_enabled', '是否启用', '{"en-US": "Enabled option", "ja-JP": "有効化するか"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.boolean_enabled', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102902, 0, 'dictType.common.status', '通用启停状态', '{"en-US": "General enablement status", "ja-JP": "共通有効・無効状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102903, 0, 'dictType.common.tag_color', '标签颜色', '{"en-US": "Tag color", "ja-JP": "タグの色"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.tag_color', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102904, 0, 'dictType.config.value.type', '配置值类型', '{"en-US": "Configuration value type", "ja-JP": "設定値の種類"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：config.value.type', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102906, 0, 'dictType.notification.type', '站内信分类', '{"en-US": "Notification type", "ja-JP": "通知の種類"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：notification.type', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102907, 0, 'dictType.platform.locale', '平台语言', '{"en-US": "Platform language", "ja-JP": "プラットフォーム言語"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.locale', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102908, 0, 'dictType.platform.menu.type', '平台菜单类型', '{"en-US": "Platform menu type", "ja-JP": "プラットフォームメニュー種別"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.menu.type', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102909, 0, 'dictType.project.generation.mode', '项目生成方式', '{"en-US": "Project generation mode", "ja-JP": "プロジェクト生成方式"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.mode', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102910, 0, 'dictType.project.generation.status', '项目生成状态', '{"en-US": "Project generation status", "ja-JP": "プロジェクト生成状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102912, 0, 'dictType.project.member.status', '项目成员状态', '{"en-US": "Project member status", "ja-JP": "プロジェクトメンバー状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.member.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102914, 0, 'dictType.project.status', '业务项目状态', '{"en-US": "Business project status", "ja-JP": "業務プロジェクト状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102915, 0, 'dictType.scheduler.execution.status', '定时任务执行状态', '{"en-US": "Scheduled task execution status", "ja-JP": "定期タスク実行状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：scheduler.execution.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102916, 0, 'dictType.security.login.status', '登录日志状态', '{"en-US": "Sign-in log status", "ja-JP": "ログイン履歴状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.login.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102917, 0, 'dictType.security.session.status', '在线会话状态', '{"en-US": "Online session status", "ja-JP": "オンラインセッション状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.session.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102918, 0, 'dictType.user.status', '平台用户状态', '{"en-US": "Platform user status", "ja-JP": "プラットフォームユーザー状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：user.status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102921, 0, 'menu.system.permission.system.platform.read', '验证平台访问', '{"en-US": "Validate platform access", "ja-JP": "プラットフォームアクセスを検証"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:platform:read', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102922, 0, 'menu.system.permission.system.user.list', '查询用户', '{"en-US": "View users", "ja-JP": "ユーザーを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102923, 0, 'menu.system.permission.system.user.create', '创建用户', '{"en-US": "Create user", "ja-JP": "ユーザーを作成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:create', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102924, 0, 'menu.system.permission.system.user.update', '编辑用户', '{"en-US": "Edit user", "ja-JP": "ユーザーを編集"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:update', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102925, 0, 'menu.system.permission.system.user.status', '启停用户', '{"en-US": "Enable or disable user", "ja-JP": "ユーザーを有効または無効にする"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102926, 0, 'menu.system.permission.system.user.reset-password', '重置密码', '{"en-US": "Reset password", "ja-JP": "パスワードをリセット"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:reset-password', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102927, 0, 'menu.system.permission.system.project.list', '查询项目', '{"en-US": "View projects", "ja-JP": "プロジェクトを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102928, 0, 'menu.system.permission.system.project.create', '创建项目', '{"en-US": "Create project", "ja-JP": "プロジェクトを作成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:create', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102929, 0, 'menu.system.permission.system.project.update', '编辑项目', '{"en-US": "Edit project", "ja-JP": "プロジェクトを編集"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:update', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102930, 0, 'menu.system.permission.system.project.status', '变更项目状态', '{"en-US": "Change project status", "ja-JP": "プロジェクト状態を変更"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:status', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102931, 0, 'menu.system.permission.system.project.member', '管理项目成员', '{"en-US": "Manage project members", "ja-JP": "プロジェクトメンバーを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:member', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102932, 0, 'menu.system.permission.system.project.role', '管理项目角色', '{"en-US": "Manage project roles", "ja-JP": "プロジェクトロールを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:role', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102933, 0, 'menu.system.permission.system.project.menu', '管理项目菜单', '{"en-US": "Manage project menus", "ja-JP": "プロジェクトメニューを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:menu', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102934, 0, 'menu.system.permission.system.config.list', '查询配置', '{"en-US": "View configurations", "ja-JP": "設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102935, 0, 'menu.system.permission.system.config.save', '保存配置', '{"en-US": "Save configuration", "ja-JP": "設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102936, 0, 'menu.system.permission.system.config.delete', '删除配置', '{"en-US": "Delete configuration", "ja-JP": "設定を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:delete', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102937, 0, 'menu.system.permission.system.dict.list', '查询字典', '{"en-US": "View dictionaries", "ja-JP": "辞書を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102938, 0, 'menu.system.permission.system.dict.save', '保存字典', '{"en-US": "Save dictionary", "ja-JP": "辞書を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102939, 0, 'menu.system.permission.system.dict.delete', '删除字典', '{"en-US": "Delete dictionary", "ja-JP": "辞書を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:delete', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102940, 0, 'menu.system.permission.system.project-factory.list', '查看项目生成', '{"en-US": "View project generations", "ja-JP": "プロジェクト生成を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102941, 0, 'menu.system.permission.system.project-factory.generate', '生成项目', '{"en-US": "Generate project", "ja-JP": "プロジェクトを生成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:generate', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102942, 0, 'menu.system.permission.system.project-factory.download', '下载项目制品', '{"en-US": "Download project artifact", "ja-JP": "プロジェクト成果物をダウンロード"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:download', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102943, 0, 'menu.system.permission.system.project-factory.push', '初始推送 GitLab', '{"en-US": "Initial GitLab push", "ja-JP": "GitLab へ初回プッシュ"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:push', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102944, 0, 'menu.system.permission.system.ai.list', '查看大模型配置', '{"en-US": "View AI provider configuration", "ja-JP": "AI プロバイダー設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102945, 0, 'menu.system.permission.system.ai.save', '保存大模型配置', '{"en-US": "Save AI provider configuration", "ja-JP": "AI プロバイダー設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102946, 0, 'menu.system.permission.system.ai.test', '测试大模型连接', '{"en-US": "Test AI provider connection", "ja-JP": "AI プロバイダー接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:test', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102947, 0, 'menu.system.permission.system.git.list', '查看 GitLab 配置', '{"en-US": "View GitLab configuration", "ja-JP": "GitLab 設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102948, 0, 'menu.system.permission.system.git.save', '保存 GitLab 配置', '{"en-US": "Save GitLab configuration", "ja-JP": "GitLab 設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102949, 0, 'menu.system.permission.system.git.test', '测试 GitLab 连接', '{"en-US": "Test GitLab connection", "ja-JP": "GitLab 接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:test', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102950, 0, 'menu.system.permission.system.scheduler.list', '查看定时任务', '{"en-US": "View scheduled tasks", "ja-JP": "定期タスクを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102951, 0, 'menu.system.permission.system.scheduler.save', '保存定时任务', '{"en-US": "Save scheduled task", "ja-JP": "定期タスクを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102952, 0, 'menu.system.permission.system.scheduler.credential', '轮换项目调度凭据', '{"en-US": "Rotate project scheduler credential", "ja-JP": "プロジェクトスケジューラー認証情報をローテーション"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:credential', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102953, 0, 'menu.system.permission.system.audit.list', '查看审计日志', '{"en-US": "View audit logs", "ja-JP": "監査ログを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:audit:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102954, 0, 'menu.system.permission.system.session.list', '查看在线会话', '{"en-US": "View online sessions", "ja-JP": "オンラインセッションを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:session:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102955, 0, 'menu.system.permission.system.session.force-offline', '强制用户下线', '{"en-US": "Force user sign-out", "ja-JP": "ユーザーを強制ログアウト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:session:force-offline', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102956, 0, 'menu.system.permission.system.org.list', '查看组织架构', '{"en-US": "View organization", "ja-JP": "組織を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102957, 0, 'menu.system.permission.system.org.save', '维护部门', '{"en-US": "Maintain department", "ja-JP": "部門を管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102958, 0, 'menu.system.permission.system.org.delete', '删除部门', '{"en-US": "Delete department", "ja-JP": "部門を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:delete', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102959, 0, 'menu.system.permission.system.org.assign', '分配用户部门', '{"en-US": "Assign users to department", "ja-JP": "ユーザーを部門に割り当て"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:assign', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102960, 0, 'menu.system.permission.system.i18n.list', '查询国际化资源', '{"en-US": "View internationalization resources", "ja-JP": "国際化リソースを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:list', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102961, 0, 'menu.system.permission.system.i18n.save', '保存国际化资源', '{"en-US": "Save internationalization resources", "ja-JP": "国際化リソースを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:save', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102962, 0, 'menu.system.permission.system.i18n.delete', '删除国际化资源', '{"en-US": "Delete internationalization resources", "ja-JP": "国際化リソースを削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:delete', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000102963, 0, 'menu.system.permission.system.project.health', '项目体检', '{"en-US": "Project health check", "ja-JP": "プロジェクト健全性チェック"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:health', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103000, 0, 'dictType.security.audit.module', '审计模块', '{"en-US": "Audit module", "ja-JP": "監査モジュール"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.audit.module', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103001, 0, 'dict.security.audit.module.user', '用户管理', '{"en-US": "Users", "ja-JP": "ユーザー管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103002, 0, 'dict.security.audit.module.role', '角色管理', '{"en-US": "Roles", "ja-JP": "ロール管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103003, 0, 'dict.security.audit.module.menu', '菜单管理', '{"en-US": "Menus", "ja-JP": "メニュー管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103004, 0, 'dict.security.audit.module.org', '组织架构', '{"en-US": "Organization", "ja-JP": "組織構成"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103005, 0, 'dict.security.audit.module.metadata', '配置与字典', '{"en-US": "Configuration and dictionaries", "ja-JP": "設定と辞書"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103006, 0, 'dict.security.audit.module.i18n', '国际化资源', '{"en-US": "Localization resources", "ja-JP": "多言語リソース"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103007, 0, 'dict.security.audit.module.project', '项目管理', '{"en-US": "Projects", "ja-JP": "プロジェクト管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103008, 0, 'dict.security.audit.module.project-factory', '项目工厂', '{"en-US": "Project factory", "ja-JP": "プロジェクトファクトリ"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103009, 0, 'dict.security.audit.module.scheduler', '定时任务', '{"en-US": "Scheduled tasks", "ja-JP": "定期タスク"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103010, 0, 'dict.security.audit.module.gitlab', 'GitLab 配置', '{"en-US": "GitLab configuration", "ja-JP": "GitLab 設定"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103011, 0, 'dict.security.audit.module.ai', '大模型配置', '{"en-US": "AI provider configuration", "ja-JP": "AI プロバイダー設定"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9100000000000103012, 0, 'dict.security.audit.module.security', '安全运营', '{"en-US": "Security operations", "ja-JP": "セキュリティ運用"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000000001, 0, 'dicts.dragSort', '拖动调整顺序', '{"en-US": "Drag to reorder", "ja-JP": "ドラッグして並べ替え"}', 'dicts', 0, 1, 'ENABLED', '字典管理拖拽手柄的提示', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000000002, 0, 'dicts.sortSaved', '顺序已保存', '{"en-US": "Order saved", "ja-JP": "並び順を保存しました"}', 'dicts', 0, 1, 'ENABLED', '字典管理拖拽排序成功提示', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004001, 0, 'projects.serviceUrl', '服务地址', '{"en-US": "Service URL", "ja-JP": "サービス URL"}', 'projects', 0, 1, 'ENABLED', 'Gateway PROJECT 路由上游', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004002, 0, 'projects.serviceUrlHelp', '按部署形态填写：K8s/Compose 用服务名，单实例用 http://主机:端口，Nacos 用 lb://服务名', '{"en-US": "Depends on deployment: service DNS for K8s/Compose, http://host:port for a single instance, lb://name for Nacos", "ja-JP": "デプロイ形態に応じて入力してください"}', 'projects', 0, 1, 'ENABLED', '服务地址填写说明', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004003, 0, 'api.project.serviceUrlRequired', '请先登记项目的服务地址', '{"en-US": "Register the project service URL first", "ja-JP": "先にサービス URL を登録してください"}', 'api', 0, 1, 'ENABLED', '生成 Gateway 路由前置校验', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004010, 0, 'projects.gatewayRoute', '网关路由', '{"en-US": "Gateway route", "ja-JP": "ゲートウェイルート"}', 'projects', 0, 1, 'ENABLED', '查看该项目的显式路由片段', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004011, 0, 'projects.gatewayRoute.hint', '把下面的片段放进受管 Gateway 配置的 routes 下。服务注册不等于对外发布，没有这段显式路由的服务不能从外部访问。', '{"en-US": "Add the snippet below to the routes of the managed Gateway config. Registering a service does not publish it; without an explicit route it stays unreachable from outside.", "ja-JP": "以下の断片を管理対象 Gateway 設定の routes に追加してください。"}', 'projects', 0, 1, 'ENABLED', '路由片段说明', 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004012, 0, 'projects.gatewayRoute.copy', '复制片段', '{"en-US": "Copy snippet", "ja-JP": "断片をコピー"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004013, 0, 'projects.gatewayRoute.copied', '已复制到剪贴板', '{"en-US": "Copied to clipboard", "ja-JP": "クリップボードにコピーしました"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004014, 0, 'projects.gatewayRoute.copyFailed', '复制失败，请手动选中复制', '{"en-US": "Copy failed, please select and copy manually", "ja-JP": "コピーに失敗しました"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004020, 0, 'layout.project.openMode.inline', '当前页面', '{"en-US": "Current page"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004021, 0, 'layout.project.openMode.newTab', '新标签页', '{"en-US": "New tab"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004022, 0, 'layout.project.loadingEntry', '正在进入项目后台…', '{"en-US": "Opening the project console…"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004023, 0, 'layout.project.entryUnavailable', '该项目暂无可用的后台入口', '{"en-US": "This project has no console entry yet"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004024, 0, 'layout.project.backToPlatform', '返回 Kaiwu 平台', '{"en-US": "Back to the Kaiwu platform"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004030, 0, 'menu.system.permission.system.agent.ask', 'AI 助手', '{"en-US": "AI assistant"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004031, 0, 'agent.dock.title', 'AI 助手', '{"en-US": "AI assistant"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004032, 0, 'agent.dock.placeholder', '问点什么，例如：我参与的项目这周有哪些生成失败', '{"en-US": "Ask something, e.g. which generation tasks failed this week"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004033, 0, 'agent.dock.send', '发送', '{"en-US": "Send"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004034, 0, 'agent.dock.thinking', '正在查询…', '{"en-US": "Working on it…"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004035, 0, 'agent.dock.empty', '可以问我平台上的项目、生成任务和定时任务。', '{"en-US": "Ask me about projects, generation tasks and scheduled jobs."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004036, 0, 'agent.dock.dataAt', '数据时间', '{"en-US": "Data as of"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004037, 0, 'agent.degraded.PROVIDER_UNAVAILABLE', 'AI 助手当前不可用，请联系管理员配置大模型 Provider。', '{"en-US": "The AI assistant is unavailable. Ask an administrator to configure a model provider."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004038, 0, 'agent.degraded.RATE_LIMITED', '请求过于频繁，请稍后再试。', '{"en-US": "Too many requests. Please try again shortly."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004039, 0, 'agent.degraded.PLAN_INVALID', '没能理解这个问题，换个说法试试。', '{"en-US": "I could not work out what to query. Try rephrasing."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004040, 0, 'agent.degraded.PARTIAL_CAPABILITY_FAILURE', '部分数据暂时取不到，以下是已取到的结果。', '{"en-US": "Some data could not be retrieved. Here is what came back."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004100, 0, 'agent.registry.entry', 'Agent 能力', '{"en-US": "Agent capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004101, 0, 'agent.registry.title', 'Agent 能力：{name}', '{"en-US": "Agent capabilities: {name}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004102, 0, 'agent.registry.intro', '仅目标项目管理员可管理能力。先签发独立凭据并配置到业务服务，再核对清单、逐版审批。', '{"en-US": "Only target project administrators can manage capabilities. Issue a credential, configure the service, then review each manifest version."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004103, 0, 'agent.registry.boundary', '能力需逐版审批；聊天执行还受在线状态、项目权限和部署开关控制。', '{"en-US": "Review each capability version. Chat execution also requires an online handler, project permission, and deployment switches."}', 'agent', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004104, 0, 'agent.registry.empty', '尚无能力注册。业务服务启用 Agent 客户端并声明能力后会出现在这里。', '{"en-US": "No capabilities registered. Enable the Agent client and declare capabilities in the business service."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004105, 0, 'agent.registry.refresh', '刷新状态', '{"en-US": "Refresh"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004106, 0, 'agent.registry.issue', '签发 / 轮换凭据', '{"en-US": "Issue / rotate credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004107, 0, 'agent.registry.rotateConfirm', '轮换后旧凭据立即失效，已批准能力需要重新注册和审批。继续？', '{"en-US": "Rotation invalidates the previous credential and resets approvals. Continue?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004108, 0, 'agent.registry.revokeCredential', '撤销注册凭据', '{"en-US": "Revoke credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004109, 0, 'agent.registry.revokeCredentialConfirm', '撤销凭据及该项目所有能力？业务服务将停止注册。', '{"en-US": "Revoke the credential and all project capabilities? The service will stop registering."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004110, 0, 'agent.registry.credentialTitle', '保存注册凭据', '{"en-US": "Save registration credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004111, 0, 'agent.registry.credentialHint', '凭据只在本次响应提供。请保存到业务服务的秘密配置中，关闭后无法再次查看；轮换后需更新配置并重启客户端。', '{"en-US": "This credential is returned once. Save it in service secret configuration. After rotation, update configuration and restart the client."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004112, 0, 'agent.registry.credentialLabel', 'Agent 注册凭据', '{"en-US": "Agent registration credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004113, 0, 'agent.registry.copy', '复制凭据', '{"en-US": "Copy credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004114, 0, 'agent.registry.copied', '凭据已复制', '{"en-US": "Credential copied"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004115, 0, 'agent.registry.close', '关闭', '{"en-US": "Close"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004116, 0, 'agent.registry.code', '能力编码', '{"en-US": "Capability code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004117, 0, 'agent.registry.version', '版本', '{"en-US": "Version"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004118, 0, 'agent.registry.status', '审批状态', '{"en-US": "Review status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004119, 0, 'agent.registry.online', '连接状态', '{"en-US": "Connection"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004120, 0, 'agent.registry.lastSeen', '最近心跳', '{"en-US": "Last heartbeat"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004121, 0, 'agent.registry.actions', '操作', '{"en-US": "Actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004122, 0, 'agent.registry.detail', '查看清单 / 审核', '{"en-US": "View / review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004123, 0, 'agent.registry.manifest', '完整能力清单', '{"en-US": "Full capability manifest"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004124, 0, 'agent.registry.hash', '清单摘要', '{"en-US": "Manifest digest"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004125, 0, 'agent.registry.approve', '批准只读能力', '{"en-US": "Approve read-only capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004126, 0, 'agent.registry.approveConfirm', '已核对权限、参数和输出字段，并确认该实现只读取数据？', '{"en-US": "Have you checked permissions, parameters and output fields, and confirmed the implementation is read-only?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004127, 0, 'agent.registry.revoke', '撤销能力', '{"en-US": "Revoke capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004128, 0, 'agent.registry.revokeConfirm', '撤销这一版能力？客户端需停止，重新开放后还需重新审批。', '{"en-US": "Revoke this capability version? Restart the client after reopening and review again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004129, 0, 'agent.registry.reopen', '重新开放待审核', '{"en-US": "Reopen for review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004130, 0, 'agent.registry.reopenConfirm', '恢复为待审核？请重启客户端刷新心跳，再重新核对清单。', '{"en-US": "Restore pending review? Restart the client to refresh heartbeat, then review the manifest again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004131, 0, 'agent.registry.approvalHint', '只有在线的待审核清单可以批准。操作绑定当前展示的版本及摘要，变更后请刷新重审。', '{"en-US": "Only online, pending manifests can be approved. Approval binds to the displayed version and digest; refresh and review again after a change."}', 'agent', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004132, 0, 'agent.registry.updated', '操作成功，状态已更新', '{"en-US": "Operation succeeded"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004133, 0, 'agent.registry.failed', '操作失败，请刷新状态后再试', '{"en-US": "Operation failed. Refresh the state before trying again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004134, 0, 'agent.registry.loadFailed', '无法读取能力，请确认你同时具备平台项目权限和本项目管理员角色。', '{"en-US": "Cannot load capabilities. Check platform project permission and target project administrator membership."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004135, 0, 'agent.registry.unknownOutcome', '请求失败，凭据可能已经轮换。请重新签发并更新业务服务配置，不要继续使用旧凭据。', '{"en-US": "The request failed and the credential may have rotated. Issue a new one and update the service configuration."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004136, 0, 'dict.agent.capability.status.PENDING', '待审核', '{"en-US": "Pending"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004137, 0, 'dict.agent.capability.status.APPROVED', '已批准', '{"en-US": "Approved"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004138, 0, 'dict.agent.capability.status.REVOKED', '已撤销', '{"en-US": "Revoked"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004139, 0, 'dict.agent.capability.connection.ONLINE', '在线', '{"en-US": "Online"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004140, 0, 'dict.agent.capability.connection.OFFLINE', '离线', '{"en-US": "Offline"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004200, 0, 'agent.action.title', '创建项目预览', '{"en-US": "Project creation preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004201, 0, 'agent.action.projectName', '项目名称', '{"en-US": "Project name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004202, 0, 'agent.action.projectCode', '项目编码', '{"en-US": "Project code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004203, 0, 'agent.action.packageName', '基础包名', '{"en-US": "Base package"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004204, 0, 'agent.action.description', '描述', '{"en-US": "Description"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004205, 0, 'agent.action.impact', '将创建一个项目，并将当前用户设为该项目管理员。', '{"en-US": "Creates one project and makes the current user its project administrator."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004206, 0, 'agent.action.pendingHint', '尚未执行。请核对以上信息，点击确认才会创建；在聊天中回复“确认”不会执行。', '{"en-US": "Not executed. Review these details and click Confirm to create. A chat reply does not execute the action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004207, 0, 'agent.action.noToken', '此预览已不能再次确认。请先取消，再重新提问生成预览。', '{"en-US": "This preview cannot be confirmed again. Cancel it before requesting a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004208, 0, 'agent.action.expiresIn', '{seconds} 秒后过期', '{"en-US": "Expires in {seconds} seconds"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004209, 0, 'agent.action.confirm', '确认创建项目', '{"en-US": "Confirm project creation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004210, 0, 'agent.action.cancel', '取消此操作', '{"en-US": "Cancel this action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004211, 0, 'agent.action.refresh', '查询操作状态', '{"en-US": "Check action status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004212, 0, 'agent.action.projects', '前往项目管理', '{"en-US": "Open project management"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004213, 0, 'agent.action.unknownHint', '操作正在执行或结果尚不明确。请查询状态或前往项目管理核验，不要重复提交。', '{"en-US": "The action is executing or its outcome is uncertain. Check its status or project management; do not resubmit."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004214, 0, 'agent.action.conflict', '项目编码已存在，本次没有创建新项目。请核验项目列表后再决定是否使用其他编码。', '{"en-US": "The project code already exists; no new project was created. Check the project list before choosing another code."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004215, 0, 'agent.action.failedHint', '操作未完成。请核验当前权限和项目状态，再重新发起预览。', '{"en-US": "The action did not complete. Check permissions and project status before requesting another preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004216, 0, 'agent.action.expiredHint', '预览已过期，请重新提问生成新预览。', '{"en-US": "This preview has expired. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004217, 0, 'agent.action.successHint', '项目已创建，可前往项目管理继续配置。', '{"en-US": "Project created. Continue configuring it in project management."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004218, 0, 'agent.action.requestFailed', '请求失败，请查询操作状态。', '{"en-US": "Request failed. Check the action status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004219, 0, 'api.agent.actionUnavailable', '操作状态暂不可用，请查询状态，勿重复创建', '{"en-US": "Action state is unavailable. Check status; do not repeat project creation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004220, 0, 'api.agent.actionForbidden', '当前无权执行此操作，请重新发起', '{"en-US": "You are not currently authorized to perform this action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004221, 0, 'api.agent.actionNotFound', '操作不存在或不可用，请重新发起', '{"en-US": "Action not found or unavailable. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004222, 0, 'api.agent.actionParameters', '项目参数不完整或格式错误，请补充项目编码与名称', '{"en-US": "Project parameters are missing or invalid. Provide a valid project code and name."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004223, 0, 'dict.agent.action.status.PENDING', '待确认', '{"en-US": "Pending confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004224, 0, 'dict.agent.action.status.EXECUTING', '执行中', '{"en-US": "Executing"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004225, 0, 'dict.agent.action.status.SUCCEEDED', '已创建', '{"en-US": "Created"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004226, 0, 'dict.agent.action.status.FAILED', '执行失败', '{"en-US": "Failed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004227, 0, 'dict.agent.action.status.CANCELLED', '已取消', '{"en-US": "Cancelled"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004228, 0, 'dict.agent.action.status.EXPIRED', '已过期', '{"en-US": "Expired"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004229, 0, 'dict.agent.action.status.REJECTED', '已拒绝', '{"en-US": "Rejected"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004230, 0, 'dict.agent.action.status.UNKNOWN', '结果待核验', '{"en-US": "Outcome uncertain"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004400, 0, 'agent.remoteAction.title', '子项目操作预览', '{"en-US": "Project action preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004401, 0, 'agent.remoteAction.project', '所属项目', '{"en-US": "Project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004402, 0, 'agent.remoteAction.affectedCount', '预计影响数量', '{"en-US": "Estimated affected items"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004403, 0, 'agent.remoteAction.pendingHint', '此操作尚未执行', '{"en-US": "This action has not run"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004404, 0, 'agent.remoteAction.reviewHint', '请核对业务系统返回的预览，再点击确认；在聊天中回复“确认”不会执行。', '{"en-US": "Review the business preview before confirming. A chat reply does not execute the action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004405, 0, 'agent.remoteAction.noToken', '确认凭证已失效，请重新发起预览。', '{"en-US": "Confirmation is no longer available. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004406, 0, 'agent.remoteAction.strongPrompt', '输入确认语', '{"en-US": "Type confirmation phrase"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004407, 0, 'agent.remoteAction.strongPlaceholder', '请输入：{phrase}', '{"en-US": "Type: {phrase}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004408, 0, 'agent.remoteAction.expiresIn', '{seconds} 秒后过期', '{"en-US": "Expires in {seconds} seconds"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004409, 0, 'agent.remoteAction.unknownHint', '执行结果尚未确认。只能查询状态，不要重复提交。', '{"en-US": "The outcome is uncertain. Check status; do not submit again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004410, 0, 'agent.remoteAction.failedHint', '操作未完成，请核验权限及业务状态后重新发起预览。', '{"en-US": "The action did not complete. Check permissions and business state before requesting a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004411, 0, 'agent.remoteAction.expiredHint', '预览已过期，请重新发起。', '{"en-US": "The preview expired. Request a new one."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004412, 0, 'agent.remoteAction.successHint', '操作已完成。', '{"en-US": "Action completed."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004413, 0, 'agent.remoteAction.result', '执行结果', '{"en-US": "Result"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004414, 0, 'agent.remoteAction.confirm', '确认执行', '{"en-US": "Confirm action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004415, 0, 'agent.remoteAction.cancel', '取消操作', '{"en-US": "Cancel action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004416, 0, 'agent.remoteAction.refresh', '查询操作状态', '{"en-US": "Check action status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004417, 0, 'agent.remoteAction.projects', '前往项目管理', '{"en-US": "Open project management"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004418, 0, 'agent.remoteAction.requestFailed', '请求失败，请查询操作状态。', '{"en-US": "Request failed. Check action status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004419, 0, 'dict.agent.remote_action.status.PENDING', '待确认', '{"en-US": "Pending confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004420, 0, 'dict.agent.remote_action.status.EXECUTING', '执行中', '{"en-US": "Executing"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004421, 0, 'dict.agent.remote_action.status.SUCCEEDED', '已完成', '{"en-US": "Completed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004422, 0, 'dict.agent.remote_action.status.FAILED', '执行失败', '{"en-US": "Failed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004423, 0, 'dict.agent.remote_action.status.CANCELLED', '已取消', '{"en-US": "Cancelled"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004424, 0, 'dict.agent.remote_action.status.EXPIRED', '已过期', '{"en-US": "Expired"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004425, 0, 'dict.agent.remote_action.status.REJECTED', '已拒绝', '{"en-US": "Rejected"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004426, 0, 'dict.agent.remote_action.status.UNKNOWN', '结果待核验', '{"en-US": "Outcome uncertain"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004500, 0, 'agent.registry.approveWrite', '批准写能力', '{"en-US": "Approve write capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004501, 0, 'agent.registry.approveWriteConfirm', '已核对业务实现、权限、预览、确认和同事务幂等账本，批准此版本写能力？实际执行仍需单独启用。', '{"en-US": "Have you reviewed the handler, authorization, preview, confirmation, and transactional idempotency ledger? Approve this version? Execution still requires separate enablement."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004502, 0, 'agent.registry.writeApprovalHint', '批准写能力前，须核对业务 Handler 的领域权限、只读预览、同事务幂等账本和确认等级。批准不会打开执行开关。', '{"en-US": "Before approving a write capability, review the handler authorization, read-only preview, transactional idempotency ledger, and confirmation level. Approval does not enable execution."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004700, 0, 'agent.registry.batchApprove', '批量批准只读能力（{count}）', '{"en-US": "Approve read-only capabilities ({count})"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004701, 0, 'agent.registry.batchReviewTitle', '批量审核 {count} 项能力', '{"en-US": "Review {count} capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004702, 0, 'agent.registry.batchReviewHint', '请逐项展开并核对权限、参数、输出字段和只读实现。整批绑定当前版本及摘要；任一项变化则整批不批准。写能力仍需逐项审核。', '{"en-US": "Expand and review each permission, parameter, output field, and read-only implementation. The batch binds to current versions and digests; any change rejects the whole batch. Review write capabilities individually."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004703, 0, 'agent.registry.batchAcknowledge', '我已逐项核对以上完整清单，同意批准所选只读能力', '{"en-US": "I have reviewed every full manifest and approve these read-only capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004704, 0, 'agent.registry.batchChanged', '所选能力已变化或包含非只读能力，请刷新后重新选择', '{"en-US": "A selected capability changed or is not read-only. Refresh and select again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004705, 0, 'agent.registry.batchMax', '每次最多审核 50 项能力', '{"en-US": "Review at most 50 capabilities at a time"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004800, 0, 'agent.local.intro', 'System 是内置项目，Agent 能力由平台代码提供，无需签发项目凭据或逐项审批。', '{"en-US": "System is built in. Its Agent capabilities are provided by platform code and require no project credential or approval."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004801, 0, 'agent.local.scope', '下表仅列出已实现的 System 能力。聊天只会看到当前账号有权使用的能力；具体操作执行前还会重新鉴权。', '{"en-US": "This table lists implemented System capabilities. Chat only sees capabilities allowed for this account; permission is checked again before execution."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004802, 0, 'agent.local.refresh', '刷新', '{"en-US": "Refresh"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004803, 0, 'agent.local.loadFailed', '加载 System Agent 能力失败', '{"en-US": "Failed to load System Agent capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004804, 0, 'agent.local.empty', '暂无已实现的 System Agent 能力', '{"en-US": "No System Agent capabilities implemented yet"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004805, 0, 'agent.local.code', '能力编码', '{"en-US": "Capability code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004806, 0, 'agent.local.description', '功能', '{"en-US": "Function"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004807, 0, 'agent.local.permission', '所需权限', '{"en-US": "Required permission"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004808, 0, 'agent.local.mode', '执行方式', '{"en-US": "Execution mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004809, 0, 'agent.local.readOnly', '只读', '{"en-US": "Read-only"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004810, 0, 'agent.local.confirmation', '确认后执行', '{"en-US": "Requires confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004811, 0, 'agent.local.availability', '当前账号', '{"en-US": "This account"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004812, 0, 'agent.local.allowed', '有权限', '{"en-US": "Allowed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004813, 0, 'agent.local.denied', '无权限', '{"en-US": "No permission"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004814, 0, 'agent.local.note', '没有对应权限时，直接向 AI 助手提出该操作会收到无权限提示。', '{"en-US": "Asking the AI assistant to perform an unauthorized operation returns a permission denial."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004900, 0, 'agent.input.title', '补充项目信息', '{"en-US": "Complete project information"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004901, 0, 'agent.input.hint', '填写后生成创建预览，核对并确认后才会创建项目。', '{"en-US": "Fill in the form to preview the project. Creation requires a separate confirmation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004902, 0, 'agent.input.projectCode', '项目编码', '{"en-US": "Project code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004903, 0, 'agent.input.projectName', '项目名称', '{"en-US": "Project name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004904, 0, 'agent.input.packageName', '基础包名（选填）', '{"en-US": "Base package (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004905, 0, 'agent.input.description', '描述（选填）', '{"en-US": "Description (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004906, 0, 'agent.input.required', '请填写此项', '{"en-US": "This field is required"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004907, 0, 'agent.input.projectCodeInvalid', '使用 2–64 位小写字母、数字或连字符，以字母开头', '{"en-US": "Use 2–64 lowercase letters, digits or hyphens, starting with a letter"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004908, 0, 'agent.input.packageNameInvalid', '请输入有效包名，例如 com.example.orders', '{"en-US": "Enter a valid package name, e.g. com.example.orders"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004909, 0, 'agent.input.submit', '生成预览', '{"en-US": "Preview project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004910, 0, 'agent.input.cancel', '取消填写', '{"en-US": "Cancel form"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004911, 0, 'agent.input.cancelled', '已取消填写，可重新提出操作请求。', '{"en-US": "Form cancelled. You can start a new request."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004912, 0, 'agent.input.denied', '无权限操作', '{"en-US": "You do not have permission to perform this operation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000004913, 0, 'agent.input.failed', '未能生成预览，请检查填写内容后重试。', '{"en-US": "Unable to generate a preview. Check the form and try again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005000, 0, 'agent.projects.title', '查看项目列表', '{"en-US": "View project list"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005001, 0, 'agent.projects.search', '搜索项目名称或编码', '{"en-US": "Search project name or code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005002, 0, 'agent.projects.failed', '加载项目列表失败，请重试', '{"en-US": "Unable to load projects. Please retry."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005003, 0, 'agent.projects.created', '项目已创建，可在聊天中查看项目列表和详情。', '{"en-US": "Project created. View its list and details in this chat."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:23', '2026-11-12 16:07:23');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005100, 0, 'agent.chat.sessions', '会话与记录', '{"en-US": "Conversations"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005101, 0, 'agent.chat.new', '新建会话', '{"en-US": "New conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005102, 0, 'agent.chat.untitled', '新会话', '{"en-US": "New conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005103, 0, 'agent.chat.rename', '会话名称', '{"en-US": "Conversation title"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005104, 0, 'agent.chat.save', '保存', '{"en-US": "Save"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005105, 0, 'agent.chat.cancel', '取消', '{"en-US": "Cancel"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005106, 0, 'agent.chat.delete', '删除', '{"en-US": "Delete"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005107, 0, 'agent.chat.deleteConfirm', '删除此会话及全部聊天记录？此操作无法撤销。', '{"en-US": "Delete this conversation and all its messages? This cannot be undone."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005108, 0, 'agent.chat.empty', '暂无会话，发送消息即可开始', '{"en-US": "No conversations yet. Send a message to start."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005109, 0, 'agent.chat.failed', '操作失败，请重试', '{"en-US": "Operation failed. Please retry."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005110, 0, 'agent.chat.history', '历史记录仅保留问答文本，业务数据和操作状态请重新查询。', '{"en-US": "History contains text only. Query again for current data and operation status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005111, 0, 'agent.chat.interrupted', '此条消息未收到完整回复，请检查操作状态后重新提问。', '{"en-US": "No complete reply was received. Check operation status before asking again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005112, 0, 'agent.chat.older', '加载更早记录', '{"en-US": "Load earlier messages"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005113, 0, 'agent.chat.loading', '正在加载聊天记录', '{"en-US": "Loading conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005114, 0, 'agent.chat.useMemory', '本会话使用记忆', '{"en-US": "Use memories in this conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005115, 0, 'agent.chat.required', '请填写内容', '{"en-US": "Please enter a value"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005116, 0, 'agent.chat.refresh', '刷新记录', '{"en-US": "Refresh history"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005117, 0, 'agent.memory.title', '个人记忆', '{"en-US": "Personal memories"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005118, 0, 'agent.memory.hint', '仅保存你手动填写的偏好，最多20条，每条500字。启用的记忆用于后续对话，不会授予权限或代替操作确认；请勿填写密码、令牌等秘密。删除会话不会删除个人记忆。', '{"en-US": "Only preferences you explicitly save are remembered (20 entries, 500 characters each). Enabled memories apply to future messages, never grant permissions or replace confirmation. Do not save secrets. Deleting a conversation does not delete memories."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005119, 0, 'agent.memory.content', '记忆内容', '{"en-US": "Memory content"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005120, 0, 'agent.memory.add', '添加记忆', '{"en-US": "Add memory"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005121, 0, 'agent.memory.edit', '编辑', '{"en-US": "Edit"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005122, 0, 'agent.memory.enabled', '启用记忆', '{"en-US": "Enable memory"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005123, 0, 'agent.memory.empty', '暂无个人记忆', '{"en-US": "No personal memories"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005124, 0, 'agent.memory.deleteConfirm', '确定删除这条记忆？', '{"en-US": "Delete this memory?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005125, 0, 'api.agent.personalNotFound', '记录不存在或无权限访问', '{"en-US": "Record not found or access denied"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005126, 0, 'api.agent.conversationLimit', '最多保存100个会话，请删除不再需要的会话', '{"en-US": "Limit of 100 conversations reached. Delete unused conversations."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005127, 0, 'api.agent.memoryLimit', '最多保存20条记忆，请删除或编辑现有记忆', '{"en-US": "Limit of 20 memories reached. Delete or edit existing memories."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005128, 0, 'api.agent.conversationBusy', '此会话正在处理消息或已更新，请稍后刷新记录', '{"en-US": "This conversation is busy or has changed. Refresh history shortly."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005129, 0, 'api.agent.messageDuplicate', '这条消息已提交，请刷新聊天记录，不要重复执行', '{"en-US": "This message was already submitted. Refresh history instead of repeating the operation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005200, 0, 'agent.navigation.previous', '上一页', '{"en-US": "Previous page"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005201, 0, 'agent.navigation.next', '下一页', '{"en-US": "Next page"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005202, 0, 'agent.navigation.page', '第 {page} 页', '{"en-US": "Page {page}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005203, 0, 'agent.navigation.actions', '操作', '{"en-US": "Actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005300, 0, 'agent.mode.exit', '返回菜单', '{"en-US": "Back to menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005301, 0, 'agent.mode.autoOpen', '登录后默认进入 AI 助手', '{"en-US": "Open AI assistant after sign-in"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005400, 0, 'agent.input.dictTypeCreateTitle', '创建字典类型', '{"en-US": "Create dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005401, 0, 'agent.input.dictCode', '字典编码', '{"en-US": "Dictionary code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005402, 0, 'agent.input.dictName', '字典名称', '{"en-US": "Dictionary name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005403, 0, 'agent.action.genericTitle', '操作预览', '{"en-US": "Operation preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005404, 0, 'agent.action.completed', '操作已完成', '{"en-US": "Operation completed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005405, 0, 'agent.action.genericImpact', '此操作会修改平台数据，请核对下方内容。', '{"en-US": "This operation will change platform data. Review the details below."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005406, 0, 'agent.action.genericPendingHint', '尚未执行。点击确认后才会保存；在聊天中回复“确认”不会执行。', '{"en-US": "Not executed yet. Click Confirm to save; replying in chat does not execute it."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005407, 0, 'agent.action.genericConfirm', '确认执行', '{"en-US": "Confirm operation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005408, 0, 'agent.input.userDisplayNameUpdateTitle', '修改用户显示名称', '{"en-US": "Update user display name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005409, 0, 'agent.input.targetUserId', '目标用户 ID', '{"en-US": "Target user ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005410, 0, 'agent.input.displayName', '显示名称', '{"en-US": "Display name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005411, 0, 'agent.input.username', '登录用户名', '{"en-US": "Login username"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005412, 0, 'agent.input.userCreateTitle', '创建平台用户', '{"en-US": "Create platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005413, 0, 'agent.input.email', '邮箱（选填）', '{"en-US": "Email (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005414, 0, 'agent.action.oneTimePassword', '一次性初始密码', '{"en-US": "One-time initial password"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005415, 0, 'agent.action.oneTimePasswordHint', '请现在复制并通过安全渠道交给新用户；关闭或刷新后无法再次查看。首次登录必须修改密码。', '{"en-US": "Copy now and deliver securely. It cannot be viewed again after closing or refreshing. The user must change it on first sign-in."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005420, 0, 'agent.input.dictItemCreateTitle', '新增字典项', '{"en-US": "Add dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005421, 0, 'agent.input.typeId', '字典类型 ID', '{"en-US": "Dictionary type ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005422, 0, 'agent.input.itemLabel', '字典项标签', '{"en-US": "Item label"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005423, 0, 'agent.input.itemValue', '字典项值', '{"en-US": "Item value"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005424, 0, 'agent.input.sortNo', '排序序号', '{"en-US": "Sort order"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005425, 0, 'agent.input.defaultItem', '设为默认项', '{"en-US": "Default item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005426, 0, 'agent.input.color', '颜色', '{"en-US": "Color"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005427, 0, 'agent.input.labelI18nKey', '标签国际化资源键', '{"en-US": "Label localization key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005428, 0, 'agent.input.status', '状态', '{"en-US": "Status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005429, 0, 'agent.input.departmentCreateTitle', '创建部门', '{"en-US": "Create department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005430, 0, 'agent.input.departmentName', '部门名称', '{"en-US": "Department name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005431, 0, 'agent.input.departmentCode', '部门编码', '{"en-US": "Department code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005432, 0, 'agent.input.parentDepartmentId', '上级部门 ID（选填）', '{"en-US": "Parent department ID (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005433, 0, 'agent.input.userStatusUpdateTitle', '启停平台用户', '{"en-US": "Enable or disable platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005434, 0, 'agent.input.currentStatus', '当前状态', '{"en-US": "Current status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005435, 0, 'agent.input.configCreateTitle', '创建非敏感参数配置', '{"en-US": "Create non-secret configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005436, 0, 'agent.input.configKey', '配置键', '{"en-US": "Configuration key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005437, 0, 'agent.input.configValue', '配置值（非敏感）', '{"en-US": "Configuration value (non-secret)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005438, 0, 'agent.input.valueType', '值类型', '{"en-US": "Value type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005439, 0, 'agent.input.dictTypeRenameTitle', '修改字典类型名称', '{"en-US": "Rename dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005440, 0, 'agent.input.currentName', '当前名称', '{"en-US": "Current name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005441, 0, 'agent.input.dictItemRenameTitle', '修改字典项标签', '{"en-US": "Rename dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005442, 0, 'agent.input.itemId', '字典项 ID', '{"en-US": "Dictionary item ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005443, 0, 'agent.input.currentLabel', '当前标签', '{"en-US": "Current label"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005444, 0, 'agent.input.departmentRenameTitle', '修改部门名称', '{"en-US": "Rename department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005445, 0, 'agent.input.departmentId', '部门 ID', '{"en-US": "Department ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005446, 0, 'agent.input.departmentStatusUpdateTitle', '启停部门', '{"en-US": "Enable or disable department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005447, 0, 'agent.input.projectStatusUpdateTitle', '变更项目状态', '{"en-US": "Change project status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005448, 0, 'agent.input.projectId', '项目 ID', '{"en-US": "Project ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005449, 0, 'agent.input.dictItemDeleteTitle', '删除字典项', '{"en-US": "Delete dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005450, 0, 'agent.input.configDeleteTitle', '删除平台配置', '{"en-US": "Delete platform configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005451, 0, 'agent.input.configId', '配置 ID', '{"en-US": "Configuration ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005452, 0, 'agent.input.secret', '敏感配置', '{"en-US": "Secret configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005453, 0, 'agent.input.projectRenameTitle', '修改项目名称', '{"en-US": "Rename project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005454, 0, 'agent.input.dictTypeDeleteTitle', '删除字典类型', '{"en-US": "Delete dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005455, 0, 'agent.input.projectRoleCreateTitle', '创建项目角色', '{"en-US": "Create project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005456, 0, 'agent.input.newRoleCode', '新角色编码', '{"en-US": "New role code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005457, 0, 'agent.input.roleName', '角色名称', '{"en-US": "Role name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005458, 0, 'agent.input.projectRoleUpdateTitle', '修改项目角色', '{"en-US": "Edit project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005459, 0, 'agent.input.targetRoleId', '目标角色编号', '{"en-US": "Target role ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005460, 0, 'agent.input.projectRoleDeleteTitle', '删除项目角色', '{"en-US": "Delete project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005461, 0, 'agent.input.projectRoleStatusTitle', '启停项目角色', '{"en-US": "Enable or disable project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005462, 0, 'agent.input.targetMenuId', '目标菜单编号', '{"en-US": "Target menu ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005463, 0, 'agent.input.projectMenuStatusTitle', '启停项目菜单', '{"en-US": "Enable or disable project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005464, 0, 'agent.input.projectMenuDeleteTitle', '删除项目菜单', '{"en-US": "Delete project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005465, 0, 'agent.input.menuIds', '菜单编号（可输入多个）', '{"en-US": "Menu IDs (multiple allowed)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005466, 0, 'agent.input.projectRoleMenuGrantTitle', '设置项目角色菜单', '{"en-US": "Set project role menus"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005467, 0, 'agent.input.roleIds', '项目角色编号（可输入多个）', '{"en-US": "Project role IDs (multiple allowed)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005468, 0, 'agent.input.projectMemberSaveTitle', '设置项目成员', '{"en-US": "Set project member"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005469, 0, 'agent.input.projectMemberDeleteTitle', '移除项目成员', '{"en-US": "Remove project member"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005470, 0, 'agent.input.departmentDeleteTitle', '删除部门', '{"en-US": "Delete department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005471, 0, 'agent.input.departmentIds', '部门编号（首项为主部门，可输入多个）', '{"en-US": "Department IDs (first is primary)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005472, 0, 'agent.input.userDepartmentAssignTitle', '设置用户部门归属', '{"en-US": "Set user departments"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005473, 0, 'agent.input.parentId', '上级菜单编号', '{"en-US": "Parent menu ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005474, 0, 'agent.input.menuName', '菜单名称', '{"en-US": "Menu name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005475, 0, 'agent.input.menuNameKey', '菜单国际化资源 Key', '{"en-US": "Menu translation key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005476, 0, 'agent.input.menuType', '菜单类型', '{"en-US": "Menu type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005477, 0, 'agent.input.routePath', '路由路径', '{"en-US": "Route path"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005478, 0, 'agent.input.componentPath', '组件路径', '{"en-US": "Component path"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005479, 0, 'agent.input.permissionCode', '权限码', '{"en-US": "Permission code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005480, 0, 'agent.input.icon', '菜单图标', '{"en-US": "Menu icon"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005481, 0, 'agent.input.visible', '是否显示', '{"en-US": "Visible"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005482, 0, 'agent.input.projectMenuCreateTitle', '创建项目菜单', '{"en-US": "Create project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005483, 0, 'agent.input.projectMenuUpdateTitle', '编辑项目菜单', '{"en-US": "Edit project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005484, 0, 'agent.input.userProfileUpdateTitle', '编辑平台用户资料', '{"en-US": "Edit platform user profile"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005485, 0, 'agent.input.userPasswordResetTitle', '重置平台用户密码', '{"en-US": "Reset platform user password"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005900, 0, 'agent.mode.classic', '传统模式', '{"en-US": "Classic mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005901, 0, 'agent.mode.enter', 'AI 助手模式', '{"en-US": "AI assistant mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005902, 0, 'agent.mode.classicHint', '已切换到传统模式，随时可以点左侧菜单底部的「AI 助手模式」切换回来。', '{"en-US": "Switched to classic mode. Use \\"AI assistant mode\\" at the bottom of the left menu to switch back anytime."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005903, 0, 'agent.setup.greeting', '你好，我是 Kaiwu AI 助手。先接入一个大模型，之后就能用一句话创建项目、查询和管理平台。暂时不想配置？点右上角「传统模式」回到菜单界面，随时可以再切回来。', '{"en-US": "Hi, I am the Kaiwu AI assistant. Connect a model first, then you can create projects and manage the platform in plain language. Not now? Use \\"Classic mode\\" at the top right to return to the menus, and switch back anytime."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005904, 0, 'agent.setup.title', '接入大模型', '{"en-US": "Connect a model"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005905, 0, 'agent.setup.hint', '支持任何 OpenAI 兼容接口。API Key 只在这个表单中填写并加密保存，不会出现在聊天记录里。', '{"en-US": "Any OpenAI-compatible API works. The API key is entered only in this form, stored encrypted, and never appears in the chat history."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005906, 0, 'agent.setup.preset', '服务商', '{"en-US": "Provider"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005907, 0, 'agent.setup.preset.deepseek', 'DeepSeek', '{"en-US": "DeepSeek"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005908, 0, 'agent.setup.preset.qwen', '通义千问', '{"en-US": "Qwen"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005909, 0, 'agent.setup.preset.openai', 'OpenAI', '{"en-US": "OpenAI"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005910, 0, 'agent.setup.preset.custom', '其他兼容服务', '{"en-US": "Other compatible"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005911, 0, 'agent.setup.submit', '保存并测试连接', '{"en-US": "Save and test connection"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005912, 0, 'agent.setup.success', '已接入 {model}，连接正常。现在可以直接提问，或者试试下面的问题。', '{"en-US": "Connected to {model}. Ask anything, or try one of the questions below."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005913, 0, 'agent.setup.testFailed', '配置已保存，但连接测试没有通过：{reason}。请检查地址、模型和 API Key 后重试。', '{"en-US": "Saved, but the connection test failed: {reason}. Check the URL, model and API key, then try again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005914, 0, 'agent.setup.noPermission', '平台还没有接入大模型，AI 助手暂时无法回答。请联系管理员配置，或者先切换到传统模式操作。', '{"en-US": "No model is connected yet, so the AI assistant cannot answer. Ask an administrator to configure one, or switch to classic mode for now."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005915, 0, 'agent.suggest.title', '可以这样问', '{"en-US": "Try asking"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005916, 0, 'agent.suggest.createProject', '帮我创建一个订单管理项目', '{"en-US": "Create an order management project for me"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005917, 0, 'agent.suggest.listProjects', '平台上现在有哪些项目？', '{"en-US": "Which projects are on the platform?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005918, 0, 'agent.suggest.failedGenerations', '最近有哪些项目生成失败了？', '{"en-US": "Which project generations failed recently?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005919, 0, 'agent.projects.continueGeneration', '继续生成第一版', '{"en-US": "Generate the first version"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005920, 0, 'agent.page.related', '可以在这些页面里操作：', '{"en-US": "You can do this on these pages:"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005930, 0, 'home.guide.run.title', '本机一条命令跑起来', '{"en-US": "Run it locally in one command"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005931, 0, 'home.guide.run.desc', '在 Kaiwu 入口目录执行下面的命令，前后端会自动接入平台；完成后回到工作台点「进入」。', '{"en-US": "From the Kaiwu entry directory, run the command below to wire both repositories into the platform, then click Open on the workbench."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005932, 0, 'home.guide.run.command', './kaiwu project-up ../business/<项目编码>-service', '{"en-US": "./kaiwu project-up ../business/<project-code>-service"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005940, 0, 'gateway.projectAccessDenied', '无权访问该项目', '{"en-US": "You do not have access to this project"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005941, 0, 'gateway.projectMismatch', '项目标识与授权不一致', '{"en-US": "The project identifier does not match the authorization"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005942, 0, 'gateway.routeProjectMissing', '路由缺少项目绑定', '{"en-US": "The route is not bound to a project"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005950, 0, 'home.guide.enter.title', '进入项目并验收', '{"en-US": "Open the project and check it"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000005951, 0, 'home.guide.enter.desc', '在下方「我参与的项目」点击项目卡片：不用再次登录就能打开业务后台，页面和接口正常即接入成功。', '{"en-US": "Click the project card under My projects below. The business admin opens without signing in again; if its pages and APIs work, the project is connected."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006000, 0, 'layout.workspace', '工作空间', '{"en-US": "Workspace"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006001, 0, 'layout.search.jump', '搜索与跳转', '{"en-US": "Search or jump"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006002, 0, 'layout.assistant.try', '试试 AI 助手', '{"en-US": "Try the AI assistant"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006003, 0, 'layout.assistant.desc', '项目查询、创建任务、代码生成与交付，都可以用自然语言完成。', '{"en-US": "Query projects, create tasks, generate and deliver code, all in plain language."}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006004, 0, 'layout.assistant.enter', '进入 AI 助手', '{"en-US": "Open AI assistant"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006005, 0, 'home.pipeline.title', '工程交付链路', '{"en-US": "Delivery pipeline"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006006, 0, 'home.pipeline.desc', '从项目定义到第一版源码交付、本机跑通', '{"en-US": "From project definition to first-version source delivery and a local run"}', 'home', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006007, 0, 'home.pipeline.define', '定义项目', '{"en-US": "Define project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006008, 0, 'home.pipeline.defineNote', '需求 · 权限 · 数据边界', '{"en-US": "Requirements · permissions · data scope"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006009, 0, 'home.pipeline.generate', 'AI 生成', '{"en-US": "AI generation"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006010, 0, 'home.pipeline.generateNote', 'SQL · 前端 · 后端', '{"en-US": "SQL · frontend · backend"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006011, 0, 'home.pipeline.deliver', '仓库交付', '{"en-US": "Repository delivery"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006012, 0, 'home.pipeline.deliverNote', 'GitLab · 初始推送', '{"en-US": "GitLab · initial push"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006013, 0, 'home.pipeline.iterate', '持续迭代', '{"en-US": "Iterate"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006014, 0, 'home.pipeline.iterateNote', 'AI 协作 · CI/CD', '{"en-US": "AI collaboration · CI/CD"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006015, 0, 'home.pipeline.open', '进入项目工厂', '{"en-US": "Open project factory"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006016, 0, 'home.todo.heading', '待办与提醒', '{"en-US": "To-dos and reminders"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006017, 0, 'home.todo.desc', '你需要关注的下一步', '{"en-US": "What needs your attention next"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006018, 0, 'home.todo.countTag', '{count} 项待处理', '{"en-US": "{count} pending"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006019, 0, 'home.projects.heading', '正在使用的项目', '{"en-US": "Projects in use"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006020, 0, 'home.projects.desc', '从这里进入业务后台或查看项目配置', '{"en-US": "Open a business console or review project settings"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006021, 0, 'home.projects.manageAll', '管理全部', '{"en-US": "Manage all"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006022, 0, 'home.stat.ai.title', 'AI 服务状态', '{"en-US": "AI service"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006023, 0, 'home.stat.ai.ok', '运行正常', '{"en-US": "Running"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006024, 0, 'home.stat.ai.off', '未启用', '{"en-US": "Not enabled"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006025, 0, 'agent.workspace.title', 'AI 工作空间', '{"en-US": "AI workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006026, 0, 'agent.workspace.subtitle', '可理解项目、生成任务并发起操作', '{"en-US": "Understands projects, creates tasks and starts actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006027, 0, 'agent.workspace.model', 'Agent · {model}', '{"en-US": "Agent · {model}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006028, 0, 'agent.welcome.title', '告诉开物，你想完成什么', '{"en-US": "Tell Kaiwu what you want to get done"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006029, 0, 'agent.welcome.line1', '从项目查询、代码生成到平台管理，用自然语言描述任务。', '{"en-US": "From project queries to code generation and platform administration, describe the task in plain language."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006030, 0, 'agent.welcome.line2', '涉及业务数据变更时，你可以先预览，再确认执行。', '{"en-US": "When business data would change, you preview it first and confirm before it runs."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006031, 0, 'agent.suggest.start', '你可以从这里开始', '{"en-US": "Start here"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006032, 0, 'agent.suggest.projects.title', '了解我的项目', '{"en-US": "Know my projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006033, 0, 'agent.suggest.projects.desc', '查询平台项目与运行状态', '{"en-US": "Query platform projects and their status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006034, 0, 'agent.suggest.failures.title', '检查交付异常', '{"en-US": "Check delivery issues"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006035, 0, 'agent.suggest.failures.desc', '查找生成失败与仓库交付问题', '{"en-US": "Find failed generations and repository delivery problems"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006036, 0, 'agent.suggest.user.title', '创建平台用户', '{"en-US": "Create a platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006037, 0, 'agent.suggest.user.desc', '生成操作预览，人工确认后执行', '{"en-US": "Preview the change, then confirm it yourself"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006038, 0, 'agent.suggest.createUser', '帮我创建一个平台用户', '{"en-US": "Create a platform user for me"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006039, 0, 'agent.suggest.generate.title', '发起项目生成', '{"en-US": "Start a project generation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006040, 0, 'agent.suggest.generate.desc', '从需求描述开始定义业务系统', '{"en-US": "Define a business system from a requirement description"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006041, 0, 'agent.chat.recent', '最近会话', '{"en-US": "Recent conversations"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006042, 0, 'agent.chat.footerTitle', '个人记忆与历史对话', '{"en-US": "Personal memories and history"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006043, 0, 'agent.chat.footerDesc', '与你的传统模式账号共享', '{"en-US": "Shared with your classic-mode account"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006044, 0, 'agent.inspector.title', '上下文与操作', '{"en-US": "Context and actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006045, 0, 'agent.inspector.desc', 'AI 理解你的当前项目、权限与业务上下文，敏感操作由你审核。', '{"en-US": "The AI works within your projects, permissions and business context. You review sensitive actions."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006046, 0, 'agent.inspector.scope', '01 · 项目范围', '{"en-US": "01 · Project scope"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006047, 0, 'agent.inspector.current', '当前上下文', '{"en-US": "Current context"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006048, 0, 'agent.inspector.workspace', '{name} 工作空间', '{"en-US": "{name} workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006049, 0, 'agent.inspector.account', '账号：{name} · {count} 个可访问项目', '{"en-US": "Account: {name} · {count} accessible projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006050, 0, 'agent.inspector.range', '当前查询范围：', '{"en-US": "Query scope: "}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006051, 0, 'agent.inspector.allProjects', '全部项目', '{"en-US": "All projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006052, 0, 'agent.inspector.pending', '待确认操作', '{"en-US": "Pending actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006053, 0, 'agent.inspector.pendingDesc', '所有变更先展示操作内容，并在你确认后提交。', '{"en-US": "Every change is previewed first and submitted only after you confirm."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006054, 0, 'agent.inspector.empty', '暂无待审核任务', '{"en-US": "Nothing to review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006055, 0, 'agent.inspector.emptyHint', '从左侧输入框发起操作', '{"en-US": "Start an action from the message box"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006056, 0, 'agent.inspector.view', '查看并确认', '{"en-US": "Review and confirm"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006057, 0, 'agent.inspector.settings', '助手设置', '{"en-US": "Assistant settings"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006058, 0, 'agent.composer.placeholder', '向开物提问，或描述你要完成的任务…', '{"en-US": "Ask Kaiwu, or describe the task you want done…"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006059, 0, 'agent.composer.scope', '当前工作空间', '{"en-US": "Current workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006060, 0, 'agent.composer.confirm', '操作需确认', '{"en-US": "Actions need confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006061, 0, 'home.pipeline.run', '本机运行', '{"en-US": "Run locally"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006062, 0, 'home.pipeline.runNote', '一条命令接入平台', '{"en-US": "One command to connect"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006063, 0, 'menu.system.i18n-resources', '国际化资源', '{"en-US": "Internationalization resources", "ja-JP": "国際化リソース"}', 'menu', 0, 1, 'ENABLED', '内置菜单名称：/i18n-resources', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006067, 0, 'roles.menuSearch', '搜索菜单名称或权限码', '{"en-US": "Search menu name or permission code", "ja-JP": "メニュー名または権限コードで検索"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006068, 0, 'roles.menuSelected', '已选 {selected} / {total}', '{"en-US": "{selected} / {total} selected", "ja-JP": "{selected} / {total} 件選択"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006069, 0, 'roles.menuSelectAll', '全选', '{"en-US": "Select all", "ja-JP": "すべて選択"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006070, 0, 'roles.menuNoMatch', '没有匹配的菜单', '{"en-US": "No matching menus", "ja-JP": "一致するメニューはありません"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006071, 0, 'projectSelect.title', '选择要进入的项目', '{"en-US": "Choose a project", "ja-JP": "入るプロジェクトを選択"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006072, 0, 'projectSelect.subtitle', '以下是你有权访问的项目', '{"en-US": "Projects you have access to", "ja-JP": "アクセス権のあるプロジェクト"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006073, 0, 'projectSelect.denied', '你没有访问「{project}」的权限，或该项目未启用、尚未配置后台入口。请从下方选择其他项目。', '{"en-US": "You do not have access to \\"{project}\\", or the project is disabled or has no admin entry. Please choose another project below.", "ja-JP": "「{project}」へのアクセス権がないか、プロジェクトが無効、または管理画面の入口が未設定です。下から別のプロジェクトを選択してください。"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006074, 0, 'projectSelect.emptyTitle', '还没有可访问的项目', '{"en-US": "No accessible projects yet", "ja-JP": "アクセスできるプロジェクトはまだありません"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006075, 0, 'projectSelect.emptyDesc', '请联系项目管理员把你加入项目，或换一个账号登录。', '{"en-US": "Ask a project administrator to add you to a project, or sign in with another account.", "ja-JP": "プロジェクト管理者に追加を依頼するか、別のアカウントでサインインしてください。"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006076, 0, 'home.todo.overdue', '已逾期', '{"en-US": "Overdue", "ja-JP": "期限切れ"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006077, 0, 'home.todo.dueAt', '截止 {time}', '{"en-US": "Due {time}", "ja-JP": "期限 {time}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006078, 0, 'home.todo.more', '还有 {count} 项未显示', '{"en-US": "{count} more not shown", "ja-JP": "ほか {count} 件は非表示"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006100, 0, 'projects.totalCount', '共 {count} 个项目', '{"en-US": "{count} projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006101, 0, 'projects.resetSearch', '重置', '{"en-US": "Reset"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006200, 0, 'projects.tab.all', '全部项目', '{"en-US": "All projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006201, 0, 'projects.tab.active', '已启用', '{"en-US": "Enabled"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006202, 0, 'projects.tab.builtIn', '平台内置', '{"en-US": "Built-in"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006203, 0, 'projects.generation.title', '生成与交付', '{"en-US": "Generation & delivery"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006204, 0, 'projects.generation.builtIn', '系统内置', '{"en-US": "Built-in system"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006205, 0, 'projects.generation.none', '尚未生成', '{"en-US": "Not generated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006206, 0, 'projects.generation.running', '生成中', '{"en-US": "Generating"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006207, 0, 'projects.generation.failed', '生成失败', '{"en-US": "Generation failed"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006209, 0, 'projects.generation.done', '交付完成', '{"en-US": "Delivered"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006210, 0, 'projects.backendNotConfigured', '尚未配置', '{"en-US": "Not configured"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006211, 0, 'projects.openAdmin', '打开管理后台', '{"en-US": "Open admin site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006212, 0, 'dicts.localeHelp.open', '查看 BCP 47 规范', '{"en-US": "View BCP 47 rules", "ja-JP": "BCP 47 の規則を見る"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006213, 0, 'dicts.localeHelp.title', 'BCP 47 语言标签规范', '{"en-US": "BCP 47 language tag rules", "ja-JP": "BCP 47 言語タグの規則"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006214, 0, 'dicts.localeHelp.intro', '语言代码会用于界面语言包、日期与数字格式化以及 Accept-Language 请求头，必须写成规范的 BCP 47 标签，大小写也要符合规范。', '{"en-US": "Locale codes drive UI language packs, date and number formatting, and the Accept-Language header, so they must be canonical BCP 47 tags with the correct letter case.", "ja-JP": "言語コードは UI の言語パック、日付・数値の書式、Accept-Language ヘッダーに使われるため、大文字・小文字も含めて正規の BCP 47 タグで記述してください。"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006215, 0, 'dicts.localeHelp.structure', '标签结构', '{"en-US": "Tag structure", "ja-JP": "タグの構造"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006216, 0, 'dicts.localeHelp.pattern', '语言[-文字][-地区]', '{"en-US": "language[-Script][-REGION]", "ja-JP": "言語[-文字][-地域]"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006217, 0, 'dicts.localeHelp.part.language', '语言：2–3 位小写字母（ISO 639），如 zh、en、ja', '{"en-US": "Language: 2–3 lowercase letters (ISO 639), e.g. zh, en, ja", "ja-JP": "言語：小文字 2～3 文字（ISO 639）、例：zh、en、ja"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006218, 0, 'dicts.localeHelp.part.script', '文字（可选）：4 位字母、首字母大写（ISO 15924），如 Hans、Hant', '{"en-US": "Script (optional): 4 letters, first letter uppercase (ISO 15924), e.g. Hans, Hant", "ja-JP": "文字（任意）：先頭のみ大文字の 4 文字（ISO 15924）、例：Hans、Hant"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006219, 0, 'dicts.localeHelp.part.region', '地区（可选）：2 位大写字母（ISO 3166-1）或 3 位数字（UN M.49），如 CN、US、419', '{"en-US": "Region (optional): 2 uppercase letters (ISO 3166-1) or 3 digits (UN M.49), e.g. CN, US, 419", "ja-JP": "地域（任意）：大文字 2 文字（ISO 3166-1）または数字 3 桁（UN M.49）、例：CN、US、419"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006220, 0, 'dicts.localeHelp.common', '常用标签', '{"en-US": "Common tags", "ja-JP": "よく使うタグ"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006221, 0, 'dicts.localeHelp.colCode', '标签', '{"en-US": "Tag", "ja-JP": "タグ"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006222, 0, 'dicts.localeHelp.colName', '语言', '{"en-US": "Language", "ja-JP": "言語"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006223, 0, 'dicts.localeHelp.colAction', '操作', '{"en-US": "Actions", "ja-JP": "操作"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006224, 0, 'dicts.localeHelp.use', '使用', '{"en-US": "Use", "ja-JP": "使用"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006225, 0, 'dicts.localeHelp.mistakes', '常见错误', '{"en-US": "Common mistakes", "ja-JP": "よくある誤り"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006226, 0, 'dicts.localeHelp.colWrong', '错误写法', '{"en-US": "Wrong", "ja-JP": "誤り"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006227, 0, 'dicts.localeHelp.colRight', '正确写法', '{"en-US": "Correct", "ja-JP": "正しい表記"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006228, 0, 'dicts.localeHelp.colReason', '原因', '{"en-US": "Reason", "ja-JP": "理由"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006229, 0, 'dicts.localeHelp.reason.underscore', '子标签之间用连字符 -，不能用下划线 _', '{"en-US": "Separate subtags with a hyphen (-), not an underscore (_)", "ja-JP": "サブタグの区切りはハイフン（-）で、アンダースコア（_）は使えません"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006230, 0, 'dicts.localeHelp.reason.regionCase', '地区子标签必须大写', '{"en-US": "The region subtag must be uppercase", "ja-JP": "地域サブタグは大文字で記述します"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006231, 0, 'dicts.localeHelp.reason.scriptCase', '文字子标签首字母大写，地区子标签全大写', '{"en-US": "Capitalize the script subtag and uppercase the region subtag", "ja-JP": "文字サブタグは先頭のみ大文字、地域サブタグはすべて大文字です"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006232, 0, 'dicts.localeHelp.reason.language', 'jp 是国家/地区代码，日语的语言代码是 ja', '{"en-US": "jp is a country code; the language code for Japanese is ja", "ja-JP": "jp は国・地域コードで、日本語の言語コードは ja です"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006233, 0, 'dicts.localeHelp.registry', '完整子标签清单：IANA Language Subtag Registry', '{"en-US": "Full subtag list: IANA Language Subtag Registry", "ja-JP": "サブタグの全一覧：IANA Language Subtag Registry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006234, 0, 'dict.project.generation.mode.DDL_SCAFFOLD', 'DDL 确定性生成', '{"en-US": "Deterministic from DDL", "ja-JP": "DDL から確定的に生成"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006235, 0, 'dictType.security.session.source', '会话来源', '{"en-US": "Session source", "ja-JP": "セッションの発行元"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006236, 0, 'dict.security.session.source.WEB', '网页登录', '{"en-US": "Web sign-in", "ja-JP": "Web ログイン"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006237, 0, 'dict.security.session.source.CLI', 'CLI 授权', '{"en-US": "CLI authorization", "ja-JP": "CLI 認可"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006238, 0, 'device.title', '授权命令行工具', '{"en-US": "Authorize a command-line tool", "ja-JP": "コマンドラインツールを認可"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006239, 0, 'device.intro', '允许后，该工具将以你的身份操作平台，权限与你本人相同，最长 7 天后需要重新授权。只允许你自己刚刚发起的请求。', '{"en-US": "Once allowed, the tool acts on the platform as you, with the same permissions, for at most 7 days. Only allow a request you just started yourself.", "ja-JP": "許可すると、このツールはあなたと同じ権限で最長 7 日間プラットフォームを操作します。自分で開始したリクエストだけを許可してください。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006240, 0, 'device.codeLabel', '授权码', '{"en-US": "Authorization code", "ja-JP": "認可コード"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006241, 0, 'device.codePlaceholder', '输入命令行里显示的授权码，例如 WDJB-MJHT', '{"en-US": "Enter the code shown in your terminal, e.g. WDJB-MJHT", "ja-JP": "ターミナルに表示されたコードを入力（例：WDJB-MJHT）"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006242, 0, 'device.lookup', '查看请求', '{"en-US": "Look up request", "ja-JP": "リクエストを確認"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006243, 0, 'device.client', '客户端', '{"en-US": "Client", "ja-JP": "クライアント"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006244, 0, 'device.requestIp', '发起地址', '{"en-US": "Requested from", "ja-JP": "要求元"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006245, 0, 'device.requestedAt', '发起时间', '{"en-US": "Requested at", "ja-JP": "要求日時"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006246, 0, 'device.approve', '允许', '{"en-US": "Allow", "ja-JP": "許可"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006247, 0, 'device.deny', '拒绝', '{"en-US": "Deny", "ja-JP": "拒否"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006248, 0, 'device.approved', '已允许，可以回到命令行继续操作。', '{"en-US": "Allowed. You can return to the terminal.", "ja-JP": "許可しました。ターミナルに戻って続行できます。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006249, 0, 'device.denied', '已拒绝，该工具不会获得访问权限。', '{"en-US": "Denied. The tool will not get access.", "ja-JP": "拒否しました。このツールはアクセスできません。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006250, 0, 'device.notFound', '授权码不存在或已过期，请回到命令行重新执行 kaiwu login。', '{"en-US": "The code does not exist or has expired. Run kaiwu login again in your terminal.", "ja-JP": "コードが存在しないか期限切れです。ターミナルで kaiwu login を再実行してください。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006251, 0, 'security.sessionSource', '来源', '{"en-US": "Source", "ja-JP": "発行元"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000006252, 0, 'security.clientName', '客户端', '{"en-US": "Client", "ja-JP": "クライアント"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007100, 0, 'dictType.storage.provider.type', '对象存储类型', '{"en-US": "Object storage type", "ja-JP": "オブジェクトストレージ種別"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007101, 0, 'dict.storage.provider.type.ALIYUN_OSS', '阿里云 OSS', '{"en-US": "Alibaba Cloud OSS", "ja-JP": "Alibaba Cloud OSS"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007102, 0, 'dict.storage.provider.type.S3_COMPATIBLE_STS', 'S3 兼容（STS）', '{"en-US": "S3 compatible (STS)", "ja-JP": "S3 互換（STS）"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007103, 0, 'dictType.storage.binding.status', '项目存储绑定状态', '{"en-US": "Project storage binding status", "ja-JP": "プロジェクトストレージ割り当て状態"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007104, 0, 'dict.storage.binding.status.ACTIVE', '生效', '{"en-US": "Active", "ja-JP": "有効"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007105, 0, 'dict.storage.binding.status.READ_ONLY', '只读', '{"en-US": "Read only", "ja-JP": "読み取り専用"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007106, 0, 'dict.storage.binding.status.DISABLED', '停用', '{"en-US": "Disabled", "ja-JP": "無効"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007110, 0, 'menu.system.storage', '对象存储', '{"en-US": "Object storage", "ja-JP": "オブジェクトストレージ"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007111, 0, 'menu.system.permission.system.storage.list', '查看对象存储', '{"en-US": "View object storage", "ja-JP": "オブジェクトストレージを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:list', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007112, 0, 'menu.system.permission.system.storage.save', '保存对象存储', '{"en-US": "Save object storage", "ja-JP": "オブジェクトストレージを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:save', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007113, 0, 'menu.system.permission.system.storage.test', '测试对象存储连接', '{"en-US": "Test object storage connection", "ja-JP": "オブジェクトストレージ接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:test', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007120, 0, 'storage.title', '对象存储', '{"en-US": "Object storage", "ja-JP": "オブジェクトストレージ"}', 'storage', 0, 1, 'ENABLED', '页面标题', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007121, 0, 'storage.subtitle', '登记存储账号并绑定到项目。业务项目只拿到限定在自身前缀的临时凭证，长期密钥不离开平台。', '{"en-US": "Register storage accounts and bind them to projects. Projects only receive short-lived credentials scoped to their own prefix; long-term keys never leave the platform.", "ja-JP": "ストレージアカウントを登録してプロジェクトに割り当てます。プロジェクトは自身のプレフィックスに限定された一時認証情報のみを受け取り、長期キーはプラットフォームの外に出ません。"}', 'storage', 0, 1, 'ENABLED', '页面副标题', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007122, 0, 'storage.tab.accounts', '存储账号', '{"en-US": "Accounts", "ja-JP": "アカウント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007123, 0, 'storage.tab.bindings', '项目绑定', '{"en-US": "Project bindings", "ja-JP": "プロジェクト割り当て"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007124, 0, 'storage.account.add', '新增账号', '{"en-US": "Add account", "ja-JP": "アカウントを追加"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007125, 0, 'storage.account.edit', '编辑账号', '{"en-US": "Edit account", "ja-JP": "アカウントを編集"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007126, 0, 'storage.account.test', '测试连接', '{"en-US": "Test connection", "ja-JP": "接続テスト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007127, 0, 'storage.account.name', '名称', '{"en-US": "Name", "ja-JP": "名前"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007128, 0, 'storage.account.code', '编码', '{"en-US": "Code", "ja-JP": "コード"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007129, 0, 'storage.account.providerType', '存储类型', '{"en-US": "Type", "ja-JP": "種別"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007130, 0, 'storage.account.endpoint', '存储地址', '{"en-US": "Endpoint", "ja-JP": "エンドポイント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007131, 0, 'storage.account.region', '区域', '{"en-US": "Region", "ja-JP": "リージョン"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007132, 0, 'storage.account.bucket', '桶名', '{"en-US": "Bucket", "ja-JP": "バケット"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007133, 0, 'storage.account.pathStyle', 'Path-style 访问', '{"en-US": "Path-style access", "ja-JP": "パススタイルアクセス"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007134, 0, 'storage.account.stsEndpoint', 'STS 地址', '{"en-US": "STS endpoint", "ja-JP": "STS エンドポイント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007135, 0, 'storage.account.roleArn', '角色 ARN', '{"en-US": "Role ARN", "ja-JP": "ロール ARN"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007136, 0, 'storage.account.accessKeyId', 'AccessKey ID', '{"en-US": "AccessKey ID", "ja-JP": "AccessKey ID"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007137, 0, 'storage.account.accessKeySecret', 'AccessKey Secret', '{"en-US": "AccessKey secret", "ja-JP": "AccessKey シークレット"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007138, 0, 'storage.account.secretKeep', '已配置，留空表示不修改', '{"en-US": "Configured. Leave blank to keep it.", "ja-JP": "設定済み。空欄のままにすると変更しません。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007139, 0, 'storage.account.ttl', '凭证有效期（秒）', '{"en-US": "Credential lifetime (seconds)", "ja-JP": "認証情報の有効期間（秒）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007140, 0, 'storage.account.enabled', '状态', '{"en-US": "Status", "ja-JP": "状態"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007141, 0, 'storage.account.bindingCount', '绑定数', '{"en-US": "Bindings", "ja-JP": "割り当て数"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007142, 0, 'storage.account.lastTest', '最近测试', '{"en-US": "Last test", "ja-JP": "最終テスト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007143, 0, 'storage.account.saved', '账号已保存', '{"en-US": "Account saved", "ja-JP": "アカウントを保存しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007144, 0, 'storage.account.testSuccess', '连接成功，用时 {latency} ms', '{"en-US": "Connected in {latency} ms", "ja-JP": "{latency} ms で接続しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007145, 0, 'storage.account.testFailed', '连接失败：{message}', '{"en-US": "Connection failed: {message}", "ja-JP": "接続に失敗しました：{message}"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007146, 0, 'storage.account.aliyunHint', '阿里云：存储地址填 https://oss-<区域>.aliyuncs.com，STS 地址填 https://sts.<区域>.aliyuncs.com，并填写可被扮演的 RAM 角色 ARN。所填主机必须在 kaiwu.storage.allowed-hosts 白名单内。', '{"en-US": "Alibaba Cloud: use https://oss-<region>.aliyuncs.com as the endpoint, https://sts.<region>.aliyuncs.com as the STS endpoint, and an assumable RAM role ARN. Hosts must be listed in kaiwu.storage.allowed-hosts.", "ja-JP": "Alibaba Cloud：エンドポイントに https://oss-<リージョン>.aliyuncs.com、STS エンドポイントに https://sts.<リージョン>.aliyuncs.com を指定し、引き受け可能な RAM ロール ARN を入力してください。ホストは kaiwu.storage.allowed-hosts に登録されている必要があります。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007147, 0, 'storage.binding.add', '绑定项目', '{"en-US": "Bind project", "ja-JP": "プロジェクトを割り当て"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007148, 0, 'storage.binding.project', '项目', '{"en-US": "Project", "ja-JP": "プロジェクト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007149, 0, 'storage.binding.storageName', '存储名', '{"en-US": "Storage name", "ja-JP": "ストレージ名"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007150, 0, 'storage.binding.account', '存储账号', '{"en-US": "Storage account", "ja-JP": "ストレージアカウント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007151, 0, 'storage.binding.status', '状态', '{"en-US": "Status", "ja-JP": "状態"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007152, 0, 'storage.binding.maxObjectSize', '单文件上限（MB）', '{"en-US": "Max file size (MB)", "ja-JP": "最大ファイルサイズ（MB）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007153, 0, 'storage.binding.contentTypes', '允许的类型', '{"en-US": "Allowed types", "ja-JP": "許可する種類"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007154, 0, 'storage.binding.contentTypesAll', '不限', '{"en-US": "Any", "ja-JP": "制限なし"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007155, 0, 'storage.binding.prefix', '对象前缀', '{"en-US": "Object prefix", "ja-JP": "オブジェクトプレフィックス"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007156, 0, 'storage.binding.storageRef', '存储引用', '{"en-US": "Storage ref", "ja-JP": "ストレージ参照"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007157, 0, 'storage.binding.createdAt', '创建时间', '{"en-US": "Created at", "ja-JP": "作成日時"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007158, 0, 'storage.binding.saved', '绑定已保存', '{"en-US": "Binding saved", "ja-JP": "割り当てを保存しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007159, 0, 'storage.binding.switchHint', '该存储名已有生效绑定且账号不同时，旧绑定会转为只读，历史文件仍可读取。', '{"en-US": "If this storage name already has an active binding to another account, the old binding becomes read-only so existing files stay readable.", "ja-JP": "このストレージ名に別アカウントの有効な割り当てがある場合、古い割り当ては読み取り専用になり、既存ファイルは引き続き読み取れます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007160, 0, 'storage.binding.makeActive', '设为生效', '{"en-US": "Activate", "ja-JP": "有効にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007161, 0, 'storage.binding.makeReadOnly', '改为只读', '{"en-US": "Make read-only", "ja-JP": "読み取り専用にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007162, 0, 'storage.binding.disable', '停用', '{"en-US": "Disable", "ja-JP": "無効にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007163, 0, 'storage.binding.statusUpdated', '状态已更新', '{"en-US": "Status updated", "ja-JP": "状態を更新しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007164, 0, 'storage.binding.disableConfirm', '停用后该绑定不再签发任何凭证，使用它的历史文件将无法读取。确定停用？', '{"en-US": "A disabled binding issues no credentials, so files stored through it can no longer be read. Disable it?", "ja-JP": "無効にした割り当てでは認証情報が発行されず、それを通じて保存したファイルは読み取れなくなります。無効にしますか？"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007165, 0, 'storage.actions', '操作', '{"en-US": "Actions", "ja-JP": "操作"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007166, 0, 'storage.account.empty', '还没有存储账号。先新增一个阿里云 OSS 或 MinIO 账号，再把项目绑定到它。', '{"en-US": "No storage accounts yet. Add an Alibaba Cloud OSS or MinIO account, then bind projects to it.", "ja-JP": "ストレージアカウントがまだありません。Alibaba Cloud OSS または MinIO のアカウントを追加してから、プロジェクトを割り当ててください。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007167, 0, 'storage.binding.empty', '还没有项目绑定。绑定后，业务项目通过 starter 即可读写自己前缀下的文件。', '{"en-US": "No project bindings yet. Once bound, a project reads and writes files under its own prefix through the starter.", "ja-JP": "プロジェクトの割り当てがまだありません。割り当て後、プロジェクトは starter を通じて自身のプレフィックス配下のファイルを読み書きできます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007168, 0, 'storage.binding.allProjects', '全部项目', '{"en-US": "All projects", "ja-JP": "すべてのプロジェクト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007169, 0, 'storage.binding.contentTypesPlaceholder', '如 image/png，回车添加；留空不限制', '{"en-US": "e.g. image/png, press Enter to add; leave empty for any", "ja-JP": "例：image/png（Enter で追加。空欄なら制限なし）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007200, 0, 'org.bulkAdd', '批量添加人员', '{"en-US": "Add members"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007201, 0, 'org.bulkTitle', '添加人员到 {name}', '{"en-US": "Add members to {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007202, 0, 'org.bulkHint', '选择要添加的用户，最多 100 人。已有主部门保持不变；没有归属的用户将以该部门为主部门。', '{"en-US": "Select up to 100 users. Existing primary departments stay unchanged; this becomes the primary department for unassigned users."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007203, 0, 'org.bulkAdded', '已添加 {count} 人', '{"en-US": "Added {count} members"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007204, 0, 'org.bulkSelected', '已选择 {count} 人（最多 100 人）', '{"en-US": "{count} selected (maximum 100)"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007300, 0, 'dictType.project.handover.status', '配置移交记录状态', '{"en-US": "Config handover record status"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007301, 0, 'dict.project.handover.status.SUCCESS', '成功', '{"en-US": "Succeeded"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007302, 0, 'dict.project.handover.status.FAILED', '失败', '{"en-US": "Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007303, 0, 'dictType.project.handover.action', '配置移交动作', '{"en-US": "Config handover action"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007304, 0, 'dict.project.handover.action.CREATE', '新增', '{"en-US": "Add"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007305, 0, 'dict.project.handover.action.UPDATE', '更新', '{"en-US": "Update"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007306, 0, 'dict.project.handover.action.REMOVED_AT_SOURCE', '源环境已删除', '{"en-US": "Removed at source"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007307, 0, 'dict.project.handover.action.DRIFT', '仅目标环境有', '{"en-US": "Only in target"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007308, 0, 'dictType.project.handover.resource', '配置移交资源类型', '{"en-US": "Config handover resource type"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007309, 0, 'dict.project.handover.resource.DICT', '字典', '{"en-US": "Dictionary"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007310, 0, 'dict.project.handover.resource.DICT_ITEM', '字典项', '{"en-US": "Dictionary item"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007311, 0, 'dict.project.handover.resource.CONFIG', '参数配置', '{"en-US": "Config"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007312, 0, 'dict.project.handover.resource.MENU', '菜单', '{"en-US": "Menu"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007313, 0, 'dict.project.handover.resource.I18N', '国际化资源', '{"en-US": "I18n resource"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007314, 0, 'dict.project.handover.resource.ROLE', '角色', '{"en-US": "Role"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007315, 0, 'dict.project.handover.resource.ROLE_GRANT', '角色授权', '{"en-US": "Role grant"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007316, 0, 'projects.configHandover', '配置移交', '{"en-US": "Config handover"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007317, 0, 'configHandover.export.title', '导出移交包', '{"en-US": "Export handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007318, 0, 'configHandover.export.desc', '导出当前项目的字典、参数配置、菜单、自定义角色授权、定时任务和国际化资源，到另一个环境导入。包里不含成员、密钥和敏感配置；定时任务在目标环境新建时默认停用。', '{"en-US": "Export this project''s dictionaries, configs, menus, custom role grants, scheduled jobs and i18n resources to import in another environment. The package contains no members, secrets or sensitive configs; scheduled jobs are created disabled in the target."}', 'configHandover', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007319, 0, 'configHandover.export.button', '导出并下载', '{"en-US": "Export and download"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007320, 0, 'configHandover.export.done', '已导出 {name}', '{"en-US": "Exported {name}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007321, 0, 'configHandover.export.stats', '字典 {dicts} · 配置 {configs} · 菜单 {menus} · 角色 {roles} · 定时任务 {jobs} · 国际化 {i18n}', '{"en-US": "Dictionaries {dicts} · Configs {configs} · Menus {menus} · Roles {roles} · Jobs {jobs} · I18n {i18n}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 2, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007322, 0, 'configHandover.export.warnings', '导出时有 {count} 项需要注意', '{"en-US": "{count} items need attention"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007323, 0, 'configHandover.import.title', '导入移交包', '{"en-US": "Import handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007324, 0, 'configHandover.import.desc', '上传从其他环境导出的移交包，先预览差异，确认后再执行。授权与删除默认不执行，需要逐项勾选。', '{"en-US": "Upload a package exported from another environment, preview the differences, then run it. Access and deletions are off by default and need explicit selection."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007325, 0, 'configHandover.import.upload', '点击或拖拽移交包（.json）到此处', '{"en-US": "Click or drag a handover package (.json) here"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007326, 0, 'configHandover.import.invalid', '不是有效的移交包', '{"en-US": "Not a valid handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007327, 0, 'configHandover.import.versionUnsupported', '不支持的移交包版本 {version}', '{"en-US": "Unsupported package version {version}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007328, 0, 'configHandover.import.projectMismatch', '移交包属于项目 {packageProject}，当前项目是 {project}', '{"en-US": "The package belongs to project {packageProject}, but the current project is {project}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007329, 0, 'configHandover.import.source', '来源 {host}，导出于 {time}，导出人 {user}', '{"en-US": "Source {host}, exported at {time} by {user}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007330, 0, 'configHandover.plan.missingPermissions', '当前账号缺少平台权限：{codes}，补齐后才能执行', '{"en-US": "Your account lacks platform permissions: {codes}. Grant them before running the import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007331, 0, 'configHandover.plan.alreadyApplied', '这个移交包已在 {time} 导入过（执行人 {user}），再次导入只会处理仍有差异的部分', '{"en-US": "This package was already imported at {time} (by {user}). Importing again only handles what still differs"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007332, 0, 'configHandover.plan.noBaseline', '这是该项目第一次通过移交包导入，无法识别「源环境已删除」的内容，从下一次导入开始才会识别。', '{"en-US": "This is the first package import for this project, so content removed at the source cannot be detected yet. Detection starts from the next import."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007333, 0, 'configHandover.plan.inSync', '目标环境已和移交包一致，没有需要导入的内容', '{"en-US": "The target already matches the package. Nothing to import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007334, 0, 'configHandover.plan.section.normal', '新增与更新（{count}）', '{"en-US": "Additions and updates ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007335, 0, 'configHandover.plan.section.access', '授权（{count}）', '{"en-US": "Access ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007336, 0, 'configHandover.plan.section.accessHint', '授权是安全决策，默认不导入。勾选后只会追加角色和授权，不会撤销目标环境已有的授权。', '{"en-US": "Access is a security decision and is not imported by default. When enabled it only adds roles and grants and never revokes existing ones."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007337, 0, 'configHandover.plan.access.apply', '同时导入授权', '{"en-US": "Import access as well"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007338, 0, 'configHandover.plan.section.delete', '源环境已删除（{count}）', '{"en-US": "Removed at source ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007339, 0, 'configHandover.plan.section.deleteHint', '上次导入时存在，本次移交包里已没有。只删除勾选的条目；平台查不到业务数据是否还在使用某个字典值，删除前请先确认。', '{"en-US": "Present in the last import but missing from this package. Only selected items are deleted. The platform cannot tell whether business data still uses a dictionary value, so confirm before deleting."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007340, 0, 'configHandover.plan.section.drift', '仅目标环境有（{count}）', '{"en-US": "Only in target ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007341, 0, 'configHandover.plan.section.driftHint', '目标环境自己新增的内容，不会被删除或覆盖。', '{"en-US": "Added in the target itself. It is neither deleted nor overwritten."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007342, 0, 'configHandover.plan.column.resource', '类型', '{"en-US": "Type"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007343, 0, 'configHandover.plan.column.key', '标识', '{"en-US": "Key"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007344, 0, 'configHandover.plan.column.action', '动作', '{"en-US": "Action"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007345, 0, 'configHandover.plan.column.detail', '说明', '{"en-US": "Details"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007346, 0, 'configHandover.apply.button', '执行导入', '{"en-US": "Run import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007347, 0, 'configHandover.apply.confirm', '将新增或更新 {changes} 项，导入授权 {access} 项，删除 {deletes} 项。确认执行？', '{"en-US": "This will add or update {changes} items, import {access} access items and delete {deletes} items. Continue?"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007348, 0, 'configHandover.apply.success', '导入完成：新增或更新 {changes} 项，删除 {deletes} 项', '{"en-US": "Import finished: {changes} items added or updated, {deletes} deleted"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007349, 0, 'configHandover.apply.stale', '目标环境在预览之后发生了变化，已重新生成预览，请核对后再执行', '{"en-US": "The target changed after the preview. The preview was refreshed; review it before running again"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007350, 0, 'configHandover.apply.nothing', '没有可执行的内容；授权和删除需要先勾选', '{"en-US": "Nothing to run. Access and deletions must be selected first"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007351, 0, 'configHandover.records.title', '移交记录', '{"en-US": "Handover records"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007352, 0, 'configHandover.records.time', '执行时间', '{"en-US": "Run at"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007353, 0, 'configHandover.records.operator', '执行人', '{"en-US": "Run by"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007354, 0, 'configHandover.records.operatorValue', '用户 {id}', '{"en-US": "User {id}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007355, 0, 'configHandover.records.source', '来源', '{"en-US": "Source"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007356, 0, 'configHandover.records.exportedAt', '导出时间', '{"en-US": "Exported at"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007357, 0, 'configHandover.records.result', '结果', '{"en-US": "Result"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007358, 0, 'configHandover.records.changes', '新增与更新', '{"en-US": "Added or updated"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007359, 0, 'configHandover.records.deletes', '删除', '{"en-US": "Deleted"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007360, 0, 'configHandover.records.access', '授权', '{"en-US": "Access"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007361, 0, 'configHandover.records.accessYes', '已导入', '{"en-US": "Imported"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007362, 0, 'configHandover.records.accessNo', '未导入', '{"en-US": "Not imported"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007363, 0, 'configHandover.records.reason', '失败原因', '{"en-US": "Failure reason"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007364, 0, 'configHandover.records.detail', '条目明细', '{"en-US": "Entry details"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007365, 0, 'configHandover.records.empty', '还没有移交记录', '{"en-US": "No handover records yet"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007400, 0, 'dict.project.handover.resource.JOB', '定时任务', '{"en-US": "Scheduled job"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007600, 0, 'ai.models', '模型列表', '{"en-US": "Models"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007601, 0, 'ai.addModel', '添加模型', '{"en-US": "Add model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007602, 0, 'ai.editModel', '编辑模型', '{"en-US": "Edit model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007603, 0, 'ai.modelRoutes', '用途分配', '{"en-US": "Model routes"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007604, 0, 'ai.planModel', '任务识别模型', '{"en-US": "Planning model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007605, 0, 'ai.answerModel', '回答模型', '{"en-US": "Answer model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007606, 0, 'ai.saveRoutes', '保存分配', '{"en-US": "Save routes"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007607, 0, 'ai.modelsEmpty', '暂无模型', '{"en-US": "No models configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007608, 0, 'ai.routesSaved', '模型用途已保存', '{"en-US": "Model routes saved"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007609, 0, 'ai.loadFailed', '加载模型配置失败', '{"en-US": "Failed to load models"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007610, 0, 'ai.selectModel', '选择模型', '{"en-US": "Select model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007611, 0, 'ai.testModel', '测试模型', '{"en-US": "Test model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007612, 0, 'ai.modelSaved', '模型已保存', '{"en-US": "Model saved"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007613, 0, 'ai.defaultModel', '默认模型', '{"en-US": "Default model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007614, 0, 'ai.modelRoutesHint', '留空使用默认配置', '{"en-US": "Leave empty to use the default model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007615, 0, 'ai.chooseModel', '选择模型', '{"en-US": "Choose a model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007616, 0, 'ai.routesNeedModels', '未配置默认模型时，请分别选择任务识别和回答模型。', '{"en-US": "Choose both planning and answer models when no default model is configured."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000007617, 0, 'ai.addressChangedKeyHint', '修改服务地址时，请重新填写 API Key，或明确清除旧密钥。', '{"en-US": "When changing the service URL, enter the API key again or explicitly clear the old key."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008502, 0, 'menu.system.permission.system.service-credential.list', '查看服务凭据', '{"en-US": "View service credentials", "ja-JP": "サービス認証情報を表示"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008503, 0, 'menu.system.permission.system.service-credential.manage', '管理服务凭据', '{"en-US": "Manage service credentials", "ja-JP": "サービス認証情報を管理"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008504, 0, 'serviceCredential.multiDisabled', '多服务凭据尚未启用', '{"en-US": "Service credentials are not enabled", "ja-JP": "サービス認証情報は有効になっていません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008800, 0, 'project.members.candidateLimitExceeded', '候选人数超过上限', '{"en-US": "Candidate limit exceeded", "ja-JP": "候補者数が上限を超えました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008900, 0, 'api.project.backendServiceConflict', '项目后端服务冲突', '{"en-US": "Project backend service conflict", "ja-JP": "プロジェクトのバックエンドサービスが競合しています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008901, 0, 'api.todo.legacyConflict', '待办键已被旧待办占用', '{"en-US": "The todo key is already used by a legacy todo", "ja-JP": "このキーは既存のタスクで使用されています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008902, 0, 'api.todo.sequenceConflict', '待办版本与已有内容冲突', '{"en-US": "The todo version conflicts with existing content", "ja-JP": "タスクのバージョンが既存の内容と競合しています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008903, 0, 'api.todo.terminalConflict', '已终结的待办不能重新打开', '{"en-US": "A terminal todo cannot be reopened", "ja-JP": "終了したタスクは再開できません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000008904, 0, 'api.todo.openLimitExceeded', '处理人的待办数量已达上限，请稍后重试', '{"en-US": "The recipient todo limit has been reached; try again later", "ja-JP": "担当者のタスク数が上限に達しました。後ほど再試行してください"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009000, 0, 'projects.backendServices.title', '后端服务', '{"en-US": "Backend services", "ja-JP": "バックエンドサービス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009001, 0, 'projects.backendServices.add', '新增服务', '{"en-US": "Add service", "ja-JP": "サービスを追加"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009002, 0, 'projects.backendServices.refresh', '刷新', '{"en-US": "Refresh", "ja-JP": "更新"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009003, 0, 'projects.backendServices.loadFailed', '加载后端服务失败', '{"en-US": "Failed to load backend services", "ja-JP": "サービスの読み込みに失敗しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009004, 0, 'projects.backendServices.saveFailed', '保存后端服务失败', '{"en-US": "Failed to save backend service", "ja-JP": "サービスの保存に失敗しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009005, 0, 'projects.backendServices.saved', '后端服务已更新', '{"en-US": "Backend service updated", "ja-JP": "サービスを更新しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009006, 0, 'projects.backendServices.code', '服务编码', '{"en-US": "Service code", "ja-JP": "サービスコード"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009007, 0, 'projects.backendServices.default', '默认服务地址', '{"en-US": "Default service address", "ja-JP": "既定サービスのアドレス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009008, 0, 'projects.backendServices.url', '上游地址', '{"en-US": "Upstream address", "ja-JP": "接続先アドレス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009009, 0, 'projects.backendServices.status', '状态', '{"en-US": "Status", "ja-JP": "状態"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009010, 0, 'projects.backendServices.actions', '操作', '{"en-US": "Actions", "ja-JP": "操作"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009011, 0, 'projects.backendServices.edit', '修改地址', '{"en-US": "Edit address", "ja-JP": "アドレスを変更"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009012, 0, 'projects.backendServices.statusConfirm', '确认更改服务状态？已发布的路由需要另行撤销或更新。', '{"en-US": "Change this service status? Published routes must be removed or updated separately.", "ja-JP": "状態を変更しますか？公開済みルートは別途更新してください。"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009013, 0, 'projects.backendServices.disable', '停用', '{"en-US": "Disable", "ja-JP": "無効化"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000009014, 0, 'projects.backendServices.enable', '启用', '{"en-US": "Enable", "ja-JP": "有効化"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000012900, 0, 'api.project.dataScopeTooLarge', '数据范围过大，请联系管理员调整', '{"en-US": "Data scope is too large; ask an administrator to adjust it", "ja-JP": "データ範囲が大きすぎます。管理者に調整を依頼してください"}', 'api', 0, 1, 'ENABLED', 'ADR 0044：project-access 数据范围超过 6144 字节', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000012901, 0, 'api.project.dataScopeInvalid', '数据范围配置无效', '{"en-US": "Invalid data scope configuration", "ja-JP": "データ範囲の設定が無効です"}', 'api', 0, 1, 'ENABLED', 'ADR 0044：保存角色数据范围校验失败', 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013100, 0, 'dictType.project.data_scope.type', '数据范围类型', '{"en-US": "Data scope type"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013101, 0, 'dict.project.data_scope.type.ALL', '全部', '{"en-US": "All"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013102, 0, 'dict.project.data_scope.type.DEPT_AND_CHILD', '本部门及下级', '{"en-US": "Own department and sub-departments"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013103, 0, 'dict.project.data_scope.type.DEPT', '本部门', '{"en-US": "Own department"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013104, 0, 'dict.project.data_scope.type.SELF', '仅本人', '{"en-US": "Own data only"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013105, 0, 'dict.project.data_scope.type.CUSTOM_DEPT', '指定部门', '{"en-US": "Specific departments"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013106, 0, 'dict.project.handover.resource.DATA_SCOPE', '受控资源', '{"en-US": "Controlled resource"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013107, 0, 'dict.project.handover.resource.ROLE_DATA_SCOPE', '角色数据范围', '{"en-US": "Role data scope"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013108, 0, 'dict.project.handover.action.REENABLE', '重新启用', '{"en-US": "Re-enable"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013109, 0, 'roles.dataScope', '数据范围', '{"en-US": "Data scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013110, 0, 'roles.grantTitle', '角色授权{suffix}', '{"en-US": "Role grants{suffix}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013111, 0, 'roles.tab.menus', '菜单授权', '{"en-US": "Menus"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013112, 0, 'roles.tab.dataScope', '数据范围', '{"en-US": "Data scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013113, 0, 'dataScope.column.resource', '资源', '{"en-US": "Resource"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013114, 0, 'dataScope.column.scope', '可见范围', '{"en-US": "Visibility"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013115, 0, 'dataScope.column.departments', '部门', '{"en-US": "Departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013116, 0, 'dataScope.includeChild', '含下级', '{"en-US": "Include sub-departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013117, 0, 'dataScope.defaultSelf', '仅本人（默认）', '{"en-US": "Own data only (default)"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013118, 0, 'dataScope.builtIn', '全部（内置角色）', '{"en-US": "All (built-in role)"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013119, 0, 'dataScope.confirmAllTitle', '授予「全部」范围', '{"en-US": "Grant the \\"All\\" scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013120, 0, 'dataScope.confirmAll', '该角色将看到本项目全部{resource}', '{"en-US": "This role will see all {resource} in the project"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013121, 0, 'dataScope.empty', '该项目尚未声明受控资源。请在业务仓 kaiwu/data-scopes.yml 中声明并同步。', '{"en-US": "No controlled resources declared yet. Declare them in kaiwu/data-scopes.yml and sync."}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013122, 0, 'dataScope.pickDepartments', '选择部门', '{"en-US": "Select departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013123, 0, 'dataScope.departmentsRequired', '请选择至少一个部门', '{"en-US": "Select at least one department"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013124, 0, 'dataScope.maxDepartments', '最多选择 {max} 个部门', '{"en-US": "Select at most {max} departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013125, 0, 'dataScope.saved', '数据范围已保存', '{"en-US": "Data scope saved"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000013126, 0, 'dataScope.sizeWarning', '所选部门过多，用户可能因数据范围过大而无法进入本项目。请改用「全部」或缩小指定部门。', '{"en-US": "Too many departments selected; users may be unable to enter the project because the data scope is too large. Use \\"All\\" or narrow the departments."}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110001, 0, 'i18n.scope', '所属范围', '{"en-US": "Scope", "ja-JP": "適用範囲"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110002, 0, 'i18n.scopePlatform', '平台', '{"en-US": "Platform", "ja-JP": "プラットフォーム"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110003, 0, 'i18n.scopeProjectHint', '项目文案由项目管理员维护，不参与平台语言开放校验', '{"en-US": "Project copy is maintained by project admins and does not affect platform language availability checks.", "ja-JP": "プロジェクトの文言はプロジェクト管理者が管理し、プラットフォームの言語公開チェックには影響しません。"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110004, 0, 'api.i18n.builtInProjectForbidden', '内置项目的文案属于平台资源', '{"en-US": "Built-in project copy is a platform resource", "ja-JP": "組み込みプロジェクトの文言はプラットフォームのリソースです"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110005, 0, 'api.i18n.projectInactive', '项目未启用', '{"en-US": "The project is not enabled", "ja-JP": "プロジェクトが有効ではありません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_i18n_message` (`id`, `scope_id`, `message_key`, `default_text`, `translations_json`, `module_code`, `public_visible`, `required_resource`, `status`, `description`, `version`, `created_at`, `updated_at`) VALUES
(9200000000000110006, 0, 'api.i18n.projectAdminRequired', '只有目标项目的有效项目管理员可以维护项目文案', '{"en-US": "Only active project administrators of the target project can maintain project copy", "ja-JP": "対象プロジェクトの有効なプロジェクト管理者のみがプロジェクトの文言を管理できます"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-12 16:07:24', '2026-11-12 16:07:24');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(1, NULL, '验证平台访问', 'BUTTON', NULL, NULL, 'system:platform:read', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(100, NULL, '用户管理', 'MENU', '/users', NULL, NULL, 'UserOutlined', 10, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(101, 100, '查询用户', 'BUTTON', NULL, NULL, 'system:user:list', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(102, 100, '创建用户', 'BUTTON', NULL, NULL, 'system:user:create', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(103, 100, '编辑用户', 'BUTTON', NULL, NULL, 'system:user:update', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(104, 100, '启停用户', 'BUTTON', NULL, NULL, 'system:user:status', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(105, 100, '重置密码', 'BUTTON', NULL, NULL, 'system:user:reset-password', NULL, 0, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(400, NULL, '项目管理', 'MENU', '/projects', NULL, NULL, 'AppstoreOutlined', 40, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(401, 400, '查询项目', 'BUTTON', NULL, NULL, 'system:project:list', NULL, 10, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(402, 400, '创建项目', 'BUTTON', NULL, NULL, 'system:project:create', NULL, 20, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(403, 400, '编辑项目', 'BUTTON', NULL, NULL, 'system:project:update', NULL, 30, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(404, 400, '变更项目状态', 'BUTTON', NULL, NULL, 'system:project:status', NULL, 40, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(405, 400, '管理项目成员', 'BUTTON', NULL, NULL, 'system:project:member', NULL, 50, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(406, 400, '管理项目角色', 'BUTTON', NULL, NULL, 'system:project:role', NULL, 60, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(407, 400, '管理项目菜单', 'BUTTON', NULL, NULL, 'system:project:menu', NULL, 70, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(500, NULL, '参数配置', 'MENU', '/configs', NULL, NULL, 'SettingOutlined', 50, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(501, 500, '查询配置', 'BUTTON', NULL, NULL, 'system:config:list', NULL, 10, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(502, 500, '保存配置', 'BUTTON', NULL, NULL, 'system:config:save', NULL, 20, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(503, 500, '删除配置', 'BUTTON', NULL, NULL, 'system:config:delete', NULL, 30, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(600, NULL, '字典管理', 'MENU', '/dictionaries', NULL, NULL, 'BookOutlined', 60, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(601, 600, '查询字典', 'BUTTON', NULL, NULL, 'system:dict:list', NULL, 10, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(602, 600, '保存字典', 'BUTTON', NULL, NULL, 'system:dict:save', NULL, 20, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(603, 600, '删除字典', 'BUTTON', NULL, NULL, 'system:dict:delete', NULL, 30, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(700, NULL, '项目工厂', 'MENU', '/project-factory', NULL, NULL, 'CodeOutlined', 70, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(701, 700, '查看项目生成', 'BUTTON', NULL, NULL, 'system:project-factory:list', NULL, 10, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(702, 700, '生成项目', 'BUTTON', NULL, NULL, 'system:project-factory:generate', NULL, 20, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(703, 700, '下载项目制品', 'BUTTON', NULL, NULL, 'system:project-factory:download', NULL, 30, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_menu` (`id`, `parent_id`, `menu_name`, `menu_type`, `route_path`, `component_path`, `permission_code`, `icon`, `sort_no`, `visible`, `status`, `created_at`, `updated_at`) VALUES
(704, 700, '初始推送 GitLab', 'BUTTON', NULL, NULL, 'system:project-factory:push', NULL, 40, 1, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:22');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8201, 8101, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.common.status.ENABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8202, 8101, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.common.status.DISABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8203, 8102, '是', 'true', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.common.boolean_enabled.true');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8204, 8102, '否', 'false', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.common.boolean_enabled.false');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8401, 8301, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.user.status.ENABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8402, 8301, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.user.status.DISABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8403, 8302, '已启用', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:24', NULL, 'dict.project.status.ACTIVE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8404, 8302, '已停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:24', NULL, 'dict.project.status.DISABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8405, 8302, '已归档', 'ARCHIVED', 30, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.status.ARCHIVED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8406, 8303, '有效', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.member.status.ACTIVE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8407, 8303, '停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.member.status.DISABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8408, 8304, '目录', 'DIR', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.platform.menu.type.DIR');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8409, 8304, '菜单', 'MENU', 20, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.platform.menu.type.MENU');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8410, 8304, '按钮', 'BUTTON', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.platform.menu.type.BUTTON');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8411, 8305, '文本', 'STRING', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.config.value.type.STRING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8412, 8305, '数值', 'NUMBER', 20, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.config.value.type.NUMBER');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8413, 8305, '布尔值', 'BOOLEAN', 30, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.config.value.type.BOOLEAN');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8414, 8305, 'JSON', 'JSON', 40, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.config.value.type.JSON');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8415, 8306, '连接成功', 'SUCCESS', 10, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.ai.test.status.SUCCESS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8416, 8306, '连接失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.ai.test.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8419, 8308, 'AI 生成项目', 'AI_PROJECT', 10, 1, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.mode.AI_PROJECT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8420, 8308, '基础空脚手架', 'BASIC_SCAFFOLD', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.mode.BASIC_SCAFFOLD');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8421, 8309, '等待生成', 'PENDING', 10, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.status.PENDING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8422, 8309, '正在生成', 'RUNNING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.status.RUNNING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8423, 8309, '生成成功', 'SUCCESS', 30, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.status.SUCCESS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8424, 8309, '生成失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.project.generation.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8434, 8313, '系统通知', 'SYSTEM', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.notification.type.SYSTEM');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8435, 8313, '项目消息', 'PROJECT', 20, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.notification.type.PROJECT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8436, 8313, '任务提醒', 'TASK', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.notification.type.TASK');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8437, 8314, '成功', 'SUCCESS', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.security.login.status.SUCCESS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8438, 8314, '失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.security.login.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8439, 8315, '在线', 'ONLINE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.security.session.status.ONLINE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8440, 8315, '已撤销', 'REVOKED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.security.session.status.REVOKED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8441, 8314, '退出', 'LOGOUT', 30, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.security.login.status.LOGOUT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8442, 8316, '执行中', 'RUNNING', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.scheduler.execution.status.RUNNING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8443, 8316, '成功', 'SUCCESS', 20, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.scheduler.execution.status.SUCCESS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8444, 8316, '失败', 'FAILED', 30, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:22', '2026-11-12 16:07:23', NULL, 'dict.scheduler.execution.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8501, 8317, '简体中文', 'zh-CN', 10, 1, NULL, '{"selectable":true,"antdLocale":"zh-CN","dateLocale":"zh-CN"}', 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.platform.locale.zh-CN');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8502, 8317, 'English (US)', 'en-US', 20, 0, NULL, '{"selectable":true,"antdLocale":"en-US","dateLocale":"en-US"}', 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.platform.locale.en-US');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8531, 8321, '成功（绿）', 'success', 10, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.success');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8532, 8321, '处理中（蓝）', 'processing', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.processing');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8533, 8321, '警告（橙）', 'warning', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.warning');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8534, 8321, '失败（红）', 'error', 40, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.error');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8535, 8321, '默认（灰）', 'default', 50, 1, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.default');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8536, 8321, '紫（类别）', 'purple', 60, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.purple');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8537, 8321, '青（类别）', 'cyan', 70, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.common.tag_color.cyan');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8541, 8331, '用户管理', 'user', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.user');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8542, 8331, '角色管理', 'role', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.role');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8543, 8331, '菜单管理', 'menu', 30, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.menu');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8544, 8331, '组织架构', 'org', 40, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.org');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8545, 8331, '配置与字典', 'metadata', 50, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.metadata');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8546, 8331, '国际化资源', 'i18n', 60, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.i18n');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8547, 8331, '项目管理', 'project', 70, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.project');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8548, 8331, '项目工厂', 'project-factory', 80, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.project-factory');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8549, 8331, '定时任务', 'scheduler', 90, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.scheduler');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8550, 8331, 'GitLab 配置', 'gitlab', 100, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.gitlab');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8551, 8331, '大模型配置', 'ai', 110, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.ai');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8552, 8331, '安全运营', 'security', 120, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.security.audit.module.security');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8553, 8308, 'DDL 确定性生成', 'DDL_SCAFFOLD', 30, 0, 'cyan', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', NULL, 'dict.project.generation.mode.DDL_SCAFFOLD');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8554, 8343, '网页登录', 'WEB', 10, 1, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', NULL, 'dict.security.session.source.WEB');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8555, 8343, 'CLI 授权', 'CLI', 20, 0, 'purple', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', NULL, 'dict.security.session.source.CLI');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8570, 8340, '待审核', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.capability.status.PENDING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8571, 8340, '已批准', 'APPROVED', 20, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.capability.status.APPROVED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8572, 8340, '已撤销', 'REVOKED', 30, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.capability.status.REVOKED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8573, 8341, '在线', 'ONLINE', 40, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.capability.connection.ONLINE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8574, 8341, '离线', 'OFFLINE', 50, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.capability.connection.OFFLINE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8575, 8342, '待确认', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.PENDING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8576, 8342, '执行中', 'EXECUTING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.EXECUTING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8577, 8342, '已创建', 'SUCCEEDED', 30, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.SUCCEEDED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8578, 8342, '执行失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8579, 8342, '已取消', 'CANCELLED', 50, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.CANCELLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8580, 8342, '已过期', 'EXPIRED', 60, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.EXPIRED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8581, 8342, '已拒绝', 'REJECTED', 70, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.REJECTED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(8582, 8342, '结果待核验', 'UNKNOWN', 80, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.action.status.UNKNOWN');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004301, 9200000000000004300, '待确认', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.PENDING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004302, 9200000000000004300, '执行中', 'EXECUTING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.EXECUTING');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004303, 9200000000000004300, '已完成', 'SUCCEEDED', 30, 0, 'success', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.SUCCEEDED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004304, 9200000000000004300, '执行失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004305, 9200000000000004300, '已取消', 'CANCELLED', 50, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.CANCELLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004306, 9200000000000004300, '已过期', 'EXPIRED', 60, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.EXPIRED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004307, 9200000000000004300, '已拒绝', 'REJECTED', 70, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.REJECTED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000004308, 9200000000000004300, '结果待核验', 'UNKNOWN', 80, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:23', '2026-11-12 16:07:23', NULL, 'dict.agent.remote_action.status.UNKNOWN');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007010, 9200000000000007000, '阿里云 OSS', 'ALIYUN_OSS', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Alibaba Cloud OSS"}', 'dict.storage.provider.type.ALIYUN_OSS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007011, 9200000000000007000, 'S3 兼容（STS）', 'S3_COMPATIBLE_STS', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "S3 compatible (STS)"}', 'dict.storage.provider.type.S3_COMPATIBLE_STS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007020, 9200000000000007001, '生效', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Active"}', 'dict.storage.binding.status.ACTIVE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007021, 9200000000000007001, '只读', 'READ_ONLY', 20, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Read only"}', 'dict.storage.binding.status.READ_ONLY');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007022, 9200000000000007001, '停用', 'DISABLED', 30, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Disabled"}', 'dict.storage.binding.status.DISABLED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007251, 9200000000000007250, '成功', 'SUCCESS', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Succeeded"}', 'dict.project.handover.status.SUCCESS');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007252, 9200000000000007250, '失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Failed"}', 'dict.project.handover.status.FAILED');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007254, 9200000000000007253, '新增', 'CREATE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Add"}', 'dict.project.handover.action.CREATE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007255, 9200000000000007253, '更新', 'UPDATE', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Update"}', 'dict.project.handover.action.UPDATE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007256, 9200000000000007253, '源环境已删除', 'REMOVED_AT_SOURCE', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Removed at source"}', 'dict.project.handover.action.REMOVED_AT_SOURCE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007257, 9200000000000007253, '仅目标环境有', 'DRIFT', 40, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Only in target"}', 'dict.project.handover.action.DRIFT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007259, 9200000000000007258, '字典', 'DICT', 10, 1, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Dictionary"}', 'dict.project.handover.resource.DICT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007260, 9200000000000007258, '字典项', 'DICT_ITEM', 20, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Dictionary item"}', 'dict.project.handover.resource.DICT_ITEM');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007261, 9200000000000007258, '参数配置', 'CONFIG', 30, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Config"}', 'dict.project.handover.resource.CONFIG');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007262, 9200000000000007258, '菜单', 'MENU', 40, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Menu"}', 'dict.project.handover.resource.MENU');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007263, 9200000000000007258, '国际化资源', 'I18N', 50, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "I18n resource"}', 'dict.project.handover.resource.I18N');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007264, 9200000000000007258, '角色', 'ROLE', 60, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Role"}', 'dict.project.handover.resource.ROLE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007265, 9200000000000007258, '角色授权', 'ROLE_GRANT', 70, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Role grant"}', 'dict.project.handover.resource.ROLE_GRANT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000007266, 9200000000000007258, '定时任务', 'JOB', 80, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Scheduled job"}', 'dict.project.handover.resource.JOB');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013001, 9200000000000013000, '全部', 'ALL', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "All"}', 'dict.project.data_scope.type.ALL');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013002, 9200000000000013000, '本部门及下级', 'DEPT_AND_CHILD', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Own department and sub-departments"}', 'dict.project.data_scope.type.DEPT_AND_CHILD');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013003, 9200000000000013000, '本部门', 'DEPT', 30, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Own department"}', 'dict.project.data_scope.type.DEPT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013004, 9200000000000013000, '仅本人', 'SELF', 40, 1, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Own data only"}', 'dict.project.data_scope.type.SELF');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013005, 9200000000000013000, '指定部门', 'CUSTOM_DEPT', 50, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Specific departments"}', 'dict.project.data_scope.type.CUSTOM_DEPT');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013006, 9200000000000007258, '受控资源', 'DATA_SCOPE', 90, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Controlled resource"}', 'dict.project.handover.resource.DATA_SCOPE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013007, 9200000000000007258, '角色数据范围', 'ROLE_DATA_SCOPE', 100, 0, 'default', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Role data scope"}', 'dict.project.handover.resource.ROLE_DATA_SCOPE');
INSERT INTO `sys_dict_item` (`id`, `dict_type_id`, `item_label`, `item_value`, `sort_no`, `default_item`, `color`, `extra_json`, `status`, `created_at`, `updated_at`, `label_i18n`, `label_i18n_key`) VALUES
(9200000000000013008, 9200000000000007253, '重新启用', 'REENABLE', 50, 0, 'processing', NULL, 'ENABLED', '2026-11-12 16:07:24', '2026-11-12 16:07:24', '{"en-US": "Re-enable"}', 'dict.project.handover.action.REENABLE');

INSERT IGNORE INTO sys_dict_item(id,dict_type_id,item_label,item_value,sort_no,default_item,color,status,label_i18n_key,created_at,updated_at) VALUES
(16800,8308,'沿用已有前端','ADOPT_FRONTEND',40,0,'blue','ENABLED','dict.project.generation.mode.ADOPT_FRONTEND',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);
INSERT IGNORE INTO sys_i18n_message(id,message_key,default_text,translations_json,module_code,public_visible,required_resource,status,version,created_at,updated_at) VALUES
(9200000000000009100,'dict.project.generation.mode.ADOPT_FRONTEND','沿用已有前端',JSON_OBJECT('en-US','Existing frontend','ja-JP','既存フロントエンド'),'dict',0,1,'ENABLED',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);
UPDATE sys_i18n_catalog_revision SET revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE catalog_code='platform';
