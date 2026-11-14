CREATE TABLE "sys_agent_conversation"
(
"id" BIGINT NOT NULL,
"user_id" BIGINT NOT NULL,
"title" VARCHAR(100 CHAR) NOT NULL,
"use_memory" TINYINT DEFAULT '1' NOT NULL,
"run_id" BIGINT DEFAULT NULL,
"busy_until" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_agent_conversation_owner" ON "sys_agent_conversation"("user_id" ASC,"updated_at" ASC,"id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_memory"
(
"id" BIGINT NOT NULL,
"user_id" BIGINT NOT NULL,
"CONTENT" VARCHAR(500 CHAR) NOT NULL,
"enabled" TINYINT DEFAULT '1' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_agent_memory_owner" ON "sys_agent_memory"("user_id" ASC,"updated_at" ASC,"id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_message"
(
"id" BIGINT NOT NULL,
"conversation_id" BIGINT NOT NULL,
"request_id" VARCHAR(64 CHAR) NOT NULL,
"question" VARCHAR(500 CHAR) NOT NULL,
"answer" CLOB,
"completed" TINYINT DEFAULT '0' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_agent_message_conversation" FOREIGN KEY("conversation_id") REFERENCES "sys_agent_conversation"("id") ON DELETE CASCADE ) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_agent_message_conversation" ON "sys_agent_message"("conversation_id" ASC,"created_at" ASC,"id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_agent_message_request" ON "sys_agent_message"("conversation_id" ASC,"request_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_ai_model_route"
(
"id" BIGINT NOT NULL,
"plan_model_id" BIGINT,
"answer_model_id" BIGINT,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_ai_provider_config"
(
"id" BIGINT NOT NULL,
"provider_name" VARCHAR(100 CHAR) NOT NULL,
"base_url" VARCHAR(512 CHAR) NOT NULL,
"api_key_ciphertext" TEXT,
"model" VARCHAR(128 CHAR) NOT NULL,
"temperature" DECIMAL(3,2) DEFAULT '0.20' NOT NULL,
"timeout_seconds" INT DEFAULT '60' NOT NULL,
"enabled" TINYINT DEFAULT '1' NOT NULL,
"last_test_status" VARCHAR(20 CHAR) DEFAULT NULL,
"last_test_message" VARCHAR(500 CHAR) DEFAULT NULL,
"last_test_at" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
"config_revision" BIGINT DEFAULT 0 NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_app_config"
(
"id" BIGINT NOT NULL,
"scope_id" BIGINT DEFAULT '0' NOT NULL,
"config_key" VARCHAR(128 CHAR) NOT NULL,
"config_value" TEXT NOT NULL,
"value_i18n_key" VARCHAR(160 CHAR) DEFAULT NULL,
"value_type" VARCHAR(16 CHAR) NOT NULL,
"secret" TINYINT DEFAULT '0' NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"description" VARCHAR(512 CHAR) DEFAULT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_app_config_scope_status" ON "sys_app_config"("scope_id" ASC,"status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_app_config_scope_key" ON "sys_app_config"("scope_id" ASC,"config_key" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_department"
(
"id" BIGINT NOT NULL,
"parent_id" BIGINT DEFAULT NULL,
"dept_name" VARCHAR(100 CHAR) NOT NULL,
"dept_code" VARCHAR(64 CHAR) NOT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"status" VARCHAR(20 CHAR) DEFAULT 'ENABLED' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_department_parent" FOREIGN KEY("parent_id") REFERENCES "sys_department"("id") WITH INDEX ) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_department_parent_sort" ON "sys_department"("parent_id" ASC,"sort_no" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_department_code" ON "sys_department"("dept_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_dict_type"
(
"id" BIGINT NOT NULL,
"scope_id" BIGINT DEFAULT '0' NOT NULL,
"dict_code" VARCHAR(128 CHAR) NOT NULL,
"dict_name" VARCHAR(128 CHAR) NOT NULL,
"dict_name_key" VARCHAR(160 CHAR) DEFAULT NULL,
"inherit_global" TINYINT DEFAULT '1' NOT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"description" VARCHAR(512 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_dict_type_scope_sort" ON "sys_dict_type"("scope_id" ASC,"sort_no" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_dict_type_scope_status" ON "sys_dict_type"("scope_id" ASC,"status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_dict_type_scope_code" ON "sys_dict_type"("scope_id" ASC,"dict_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_i18n_catalog_revision"
(
"catalog_code" VARCHAR(32 CHAR) NOT NULL,
"revision" BIGINT DEFAULT '1' NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("catalog_code")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_i18n_message"
(
"id" BIGINT NOT NULL,
"message_key" VARCHAR(160 CHAR) NOT NULL,
"default_text" VARCHAR(2000 CHAR) NOT NULL,
"translations_json" JSONB DEFAULT NULL,
"module_code" VARCHAR(64 CHAR) NOT NULL,
"public_visible" TINYINT DEFAULT '0' NOT NULL,
"required_resource" TINYINT DEFAULT '1' NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"description" VARCHAR(512 CHAR) DEFAULT NULL,
"VERSION" BIGINT DEFAULT '1' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
"scope_id" BIGINT DEFAULT 0 NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_i18n_message_module_status" ON "sys_i18n_message"("module_code" ASC,"status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_i18n_message_scope_key" ON "sys_i18n_message"("scope_id" ASC,"message_key" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_login_log"
(
"id" BIGINT IDENTITY(1, 1) NOT NULL,
"username" VARCHAR(64 CHAR) DEFAULT NULL,
"user_id" BIGINT DEFAULT NULL,
"login_status" VARCHAR(20 CHAR) NOT NULL,
"message" VARCHAR(255 CHAR) DEFAULT NULL,
"client_ip" VARCHAR(64 CHAR) DEFAULT NULL,
"trace_id" VARCHAR(64 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_login_log_status_time" ON "sys_login_log"("login_status" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_login_log_username_time" ON "sys_login_log"("username" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_managed_todo"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"project_code" VARCHAR(64 CHAR) NOT NULL,
"producer_service" VARCHAR(16 CHAR) NOT NULL,
"biz_key" VARCHAR(128 CHAR) NOT NULL,
"recipient_user_id" BIGINT NOT NULL,
"operation_sequence" BIGINT NOT NULL,
"state" VARCHAR(16 CHAR) NOT NULL,
"terminal" BIT NOT NULL,
"stale" BIT DEFAULT 0 NOT NULL,
"payload_digest" BINARY(32) NOT NULL,
"operation_created_at" TIMESTAMP(6) NOT NULL,
"title" VARCHAR(200 CHAR),
"CONTENT" VARCHAR(2000 CHAR),
"link_url" VARCHAR(512 CHAR),
"due_at" TIMESTAMP(6),
"last_seen_at" TIMESTAMP(6) NOT NULL,
"created_at" TIMESTAMP(6) NOT NULL,
"updated_at" TIMESTAMP(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "uk_managed_todo" UNIQUE("project_code", "producer_service", "biz_key", "recipient_user_id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_managed_cleanup" ON "sys_managed_todo"("state" ASC,"terminal" ASC,"last_seen_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_managed_recipient" ON "sys_managed_todo"("recipient_user_id" ASC,"state" ASC,"updated_at" ASC,"id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_menu"
(
"id" BIGINT NOT NULL,
"parent_id" BIGINT DEFAULT NULL,
"menu_name" VARCHAR(100 CHAR) NOT NULL,
"menu_type" VARCHAR(20 CHAR) NOT NULL,
"route_path" VARCHAR(256 CHAR) DEFAULT NULL,
"component_path" VARCHAR(256 CHAR) DEFAULT NULL,
"permission_code" VARCHAR(128 CHAR) DEFAULT NULL,
"icon" VARCHAR(64 CHAR) DEFAULT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"VISIBLE" TINYINT DEFAULT '1' NOT NULL,
"status" VARCHAR(20 CHAR) DEFAULT 'ENABLED' NOT NULL,
"created_at" DATETIME(6) DEFAULT CURRENT_TIMESTAMP NOT NULL,
"updated_at" DATETIME(6) DEFAULT CURRENT_TIMESTAMP NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_menu_parent_sort" ON "sys_menu"("parent_id" ASC,"sort_no" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_menu_permission" ON "sys_menu"("permission_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_notification"
(
"id" BIGINT NOT NULL,
"recipient_user_id" BIGINT NOT NULL,
"project_id" BIGINT DEFAULT NULL,
"project_code" VARCHAR(64 CHAR) DEFAULT NULL,
"notification_type" VARCHAR(32 CHAR) NOT NULL,
"title" VARCHAR(200 CHAR) NOT NULL,
"CONTENT" VARCHAR(2000 CHAR) DEFAULT NULL,
"link_url" VARCHAR(512 CHAR) DEFAULT NULL,
"read_at" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_notification_project" ON "sys_notification"("project_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_notification_recipient_read" ON "sys_notification"("recipient_user_id" ASC,"read_at" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_oper_log"
(
"id" BIGINT IDENTITY(1, 1) NOT NULL,
"user_id" BIGINT DEFAULT NULL,
"username" VARCHAR(64 CHAR) DEFAULT NULL,
"module" VARCHAR(64 CHAR) NOT NULL,
"operation" VARCHAR(100 CHAR) NOT NULL,
"request_method" VARCHAR(20 CHAR) NOT NULL,
"request_path" VARCHAR(255 CHAR) NOT NULL,
"response_status" INT NOT NULL,
"detail" VARCHAR(1000 CHAR) DEFAULT NULL,
"client_ip" VARCHAR(64 CHAR) DEFAULT NULL,
"trace_id" VARCHAR(64 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"target_type" VARCHAR(64 CHAR) DEFAULT NULL,
"target_id" VARCHAR(64 CHAR) DEFAULT NULL,
"change_json" TEXT,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_oper_log_module_time" ON "sys_oper_log"("module" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_oper_log_target" ON "sys_oper_log"("target_type" ASC,"target_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_oper_log_user_time" ON "sys_oper_log"("user_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_runtime_task"
(
"task_key" VARCHAR(128 CHAR) NOT NULL,
"task_status" VARCHAR(20 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"completed_at" DATETIME(6) DEFAULT NULL,
NOT CLUSTER PRIMARY KEY("task_key")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_storage_account"
(
"id" BIGINT NOT NULL,
"account_code" VARCHAR(64 CHAR) NOT NULL,
"account_name" VARCHAR(100 CHAR) NOT NULL,
"provider_type" VARCHAR(32 CHAR) NOT NULL,
"endpoint" VARCHAR(255 CHAR) NOT NULL,
"region" VARCHAR(64 CHAR) NOT NULL,
"bucket" VARCHAR(63 CHAR) NOT NULL,
"path_style" TINYINT DEFAULT 0 NOT NULL,
"sts_endpoint" VARCHAR(255 CHAR) NOT NULL,
"role_arn" VARCHAR(255 CHAR),
"access_key_id" VARCHAR(128 CHAR) NOT NULL,
"access_key_secret_ciphertext" VARCHAR(1024 CHAR) NOT NULL,
"credential_ttl_seconds" INT DEFAULT 1800 NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"last_test_status" VARCHAR(16 CHAR),
"last_test_message" VARCHAR(500 CHAR),
"last_test_at" TIMESTAMP(6),
"created_by" BIGINT,
"created_at" TIMESTAMP(6) NOT NULL,
"updated_at" TIMESTAMP(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_storage_account_code" ON "sys_storage_account"("account_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_todo"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"project_code" VARCHAR(64 CHAR) NOT NULL,
"biz_key" VARCHAR(128 CHAR) NOT NULL,
"recipient_user_id" BIGINT NOT NULL,
"title" VARCHAR(200 CHAR) NOT NULL,
"CONTENT" VARCHAR(2000 CHAR) DEFAULT NULL,
"link_url" VARCHAR(512 CHAR) DEFAULT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"due_at" DATETIME(6) DEFAULT NULL,
"opened_at" DATETIME(6) NOT NULL,
"closed_at" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_todo_closed" ON "sys_todo"("status" ASC,"closed_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_todo_recipient" ON "sys_todo"("recipient_user_id" ASC,"status" ASC,"opened_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_todo_stale" ON "sys_todo"("status" ASC,"updated_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_todo_biz" ON "sys_todo"("project_code" ASC,"biz_key" ASC,"recipient_user_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_todo_biz_lock"
(
"project_code" VARCHAR(64 CHAR) NOT NULL,
"biz_key" VARCHAR(128 CHAR) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_code", "biz_key")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_todo_key_guard"
(
"project_code" VARCHAR(64 CHAR) NOT NULL,
"biz_key" VARCHAR(128 CHAR) NOT NULL,
"recipient_user_id" BIGINT NOT NULL,
"kind" VARCHAR(16 CHAR) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_code", "biz_key", "recipient_user_id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_todo_recipient_quota"
(
"project_code" VARCHAR(64 CHAR) NOT NULL,
"recipient_user_id" BIGINT NOT NULL,
"open_count" BIGINT DEFAULT 0 NOT NULL,
NOT CLUSTER PRIMARY KEY("project_code", "recipient_user_id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_user"
(
"id" BIGINT NOT NULL,
"username" VARCHAR(64 CHAR) NOT NULL,
"password_hash" VARCHAR(100 CHAR) NOT NULL,
"display_name" VARCHAR(100 CHAR) NOT NULL,
"email" VARCHAR(200 CHAR) DEFAULT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"locale" VARCHAR(16 CHAR) DEFAULT 'zh-CN' NOT NULL,
"must_change_password" TINYINT DEFAULT '0' NOT NULL,
"agent_auto_open" TINYINT DEFAULT '0' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_user_username" ON "sys_user"("username" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_user_department"
(
"user_id" BIGINT NOT NULL,
"department_id" BIGINT NOT NULL,
"primary_department" TINYINT DEFAULT '0' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("user_id", "department_id"),
CONSTRAINT "fk_sys_user_department_department" FOREIGN KEY("department_id") REFERENCES "sys_department"("id"),
CONSTRAINT "fk_sys_user_department_user" FOREIGN KEY("user_id") REFERENCES "sys_user"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_user_department_department" ON "sys_user_department"("department_id" ASC,"primary_department" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_device_authorization"
(
"id" VARCHAR(36 CHAR) NOT NULL,
"device_code_hash" VARCHAR(64 CHAR) NOT NULL,
"user_code" VARCHAR(16 CHAR) NOT NULL,
"client_name" VARCHAR(64 CHAR) NOT NULL,
"request_ip" VARCHAR(64 CHAR),
"auth_status" VARCHAR(16 CHAR) NOT NULL,
"user_id" BIGINT,
"expires_at" TIMESTAMP(6) NOT NULL,
"created_at" TIMESTAMP(6) NOT NULL,
"decided_at" TIMESTAMP(6),
"consumed_at" TIMESTAMP(6),
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_device_authorization_user" FOREIGN KEY("user_id") REFERENCES "sys_user"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_device_authorization_user_code" ON "sys_device_authorization"("user_code" ASC,"auth_status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_device_authorization_device_code" ON "sys_device_authorization"("device_code_hash" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_dict_item"
(
"id" BIGINT NOT NULL,
"dict_type_id" BIGINT NOT NULL,
"item_label" VARCHAR(128 CHAR) NOT NULL,
"item_value" VARCHAR(128 CHAR) NOT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"default_item" TINYINT DEFAULT '0' NOT NULL,
"color" VARCHAR(32 CHAR) DEFAULT NULL,
"extra_json" TEXT,
"status" VARCHAR(16 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
"label_i18n" JSONB DEFAULT NULL,
"label_i18n_key" VARCHAR(160 CHAR) DEFAULT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_dict_item_type" FOREIGN KEY("dict_type_id") REFERENCES "sys_dict_type"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_dict_item_type_status_sort" ON "sys_dict_item"("dict_type_id" ASC,"status" ASC,"sort_no" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_dict_item_type_value" ON "sys_dict_item"("dict_type_id" ASC,"item_value" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_online_session"
(
"id" VARCHAR(36 CHAR) NOT NULL,
"user_id" BIGINT NOT NULL,
"refresh_token_hash" VARCHAR(64 CHAR) NOT NULL,
"session_status" VARCHAR(20 CHAR) NOT NULL,
"expires_at" DATETIME(6) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"last_seen_at" DATETIME(6) NOT NULL,
"revoked_at" DATETIME(6) DEFAULT NULL,
"session_source" VARCHAR(16 CHAR) DEFAULT 'WEB' NOT NULL,
"client_name" VARCHAR(64 CHAR),
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_online_session_user" FOREIGN KEY("user_id") REFERENCES "sys_user"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_online_session_user_status" ON "sys_online_session"("user_id" ASC,"session_status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project"
(
"id" BIGINT NOT NULL,
"project_code" VARCHAR(64 CHAR) NOT NULL,
"project_name" VARCHAR(100 CHAR) NOT NULL,
"description" VARCHAR(500 CHAR) DEFAULT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"built_in" TINYINT DEFAULT '0' NOT NULL,
"created_by" BIGINT NOT NULL,
"package_name" VARCHAR(128 CHAR) NOT NULL,
"repository_url" VARCHAR(512 CHAR) DEFAULT NULL,
"gitlab_project_id" VARCHAR(256 CHAR) DEFAULT NULL,
"default_branch" VARCHAR(64 CHAR) DEFAULT 'main' NOT NULL,
"backend_url" VARCHAR(512 CHAR) DEFAULT NULL,
"backend_label" VARCHAR(100 CHAR) DEFAULT NULL,
"service_url" VARCHAR(512 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
"health_check_enabled" TINYINT DEFAULT '1' NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_project_creator" FOREIGN KEY("created_by") REFERENCES "sys_user"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "ix_dm_fk_sys_project_creator" ON "sys_project"("created_by" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_project_code" ON "sys_project"("project_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_backend_service"
(
"project_id" BIGINT NOT NULL,
"service_code" VARCHAR(16 CHAR) NOT NULL,
"service_url" VARCHAR(512 CHAR),
"status" VARCHAR(16 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "service_code"),
CONSTRAINT "fk_backend_service_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_config_handover"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"package_digest" VARCHAR(64 CHAR),
"source_host" VARCHAR(255 CHAR),
"source_exported_by" VARCHAR(64 CHAR),
"source_exported_at" VARCHAR(40 CHAR),
"plan_hash" VARCHAR(128 CHAR) NOT NULL,
"git_commit" VARCHAR(64 CHAR),
"applied_access" TINYINT DEFAULT 0 NOT NULL,
"change_count" INT DEFAULT 0 NOT NULL,
"delete_count" INT DEFAULT 0 NOT NULL,
"failure_reason" VARCHAR(500 CHAR),
"changes_json" CLOB,
"keys_json" CLOB,
"operator_id" BIGINT NOT NULL,
"created_at" TIMESTAMP(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_project_config_handover_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_config_handover_project" ON "sys_project_config_handover"("project_id" ASC,"status" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_data_resource"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"resource_code" VARCHAR(128 CHAR) NOT NULL,
"resource_name" VARCHAR(100 CHAR) NOT NULL,
"allowed_scopes" VARCHAR(255 CHAR) NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "uk_sys_project_data_resource" UNIQUE("project_id", "resource_code"),
CONSTRAINT "fk_sys_project_data_resource_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id") ON DELETE CASCADE ) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_generation"
(
"task_no" VARCHAR(64 CHAR) NOT NULL,
"project_id" BIGINT NOT NULL,
"owner_user_id" BIGINT NOT NULL,
"generation_mode" VARCHAR(32 CHAR) NOT NULL,
"business_description" TEXT,
"ddl_content" CLOB,
"generation_status" VARCHAR(20 CHAR) NOT NULL,
"template_version" VARCHAR(32 CHAR) NOT NULL,
"blueprint_json" CLOB,
"ai_model" VARCHAR(128 CHAR) DEFAULT NULL,
"design_summary" VARCHAR(1000 CHAR) DEFAULT NULL,
"backend_artifact_name" VARCHAR(255 CHAR) DEFAULT NULL,
"frontend_artifact_name" VARCHAR(255 CHAR) DEFAULT NULL,
"backend_file_manifest" CLOB,
"frontend_file_manifest" CLOB,
"last_error" VARCHAR(2000 CHAR) DEFAULT NULL,
"started_at" DATETIME(6) DEFAULT NULL,
"completed_at" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("task_no"),
CONSTRAINT "fk_sys_project_generation_owner" FOREIGN KEY("owner_user_id") REFERENCES "sys_user"("id"),
CONSTRAINT "fk_sys_project_generation_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_generation_owner_time" ON "sys_project_generation"("owner_user_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_generation_status" ON "sys_project_generation"("generation_status" ASC,"updated_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_project_generation_project" ON "sys_project_generation"("project_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_member"
(
"project_id" BIGINT NOT NULL,
"user_id" BIGINT NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "user_id"),
CONSTRAINT "fk_sys_project_member_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id"),
CONSTRAINT "fk_sys_project_member_user" FOREIGN KEY("user_id") REFERENCES "sys_user"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "ix_dm_fk_sys_project_member_user" ON "sys_project_member"("user_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_menu"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"parent_id" BIGINT DEFAULT NULL,
"menu_name" VARCHAR(100 CHAR) NOT NULL,
"menu_name_i18n" JSONB DEFAULT NULL,
"menu_name_key" VARCHAR(160 CHAR) DEFAULT NULL,
"menu_type" VARCHAR(20 CHAR) NOT NULL,
"route_path" VARCHAR(256 CHAR) DEFAULT NULL,
"component_path" VARCHAR(256 CHAR) DEFAULT NULL,
"permission_code" VARCHAR(128 CHAR) DEFAULT NULL,
"icon" VARCHAR(64 CHAR) DEFAULT NULL,
"sort_no" INT DEFAULT '0' NOT NULL,
"VISIBLE" TINYINT DEFAULT '1' NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_project_menu_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_menu_parent_sort" ON "sys_project_menu"("project_id" ASC,"parent_id" ASC,"sort_no" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_project_menu_permission" ON "sys_project_menu"("project_id" ASC,"permission_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_repository"
(
"project_id" BIGINT NOT NULL,
"repository_type" VARCHAR(16 CHAR) NOT NULL,
"gitlab_project_id" VARCHAR(256 CHAR) DEFAULT NULL,
"web_url" VARCHAR(512 CHAR) DEFAULT NULL,
"http_clone_url" VARCHAR(512 CHAR) DEFAULT NULL,
"ssh_clone_url" VARCHAR(512 CHAR) DEFAULT NULL,
"default_branch" VARCHAR(64 CHAR) DEFAULT 'main' NOT NULL,
"push_status" VARCHAR(20 CHAR) DEFAULT 'NOT_CONFIGURED' NOT NULL,
"commit_sha" VARCHAR(64 CHAR) DEFAULT NULL,
"last_error" VARCHAR(1000 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "repository_type"),
CONSTRAINT "fk_sys_project_repository_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_role"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"role_code" VARCHAR(64 CHAR) NOT NULL,
"role_name" VARCHAR(100 CHAR) NOT NULL,
"description" VARCHAR(255 CHAR) DEFAULT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"built_in" TINYINT DEFAULT '0' NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_project_role_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_project_role_code" ON "sys_project_role"("project_id" ASC,"role_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_role_data_scope"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"role_id" BIGINT NOT NULL,
"resource_code" VARCHAR(128 CHAR) NOT NULL,
"scope_type" VARCHAR(32 CHAR) NOT NULL,
"include_child" TINYINT DEFAULT 0 NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "uk_sys_project_role_data_scope" UNIQUE("role_id", "resource_code"),
CONSTRAINT "fk_sys_project_role_data_scope_role" FOREIGN KEY("role_id") REFERENCES "sys_project_role"("id") ON DELETE CASCADE ) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_role_data_scope_project" ON "sys_project_role_data_scope"("project_id" ASC,"resource_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_role_data_scope_dept"
(
"scope_id" BIGINT NOT NULL,
"department_id" BIGINT NOT NULL,
NOT CLUSTER PRIMARY KEY("scope_id", "department_id"),
CONSTRAINT "fk_sys_project_role_data_scope_dept_scope" FOREIGN KEY("scope_id") REFERENCES "sys_project_role_data_scope"("id") ON DELETE CASCADE ,
CONSTRAINT "fk_sys_project_role_data_scope_dept_department" FOREIGN KEY("department_id") REFERENCES "sys_department"("id") ON DELETE CASCADE ) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_role_data_scope_dept_department" ON "sys_project_role_data_scope_dept"("department_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_role_menu"
(
"project_id" BIGINT NOT NULL,
"role_id" BIGINT NOT NULL,
"menu_id" BIGINT NOT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "role_id", "menu_id"),
CONSTRAINT "fk_sys_project_role_menu_menu" FOREIGN KEY("menu_id") REFERENCES "sys_project_menu"("id"),
CONSTRAINT "fk_sys_project_role_menu_role" FOREIGN KEY("role_id") REFERENCES "sys_project_role"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "ix_dm_fk_sys_project_role_menu_menu" ON "sys_project_role_menu"("menu_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "ix_dm_fk_sys_project_role_menu_role" ON "sys_project_role_menu"("role_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_storage"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"storage_name" VARCHAR(32 CHAR) NOT NULL,
"account_id" BIGINT NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"max_object_bytes" BIGINT NOT NULL,
"allowed_content_types" VARCHAR(2000 CHAR),
"active_marker" TINYINT GENERATED ALWAYS AS ( CASE  WHEN status = 'ACTIVE' THEN 1 ELSE NULL  END) VIRTUAL ,
"created_at" TIMESTAMP(6) NOT NULL,
"updated_at" TIMESTAMP(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_project_storage_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id"),
CONSTRAINT "fk_sys_project_storage_account" FOREIGN KEY("account_id") REFERENCES "sys_storage_account"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_project_storage_account" ON "sys_project_storage"("account_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_project_storage_active" ON "sys_project_storage"(project_id,storage_name,active_marker) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_scheduler_credential"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"token_hash" VARCHAR(100 CHAR) NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
"service_code" VARCHAR(16 CHAR) DEFAULT 'default' NOT NULL,
"expires_at" DATETIME(6),
"last_used_at" DATETIME(6),
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_scheduler_credential_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_credential_project_service" ON "sys_scheduler_credential"("project_id" ASC,"service_code" ASC,"status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_scheduler_credential_project_status" ON "sys_scheduler_credential"("project_id" ASC,"status" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_scheduler_handler"
(
"project_id" BIGINT NOT NULL,
"task_type" VARCHAR(128 CHAR) NOT NULL,
"task_name" VARCHAR(128 CHAR) NOT NULL,
"instance_id" VARCHAR(128 CHAR) NOT NULL,
"last_seen_at" DATETIME(6) NOT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "task_type"),
CONSTRAINT "fk_sys_scheduler_handler_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_scheduler_handler_seen" ON "sys_scheduler_handler"("last_seen_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_scheduler_job"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"job_name" VARCHAR(128 CHAR) NOT NULL,
"task_type" VARCHAR(128 CHAR) NOT NULL,
"cron_expression" VARCHAR(128 CHAR) NOT NULL,
"zone_id" VARCHAR(64 CHAR) NOT NULL,
"request_payload" TEXT,
"enabled" TINYINT DEFAULT '0' NOT NULL,
"deleted" TINYINT DEFAULT '0' NOT NULL,
"config_version" BIGINT DEFAULT '1' NOT NULL,
"last_run_time" DATETIME(6) DEFAULT NULL,
"next_run_time" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_scheduler_job_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_scheduler_job_project_enabled" ON "sys_scheduler_job"("project_id" ASC,"enabled" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_service_credential_scope"
(
"credential_id" BIGINT NOT NULL,
"scope_code" VARCHAR(64 CHAR) NOT NULL,
NOT CLUSTER PRIMARY KEY("credential_id", "scope_code"),
CONSTRAINT "fk_service_credential_scope" FOREIGN KEY("credential_id") REFERENCES "sys_scheduler_credential"("id")) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_capability"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"capability_code" VARCHAR(160 CHAR) NOT NULL,
"VERSION" VARCHAR(16 CHAR) NOT NULL,
"manifest_json" JSONB NOT NULL,
"manifest_hash" CHAR(64) NOT NULL,
"status" VARCHAR(16 CHAR) DEFAULT 'PENDING' NOT NULL,
"last_seen_at" DATETIME(3) DEFAULT NULL,
"created_at" DATETIME(3) NOT NULL,
"updated_at" DATETIME(3) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_agent_capability_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id"),
CONSTRAINT "ck_sys_agent_capability_status" CHECK(status IN ('PENDING', 'APPROVED', 'REVOKED'))) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_agent_capability_code" ON "sys_agent_capability"("project_id" ASC,"capability_code" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_credential"
(
"project_id" BIGINT NOT NULL,
"credential_id" VARCHAR(36 CHAR) NOT NULL,
"token_hash" CHAR(64) NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"created_at" DATETIME(3) NOT NULL,
"updated_at" DATETIME(3) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id"),
CONSTRAINT "fk_sys_agent_credential_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id"),
CONSTRAINT "ck_sys_agent_credential_status" CHECK(status IN ('ACTIVE', 'REVOKED'))) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_agent_credential_id" ON "sys_agent_credential"("credential_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_registry_event"
(
"id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"capability_code" VARCHAR(160 CHAR) DEFAULT NULL,
"manifest_hash" CHAR(64) DEFAULT NULL,
"operation" VARCHAR(32 CHAR) NOT NULL,
"actor_user_id" BIGINT DEFAULT NULL,
"credential_id" VARCHAR(36 CHAR) DEFAULT NULL,
"occurred_at" DATETIME(3) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_agent_registry_event_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_agent_registry_event_project_time" ON "sys_agent_registry_event"("project_id" ASC,"occurred_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_agent_remote_action"
(
"action_id" CHAR(36) NOT NULL,
"project_id" BIGINT NOT NULL,
"user_id" BIGINT NOT NULL,
"session_id" VARCHAR(128 CHAR) NOT NULL,
"capability_code" VARCHAR(160 CHAR) NOT NULL,
"capability_version" VARCHAR(16 CHAR) NOT NULL,
"manifest_hash" CHAR(64) NOT NULL,
"params_hash" CHAR(64) NOT NULL,
"preconditions_hash" CHAR(64) NOT NULL,
"preview_hash" CHAR(64) NOT NULL,
"frozen_ciphertext" CLOB NOT NULL,
"token_hash" CHAR(64) NOT NULL,
"confirmation_mode" VARCHAR(16 CHAR) NOT NULL,
"status" VARCHAR(16 CHAR) NOT NULL,
"expires_at" DATETIME(3) NOT NULL,
"started_at" DATETIME(3) DEFAULT NULL,
"finished_at" DATETIME(3) DEFAULT NULL,
"result_ciphertext" CLOB,
"reason_code" VARCHAR(64 CHAR) DEFAULT NULL,
"revision" INT DEFAULT '0' NOT NULL,
"created_at" DATETIME(3) NOT NULL,
"updated_at" DATETIME(3) NOT NULL,
NOT CLUSTER PRIMARY KEY("action_id"),
CONSTRAINT "fk_sys_agent_remote_action_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id"),
CONSTRAINT "ck_sys_agent_remote_action_confirmation" CHECK(confirmation_mode IN ('REQUIRED', 'STRONG'))
,CONSTRAINT "ck_sys_agent_remote_action_status" CHECK(status IN ('PENDING', 'EXECUTING', 'SUCCEEDED', 'REJECTED', 'FAILED', 'UNKNOWN', 'CANCELLED', 'EXPIRED'))) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_agent_remote_action_owner" ON "sys_agent_remote_action"("user_id" ASC,"session_id" ASC,"status" ASC,"expires_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_agent_remote_action_project" ON "sys_agent_remote_action"("project_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_codegen_task"
(
"task_no" VARCHAR(64 CHAR) NOT NULL,
"project_id" BIGINT NOT NULL,
"owner_user_id" BIGINT NOT NULL,
"module_code" VARCHAR(64 CHAR) NOT NULL,
"module_name" VARCHAR(100 CHAR) NOT NULL,
"permission_prefix" VARCHAR(128 CHAR) NOT NULL,
"ddl_content" CLOB NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"artifact_name" VARCHAR(128 CHAR) NOT NULL,
"file_manifest" TEXT NOT NULL,
"generation_mode" VARCHAR(32 CHAR) DEFAULT 'DETERMINISTIC' NOT NULL,
"ai_model" VARCHAR(128 CHAR) DEFAULT NULL,
"design_summary" VARCHAR(1000 CHAR) DEFAULT NULL,
"source_branch" VARCHAR(128 CHAR) DEFAULT NULL,
"mr_url" VARCHAR(512 CHAR) DEFAULT NULL,
"last_error" VARCHAR(1000 CHAR) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("task_no"),
CONSTRAINT "fk_sys_codegen_owner" FOREIGN KEY("owner_user_id") REFERENCES "sys_user"("id"),
CONSTRAINT "fk_sys_codegen_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_codegen_owner_time" ON "sys_codegen_task"("owner_user_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_codegen_project_time" ON "sys_codegen_task"("project_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_project_member_role"
(
"project_id" BIGINT NOT NULL,
"user_id" BIGINT NOT NULL,
"role_id" BIGINT NOT NULL,
"created_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("project_id", "user_id", "role_id"),
CONSTRAINT "fk_sys_project_member_role_member" FOREIGN KEY("project_id", "user_id") REFERENCES "sys_project_member"("project_id", "user_id"),
CONSTRAINT "fk_sys_project_member_role_role" FOREIGN KEY("role_id") REFERENCES "sys_project_role"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "ix_dm_fk_sys_project_member_role_role" ON "sys_project_member_role"("role_id" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

CREATE TABLE "sys_scheduler_execution"
(
"id" BIGINT NOT NULL,
"job_id" BIGINT NOT NULL,
"project_id" BIGINT NOT NULL,
"config_version" BIGINT NOT NULL,
"scheduled_at" DATETIME(3) NOT NULL,
"instance_id" VARCHAR(128 CHAR) NOT NULL,
"status" VARCHAR(20 CHAR) NOT NULL,
"lease_until" DATETIME(6) DEFAULT NULL,
"message" VARCHAR(1000 CHAR) DEFAULT NULL,
"started_at" DATETIME(6) DEFAULT NULL,
"completed_at" DATETIME(6) DEFAULT NULL,
"created_at" DATETIME(6) NOT NULL,
"updated_at" DATETIME(6) NOT NULL,
NOT CLUSTER PRIMARY KEY("id"),
CONSTRAINT "fk_sys_scheduler_execution_job" FOREIGN KEY("job_id") REFERENCES "sys_scheduler_job"("id"),
CONSTRAINT "fk_sys_scheduler_execution_project" FOREIGN KEY("project_id") REFERENCES "sys_project"("id")) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_scheduler_execution_lease" ON "sys_scheduler_execution"("status" ASC,"lease_until" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE  INDEX "idx_sys_scheduler_execution_project_time" ON "sys_scheduler_execution"("project_id" ASC,"created_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);
CREATE OR REPLACE UNIQUE  INDEX "uk_sys_scheduler_execution_fire" ON "sys_scheduler_execution"("job_id" ASC,"scheduled_at" ASC) STORAGE(ON "MAIN", CLUSTERBTR);

INSERT INTO "sys_ai_model_route" ("id", "plan_model_id", "answer_model_id") VALUES
(1, NULL, NULL);
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(8001, 0, 'app.admin.brand', 'Kaiwu', NULL, 'STRING', 0, 'ENABLED', '业务管理端默认品牌名称', 10, '2026-11-13 01:09:44.394811', '2026-11-13 01:09:44.394818');
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(8002, 0, 'app.admin.label', '业务后台', NULL, 'STRING', 0, 'ENABLED', '业务管理端默认应用名称', 20, '2026-11-13 01:09:44.398331', '2026-11-13 01:09:44.398334');
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(8003, 0, 'common.table.page_size', '20', NULL, 'NUMBER', 0, 'ENABLED', '列表默认每页条数，业务端使用前应限制在 5-200', 30, '2026-11-13 01:09:44.400288', '2026-11-13 01:09:44.400292');
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(9200000000000007500, 0, 'platform.notification.poll_seconds', '60', NULL, 'NUMBER', 0, 'ENABLED', '消息铃铛刷新间隔（秒，15-600）；在线时约一分钟内刷新', 40, '2026-11-13 01:09:52.268196', '2026-11-13 01:09:52.268196');
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(9200000000000007501, 0, 'platform.factory.poll_seconds', '3', NULL, 'NUMBER', 0, 'ENABLED', '项目工厂运行中任务刷新间隔（秒，2-60）；在线时约一分钟内刷新', 50, '2026-11-13 01:09:52.276908', '2026-11-13 01:09:52.276908');
INSERT INTO "sys_app_config" ("id", "scope_id", "config_key", "config_value", "value_i18n_key", "value_type", "secret", "status", "description", "sort_no", "created_at", "updated_at") VALUES
(9200000000000007502, 0, 'platform.home.poll_seconds', '5', NULL, 'NUMBER', 0, 'ENABLED', '工作台运行中任务刷新间隔（秒，2-60）；在线时约一分钟内刷新', 60, '2026-11-13 01:09:52.284406', '2026-11-13 01:09:52.284406');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8101, 0, 'common.status', '通用启停状态', 'dictType.common.status', 0, 0, 'ENABLED', '平台和生成业务可复用的启停状态', '2026-11-13 01:09:44.543040', '2026-11-13 01:09:44.543043');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8102, 0, 'common.boolean_enabled', '是否启用', 'dictType.common.boolean_enabled', 0, 0, 'ENABLED', '布尔启用选项', '2026-11-13 01:09:44.544541', '2026-11-13 01:09:44.544544');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8301, 0, 'user.status', '平台用户状态', 'dictType.user.status', 0, 0, 'ENABLED', '平台身份账号是否可用', '2026-11-13 01:09:44.545672', '2026-11-13 01:09:44.545675');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8302, 0, 'project.status', '业务项目状态', 'dictType.project.status', 0, 0, 'ENABLED', '业务项目生命周期：启用、停用、归档', '2026-11-13 01:09:44.546868', '2026-11-13 01:09:44.546871');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8303, 0, 'project.member.status', '项目成员状态', 'dictType.project.member.status', 0, 0, 'ENABLED', '成员在项目内是否有效', '2026-11-13 01:09:44.548162', '2026-11-13 01:09:44.548165');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8304, 0, 'platform.menu.type', '平台菜单类型', 'dictType.platform.menu.type', 0, 0, 'ENABLED', '菜单节点类型：目录、菜单、按钮', '2026-11-13 01:09:44.549357', '2026-11-13 01:09:44.549360');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8305, 0, 'config.value.type', '配置值类型', 'dictType.config.value.type', 0, 0, 'ENABLED', '应用配置的值类型：STRING/NUMBER/BOOLEAN/JSON', '2026-11-13 01:09:44.550606', '2026-11-13 01:09:44.550609');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8306, 0, 'ai.test.status', '大模型连通测试状态', 'dictType.ai.test.status', 0, 0, 'ENABLED', '大模型 provider 最近一次连通测试结果', '2026-11-13 01:09:44.552001', '2026-11-13 01:09:44.552003');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8308, 0, 'project.generation.mode', '项目生成方式', 'dictType.project.generation.mode', 0, 0, 'ENABLED', '项目工厂生成方式：AI 项目 / 基础空脚手架', '2026-11-13 01:09:44.557933', '2026-11-13 01:09:44.557937');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8309, 0, 'project.generation.status', '项目生成状态', 'dictType.project.generation.status', 0, 0, 'ENABLED', '项目生成任务生命周期', '2026-11-13 01:09:44.559230', '2026-11-13 01:09:44.559233');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8313, 0, 'notification.type', '站内信分类', 'dictType.notification.type', 0, 0, 'ENABLED', '站内信来源分类：系统、项目、任务', '2026-11-13 01:09:44.561692', '2026-11-13 01:09:44.561695');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8314, 0, 'security.login.status', '登录日志状态', 'dictType.security.login.status', 0, 0, 'ENABLED', '登录审计结果；当前后端只写入 SUCCESS 与 FAILED', '2026-11-13 01:09:44.562905', '2026-11-13 01:09:44.562908');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8315, 0, 'security.session.status', '在线会话状态', 'dictType.security.session.status', 0, 0, 'ENABLED', '在线会话生命周期：在线、已撤销', '2026-11-13 01:09:44.564163', '2026-11-13 01:09:44.564166');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8316, 0, 'scheduler.execution.status', '定时任务执行状态', 'dictType.scheduler.execution.status', 0, 0, 'ENABLED', '项目定时任务执行生命周期', '2026-11-13 01:09:44.565849', '2026-11-13 01:09:44.565857');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8317, 0, 'platform.locale', '平台语言', 'dictType.platform.locale', 0, 0, 'ENABLED', '平台语言唯一目录；约束运行期所有多语言 JSON 的 locale key', '2026-11-13 01:09:44.568195', '2026-11-13 01:09:44.568201');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8321, 0, 'common.tag_color', '标签颜色', 'dictType.common.tag_color', 0, 0, 'ENABLED', '字典项 Tag 的展示颜色；状态类优先用语义色，类别类可用 purple/cyan', '2026-11-13 01:09:44.572286', '2026-11-13 01:09:44.572297');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8331, 0, 'security.audit.module', '审计模块', 'dictType.security.audit.module', 0, 0, 'ENABLED', '操作审计日志的来源模块；取值为 AuditService.recordOperation 的 module 实参', '2026-11-13 01:09:44.574447', '2026-11-13 01:09:44.574452');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8340, 0, 'agent.capability.status', 'Agent 能力审批状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-13 01:09:44.575966', '2026-11-13 01:09:44.575971');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8341, 0, 'agent.capability.connection', 'Agent 能力连接状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-13 01:09:44.577342', '2026-11-13 01:09:44.577346');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8342, 0, 'agent.action.status', 'Agent 操作状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-13 01:09:44.578701', '2026-11-13 01:09:44.578706');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(8343, 0, 'security.session.source', '会话来源', 'dictType.security.session.source', 0, 0, 'ENABLED', '在线会话的签发方式；取值为 sys_online_session.session_source', '2026-11-13 01:09:48.776504', '2026-11-13 01:09:48.776504');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000004300, 0, 'agent.remote_action.status', 'Agent 子项目操作状态', NULL, 0, 0, 'ENABLED', NULL, '2026-11-13 01:09:44.580266', '2026-11-13 01:09:44.580272');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000007000, 0, 'storage.provider.type', '对象存储类型', 'dictType.storage.provider.type', 0, 0, 'ENABLED', '决定 System 使用哪种 STS 签发器，以及业务项目的访问风格', '2026-11-13 01:09:49.840993', '2026-11-13 01:09:49.840993');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000007001, 0, 'storage.binding.status', '项目存储绑定状态', 'dictType.storage.binding.status', 0, 0, 'ENABLED', 'ACTIVE 可读写；READ_ONLY 只签发读权限，用于切换存储后读取历史文件', '2026-11-13 01:09:49.850181', '2026-11-13 01:09:49.850181');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000007250, 0, 'project.handover.status', '配置移交记录状态', 'dictType.project.handover.status', 0, 0, 'ENABLED', '记录一次配置移交的结果', '2026-11-13 01:09:51.390978', '2026-11-13 01:09:51.390978');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000007253, 0, 'project.handover.action', '配置移交动作', 'dictType.project.handover.action', 0, 0, 'ENABLED', '计划里每个条目的处理方式', '2026-11-13 01:09:51.400892', '2026-11-13 01:09:51.400892');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000007258, 0, 'project.handover.resource', '配置移交资源类型', 'dictType.project.handover.resource', 0, 0, 'ENABLED', '计划条目所属的资源类型', '2026-11-13 01:09:51.411638', '2026-11-13 01:09:51.411638');
INSERT INTO "sys_dict_type" ("id", "scope_id", "dict_code", "dict_name", "dict_name_key", "inherit_global", "sort_no", "status", "description", "created_at", "updated_at") VALUES
(9200000000000013000, 0, 'project.data_scope.type', '数据范围类型', 'dictType.project.data_scope.type', 0, 0, 'ENABLED', '角色在受控资源上的可见范围', '2026-11-13 01:09:52.744122', '2026-11-13 01:09:52.744122');
INSERT INTO "sys_i18n_catalog_revision" ("catalog_code", "revision", "updated_at") VALUES
('platform', 98, '2026-11-13 01:09:53.792532');
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(7170, 'storage.account.bucketHint', '在对象存储控制台的 Bucket 列表里复制名称，只填名称，不带域名。', '{"en-US":"Copy the name from the bucket list in your object storage console; the name only, without a domain.","ja-JP":"コンソールのバケット一覧からバケット名のみをコピーします（ドメインは不要）。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.994702', '2026-11-13 01:09:50.994702', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(7171, 'storage.account.stsEndpointHint', '阿里云无需查询，按区域拼写：https://sts.<区域>.aliyuncs.com；S3 兼容填该服务的 STS 接口地址。', '{"en-US":"For Alibaba Cloud, build it from the region: https://sts.<region>.aliyuncs.com. For S3-compatible services, use the service STS endpoint.","ja-JP":"Alibaba Cloud ではリージョンから https://sts.<リージョン>.aliyuncs.com と組み立てます。S3 互換では当該サービスの STS エンドポイントを指定します。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.011867', '2026-11-13 01:09:51.011867', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(7172, 'storage.account.regionHint', '填 Bucket 概览里的地域 ID（如 cn-hangzhou），不是中文名；须与存储地址里的区域一致。', '{"en-US":"Use the region ID from the bucket overview (e.g. cn-hangzhou), not the display name; it must match the region in the endpoint.","ja-JP":"バケット概要のリージョン ID（例：cn-hangzhou）を入力します。表示名ではなく、エンドポイントのリージョンと一致させてください。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.027716', '2026-11-13 01:09:51.027716', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(7173, 'storage.account.roleArnHint', '在 RAM 控制台 → 角色 → 基本信息里复制 ARN，形如 acs:ram::账号ID:role/角色名。阿里云必填，S3 兼容可留空。', '{"en-US":"Copy the ARN from RAM console → Roles → Basic information, e.g. acs:ram::<account-id>:role/<role-name>. Required for Alibaba Cloud; optional for S3-compatible services.","ja-JP":"RAM コンソール → ロール → 基本情報から ARN（例：acs:ram::アカウントID:role/ロール名）をコピーします。Alibaba Cloud では必須、S3 互換では省略できます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.043826', '2026-11-13 01:09:51.043826', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000001, 'ai.apiKey', 'API Key（{state}）', '{"en-US":"API key ({state})"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.590933', '2026-11-13 01:09:44.590941', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000002, 'ai.apiKeyPlaceholder', '留空保留原值；无鉴权的内网模型可不填', '{"en-US":"Leave empty to keep the current value; optional for internal providers without authentication"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.593288', '2026-11-13 01:09:44.593293', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000003, 'ai.apiKeyPlain', 'API Key', '{"en-US":"API key"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.595319', '2026-11-13 01:09:44.595324', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000004, 'ai.baseUrl', 'API Base URL', '{"en-US":"API Base URL"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.599055', '2026-11-13 01:09:44.599073', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000005, 'ai.baseUrlPlaceholder', 'https://api.openai.com/v1', '{"en-US":"https://api.openai.com/v1"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.601969', '2026-11-13 01:09:44.601975', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000006, 'ai.clearApiKey', '清除已保存的 API Key', '{"en-US":"Clear saved API key"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.603648', '2026-11-13 01:09:44.603652', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000007, 'ai.configured', '已配置', '{"en-US":"Configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.605299', '2026-11-13 01:09:44.605303', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000008, 'ai.currentModel', '当前模型', '{"en-US":"Current model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.606814', '2026-11-13 01:09:44.606817', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000010, 'ai.model', '模型', '{"en-US":"Model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.609611', '2026-11-13 01:09:44.609614', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000011, 'ai.modelPlaceholder', '例如：gpt-4.1-mini', '{"en-US":"For example, gpt-4.1-mini"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.610895', '2026-11-13 01:09:44.610898', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000012, 'ai.name', '配置名称', '{"en-US":"Configuration name"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.612474', '2026-11-13 01:09:44.612479', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000013, 'ai.namePlaceholder', '例如：OpenAI、DeepSeek、本地兼容服务', '{"en-US":"For example, OpenAI, DeepSeek, or a local compatible service"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.614845', '2026-11-13 01:09:44.614860', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000014, 'ai.notConfigured', '未配置', '{"en-US":"Not configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.618188', '2026-11-13 01:09:44.618195', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000015, 'ai.provider', 'Provider', '{"en-US":"Provider"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.619973', '2026-11-13 01:09:44.619977', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000016, 'ai.saved', '大模型配置已加密保存', '{"en-US":"AI provider configuration saved securely"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.622360', '2026-11-13 01:09:44.622367', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000017, 'ai.subtitle', '只管理 OpenAI-compatible Provider；密钥加密保存且永不回传', '{"en-US":"Manage an OpenAI-compatible provider. Secrets are encrypted and never returned."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.623944', '2026-11-13 01:09:44.623948', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000018, 'ai.temperature', 'Temperature', '{"en-US":"Temperature"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.625401', '2026-11-13 01:09:44.625404', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000019, 'ai.testFailed', '连接测试失败，详情见运行状态', '{"en-US":"Connection test failed. See Runtime status for details."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.626739', '2026-11-13 01:09:44.626743', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000020, 'ai.testSaved', '测试已保存配置', '{"en-US":"Test saved configuration"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.628198', '2026-11-13 01:09:44.628201', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000021, 'ai.testSuccess', '连接成功 · {latency} ms', '{"en-US":"Connected · {latency} ms"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.630155', '2026-11-13 01:09:44.630163', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000022, 'ai.timeout', '请求超时（秒）', '{"en-US":"Request timeout (seconds)"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.632942', '2026-11-13 01:09:44.632958', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000023, 'ai.title', '大模型配置', '{"en-US":"AI provider"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.635563', '2026-11-13 01:09:44.635568', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000024, 'ai.urlRule', '请输入完整 HTTP(S) URL', '{"en-US":"Enter a complete HTTP(S) URL"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.637772', '2026-11-13 01:09:44.637778', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000025, 'api.auth.accountLocked', '登录失败次数过多，请 {minutes} 分钟后再试', '{"en-US":"Too many failed sign-in attempts. Try again in {minutes} minutes."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.639858', '2026-11-13 01:09:44.639863', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000026, 'api.auth.invalidCredentials', '用户名或密码错误', '{"en-US":"Incorrect username or password"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.641408', '2026-11-13 01:09:44.641412', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000027, 'api.auth.password.incorrect', '当前密码错误', '{"en-US":"The current password is incorrect"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.642792', '2026-11-13 01:09:44.642795', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000028, 'api.auth.password.mismatch', '两次输入的新密码不一致', '{"en-US":"The new passwords do not match"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.644085', '2026-11-13 01:09:44.644088', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000029, 'api.auth.password.tooLong', '新密码 UTF-8 编码后不能超过 72 字节', '{"en-US":"The new password cannot exceed 72 UTF-8 bytes"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.645422', '2026-11-13 01:09:44.645426', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000030, 'api.auth.password.unchanged', '新密码不能与当前密码相同', '{"en-US":"The new password must differ from the current password"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.647083', '2026-11-13 01:09:44.647089', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000031, 'api.auth.refreshInvalid', '刷新令牌无效或已过期', '{"en-US":"The refresh token is invalid or expired"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.648892', '2026-11-13 01:09:44.648899', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000032, 'api.locale.unsupported', '暂不支持该语言', '{"en-US":"This language is not supported"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.650607', '2026-11-13 01:09:44.650611', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000033, 'api.pagination.invalid', '分页参数超出允许范围', '{"en-US":"Pagination parameters are out of range"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.652101', '2026-11-13 01:09:44.652105', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000034, 'api.project.notFound', '项目不存在', '{"en-US":"Project not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.653459', '2026-11-13 01:09:44.653462', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000035, 'api.projectFactory.activeRequired', '只有启用项目可以生成', '{"en-US":"Only active projects can be generated"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.656366', '2026-11-13 01:09:44.656368', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000036, 'api.projectFactory.adminRequired', '只有目标项目的有效项目管理员可以使用项目工厂', '{"en-US":"Only an active project administrator for the target project can use Project factory"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.657751', '2026-11-13 01:09:44.657753', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000037, 'api.projectFactory.builtInForbidden', '内置 system 项目已有真实源码，不能通过项目工厂生成', '{"en-US":"The built-in system project already has real source and cannot be generated by Project factory"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.659027', '2026-11-13 01:09:44.659029', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000038, 'api.user.cannotDisableSelf', '不能停用当前登录用户', '{"en-US":"You cannot disable the currently signed-in user"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.660269', '2026-11-13 01:09:44.660272', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000039, 'api.user.changeOwnPassword', '请通过个人安全设置修改自己的密码', '{"en-US":"Change your own password in Profile security settings"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.661562', '2026-11-13 01:09:44.661565', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000040, 'api.user.export.tooManyRows', '导出结果超过 {limit} 条，请先用用户名或显示名筛选后再导出', '{"en-US":"The export exceeds {limit} rows. Filter by username or display name first."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.662768', '2026-11-13 01:09:44.662771', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000041, 'api.user.import.displayNameInvalid', '姓名不能为空且最多 100 字', '{"en-US":"Display name is required and cannot exceed 100 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.663919', '2026-11-13 01:09:44.663922', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000042, 'api.user.import.failed', '导入失败', '{"en-US":"Import failed"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.665196', '2026-11-13 01:09:44.665199', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000043, 'api.user.import.fileSize', 'Excel 文件大小必须在 1B 到 10MB 之间', '{"en-US":"The Excel file must be between 1 byte and 10 MB"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.666482', '2026-11-13 01:09:44.666486', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000044, 'api.user.import.invalidWorkbook', '无法读取 Excel，请使用平台模板', '{"en-US":"Cannot read the Excel workbook. Use the platform template."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.668094', '2026-11-13 01:09:44.668099', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000045, 'api.user.import.passwordInvalid', '初始密码长度必须为 12-72 位', '{"en-US":"The initial password must contain 12 to 72 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.669624', '2026-11-13 01:09:44.669627', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000046, 'api.user.import.statusInvalid', '状态只能是 ENABLED 或 DISABLED', '{"en-US":"Status must be ENABLED or DISABLED"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.670998', '2026-11-13 01:09:44.671001', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000047, 'api.user.import.tooManyRows', '单次最多导入 5000 行', '{"en-US":"A single import can contain at most 5,000 rows"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.672565', '2026-11-13 01:09:44.672568', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000048, 'api.user.import.unknownDepartment', '存在未知部门编码', '{"en-US":"One or more department codes are unknown"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.673885', '2026-11-13 01:09:44.673888', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000049, 'api.user.import.usernameInvalid', '用户名格式不正确', '{"en-US":"The username format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.675122', '2026-11-13 01:09:44.675125', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000050, 'api.user.notFound', '用户不存在', '{"en-US":"User not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.676298', '2026-11-13 01:09:44.676301', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000051, 'api.user.usernameExists', '用户名已存在', '{"en-US":"The username already exists"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.677481', '2026-11-13 01:09:44.677484', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000052, 'api.user.workbook.generateFailed', '生成用户表格失败', '{"en-US":"Failed to generate the user workbook"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.678749', '2026-11-13 01:09:44.678752', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000053, 'api.validation.failed', '请求参数错误', '{"en-US":"Invalid request parameters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.679940', '2026-11-13 01:09:44.679943', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000054, 'client.catalogFailed', '语言资源加载失败，已保留当前界面语言', '{"en-US":"Language resources failed to load; the current language was kept"}', 'client', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.681223', '2026-11-13 01:09:44.681226', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000055, 'client.connectionFailed', '无法连接服务，请确认 Kaiwu 网关已启动', '{"en-US":"Cannot connect to the service. Confirm that the Kaiwu Gateway is running."}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.682482', '2026-11-13 01:09:44.682485', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000056, 'client.downloadFailed', '下载失败（HTTP {status}）', '{"en-US":"Download failed (HTTP {status})"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.683669', '2026-11-13 01:09:44.683672', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000057, 'client.loginFailed', '登录失败（HTTP {status}）', '{"en-US":"Sign-in failed (HTTP {status})"}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.684873', '2026-11-13 01:09:44.684876', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000058, 'client.refreshFailed', '刷新失败（HTTP {status}）', '{"en-US":"Token refresh failed (HTTP {status})"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.686438', '2026-11-13 01:09:44.686442', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000059, 'client.refreshInvalid', '刷新令牌无效或已过期', '{"en-US":"The refresh token is invalid or expired"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.688000', '2026-11-13 01:09:44.688005', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000060, 'client.refreshMissing', '缺少刷新令牌', '{"en-US":"Refresh token is missing"}', 'client', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.690440', '2026-11-13 01:09:44.690443', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000061, 'client.requestFailed', '请求失败（HTTP {status}）', '{"en-US":"Request failed (HTTP {status})"}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.691772', '2026-11-13 01:09:44.691775', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000062, 'client.serviceUnavailable', '服务暂时不可用，请检查 Gateway/Nacos 配置后重试', '{"en-US":"The service is temporarily unavailable. Check Gateway/Nacos and try again."}', 'client', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.693154', '2026-11-13 01:09:44.693158', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000063, 'client.sessionExpired', '会话已失效', '{"en-US":"Your session has expired"}', 'client', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.694506', '2026-11-13 01:09:44.694509', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000064, 'common.clearSelection', '取消选择', '{"en-US":"Clear selection"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.695722', '2026-11-13 01:09:44.695725', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000065, 'common.delete', '删除', '{"en-US":"Delete"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.696899', '2026-11-13 01:09:44.696901', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000066, 'common.deleted', '已删除', '{"en-US":"Deleted"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.698203', '2026-11-13 01:09:44.698205', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000067, 'common.disable', '停用', '{"en-US":"Disable"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.699403', '2026-11-13 01:09:44.699405', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000068, 'common.edit', '编辑', '{"en-US":"Edit"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.700695', '2026-11-13 01:09:44.700698', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000069, 'common.enable', '启用', '{"en-US":"Enable"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.701987', '2026-11-13 01:09:44.701990', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000070, 'common.language', '语言', '{"en-US":"Language"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.703390', '2026-11-13 01:09:44.703393', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000071, 'common.language.enUS', 'English', '{"en-US":"English"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.704712', '2026-11-13 01:09:44.704715', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000072, 'common.language.updateFailed', '保存语言设置失败', '{"en-US":"Failed to save language preference"}', 'common', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.706392', '2026-11-13 01:09:44.706395', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000073, 'common.language.updated', '语言设置已保存', '{"en-US":"Language preference saved"}', 'common', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.707693', '2026-11-13 01:09:44.707696', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000074, 'common.language.zhCN', '简体中文', '{"en-US":"简体中文"}', 'common', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.708992', '2026-11-13 01:09:44.708996', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000075, 'common.operationFailed', '操作失败', '{"en-US":"Operation failed"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.710267', '2026-11-13 01:09:44.710270', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000076, 'common.refresh', '刷新', '{"en-US":"Refresh"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.711566', '2026-11-13 01:09:44.711569', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000077, 'common.saved', '已保存', '{"en-US":"Saved"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.712738', '2026-11-13 01:09:44.712741', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000078, 'common.selectedCount', '已选择 {count} 项', '{"en-US":"{count} selected"}', 'common', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.713911', '2026-11-13 01:09:44.713914', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000080, 'config.recentTest', '最近测试', '{"en-US":"Latest test"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.716233', '2026-11-13 01:09:44.716235', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000081, 'config.runtime', '运行状态', '{"en-US":"Runtime status"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.717439', '2026-11-13 01:09:44.717442', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000082, 'config.testTime', '测试时间', '{"en-US":"Test time"}', 'config', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.718767', '2026-11-13 01:09:44.718770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000083, 'configs.actions', '操作', '{"en-US":"Actions"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.720061', '2026-11-13 01:09:44.720063', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000084, 'configs.create', '新增配置', '{"en-US":"Create configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.724183', '2026-11-13 01:09:44.724187', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000085, 'configs.createTitle', '新增配置', '{"en-US":"Create configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.725698', '2026-11-13 01:09:44.725700', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000086, 'configs.delete', '删除', '{"en-US":"Delete"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.726973', '2026-11-13 01:09:44.726976', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000087, 'configs.deleteConfirm', '确认删除该配置？', '{"en-US":"Delete this configuration?"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.728241', '2026-11-13 01:09:44.728243', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000088, 'configs.deleted', '配置已删除', '{"en-US":"Configuration deleted"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.729348', '2026-11-13 01:09:44.729351', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000089, 'configs.description', '说明', '{"en-US":"Description"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.730585', '2026-11-13 01:09:44.730588', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000090, 'configs.edit', '编辑', '{"en-US":"Edit"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.731780', '2026-11-13 01:09:44.731783', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000091, 'configs.editTitle', '编辑配置', '{"en-US":"Edit configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.732951', '2026-11-13 01:09:44.732954', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000092, 'configs.empty', '当前范围暂无配置，点击右上角新增', '{"en-US":"No configuration in this scope. Use Create in the upper right."}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.734138', '2026-11-13 01:09:44.734140', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000093, 'configs.encrypted', '已加密', '{"en-US":"Encrypted"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.735429', '2026-11-13 01:09:44.735432', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000094, 'configs.key', '配置键', '{"en-US":"Key"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.736782', '2026-11-13 01:09:44.736785', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000095, 'configs.keyRule', '配置键格式不正确', '{"en-US":"The key format is invalid"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.739252', '2026-11-13 01:09:44.739254', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000096, 'configs.saved', '配置已保存', '{"en-US":"Configuration saved"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.740571', '2026-11-13 01:09:44.740573', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000097, 'configs.secret', '敏感配置', '{"en-US":"Secret"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.741945', '2026-11-13 01:09:44.741947', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000098, 'configs.secretPlaceholder', '保留 ****** 或留空表示不修改密文', '{"en-US":"Keep ****** or leave empty to retain the encrypted value"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.743196', '2026-11-13 01:09:44.743199', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000099, 'configs.secretTooltip', 'AES-GCM 加密保存，且不会通过 effective config API 下发', '{"en-US":"Encrypted with AES-GCM and never returned by the effective configuration API"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.744472', '2026-11-13 01:09:44.744474', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000100, 'configs.sort', '排序', '{"en-US":"Sort order"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.745598', '2026-11-13 01:09:44.745601', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000101, 'configs.status', '状态', '{"en-US":"Status"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.746787', '2026-11-13 01:09:44.746790', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000102, 'configs.subtitle', '全局默认可被项目同名配置覆盖，敏感配置永不下发业务前端', '{"en-US":"Project settings override global defaults with the same key. Secrets are never sent to business frontends."}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.748060', '2026-11-13 01:09:44.748063', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000103, 'configs.title', '参数配置', '{"en-US":"Configuration"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.749317', '2026-11-13 01:09:44.749319', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000104, 'configs.value', '配置值', '{"en-US":"Value"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.750433', '2026-11-13 01:09:44.750436', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000105, 'configs.valueType', '值类型', '{"en-US":"Value type"}', 'configs', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.751656', '2026-11-13 01:09:44.751659', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000106, 'dict.ai.test.status.FAILED', '失败', '{"en-US":"Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.752905', '2026-11-13 01:09:44.752908', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000107, 'dict.ai.test.status.SUCCESS', '成功', '{"en-US":"Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.754228', '2026-11-13 01:09:44.754231', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000108, 'dict.common.boolean_enabled.false', '否', '{"en-US":"No"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.756848', '2026-11-13 01:09:44.756851', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000109, 'dict.common.boolean_enabled.true', '是', '{"en-US":"Yes"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.758322', '2026-11-13 01:09:44.758325', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000110, 'dict.common.status.DISABLED', '停用', '{"en-US":"Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.759638', '2026-11-13 01:09:44.759641', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000111, 'dict.common.status.ENABLED', '启用', '{"en-US":"Enabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.760947', '2026-11-13 01:09:44.760950', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000112, 'dict.config.value.type.BOOLEAN', '布尔值', '{"en-US":"Boolean"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.762857', '2026-11-13 01:09:44.762860', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000113, 'dict.config.value.type.JSON', 'JSON', '{"en-US":"JSON"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.764042', '2026-11-13 01:09:44.764045', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000114, 'dict.config.value.type.NUMBER', '数值', '{"en-US":"Number"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.765251', '2026-11-13 01:09:44.765254', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000115, 'dict.config.value.type.STRING', '文本', '{"en-US":"Text"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.766420', '2026-11-13 01:09:44.766423', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000118, 'dict.notification.type.PROJECT', '项目消息', '{"en-US":"Project message"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.770358', '2026-11-13 01:09:44.770360', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000119, 'dict.notification.type.SYSTEM', '系统通知', '{"en-US":"System notification"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.773321', '2026-11-13 01:09:44.773324', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000120, 'dict.notification.type.TASK', '任务提醒', '{"en-US":"Task reminder"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.774689', '2026-11-13 01:09:44.774692', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000121, 'dict.platform.menu.type.BUTTON', '按钮', '{"en-US":"Button"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.775893', '2026-11-13 01:09:44.775896', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000122, 'dict.platform.menu.type.DIR', '目录', '{"en-US":"Directory"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.777122', '2026-11-13 01:09:44.777125', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000123, 'dict.platform.menu.type.DIRECTORY', '目录', '{"en-US":"Directory"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.778321', '2026-11-13 01:09:44.778323', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000124, 'dict.platform.menu.type.MENU', '菜单', '{"en-US":"Menu"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.779440', '2026-11-13 01:09:44.779443', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000125, 'dict.project.generation.mode.AI_PROJECT', 'AI 生成项目', '{"en-US":"AI-generated project"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.780578', '2026-11-13 01:09:44.780581', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000126, 'dict.project.generation.mode.BASIC_SCAFFOLD', '基础空脚手架', '{"en-US":"Basic empty scaffold"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.781794', '2026-11-13 01:09:44.781797', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000127, 'dict.project.generation.status.FAILED', '生成失败', '{"en-US":"Generation failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.782966', '2026-11-13 01:09:44.782969', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000128, 'dict.project.generation.status.PENDING', '等待生成', '{"en-US":"Waiting"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.784176', '2026-11-13 01:09:44.784178', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000129, 'dict.project.generation.status.RUNNING', '正在生成', '{"en-US":"Generating"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.785486', '2026-11-13 01:09:44.785489', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000130, 'dict.project.generation.status.SUCCESS', '生成成功', '{"en-US":"Generated"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.786836', '2026-11-13 01:09:44.786839', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000131, 'dict.project.member.status.ACTIVE', '有效', '{"en-US":"Active"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.791397', '2026-11-13 01:09:44.791400', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000132, 'dict.project.member.status.DISABLED', '停用', '{"en-US":"Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.792689', '2026-11-13 01:09:44.792692', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000137, 'dict.project.status.ACTIVE', '已启用', '{"en-US":"Active"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.798584', '2026-11-13 01:09:44.798587', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000138, 'dict.project.status.ARCHIVED', '已归档', '{"en-US":"Archived"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.799753', '2026-11-13 01:09:44.799756', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000139, 'dict.project.status.DISABLED', '已停用', '{"en-US":"Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.801016', '2026-11-13 01:09:44.801026', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000140, 'dict.scheduler.execution.status.FAILED', '失败', '{"en-US":"Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.802417', '2026-11-13 01:09:44.802420', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000141, 'dict.scheduler.execution.status.RUNNING', '执行中', '{"en-US":"Running"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.803847', '2026-11-13 01:09:44.803849', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000142, 'dict.scheduler.execution.status.SUCCESS', '成功', '{"en-US":"Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.805761', '2026-11-13 01:09:44.805764', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000143, 'dict.security.login.status.FAILED', '失败', '{"en-US":"Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.807198', '2026-11-13 01:09:44.807201', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000144, 'dict.security.login.status.LOGOUT', '退出', '{"en-US":"Signed out"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.808454', '2026-11-13 01:09:44.808456', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000145, 'dict.security.login.status.SUCCESS', '成功', '{"en-US":"Success"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.809657', '2026-11-13 01:09:44.809659', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000146, 'dict.security.session.status.ONLINE', '在线', '{"en-US":"Online"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.810863', '2026-11-13 01:09:44.810865', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000147, 'dict.security.session.status.REVOKED', '已撤销', '{"en-US":"Revoked"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.812091', '2026-11-13 01:09:44.812094', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000148, 'dict.user.status.DISABLED', '停用', '{"en-US":"Disabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.813246', '2026-11-13 01:09:44.813249', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000149, 'dict.user.status.ENABLED', '启用', '{"en-US":"Enabled"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.814496', '2026-11-13 01:09:44.814499', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000150, 'dicts.actions', '操作', '{"en-US":"Actions"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.815722', '2026-11-13 01:09:44.815725', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000151, 'dicts.code', '字典编码', '{"en-US":"Dictionary code"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.816845', '2026-11-13 01:09:44.816848', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000152, 'dicts.codeRule', '字典编码格式不正确', '{"en-US":"The dictionary code format is invalid"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.818079', '2026-11-13 01:09:44.818081', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000153, 'dicts.color', '颜色', '{"en-US":"Color"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.819383', '2026-11-13 01:09:44.819385', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000154, 'dicts.create', '新增字典', '{"en-US":"Create dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.820634', '2026-11-13 01:09:44.820637', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000155, 'dicts.createItem', '新增字典项', '{"en-US":"Create entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.823223', '2026-11-13 01:09:44.823226', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000156, 'dicts.createItemTitle', '新增字典项', '{"en-US":"Create dictionary entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.824552', '2026-11-13 01:09:44.824554', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000157, 'dicts.createTitle', '新增字典', '{"en-US":"Create dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.825844', '2026-11-13 01:09:44.825847', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000158, 'dicts.default', '默认', '{"en-US":"Default"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.827082', '2026-11-13 01:09:44.827084', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000159, 'dicts.defaultItem', '默认项', '{"en-US":"Default entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.828340', '2026-11-13 01:09:44.828343', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000160, 'dicts.delete', '删除', '{"en-US":"Delete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.829513', '2026-11-13 01:09:44.829516', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000161, 'dicts.deleteItemConfirm', '确认删除该字典项？', '{"en-US":"Delete this dictionary entry?"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.830743', '2026-11-13 01:09:44.830745', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000162, 'dicts.deleteTypeConfirm', '删除字典及全部字典项？', '{"en-US":"Delete this dictionary and all its entries?"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.832038', '2026-11-13 01:09:44.832041', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000163, 'dicts.deleted', '字典已删除', '{"en-US":"Dictionary deleted"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.833327', '2026-11-13 01:09:44.833330', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000164, 'dicts.description', '说明', '{"en-US":"Description"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.834706', '2026-11-13 01:09:44.834709', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000165, 'dicts.dictionary', '字典', '{"en-US":"Dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.836089', '2026-11-13 01:09:44.836093', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000166, 'dicts.displayColor', '展示颜色', '{"en-US":"Display color"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.837442', '2026-11-13 01:09:44.837444', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000167, 'dicts.displayLabel', '显示标签', '{"en-US":"Display label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.840605', '2026-11-13 01:09:44.840608', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000168, 'dicts.edit', '编辑', '{"en-US":"Edit"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.841927', '2026-11-13 01:09:44.841930', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000169, 'dicts.editItemTitle', '编辑字典项', '{"en-US":"Edit dictionary entry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.843196', '2026-11-13 01:09:44.843198', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000170, 'dicts.editTitle', '编辑字典', '{"en-US":"Edit dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.844353', '2026-11-13 01:09:44.844355', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000171, 'dicts.extraJson', '扩展 JSON', '{"en-US":"Extra JSON"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.845451', '2026-11-13 01:09:44.845454', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000172, 'dicts.extraJsonPlaceholder', '例如 {"icon":"check"}', '{"en-US":"For example, {\"icon\":\"check\"}"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.846739', '2026-11-13 01:09:44.846741', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000173, 'dicts.independent', '项目独立，不继承全局', '{"en-US":"Project-only; does not inherit global entries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.847966', '2026-11-13 01:09:44.847969', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000174, 'dicts.inherit', '继承全局，同值由项目覆盖', '{"en-US":"Inherits global entries; project values override matches"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.849251', '2026-11-13 01:09:44.849254', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000175, 'dicts.inheritGlobal', '继承全局字典', '{"en-US":"Inherit global dictionary"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.850391', '2026-11-13 01:09:44.850393', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000176, 'dicts.itemDeleted', '字典项已删除', '{"en-US":"Dictionary entry deleted"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.851784', '2026-11-13 01:09:44.851788', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000177, 'dicts.itemSaved', '字典项已保存', '{"en-US":"Dictionary entry saved"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.853413', '2026-11-13 01:09:44.853420', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000178, 'dicts.label', '标签', '{"en-US":"Label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.855016', '2026-11-13 01:09:44.855027', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000179, 'dicts.labelEnUs', '英文标签', '{"en-US":"English label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.857474', '2026-11-13 01:09:44.857477', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000180, 'dicts.labelEnUsTip', '英文界面下显示的标签；留空则显示上面的原文', '{"en-US":"Shown when the UI is in English. Leave empty to fall back to the text above."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.858939', '2026-11-13 01:09:44.858942', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000181, 'dicts.loadFailed', '加载字典失败', '{"en-US":"Failed to load dictionaries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.860284', '2026-11-13 01:09:44.860287', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000182, 'dicts.loadItemsFailed', '加载字典项失败', '{"en-US":"Failed to load dictionary entries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.861656', '2026-11-13 01:09:44.861659', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000183, 'dicts.loadLocalesFailed', '加载已启用语言失败', '{"en-US":"Failed to load enabled languages"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.863050', '2026-11-13 01:09:44.863055', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000184, 'dicts.name', '字典名称', '{"en-US":"Dictionary name"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.864669', '2026-11-13 01:09:44.864675', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000185, 'dicts.saved', '字典已保存', '{"en-US":"Dictionary saved"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.866269', '2026-11-13 01:09:44.866272', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000186, 'dicts.selectFirst', '请先新增或选择字典', '{"en-US":"Create or select a dictionary first"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.867751', '2026-11-13 01:09:44.867754', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000187, 'dicts.sort', '排序', '{"en-US":"Sort"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.868997', '2026-11-13 01:09:44.869000', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000188, 'dicts.status', '状态', '{"en-US":"Status"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.870322', '2026-11-13 01:09:44.870325', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000189, 'dicts.subtitle', '项目字典可继承全局字典，同值项目项覆盖全局项', '{"en-US":"Project dictionaries can inherit global entries; project entries override equal global values."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.874081', '2026-11-13 01:09:44.874084', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000190, 'dicts.title', '字典管理', '{"en-US":"Dictionaries"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.875398', '2026-11-13 01:09:44.875401', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000191, 'dicts.translation', '{locale} 标签', '{"en-US":"{locale} label"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.876545', '2026-11-13 01:09:44.876548', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000192, 'dicts.translationTip', '已启用语言中的译文；留空时显示默认标签。新增语言后会自动出现对应输入项。', '{"en-US":"A translation for an enabled language. Leave empty to use the default label; new languages appear here automatically."}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.877754', '2026-11-13 01:09:44.877756', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000193, 'dicts.value', '字典值', '{"en-US":"Value"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.878821', '2026-11-13 01:09:44.878823', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000194, 'factory.action.backendZip', '后端 ZIP', '{"en-US":"Backend ZIP"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.879899', '2026-11-13 01:09:44.879902', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000195, 'factory.action.details', '详情', '{"en-US":"Details"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.881085', '2026-11-13 01:09:44.881087', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000196, 'factory.action.frontendZip', '前端 ZIP', '{"en-US":"Frontend ZIP"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.882197', '2026-11-13 01:09:44.882200', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000198, 'factory.action.retry', '修改后重试', '{"en-US":"Edit and retry"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.884599', '2026-11-13 01:09:44.884601', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000199, 'factory.column.actions', '操作', '{"en-US":"Actions"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.885988', '2026-11-13 01:09:44.885991', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000200, 'factory.column.createdAt', '创建时间', '{"en-US":"Created at"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.887343', '2026-11-13 01:09:44.887346', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000201, 'factory.column.failure', '失败原因', '{"en-US":"Failure reason"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.890138', '2026-11-13 01:09:44.890141', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000202, 'factory.column.mode', '生成方式', '{"en-US":"Generation mode"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.891374', '2026-11-13 01:09:44.891377', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000203, 'factory.column.project', '项目', '{"en-US":"Project"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.892553', '2026-11-13 01:09:44.892556', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000204, 'factory.column.readiness', '交付就绪度', '{"en-US":"Delivery readiness"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.893846', '2026-11-13 01:09:44.893848', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000206, 'factory.column.status', '生成状态', '{"en-US":"Generation status"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.896241', '2026-11-13 01:09:44.896244', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000207, 'factory.description', '在脚手架约束内一次生成后端与前端仓库；两份 ZIP 始终可下载，GitLab 只向项目配置分支做一次初始提交，后续 CI/CD 与分支策略由业务仓库接管。', '{"en-US":"Generate backend and frontend repositories once within the scaffold boundary. Both ZIP files remain downloadable. GitLab receives one initial commit on the configured project branch; the business repositories own later CI/CD and branch strategy.","ja-JP":"スキャフォールドの制約内でバックエンドとフロントエンドのリポジトリを一度だけ生成します。2 つの ZIP は常にダウンロードでき、GitLab への初回コミット後の CI/CD とブランチ戦略は業務リポジトリが管理します。"}', 'factory', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:44.897624', '2026-11-13 01:09:44.897627', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000208, 'factory.empty', '还没有生成任务；请在项目管理里开通项目，或对已有项目使用「生成第一版」', '{"en-US":"No generation tasks yet. Set up a project or use Generate first version for an existing project."}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.898834', '2026-11-13 01:09:44.898836', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000209, 'factory.failure.unknown', '未记录具体失败原因', '{"en-US":"No specific failure reason was recorded"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.900051', '2026-11-13 01:09:44.900054', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000211, 'factory.myTasks', '我的项目生成', '{"en-US":"My generation tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.902758', '2026-11-13 01:09:44.902761', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000212, 'factory.newProject', '开通新项目', '{"en-US":"Set up a project"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.904214', '2026-11-13 01:09:44.904217', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000213, 'factory.preview.backendFiles', '后端文件 · {count}', '{"en-US":"Backend files · {count}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.906697', '2026-11-13 01:09:44.906700', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000214, 'factory.preview.close', '关闭', '{"en-US":"Close"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.907936', '2026-11-13 01:09:44.907939', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000215, 'factory.preview.completedAt', '完成时间', '{"en-US":"Completed at"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.909223', '2026-11-13 01:09:44.909225', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000216, 'factory.preview.error', '任务错误', '{"en-US":"Task error"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.910328', '2026-11-13 01:09:44.910331', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000217, 'factory.preview.frontendFiles', '前端文件 · {count}', '{"en-US":"Frontend files · {count}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.911585', '2026-11-13 01:09:44.911588', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000218, 'factory.preview.model', 'AI 模型', '{"en-US":"AI model"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.912715', '2026-11-13 01:09:44.912717', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000219, 'factory.preview.noFiles', '暂无生成文件', '{"en-US":"No generated files"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.913906', '2026-11-13 01:09:44.913909', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000220, 'factory.preview.overview', '概览', '{"en-US":"Overview"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.915137', '2026-11-13 01:09:44.915140', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000221, 'factory.preview.projectTitle', '生成详情：{project}', '{"en-US":"Generation details: {project}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.916339', '2026-11-13 01:09:44.916341', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000222, 'factory.preview.summary', '设计摘要', '{"en-US":"Design summary"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.917511', '2026-11-13 01:09:44.917514', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000223, 'factory.preview.taskNo', '任务号', '{"en-US":"Task number"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.918854', '2026-11-13 01:09:44.918858', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000224, 'factory.preview.template', '脚手架版本', '{"en-US":"Scaffold version"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.921271', '2026-11-13 01:09:44.921292', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000225, 'factory.preview.title', '生成详情', '{"en-US":"Generation details"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.924470', '2026-11-13 01:09:44.924475', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000238, 'factory.readiness.tooltip', '生成成功、后端制品、前端制品、后端推送、前端推送', '{"en-US":"Generation, backend artifact, frontend artifact, backend push, frontend push"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.943223', '2026-11-13 01:09:44.943226', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000239, 'factory.refresh', '刷新', '{"en-US":"Refresh"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.944544', '2026-11-13 01:09:44.944548', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000244, 'factory.retry.basic', '基础脚手架没有业务描述和 DDL，可直接重新生成', '{"en-US":"Basic scaffolds have no business description or DDL and can be regenerated directly"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.951525', '2026-11-13 01:09:44.951531', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000247, 'factory.retry.ddl', 'MySQL DDL（可选）', '{"en-US":"MySQL DDL (optional)"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.958272', '2026-11-13 01:09:44.958275', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000248, 'factory.retry.ddlExtra', '支持 CREATE TABLE 以及对应的独立 CREATE INDEX 语句', '{"en-US":"Supports CREATE TABLE and corresponding standalone CREATE INDEX statements"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.959509', '2026-11-13 01:09:44.959511', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000249, 'factory.retry.description', '可修改业务描述和 DDL 后重新生成；原失败任务会保留任务号并使用本次输入。', '{"en-US":"Edit the business description and DDL before regenerating. The failed task keeps its task number and uses the updated input."}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.960687', '2026-11-13 01:09:44.960690', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000250, 'factory.retry.lastFailed', '上次生成失败', '{"en-US":"The previous generation failed"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.961910', '2026-11-13 01:09:44.961913', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000251, 'factory.retry.submit', '保存输入并重新生成', '{"en-US":"Save input and regenerate"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.963147', '2026-11-13 01:09:44.963150', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000252, 'factory.retry.success', '修改后的任务已重新排队', '{"en-US":"The updated task has been queued again"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.964404', '2026-11-13 01:09:44.964406', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000253, 'factory.retry.title', '修改后重试：{project}', '{"en-US":"Edit and retry: {project}"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.965820', '2026-11-13 01:09:44.965823', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000254, 'factory.stat.failed', '失败', '{"en-US":"Failed"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.967105', '2026-11-13 01:09:44.967109', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000255, 'factory.stat.noFailure', '暂无失败', '{"en-US":"No failures"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.968691', '2026-11-13 01:09:44.968696', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000257, 'factory.stat.ready', '全部已就绪', '{"en-US":"Everything is ready"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.972273', '2026-11-13 01:09:44.972281', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000258, 'factory.stat.retry', '可在下方重试', '{"en-US":"Retry from the list below"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.974276', '2026-11-13 01:09:44.974280', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000259, 'factory.stat.running', '进行中', '{"en-US":"In progress"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.975715', '2026-11-13 01:09:44.975718', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000260, 'factory.stat.runningHint', '每 2.5s 自动刷新', '{"en-US":"Refreshes every 2.5 seconds"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.976957', '2026-11-13 01:09:44.976960', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000261, 'factory.stat.success', '已成功', '{"en-US":"Successful"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.978335', '2026-11-13 01:09:44.978337', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000262, 'factory.stat.total', '全部任务', '{"en-US":"All tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.979978', '2026-11-13 01:09:44.979984', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000263, 'factory.stat.totalHint', '按当前用户过滤', '{"en-US":"Filtered for the current user"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.981870', '2026-11-13 01:09:44.981875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000264, 'factory.taskCount', '共 {count} 个任务', '{"en-US":"{count} tasks"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.983590', '2026-11-13 01:09:44.983595', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000265, 'factory.title', '项目工厂', '{"en-US":"Project factory"}', 'factory', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.985219', '2026-11-13 01:09:44.985222', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000266, 'gateway.authenticationRequired', '未登录或登录已过期', '{"en-US":"Sign-in is required or has expired"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.986571', '2026-11-13 01:09:44.986574', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000267, 'gateway.projectAuthUnavailable', '项目鉴权尚未启用', '{"en-US":"Project authentication is not enabled"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.988214', '2026-11-13 01:09:44.988218', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000268, 'gateway.resourceNotFound', '资源不存在', '{"en-US":"Resource not found"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.989870', '2026-11-13 01:09:44.989873', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000269, 'gateway.routePolicyInvalid', '未知路由访问模式', '{"en-US":"Unknown route access mode"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.991472', '2026-11-13 01:09:44.991475', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000270, 'gateway.routePolicyMissing', '路由安全元数据缺失', '{"en-US":"Route security metadata is missing"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.992710', '2026-11-13 01:09:44.992713', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000271, 'gateway.sessionExpired', '会话已失效，请重新登录', '{"en-US":"Your session has expired. Sign in again."}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.993978', '2026-11-13 01:09:44.993981', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000272, 'gateway.sessionVerificationUnavailable', '会话校验暂不可用', '{"en-US":"Session verification is temporarily unavailable"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:44.995247', '2026-11-13 01:09:44.995250', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000289, 'home.controlPlane', 'KAIWU CONTROL PLANE', '{"en-US":"KAIWU CONTROL PLANE"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.019934', '2026-11-13 01:09:45.019937', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000290, 'home.defaultUser', '管理员', '{"en-US":"Administrator"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.021927', '2026-11-13 01:09:45.021930', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000291, 'home.greeting.afternoon', '下午好', '{"en-US":"Good afternoon"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.023381', '2026-11-13 01:09:45.023384', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000292, 'home.greeting.evening', '晚上好', '{"en-US":"Good evening"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.024691', '2026-11-13 01:09:45.024694', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000293, 'home.greeting.lateNight', '夜深了', '{"en-US":"Working late"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.025856', '2026-11-13 01:09:45.025858', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000294, 'home.greeting.morning', '早上好', '{"en-US":"Good morning"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.027147', '2026-11-13 01:09:45.027150', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000295, 'home.greeting.noon', '中午好', '{"en-US":"Good afternoon"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.028347', '2026-11-13 01:09:45.028350', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000296, 'home.greeting.user', '{greeting}，{name}', '{"en-US":"{greeting}, {name}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.029425', '2026-11-13 01:09:45.029428', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000297, 'home.guide.aiOptional', '尚未配置 AI 也可以选择“基础脚手架”；配置 AI 后可根据业务描述生成第一版模块。', '{"en-US":"Without AI configuration, you can still choose Basic scaffold. Configure AI to generate initial modules from a business description."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.030599', '2026-11-13 01:09:45.030602', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000298, 'home.guide.aiReady', 'AI 已就绪，可直接从业务描述生成受校验蓝图。', '{"en-US":"AI is ready and can create a validated blueprint from a business description."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.031767', '2026-11-13 01:09:45.031770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000299, 'home.guide.alertDescription', 'AI 辅助生成受约束的第一版，确定性脚手架交付独立源码；团队可在自己的 Git 仓库中接续 AI 开发、测试和发布。', '{"en-US":"AI helps create a constrained first version, while deterministic scaffolding delivers standalone source code. Your team can continue AI-assisted development, testing, and releases in its own Git repositories."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.032831', '2026-11-13 01:09:45.032833', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000300, 'home.guide.alertTitle', '在受控边界内，创建可维护的业务项目', '{"en-US":"Create maintainable business projects within clear boundaries"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.033970', '2026-11-13 01:09:45.033973', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000301, 'home.guide.deliver.desc', '拿到独立双仓库后按正常工程流程开发，Kaiwu 不会再次覆盖代码。', '{"en-US":"Continue normal development in the two independent repositories. Kaiwu will never overwrite them."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.035226', '2026-11-13 01:09:45.035230', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000302, 'home.guide.deliver.title', '下载或首次推送', '{"en-US":"Download or make the initial push"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.036515', '2026-11-13 01:09:45.036518', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000303, 'home.guide.generate.desc', '平台创建项目、成员基础角色，并用受约束蓝图生成前后端源码。', '{"en-US":"The platform creates the project and base member role, then generates frontend and backend source from a constrained blueprint."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.037883', '2026-11-13 01:09:45.037886', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000304, 'home.guide.generate.title', '开通并生成第一版', '{"en-US":"Initialize and generate"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.039313', '2026-11-13 01:09:45.039316', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000307, 'home.guide.scope.desc', '写清核心对象、查询方式和状态；已有库可直接粘贴 CREATE TABLE DDL。', '{"en-US":"Describe core entities, query patterns, and states. If a schema exists, paste its CREATE TABLE DDL."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.042883', '2026-11-13 01:09:45.042885', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000308, 'home.guide.scope.title', '准备业务范围', '{"en-US":"Define the business scope"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.044030', '2026-11-13 01:09:45.044033', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000309, 'home.guide.start', '开始开通项目', '{"en-US":"Set up a project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.045216', '2026-11-13 01:09:45.045219', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000310, 'home.guide.title', '从第一个项目开始', '{"en-US":"Start with your first project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.046372', '2026-11-13 01:09:45.046374', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000312, 'home.load.failed', '加载失败', '{"en-US":"Failed to load"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.048689', '2026-11-13 01:09:45.048691', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000313, 'home.projects.empty', '你还没有加入任何项目，请联系管理员在项目权限中心分配角色。', '{"en-US":"You have not joined a project. Ask an administrator to assign a role in the project access center."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.049787', '2026-11-13 01:09:45.049790', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000314, 'home.projects.noEntry', '未配置入口', '{"en-US":"No entry URL"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.050988', '2026-11-13 01:09:45.050991', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000315, 'home.projects.noEntryMessage', '该项目尚未配置业务后台入口，请到项目管理里维护 backendUrl', '{"en-US":"This project has no administration URL. Configure backendUrl in Projects."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.052350', '2026-11-13 01:09:45.052353', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000316, 'home.projects.noMatch', '没有匹配的项目', '{"en-US":"No matching projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.053792', '2026-11-13 01:09:45.053795', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000317, 'home.projects.search', '按名称或编码搜索', '{"en-US":"Search by name or code"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.055681', '2026-11-13 01:09:45.055686', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000318, 'home.projects.title', '我参与的项目', '{"en-US":"My projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.057075', '2026-11-13 01:09:45.057078', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000319, 'home.projects.titleCount', '我参与的项目 · {count}', '{"en-US":"My projects · {count}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.058270', '2026-11-13 01:09:45.058272', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000320, 'home.refresh', '刷新', '{"en-US":"Refresh"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.059462', '2026-11-13 01:09:45.059465', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000321, 'home.request.failed', '请求失败', '{"en-US":"Request failed"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.060637', '2026-11-13 01:09:45.060639', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000322, 'home.summary.clear', '当前没有待处理事项，一切正常', '{"en-US":"Everything is running normally. Nothing needs your attention."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.061815', '2026-11-13 01:09:45.061818', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000323, 'home.summary.pending', '有 {count} 项需要你处理', '{"en-US":"{count} items need your attention"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.062898', '2026-11-13 01:09:45.062900', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000324, 'home.todo.aiNoKey', '尚未配置 API Key，AI 生成项目不可用', '{"en-US":"No API key is configured, so AI project generation is unavailable"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.064090', '2026-11-13 01:09:45.064092', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000325, 'home.todo.aiNotReady', '大模型未就绪', '{"en-US":"AI provider not ready"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.065232', '2026-11-13 01:09:45.065235', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000326, 'home.todo.configure', '去配置', '{"en-US":"Configure"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.066349', '2026-11-13 01:09:45.066352', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000328, 'home.todo.empty', '没有需要处理的事项，平台能力和生成任务都正常。', '{"en-US":"There are no outstanding items. Platform capabilities and generation tasks are healthy."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.068965', '2026-11-13 01:09:45.068968', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000329, 'home.todo.generating', '{project} 正在生成', '{"en-US":"Generating {project}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.070315', '2026-11-13 01:09:45.070317', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000330, 'home.todo.generatingDesc', '任务在后台执行，完成后可下载或推送', '{"en-US":"The task is running in the background. Download or push it when complete."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.071839', '2026-11-13 01:09:45.071842', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000331, 'home.todo.generationFailed', '{project} 生成失败', '{"en-US":"Generation failed for {project}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.074057', '2026-11-13 01:09:45.074060', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000332, 'home.todo.generationFailedDesc', '可在项目工厂查看原因并重试', '{"en-US":"Open Project factory to review the cause and retry"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.075305', '2026-11-13 01:09:45.075308', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000335, 'home.todo.handle', '去处理', '{"en-US":"Resolve"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.078740', '2026-11-13 01:09:45.078743', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000336, 'home.todo.lastTestFailed', '最近一次连通测试失败', '{"en-US":"The latest connectivity test failed"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.079842', '2026-11-13 01:09:45.079845', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000337, 'home.todo.open', '查看', '{"en-US":"View"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.081282', '2026-11-13 01:09:45.081285', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000340, 'home.todo.title', '待处理', '{"en-US":"To do"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.085358', '2026-11-13 01:09:45.085361', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000341, 'home.todo.unread.default', '来自平台与业务项目的站内信', '{"en-US":"Messages from the platform and business projects"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.086862', '2026-11-13 01:09:45.086865', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000342, 'home.todo.unread.latest', '最新：{title}', '{"en-US":"Latest: {title}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.090172', '2026-11-13 01:09:45.090175', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000343, 'home.todo.unread.title', '{count} 条未读消息', '{"en-US":"{count} unread messages"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.091445', '2026-11-13 01:09:45.091448', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000344, 'home.todo.view', '去查看', '{"en-US":"View"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.092660', '2026-11-13 01:09:45.092663', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000345, 'i18n.actions', '操作', '{"en-US":"Actions"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.093955', '2026-11-13 01:09:45.093958', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000346, 'i18n.coverage', '译文', '{"en-US":"Translations"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.095181', '2026-11-13 01:09:45.095184', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000347, 'i18n.create', '新增资源', '{"en-US":"New resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.096405', '2026-11-13 01:09:45.096408', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000348, 'i18n.createTitle', '新增国际化资源', '{"en-US":"New internationalization resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.101975', '2026-11-13 01:09:45.101994', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000349, 'i18n.defaultText', '默认文案（zh-CN）', '{"en-US":"Default text (zh-CN)"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.109865', '2026-11-13 01:09:45.109875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000350, 'i18n.deleteConfirm', '确定删除该资源？', '{"en-US":"Delete this resource?"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.113411', '2026-11-13 01:09:45.113422', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000351, 'i18n.description', '说明', '{"en-US":"Description"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.116428', '2026-11-13 01:09:45.116441', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000352, 'i18n.editTitle', '编辑国际化资源', '{"en-US":"Edit internationalization resource"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.122639', '2026-11-13 01:09:45.122649', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000353, 'i18n.key', '资源 key', '{"en-US":"Resource key"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.124746', '2026-11-13 01:09:45.124751', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000354, 'i18n.module', '模块', '{"en-US":"Module"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.126335', '2026-11-13 01:09:45.126338', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000355, 'i18n.public', '登录前公开', '{"en-US":"Public before sign-in"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.127628', '2026-11-13 01:09:45.127631', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000356, 'i18n.required', '覆盖必需', '{"en-US":"Required for coverage"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.128797', '2026-11-13 01:09:45.128800', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000357, 'i18n.status', '状态', '{"en-US":"Status"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.129895', '2026-11-13 01:09:45.129898', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000358, 'i18n.subtitle', '统一维护页面与 API 文案；语言是否可选由覆盖校验决定', '{"en-US":"Manage UI and API messages; coverage controls language availability"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.131156', '2026-11-13 01:09:45.131159', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000359, 'i18n.title', '国际化资源', '{"en-US":"Internationalization resources"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.132338', '2026-11-13 01:09:45.132341', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000360, 'layout.notification.empty', '没有未读消息', '{"en-US":"No unread messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.133550', '2026-11-13 01:09:45.133553', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000361, 'layout.notification.readAll', '全部已读', '{"en-US":"Mark all read"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.134791', '2026-11-13 01:09:45.134794', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000362, 'layout.notification.unread', '未读消息', '{"en-US":"Unread messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.136263', '2026-11-13 01:09:45.136267', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000363, 'layout.notification.viewAll', '查看全部消息', '{"en-US":"View all messages"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.138320', '2026-11-13 01:09:45.138325', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000364, 'layout.search.aria', '全局搜索', '{"en-US":"Global search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.139941', '2026-11-13 01:09:45.139944', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000365, 'layout.search.empty', '没有匹配结果', '{"en-US":"No matching results"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.141317', '2026-11-13 01:09:45.141320', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000366, 'layout.search.placeholder', '搜索项目、用户、交付任务（至少 2 个字符）', '{"en-US":"Search projects, users, and delivery tasks (2+ characters)"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.142591', '2026-11-13 01:09:45.142594', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000367, 'layout.search.prompt', '输入关键词开始搜索', '{"en-US":"Enter a keyword to start searching"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.143767', '2026-11-13 01:09:45.143769', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000368, 'layout.search.short', '搜索', '{"en-US":"Search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.144931', '2026-11-13 01:09:45.144934', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000369, 'layout.search.title', '全局搜索', '{"en-US":"Global search"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.146018', '2026-11-13 01:09:45.146029', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000370, 'layout.search.type.delivery', '交付', '{"en-US":"Delivery"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.147205', '2026-11-13 01:09:45.147208', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000371, 'layout.search.type.project', '项目', '{"en-US":"Project"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.148323', '2026-11-13 01:09:45.148326', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000372, 'layout.search.type.user', '用户', '{"en-US":"User"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.149469', '2026-11-13 01:09:45.149472', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000373, 'layout.user.logout', '退出登录', '{"en-US":"Sign out"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.150715', '2026-11-13 01:09:45.150717', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000374, 'layout.user.notLoggedIn', '未登录', '{"en-US":"Not signed in"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.152060', '2026-11-13 01:09:45.152063', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000375, 'layout.user.profile', '个人设置', '{"en-US":"Profile"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.153378', '2026-11-13 01:09:45.153380', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000376, 'layout.user.switchProject', '切换项目', '{"en-US":"Switch project"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.155096', '2026-11-13 01:09:45.155101', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000377, 'login.brand.subtitle', '面向 AI 时代受控开发的项目平台', '{"en-US":"A project platform for controlled AI-era development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.156723', '2026-11-13 01:09:45.156726', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000378, 'login.failure', '登录失败', '{"en-US":"Sign-in failed"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.158034', '2026-11-13 01:09:45.158037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000379, 'login.footer', '管理员密码由启动环境变量注入，仓库不保存默认密码。', '{"en-US":"The administrator password is injected by the runtime environment. No default password is stored in the repository."}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.159271', '2026-11-13 01:09:45.159274', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000380, 'login.form.submit', '登录', '{"en-US":"Sign in"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.160487', '2026-11-13 01:09:45.160490', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000381, 'login.form.subtitle', '请使用管理员账号继续', '{"en-US":"Continue with your administrator account"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.161792', '2026-11-13 01:09:45.161796', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000382, 'login.form.title', '登录管理后台', '{"en-US":"Sign in to Kaiwu"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.162991', '2026-11-13 01:09:45.162994', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000383, 'login.hero.description', 'AI 负责写，平台负责守：受控蓝图生成独立前后端，权限、迁移与 CI 约束随仓库交付，团队用任意 AI 编程工具接着迭代。', '{"en-US":"AI writes, the platform guards: controlled blueprints generate independent frontend and backend repositories that ship with access, migration, and CI constraints, so your team keeps iterating with any AI coding tool."}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.164234', '2026-11-13 01:09:51.273515', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000384, 'login.hero.title.first', '让 AI 加速交付，', '{"en-US":"Let AI accelerate delivery,"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.165420', '2026-11-13 01:09:45.165423', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000385, 'login.hero.title.second', '让工程始终可控', '{"en-US":"keep engineering in control"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.166656', '2026-11-13 01:09:45.166659', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000386, 'login.highlight.isolation', '独立仓库、数据库与交付路径', '{"en-US":"Independent repositories, databases, and delivery paths"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.167930', '2026-11-13 01:09:45.167933', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000387, 'login.highlight.oneshot', '代码归你，平台不覆盖', '{"en-US":"Your code stays yours; the platform never overwrites it"}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.169275', '2026-11-13 01:09:51.278666', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000388, 'login.highlight.permission', 'AI 受控生成，工程边界清晰', '{"en-US":"Controlled AI generation, clear engineering boundaries"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.170983', '2026-11-13 01:09:45.170990', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000389, 'login.password.placeholder', '密码', '{"en-US":"Password"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.172844', '2026-11-13 01:09:45.172846', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000390, 'login.password.required', '请输入密码', '{"en-US":"Enter your password"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.174068', '2026-11-13 01:09:45.174071', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000391, 'login.sessionExit', '已退出登录：{reason}', '{"en-US":"Signed out: {reason}"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.175375', '2026-11-13 01:09:45.175377', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000392, 'login.steps.continue.description', '项目自带工程约束，交给团队常用的 AI 编程工具继续迭代', '{"en-US":"Built-in engineering constraints let your team continue with its preferred AI coding tools"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.176639', '2026-11-13 01:09:45.176641', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000393, 'login.steps.continue.title', '接续 AI 开发', '{"en-US":"Continue with AI development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.177844', '2026-11-13 01:09:45.177847', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000394, 'login.steps.create.description', '登记业务项目，明确成员、角色与边界', '{"en-US":"Register the project and define members, roles, and boundaries"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.179016', '2026-11-13 01:09:45.179027', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000395, 'login.steps.create.title', '建项目', '{"en-US":"Create a project"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.180171', '2026-11-13 01:09:45.180174', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000396, 'login.steps.deliver.description', '下载 ZIP，或向空 GitLab 仓库一次性初始化', '{"en-US":"Download the ZIP, or initialize an empty GitLab repository once"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.181360', '2026-11-13 01:09:45.181363', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000397, 'login.steps.deliver.title', '交付到你的仓库', '{"en-US":"Deliver to your repository"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.182530', '2026-11-13 01:09:45.182532', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000398, 'login.steps.generate.description', '描述业务或导入建表 SQL，得到可维护的前后端', '{"en-US":"Describe the business or import DDL for maintainable frontends and backends"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.183764', '2026-11-13 01:09:45.183767', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000399, 'login.steps.generate.title', '生成可交付的第一版', '{"en-US":"Generate a deliverable first version"}', 'login', 1, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.185149', '2026-11-13 01:09:51.282444', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000400, 'login.steps.title', '4 步，进入受控 AI 开发', '{"en-US":"Four steps to controlled AI development"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.186486', '2026-11-13 01:09:45.186489', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000401, 'login.username.placeholder', '用户名', '{"en-US":"Username"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.188192', '2026-11-13 01:09:45.188195', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000402, 'login.username.required', '请输入用户名', '{"en-US":"Enter your username"}', 'login', 1, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.189597', '2026-11-13 01:09:45.189600', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000403, 'members.actions', '操作', '{"en-US":"Actions"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.190764', '2026-11-13 01:09:45.190767', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000404, 'members.add', '添加成员', '{"en-US":"Add member"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.192000', '2026-11-13 01:09:45.192003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000405, 'members.displayName', '显示名称', '{"en-US":"Display name"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.193236', '2026-11-13 01:09:45.193239', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000406, 'members.edit', '编辑', '{"en-US":"Edit"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.194486', '2026-11-13 01:09:45.194489', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000407, 'members.editTitle', '编辑成员：{username}', '{"en-US":"Edit member: {username}"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.195585', '2026-11-13 01:09:45.195587', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000408, 'members.memberStatus', '成员状态', '{"en-US":"Member status"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.196676', '2026-11-13 01:09:45.196678', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000409, 'members.platformUser', '平台用户', '{"en-US":"Platform user"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.197900', '2026-11-13 01:09:45.197903', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000410, 'members.projectRole', '项目角色', '{"en-US":"Project roles"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.199042', '2026-11-13 01:09:45.199046', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000411, 'members.remove', '移除', '{"en-US":"Remove"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.200390', '2026-11-13 01:09:45.200394', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000412, 'members.removeConfirm', '确认移除该项目成员？', '{"en-US":"Remove this project member?"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.201735', '2026-11-13 01:09:45.201737', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000413, 'members.removed', '成员已移除', '{"en-US":"Member removed"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.202978', '2026-11-13 01:09:45.202981', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000414, 'members.roles', '角色', '{"en-US":"Roles"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.204687', '2026-11-13 01:09:45.204691', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000415, 'members.saved', '成员配置已保存', '{"en-US":"Member configuration saved"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.206735', '2026-11-13 01:09:45.206738', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000416, 'members.status', '状态', '{"en-US":"Status"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.207947', '2026-11-13 01:09:45.207950', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000417, 'members.userOption', '{name}（{username}）', '{"en-US":"{name} ({username})"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.209101', '2026-11-13 01:09:45.209104', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000418, 'members.username', '用户名', '{"en-US":"Username"}', 'members', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.210277', '2026-11-13 01:09:45.210279', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000419, 'menu.system.ai-provider', '大模型配置', '{"en-US":"AI provider"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.211474', '2026-11-13 01:09:45.211477', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000420, 'menu.system.configs', '参数配置', '{"en-US":"Configuration"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.213625', '2026-11-13 01:09:45.213628', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000421, 'menu.system.dictionaries', '字典管理', '{"en-US":"Dictionaries"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.214821', '2026-11-13 01:09:45.214823', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000422, 'menu.system.directory.delivery', '研发交付', '{"en-US":"Development & delivery"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.215953', '2026-11-13 01:09:45.215955', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000423, 'menu.system.directory.platform', '平台管理', '{"en-US":"Platform"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.217151', '2026-11-13 01:09:45.217154', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000425, 'menu.system.home', '工作台', '{"en-US":"Workbench"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.219621', '2026-11-13 01:09:45.219624', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000426, 'menu.system.notifications', '消息中心', '{"en-US":"Messages"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.221331', '2026-11-13 01:09:45.221334', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000427, 'menu.system.organization', '组织架构', '{"en-US":"Organization"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.223450', '2026-11-13 01:09:45.223453', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000428, 'menu.system.project-factory', '项目工厂', '{"en-US":"Project factory"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.224744', '2026-11-13 01:09:45.224747', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000429, 'menu.system.projects', '项目管理', '{"en-US":"Projects"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.226015', '2026-11-13 01:09:45.226018', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000430, 'menu.system.scheduler', '定时任务', '{"en-US":"Scheduled tasks"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.227291', '2026-11-13 01:09:45.227294', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000431, 'menu.system.security', '安全运营', '{"en-US":"Security operations"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.228572', '2026-11-13 01:09:45.228575', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000432, 'menu.system.users', '用户管理', '{"en-US":"Users"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.229841', '2026-11-13 01:09:45.229844', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000433, 'menus.actions', '操作', '{"en-US":"Actions"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.231078', '2026-11-13 01:09:45.231081', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000434, 'menus.addChild', '新增子节点', '{"en-US":"Add child"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.232301', '2026-11-13 01:09:45.232304', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000435, 'menus.componentPath', '组件路径', '{"en-US":"Component path"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.233571', '2026-11-13 01:09:45.233575', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000436, 'menus.createRoot', '新建根节点', '{"en-US":"Create root node"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.234874', '2026-11-13 01:09:45.234877', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000437, 'menus.createTitle', '新建项目菜单', '{"en-US":"Create project menu"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.236191', '2026-11-13 01:09:45.236194', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000438, 'menus.delete', '删除', '{"en-US":"Delete"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.237472', '2026-11-13 01:09:45.237474', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000439, 'menus.deleteConfirm', '确认删除该项目菜单？仅叶子节点可删除。', '{"en-US":"Delete this project menu? Only leaf nodes can be deleted."}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.240458', '2026-11-13 01:09:45.240461', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000440, 'menus.deleted', '项目菜单已删除', '{"en-US":"Project menu deleted"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.241767', '2026-11-13 01:09:45.241770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000441, 'menus.disableConfirm', '确认停用菜单？', '{"en-US":"Disable this menu?"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.243009', '2026-11-13 01:09:45.243011', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000442, 'menus.edit', '编辑', '{"en-US":"Edit"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.244195', '2026-11-13 01:09:45.244197', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000443, 'menus.editTitle', '编辑项目菜单：{name}', '{"en-US":"Edit project menu: {name}"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.245384', '2026-11-13 01:09:45.245387', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000444, 'menus.enableConfirm', '确认启用菜单？', '{"en-US":"Enable this menu?"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.246443', '2026-11-13 01:09:45.246445', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000445, 'menus.icon', '菜单图标', '{"en-US":"Menu icon"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.247587', '2026-11-13 01:09:45.247589', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000446, 'menus.iconExtra', '仅 DIRECTORY 和 MENU 会在侧栏显示图标；BUTTON 可留空', '{"en-US":"Only DIRECTORY and MENU appear in the sidebar; BUTTON can leave this empty"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.248714', '2026-11-13 01:09:45.248716', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000447, 'menus.iconPlaceholder', '可选，选择侧栏图标', '{"en-US":"Optional sidebar icon"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.249773', '2026-11-13 01:09:45.249776', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000448, 'menus.name', '菜单名称', '{"en-US":"Menu name"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.250983', '2026-11-13 01:09:45.250986', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000449, 'menus.order', '顺序', '{"en-US":"Order"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.252332', '2026-11-13 01:09:45.252336', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000450, 'menus.orderFailed', '排序失败', '{"en-US":"Failed to reorder"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.253660', '2026-11-13 01:09:45.253664', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000451, 'menus.orderUpdated', '顺序已更新', '{"en-US":"Order updated"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.255107', '2026-11-13 01:09:45.255110', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000452, 'menus.parent', '父节点', '{"en-US":"Parent"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.256376', '2026-11-13 01:09:45.256379', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000453, 'menus.permission', '权限码', '{"en-US":"Permission code"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.257553', '2026-11-13 01:09:45.257555', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000454, 'menus.permissionExtra', '必须与业务后端 @RequirePermission、前端 AuthButton 完全一致', '{"en-US":"Must exactly match backend @RequirePermission and frontend AuthButton"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.258691', '2026-11-13 01:09:45.258693', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000455, 'menus.permissionPlaceholder', 'BUTTON 必填，例如 order:record:list', '{"en-US":"Required for BUTTON, for example order:record:list"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.260010', '2026-11-13 01:09:45.260013', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000456, 'menus.root', '根节点', '{"en-US":"Root"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.261314', '2026-11-13 01:09:45.261317', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000457, 'menus.route', '路由', '{"en-US":"Route"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.262448', '2026-11-13 01:09:45.262450', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000458, 'menus.routePath', '路由路径', '{"en-US":"Route path"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.263561', '2026-11-13 01:09:45.263563', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000459, 'menus.routeRequired', 'MENU 必填', '{"en-US":"Required for MENU"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.264697', '2026-11-13 01:09:45.264699', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000460, 'menus.saved', '项目菜单已保存', '{"en-US":"Project menu saved"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.265814', '2026-11-13 01:09:45.265816', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000461, 'menus.sort', '排序', '{"en-US":"Sort order"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.266947', '2026-11-13 01:09:45.266949', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000462, 'menus.status', '状态', '{"en-US":"Status"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.268094', '2026-11-13 01:09:45.268097', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000463, 'menus.type', '菜单类型', '{"en-US":"Menu type"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.269337', '2026-11-13 01:09:45.269340', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000464, 'menus.visible', '是否显示', '{"en-US":"Visible"}', 'menus', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.270545', '2026-11-13 01:09:45.270547', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000465, 'notifications.actions', '操作', '{"en-US":"Actions"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.272542', '2026-11-13 01:09:45.272544', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000466, 'notifications.all', '全部', '{"en-US":"All"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.274006', '2026-11-13 01:09:45.274008', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000467, 'notifications.allTypes', '全部分类', '{"en-US":"All types"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.275225', '2026-11-13 01:09:45.275228', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000468, 'notifications.empty', '还没有收到任何消息', '{"en-US":"No messages yet"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.276504', '2026-11-13 01:09:45.276507', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000469, 'notifications.emptyFiltered', '没有符合条件的消息', '{"en-US":"No messages match the filters"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.277714', '2026-11-13 01:09:45.277717', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000470, 'notifications.markAll', '全部已读', '{"en-US":"Mark all read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.278925', '2026-11-13 01:09:45.278927', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000471, 'notifications.markRead', '标记已读', '{"en-US":"Mark read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.280150', '2026-11-13 01:09:45.280153', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000472, 'notifications.markedCount', '已将 {count} 条消息标记为已读', '{"en-US":"{count} messages marked as read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.281324', '2026-11-13 01:09:45.281327', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000473, 'notifications.message', '消息', '{"en-US":"Message"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.282491', '2026-11-13 01:09:45.282493', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000474, 'notifications.noUnread', '没有未读消息', '{"en-US":"No unread messages"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.283661', '2026-11-13 01:09:45.283664', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000475, 'notifications.platform', '平台', '{"en-US":"Platform"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.284826', '2026-11-13 01:09:45.284828', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000476, 'notifications.read', '已读', '{"en-US":"Read"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.286002', '2026-11-13 01:09:45.286005', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000477, 'notifications.source', '来源项目', '{"en-US":"Source project"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.287337', '2026-11-13 01:09:45.287340', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000478, 'notifications.status', '状态', '{"en-US":"Status"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.289731', '2026-11-13 01:09:45.289736', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000479, 'notifications.subtitle', '平台与业务项目产生的站内信；消息是事实记录，只能标记已读，不能编辑或撤回', '{"en-US":"Messages from the platform and business projects are factual records. They can be marked read but cannot be edited or recalled."}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.291564', '2026-11-13 01:09:45.291569', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000480, 'notifications.time', '时间', '{"en-US":"Time"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.293411', '2026-11-13 01:09:45.293418', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000481, 'notifications.title', '消息中心', '{"en-US":"Notifications"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.295330', '2026-11-13 01:09:45.295338', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000482, 'notifications.type', '分类', '{"en-US":"Type"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.298355', '2026-11-13 01:09:45.298365', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000483, 'notifications.unread', '未读', '{"en-US":"Unread"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.300534', '2026-11-13 01:09:45.300540', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000484, 'notifications.view', '查看', '{"en-US":"View"}', 'notifications', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.302784', '2026-11-13 01:09:45.302796', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000485, 'onboarding.ai.description', '权限、路由、SQL、Docker 和 CI 均由版本化脚手架生成。生成后下载仓库，用 AI 工具按仓库里的 AGENTS.md 继续开发业务代码。', '{"en-US":"Permissions, routes, SQL, Docker, and CI are generated by versioned scaffolding. Download the repository and let your AI tool continue the business code following AGENTS.md.","ja-JP":"権限・ルーティング・SQL・Docker・CI はバージョン管理されたスキャフォールドが生成します。生成後にリポジトリをダウンロードし、AI ツールが AGENTS.md に従って業務コードを続けます。"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.305880', '2026-11-13 01:09:49.210605', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000486, 'onboarding.ai.title', '平台只生成确定性脚手架，业务代码由你的 AI 工具完成', '{"en-US":"The platform only generates a deterministic scaffold; your AI tool writes the business code","ja-JP":"プラットフォームは確定的なスキャフォールドのみ生成し、業務コードは AI ツールが書きます"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.308041', '2026-11-13 01:09:49.203076', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000487, 'onboarding.boundary.description', 'Kaiwu 不提供在线表单搭建或持续覆盖式生成。项目生成成功后，代码会交由独立仓库和开发团队维护。', '{"en-US":"Kaiwu does not provide online form building or repeated overwrite generation. After generation, independent repositories and the development team own the source."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.310796', '2026-11-13 01:09:45.310810', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000488, 'onboarding.boundary.title', '先定义项目边界，再生成第一版源码', '{"en-US":"Define the project boundary before generating the first source baseline"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.313855', '2026-11-13 01:09:45.313863', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000492, 'onboarding.confirm.description', '生成成功后可下载后端和前端 ZIP；若 GitLab 已配置，可向项目配置分支显式执行一次初始推送。后续修改完全由业务仓库接管。', '{"en-US":"After success, download backend and frontend ZIP files or explicitly make one initial push to the configured project branch when GitLab is available. Business repositories own all later changes.","ja-JP":"生成後はバックエンドとフロントエンドの ZIP をダウンロードできます。GitLab が設定されている場合は、プロジェクトで設定したブランチへ一度だけ初回プッシュできます。その後の変更は業務リポジトリが管理します。"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.325540', '2026-11-13 01:09:45.325552', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000493, 'onboarding.confirm.title', '提交后会创建项目并提交唯一的一次第一版生成任务', '{"en-US":"Submitting creates the project and its one permitted initial generation task"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.334079', '2026-11-13 01:09:45.334130', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000494, 'onboarding.ddl', '数据库 DDL', '{"en-US":"Database DDL","ja-JP":"データベース DDL"}', 'onboarding', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.338432', '2026-11-13 01:09:49.216454', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000495, 'onboarding.ddl.extra', '只接受 CREATE TABLE。已有 MySQL 库也可在项目创建后，从“生成第一版”中只读导入结构。', '{"en-US":"Only CREATE TABLE is accepted. After project creation, an existing MySQL schema can also be imported read-only from Generate first version."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.343327', '2026-11-13 01:09:45.343341', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000496, 'onboarding.ddl.placeholder', '可粘贴 CREATE TABLE 语句', '{"en-US":"Paste CREATE TABLE statements"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.351102', '2026-11-13 01:09:45.351123', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000497, 'onboarding.description', '项目说明（可选）', '{"en-US":"Project description (optional)"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.358799', '2026-11-13 01:09:45.358872', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000498, 'onboarding.description.placeholder', '例如：面向销售团队的客户资料与跟进记录管理后台', '{"en-US":"For example, a customer and sales follow-up administration system"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.386385', '2026-11-13 01:09:45.386423', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000499, 'onboarding.exit.button', '退出向导', '{"en-US":"Exit wizard"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.412448', '2026-11-13 01:09:45.412475', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000500, 'onboarding.exit.cancel', '继续填写', '{"en-US":"Continue editing"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.423590', '2026-11-13 01:09:45.423610', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000501, 'onboarding.exit.confirm', '退出', '{"en-US":"Exit"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.434388', '2026-11-13 01:09:45.434403', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000502, 'onboarding.exit.created', '项目已创建，退出后可在项目管理中继续配置成员与生成任务。', '{"en-US":"The project has been created. Continue member and generation setup from Projects."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.523696', '2026-11-13 01:09:45.523711', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000503, 'onboarding.exit.title', '退出项目开通向导？', '{"en-US":"Exit the project setup wizard?"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.527793', '2026-11-13 01:09:45.527808', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000504, 'onboarding.exit.unsubmitted', '尚未提交，已填写的内容不会保存。', '{"en-US":"Nothing has been submitted. Your entries will not be saved."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.543503', '2026-11-13 01:09:45.543515', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000505, 'onboarding.failure.default', '开通失败', '{"en-US":"Project setup failed"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.546602', '2026-11-13 01:09:45.546614', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000506, 'onboarding.failure.preserved', '项目已保留，可修正后继续：{detail}', '{"en-US":"The project was preserved. Correct the input and continue: {detail}"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.550326', '2026-11-13 01:09:45.550345', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000507, 'onboarding.member.option', '{displayName}（{username}）', '{"en-US":"{displayName} ({username})"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.591651', '2026-11-13 01:09:45.591672', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000508, 'onboarding.members.description', '创建人会自动成为项目管理员。初始成员不是必填项；这里选择的用户会加入“项目成员”基础角色，后续可在项目权限中心细分权限。', '{"en-US":"The creator automatically becomes project administrator. Initial members are optional; selected users join the base Project member role and can receive finer access later."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.612299', '2026-11-13 01:09:45.612324', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000509, 'onboarding.members.label', '初始成员（可选）', '{"en-US":"Initial members (optional)"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.628888', '2026-11-13 01:09:45.628914', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000511, 'onboarding.mode.basic', '基础脚手架', '{"en-US":"Basic scaffold"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.644876', '2026-11-13 01:09:45.644887', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000512, 'onboarding.mode.label', '生成方式', '{"en-US":"Generation mode"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.647218', '2026-11-13 01:09:45.647225', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000513, 'onboarding.next', '下一步', '{"en-US":"Next"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.648829', '2026-11-13 01:09:45.648833', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000514, 'onboarding.packageName', 'Java 包名', '{"en-US":"Java package"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.650348', '2026-11-13 01:09:45.650352', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000515, 'onboarding.packageName.extra', '用于生成后端的基础包路径；使用团队已有的 Java 命名空间即可。', '{"en-US":"Base package for the generated backend. Use your team’s existing Java namespace."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.653259', '2026-11-13 01:09:45.653265', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000516, 'onboarding.packageName.placeholder', '例如 com.example.app', '{"en-US":"For example, com.example.app"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.657131', '2026-11-13 01:09:45.657141', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000517, 'onboarding.permission.warning', '当前账号缺少项目生成权限，无法完成最后一步', '{"en-US":"Your account lacks project generation permission, so the final step is unavailable"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.659111', '2026-11-13 01:09:45.659116', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000518, 'onboarding.previous', '上一步', '{"en-US":"Previous"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.660474', '2026-11-13 01:09:45.660478', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000519, 'onboarding.projectCode', '项目编码', '{"en-US":"Project code"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.661795', '2026-11-13 01:09:45.661799', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000520, 'onboarding.projectCode.placeholder', '例如 crm-center', '{"en-US":"For example, crm-center"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.663719', '2026-11-13 01:09:45.663727', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000521, 'onboarding.projectCode.rule', '小写字母开头，仅小写字母、数字和连字符', '{"en-US":"Start with a lowercase letter and use only lowercase letters, numbers, and hyphens"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.666000', '2026-11-13 01:09:45.666012', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000522, 'onboarding.projectName', '项目名称', '{"en-US":"Project name"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.667910', '2026-11-13 01:09:45.667915', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000523, 'onboarding.projectName.placeholder', '例如 客户管理中心', '{"en-US":"For example, Customer management"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.669579', '2026-11-13 01:09:45.669583', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000524, 'onboarding.result.factory', '查看项目工厂', '{"en-US":"View Project factory"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.672226', '2026-11-13 01:09:45.672237', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000525, 'onboarding.result.projects', '管理项目', '{"en-US":"Manage projects"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.674182', '2026-11-13 01:09:45.674187', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000526, 'onboarding.result.subtitle', '{project} 的生成任务 {taskNo} 已创建，可在项目工厂持续查看。', '{"en-US":"Generation task {taskNo} was created for {project}. Track it in Project factory."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.675551', '2026-11-13 01:09:45.675556', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000527, 'onboarding.result.title', '项目开通流程已提交', '{"en-US":"Project setup submitted"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.676966', '2026-11-13 01:09:45.676974', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000528, 'onboarding.resume.info', '检测到本人创建的未完成项目，已从中断步骤继续', '{"en-US":"Your unfinished project was found. Setup has resumed from the interrupted step."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.680113', '2026-11-13 01:09:45.680124', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000529, 'onboarding.step.confirm', '确认开通', '{"en-US":"Confirm setup"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.682724', '2026-11-13 01:09:45.682734', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000530, 'onboarding.step.generation', '生成方式', '{"en-US":"Generation mode"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.685051', '2026-11-13 01:09:45.685059', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000531, 'onboarding.step.members', '项目成员', '{"en-US":"Project members"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.686812', '2026-11-13 01:09:45.686817', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000532, 'onboarding.step.project', '项目信息', '{"en-US":"Project details"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.689907', '2026-11-13 01:09:45.689916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000533, 'onboarding.submit', '创建并生成', '{"en-US":"Create and generate"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.691684', '2026-11-13 01:09:45.691689', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000534, 'onboarding.subtitle', '一次完成项目、基础成员角色和代码生成任务的初始化', '{"en-US":"Initialize a project, its base member role, and its source generation task in one flow"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.693065', '2026-11-13 01:09:45.693069', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000535, 'onboarding.success.created', '项目已创建并提交生成', '{"en-US":"Project created and generation submitted"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.694336', '2026-11-13 01:09:45.694339', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000536, 'onboarding.success.restored', '项目已有生成任务，已恢复开通结果', '{"en-US":"The project already has a generation task. Its setup result has been restored."}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.695736', '2026-11-13 01:09:45.695741', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000537, 'onboarding.title', '项目开通向导', '{"en-US":"Project setup wizard"}', 'onboarding', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.697333', '2026-11-13 01:09:45.697341', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000538, 'org.actions', '操作', '{"en-US":"Actions"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.699454', '2026-11-13 01:09:45.699462', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000539, 'org.additional', '兼任部门', '{"en-US":"Additional departments"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.701366', '2026-11-13 01:09:45.701372', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000540, 'org.adjust', '调整归属', '{"en-US":"Adjust membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.703122', '2026-11-13 01:09:45.703130', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000541, 'org.allUsers', '全部用户', '{"en-US":"All users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.708828', '2026-11-13 01:09:45.708839', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000542, 'org.assignTitle', '分配部门：{name}', '{"en-US":"Assign departments: {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.710977', '2026-11-13 01:09:45.710983', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000543, 'org.assignmentFailed', '部门归属更新失败', '{"en-US":"Failed to update department membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.712491', '2026-11-13 01:09:45.712495', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000544, 'org.assignmentHint', '主部门用于默认数据归属；兼任部门用于跨部门协作。清空主部门会将用户设为未分配。', '{"en-US":"The primary department owns data by default; additional departments support cross-team collaboration. Clearing primary leaves the user unassigned."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.713814', '2026-11-13 01:09:45.713818', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000545, 'org.assignmentUpdated', '用户部门归属已更新', '{"en-US":"User department membership updated"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.715051', '2026-11-13 01:09:45.715055', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000546, 'org.code', '部门编码', '{"en-US":"Department code"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.716358', '2026-11-13 01:09:45.716362', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000547, 'org.codeRule', '小写字母开头，仅小写字母、数字和连字符', '{"en-US":"Start with a lowercase letter and use only lowercase letters, numbers, and hyphens"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.717701', '2026-11-13 01:09:45.717706', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000548, 'org.create', '新建部门', '{"en-US":"Create department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.719542', '2026-11-13 01:09:45.719554', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000549, 'org.createTitle', '新建部门', '{"en-US":"Create department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.727107', '2026-11-13 01:09:45.727121', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000550, 'org.created', '部门已创建', '{"en-US":"Department created"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.731937', '2026-11-13 01:09:45.731952', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000551, 'org.delete', '删除', '{"en-US":"Delete"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.736897', '2026-11-13 01:09:45.736922', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000552, 'org.deleteConfirm', '确认删除该部门？', '{"en-US":"Delete this department?"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.744825', '2026-11-13 01:09:45.744838', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000553, 'org.deleteHint', '存在下级部门或用户归属时会拒绝删除。', '{"en-US":"Departments with children or assigned users cannot be deleted."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.749070', '2026-11-13 01:09:45.749081', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000554, 'org.deleted', '部门已删除', '{"en-US":"Department deleted"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.753070', '2026-11-13 01:09:45.753082', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000555, 'org.edit', '编辑', '{"en-US":"Edit"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.758557', '2026-11-13 01:09:45.758569', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000556, 'org.editTitle', '编辑部门', '{"en-US":"Edit department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.760414', '2026-11-13 01:09:45.760420', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000557, 'org.loadFailed', '组织架构加载失败', '{"en-US":"Failed to load the organization"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.762427', '2026-11-13 01:09:45.762437', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000558, 'org.membership', '部门归属', '{"en-US":"Department membership"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.765010', '2026-11-13 01:09:45.765018', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000559, 'org.name', '部门名称', '{"en-US":"Department name"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.766760', '2026-11-13 01:09:45.766764', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000560, 'org.option', '{name}（{code}）', '{"en-US":"{name} ({code})"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.768254', '2026-11-13 01:09:45.768260', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000561, 'org.parent', '上级部门', '{"en-US":"Parent department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.771926', '2026-11-13 01:09:45.771939', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000562, 'org.peopleCount', '{count} 人', '{"en-US":"{count} people"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.774801', '2026-11-13 01:09:45.774807', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000563, 'org.primary', '主部门', '{"en-US":"Primary department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.776474', '2026-11-13 01:09:45.776479', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000564, 'org.primaryTag', '主部门 · {name}', '{"en-US":"Primary · {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.778196', '2026-11-13 01:09:45.778203', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000565, 'org.saveFailed', '部门保存失败', '{"en-US":"Failed to save department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.779978', '2026-11-13 01:09:45.779984', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000566, 'org.searchUsers', '搜索姓名或账号', '{"en-US":"Search name or account"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.781867', '2026-11-13 01:09:45.781875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000567, 'org.selectAdditional', '可选择多个兼任部门', '{"en-US":"Select one or more additional departments"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.783707', '2026-11-13 01:09:45.783714', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000568, 'org.selectPrimary', '选择主部门', '{"en-US":"Select a primary department"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.785419', '2026-11-13 01:09:45.785424', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000569, 'org.selectPrimaryFirst', '请先选择主部门', '{"en-US":"Select a primary department first"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.788065', '2026-11-13 01:09:45.788085', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000570, 'org.sort', '排序', '{"en-US":"Sort order"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.791501', '2026-11-13 01:09:45.791513', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000571, 'org.status', '状态', '{"en-US":"Status"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.794664', '2026-11-13 01:09:45.794673', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000572, 'org.subtitle', '维护部门树和用户归属；一个用户可归属多个部门，首项为主部门', '{"en-US":"Maintain the department tree and user membership. A user can belong to multiple departments; the first is primary."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.796777', '2026-11-13 01:09:45.796783', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000573, 'org.title', '组织架构', '{"en-US":"Organization"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.798245', '2026-11-13 01:09:45.798249', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000574, 'org.totalUsers', '共 {total} 位用户', '{"en-US":"{total} users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.799463', '2026-11-13 01:09:45.799466', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000575, 'org.tree', '部门树', '{"en-US":"Department tree"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.800597', '2026-11-13 01:09:45.800599', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000576, 'org.treeHint', '点击部门筛选右侧用户', '{"en-US":"Select a department to filter users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.801704', '2026-11-13 01:09:45.801707', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000577, 'org.unassigned', '未分配', '{"en-US":"Unassigned"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.803003', '2026-11-13 01:09:45.803007', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000578, 'org.unknown', '未知部门 {id}', '{"en-US":"Unknown department {id}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.805796', '2026-11-13 01:09:45.805803', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000579, 'org.updated', '部门已更新', '{"en-US":"Department updated"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.807434', '2026-11-13 01:09:45.807438', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000580, 'org.user', '用户', '{"en-US":"User"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.808824', '2026-11-13 01:09:45.808828', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000581, 'org.userMembership', '用户归属 · {scope}', '{"en-US":"User membership · {scope}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.810141', '2026-11-13 01:09:45.810144', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000582, 'org.viewAll', '查看全部用户', '{"en-US":"View all users"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.811430', '2026-11-13 01:09:45.811433', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000583, 'password.confirm', '确认新密码', '{"en-US":"Confirm new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.812636', '2026-11-13 01:09:45.812640', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000584, 'password.confirm.mismatch', '两次输入的新密码不一致', '{"en-US":"The two passwords do not match"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.813836', '2026-11-13 01:09:45.813839', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000585, 'password.confirm.required', '请再次输入新密码', '{"en-US":"Enter the new password again"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.814995', '2026-11-13 01:09:45.814998', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000586, 'password.current', '当前密码', '{"en-US":"Current password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.816172', '2026-11-13 01:09:45.816175', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000587, 'password.current.required', '请输入当前密码', '{"en-US":"Enter your current password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.817409', '2026-11-13 01:09:45.817413', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000588, 'password.force.alertDescription', '为保证账号安全，请设置只有你本人知道的新密码后再继续使用。', '{"en-US":"Set a new password known only to you before continuing."}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.818626', '2026-11-13 01:09:45.818628', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000589, 'password.force.alertTitle', '当前密码由管理员设定', '{"en-US":"Your current password was set by an administrator"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.819807', '2026-11-13 01:09:45.819810', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000590, 'password.force.failure', '修改密码失败', '{"en-US":"Failed to update password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.822899', '2026-11-13 01:09:45.822908', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000591, 'password.force.submit', '设置新密码', '{"en-US":"Set new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.824629', '2026-11-13 01:09:45.824633', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000592, 'password.force.success', '密码已更新，现在可以正常使用平台', '{"en-US":"Password updated. You can now use the platform."}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.825925', '2026-11-13 01:09:45.825929', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000593, 'password.force.title', '请先修改初始密码', '{"en-US":"Change your initial password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.827178', '2026-11-13 01:09:45.827181', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000594, 'password.new', '新密码', '{"en-US":"New password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.828389', '2026-11-13 01:09:45.828392', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000595, 'password.new.extra', '8 到 72 个字符，中文按 UTF-8 字节计算', '{"en-US":"8–72 characters; non-ASCII text is counted as UTF-8 bytes"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.829545', '2026-11-13 01:09:45.829548', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000596, 'password.new.length', '密码长度必须为8到72个字符', '{"en-US":"Password must be 8–72 characters"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.830721', '2026-11-13 01:09:45.830724', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000597, 'password.new.required', '请输入新密码', '{"en-US":"Enter a new password"}', 'password', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.831915', '2026-11-13 01:09:45.831918', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000598, 'profile.account', '账号信息', '{"en-US":"Account information"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.833119', '2026-11-13 01:09:45.833122', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000599, 'profile.changePassword', '修改密码', '{"en-US":"Change password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.834252', '2026-11-13 01:09:45.834255', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000600, 'profile.confirmPassword', '确认新密码', '{"en-US":"Confirm new password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.835452', '2026-11-13 01:09:45.835455', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000601, 'profile.confirmPasswordRequired', '请再次输入新密码', '{"en-US":"Enter the new password again"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.836660', '2026-11-13 01:09:45.836663', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000602, 'profile.currentPassword', '当前密码', '{"en-US":"Current password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.839762', '2026-11-13 01:09:45.839773', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000603, 'profile.currentPasswordRequired', '请输入当前密码', '{"en-US":"Enter your current password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.841873', '2026-11-13 01:09:45.841877', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000604, 'profile.displayName', '显示名称', '{"en-US":"Display name"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.843288', '2026-11-13 01:09:45.843292', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000605, 'profile.editHint', '修改显示名或邮箱请联系管理员，在用户管理里操作', '{"en-US":"Contact an administrator to change your display name or email in Users."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.844513', '2026-11-13 01:09:45.844516', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000606, 'profile.group.other', '其它', '{"en-US":"Other"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.845696', '2026-11-13 01:09:45.845699', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000607, 'profile.group.system', '平台', '{"en-US":"Platform"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.846999', '2026-11-13 01:09:45.847003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000608, 'profile.newPassword', '新密码', '{"en-US":"New password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.848160', '2026-11-13 01:09:45.848163', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000609, 'profile.newPasswordExtra', '8 到 72 个字符，中文按 UTF-8 字节计算', '{"en-US":"8 to 72 characters; non-ASCII characters are counted as UTF-8 bytes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.849332', '2026-11-13 01:09:45.849335', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000610, 'profile.newPasswordRequired', '请输入新密码', '{"en-US":"Enter a new password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.850463', '2026-11-13 01:09:45.850466', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000611, 'profile.noPermissions', '当前账号没有任何权限码，请联系管理员在项目权限中心分配角色。', '{"en-US":"This account has no permission codes. Ask an administrator to assign a role in the project access center."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.851766', '2026-11-13 01:09:45.851770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000612, 'profile.openUsers', '前往用户管理 →', '{"en-US":"Open Users →"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.853151', '2026-11-13 01:09:45.853154', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000613, 'profile.passwordChanged', '密码已更新，其它设备上的登录已被下线', '{"en-US":"Password updated. Sessions on other devices have been revoked."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.856174', '2026-11-13 01:09:45.856185', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000614, 'profile.passwordFailed', '修改密码失败', '{"en-US":"Failed to change password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.858372', '2026-11-13 01:09:45.858378', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000615, 'profile.passwordHint', '密码更新后，其它设备上的登录会被立即下线；当前页面无需重新登录。', '{"en-US":"Updating your password immediately signs out other devices. This page stays signed in."}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.859905', '2026-11-13 01:09:45.859908', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000616, 'profile.passwordLength', '密码长度必须为 8 到 72 个字符', '{"en-US":"The password must contain 8 to 72 characters"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.861251', '2026-11-13 01:09:45.861255', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000617, 'profile.passwordMismatch', '两次输入的新密码不一致', '{"en-US":"The new passwords do not match"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.862492', '2026-11-13 01:09:45.862497', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000618, 'profile.passwordSubmit', '更新密码', '{"en-US":"Update password"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.863742', '2026-11-13 01:09:45.863745', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000619, 'profile.permissionCount', '共 {count} 个权限码', '{"en-US":"{count} permission codes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.864949', '2026-11-13 01:09:45.864952', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000620, 'profile.permissions', '权限码', '{"en-US":"Permission codes"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.866170', '2026-11-13 01:09:45.866173', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000621, 'profile.permissionsHint', '按前缀分组，与后端注解、menu.sql 三端同码', '{"en-US":"Grouped by prefix; codes match backend annotations and menu.sql"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.867662', '2026-11-13 01:09:45.867667', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000622, 'profile.userId', '用户 ID', '{"en-US":"User ID"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.869016', '2026-11-13 01:09:45.869029', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000623, 'profile.username', '用户名', '{"en-US":"Username"}', 'profile', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.871677', '2026-11-13 01:09:45.871704', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000624, 'projects.accessCenter', '权限中心', '{"en-US":"Access center"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.874436', '2026-11-13 01:09:45.874441', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000625, 'projects.accessTitle', '{name}：项目权限中心', '{"en-US":"{name}: Project access center"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.875851', '2026-11-13 01:09:45.875855', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000626, 'projects.actions', '操作', '{"en-US":"Actions"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.877192', '2026-11-13 01:09:45.877196', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000627, 'projects.archive', '归档', '{"en-US":"Archive"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.878442', '2026-11-13 01:09:45.878445', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000628, 'projects.archiveConfirm', '确认归档项目？归档后当前成员不可再进入。', '{"en-US":"Archive this project? Current members will no longer be able to enter."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.879683', '2026-11-13 01:09:45.879687', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000629, 'projects.archived', '项目已归档', '{"en-US":"Project archived"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.881086', '2026-11-13 01:09:45.881089', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000630, 'projects.backend', '业务后台', '{"en-US":"Administration site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.882282', '2026-11-13 01:09:45.882286', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000631, 'projects.backendLabel', '业务后台入口名称', '{"en-US":"Administration link label"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.883465', '2026-11-13 01:09:45.883469', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000635, 'projects.backendUrl', '业务后台入口', '{"en-US":"Administration URL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.890545', '2026-11-13 01:09:45.890552', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000636, 'projects.basicDescription', '适合先拿到可启动仓库结构，再由开发者自行实现业务。', '{"en-US":"Use it to obtain runnable repository structure, then implement the business manually."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.892114', '2026-11-13 01:09:45.892117', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000637, 'projects.basicTitle', '基础空脚手架不调用 AI，也不生成业务表和 CRUD', '{"en-US":"Basic scaffold does not call AI or generate business tables and CRUD"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.893402', '2026-11-13 01:09:45.893405', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000638, 'projects.builtIn', '内置', '{"en-US":"Built-in"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.894594', '2026-11-13 01:09:45.894597', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000640, 'projects.businessMenus', '业务菜单', '{"en-US":"Business menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.896819', '2026-11-13 01:09:45.896822', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000643, 'projects.businessScope', '这里的成员、角色、业务菜单和权限码只属于当前项目，不会影响 system 或其他项目。', '{"en-US":"Members, roles, business menus, and permission codes here belong only to this project and do not affect system or other projects."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.900438', '2026-11-13 01:09:45.900442', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000644, 'projects.createdAt', '创建时间', '{"en-US":"Created at"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.901660', '2026-11-13 01:09:45.901663', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000645, 'projects.currentScope', '当前范围：{name}（{code}）', '{"en-US":"Current scope: {name} ({code})"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.902956', '2026-11-13 01:09:45.902959', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000646, 'projects.database', '数据库', '{"en-US":"Database"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.905661', '2026-11-13 01:09:45.905679', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000647, 'projects.ddl', 'MySQL DDL', '{"en-US":"MySQL DDL","ja-JP":"MySQL DDL"}', 'projects', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.907991', '2026-11-13 01:09:49.223147', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000648, 'projects.ddlExtra', '粘贴 CREATE TABLE，或使用下方只读导入已有库的结构', '{"en-US":"Paste CREATE TABLE DDL, or use the read-only import below to read an existing database schema.","ja-JP":"CREATE TABLE を貼り付けるか、下の読み取り専用インポートで既存データベースの構造を取り込みます。"}', 'projects', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:45.909760', '2026-11-13 01:09:49.227826', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000649, 'projects.defaultBranch', '默认目标分支', '{"en-US":"Default target branch"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.911277', '2026-11-13 01:09:45.911280', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000655, 'projects.description', '描述', '{"en-US":"Description"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.919645', '2026-11-13 01:09:45.919649', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000656, 'projects.disable', '停用', '{"en-US":"Disable"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.921999', '2026-11-13 01:09:45.922009', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000657, 'projects.disableConfirm', '确认停用项目？', '{"en-US":"Disable this project?"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.923991', '2026-11-13 01:09:45.923997', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000658, 'projects.edit', '编辑', '{"en-US":"Edit"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.925971', '2026-11-13 01:09:45.925977', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000659, 'projects.editTitle', '编辑项目{suffix}', '{"en-US":"Edit project{suffix}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.927810', '2026-11-13 01:09:45.927818', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000660, 'projects.enable', '启用', '{"en-US":"Enable"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.929794', '2026-11-13 01:09:45.929802', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000661, 'projects.enableConfirm', '确认启用项目？', '{"en-US":"Enable this project?"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.931893', '2026-11-13 01:09:45.931903', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000665, 'projects.generateFirst', '生成第一版', '{"en-US":"Generate first version"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.938278', '2026-11-13 01:09:45.938285', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000666, 'projects.generateTitle', '生成第一版：{name}', '{"en-US":"Generate first version: {name}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.939917', '2026-11-13 01:09:45.939921', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000669, 'projects.generationMode', '生成方式', '{"en-US":"Generation mode"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.943949', '2026-11-13 01:09:45.943952', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000670, 'projects.generationQueued', '生成任务已进入队列，可在项目工厂查看进度', '{"en-US":"Generation queued. Track progress in Project factory."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.945195', '2026-11-13 01:09:45.945199', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000671, 'projects.gitlabId', 'GitLab 项目标识', '{"en-US":"GitLab project identifier"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.946791', '2026-11-13 01:09:45.946796', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000672, 'projects.gitlabIdPlaceholder', '数字 ID 或 group/project', '{"en-US":"Numeric ID or group/project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.948610', '2026-11-13 01:09:45.948617', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000675, 'projects.host', '主机', '{"en-US":"Host"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.953257', '2026-11-13 01:09:45.953263', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000676, 'projects.hostPlaceholder', '只填主机名或 IPv4，不填 jdbc:mysql:// 和端口', '{"en-US":"Enter only a hostname or IPv4 address, without jdbc:mysql:// or a port"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.954909', '2026-11-13 01:09:45.954916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000677, 'projects.importSchema', '从 MySQL 只读导入结构', '{"en-US":"Import schema read-only from MySQL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.956439', '2026-11-13 01:09:45.956442', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000678, 'projects.importTitle', '从 MySQL 只读导入表结构', '{"en-US":"Import table schema read-only from MySQL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.957746', '2026-11-13 01:09:45.957749', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000679, 'projects.importedSchema', '已只读导入 {tables} 张表、{columns} 个字段；密码未保存', '{"en-US":"Imported {tables} tables and {columns} columns read-only; the password was not saved"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.958976', '2026-11-13 01:09:45.958979', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000680, 'projects.keyword', '关键词', '{"en-US":"Keyword"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.960132', '2026-11-13 01:09:45.960135', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000681, 'projects.keywordPlaceholder', '项目编码或名称', '{"en-US":"Project code or name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.961252', '2026-11-13 01:09:45.961255', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000682, 'projects.legacyRepo', '单仓代码生成', '{"en-US":"Legacy single repository"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.962496', '2026-11-13 01:09:45.962501', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000683, 'projects.legacyRepoPlaceholder', '旧版单仓代码生成使用', '{"en-US":"Used by legacy single-repository generation"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.964222', '2026-11-13 01:09:45.964229', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000684, 'projects.legacyRepoTooltip', '仅供旧版代码生成与 MR 使用；新项目的后端、前端双仓库请使用项目列表中的“仓库交付”', '{"en-US":"Used only by the legacy generator and merge requests. Use Repository delivery for new separate backend and frontend repositories."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.966013', '2026-11-13 01:09:45.966018', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000685, 'projects.legacyRepoUrl', '单仓代码生成仓库地址', '{"en-US":"Legacy repository URL"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.967415', '2026-11-13 01:09:45.967418', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000686, 'projects.name', '项目名称', '{"en-US":"Project name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.968815', '2026-11-13 01:09:45.968819', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000689, 'projects.open', '开通项目', '{"en-US":"Set up project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.973426', '2026-11-13 01:09:45.973431', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000690, 'projects.openBackend', '打开后台', '{"en-US":"Open administration site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.974712', '2026-11-13 01:09:45.974716', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000693, 'projects.package', '基础包名', '{"en-US":"Base package"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.978471', '2026-11-13 01:09:45.978474', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000694, 'projects.packageRule', '请输入合法 Java 包名', '{"en-US":"Enter a valid Java package name"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.979725', '2026-11-13 01:09:45.979728', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000695, 'projects.password', '密码', '{"en-US":"Password"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.980873', '2026-11-13 01:09:45.980875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000696, 'projects.passwordOnce', '密码只用于这一次请求', '{"en-US":"The password is used for this request only"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.982048', '2026-11-13 01:09:45.982051', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000697, 'projects.permissionMenus', '权限菜单', '{"en-US":"Permission menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.983168', '2026-11-13 01:09:45.983171', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000698, 'projects.platformMenus', '平台菜单', '{"en-US":"Platform menus"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.984408', '2026-11-13 01:09:45.984412', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000699, 'projects.port', '端口', '{"en-US":"Port"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.985602', '2026-11-13 01:09:45.985605', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000700, 'projects.project', '项目', '{"en-US":"Project"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.986906', '2026-11-13 01:09:45.986912', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000701, 'projects.projectDescription', '项目描述', '{"en-US":"Project description"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.988999', '2026-11-13 01:09:45.989010', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000702, 'projects.projectMembers', '项目成员', '{"en-US":"Project members"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.990481', '2026-11-13 01:09:45.990484', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000707, 'projects.readSchema', '读取表结构', '{"en-US":"Read schema"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.996766', '2026-11-13 01:09:45.996770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000708, 'projects.readonlyUser', '只读账号', '{"en-US":"Read-only username"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:45.997932', '2026-11-13 01:09:45.997935', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000710, 'projects.roleGrant', '角色授权', '{"en-US":"Role grants"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.000303', '2026-11-13 01:09:46.000306', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000711, 'projects.schemaSafety', 'System 只查询 information_schema 和 SHOW CREATE TABLE，不读取业务行；地址、账号、密码不会写入数据库、日志或生成任务。建议使用只读账号。', '{"en-US":"System queries only information_schema and SHOW CREATE TABLE, never business rows. Address, username, and password are not stored in the database, logs, or generation task. Use a read-only account."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.001479', '2026-11-13 01:09:46.001482', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000712, 'projects.status', '状态', '{"en-US":"Status"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.002644', '2026-11-13 01:09:46.002647', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000713, 'projects.statusUpdated', '项目状态已更新', '{"en-US":"Project status updated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.004316', '2026-11-13 01:09:46.004323', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000714, 'projects.submitGeneration', '提交生成', '{"en-US":"Submit generation"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.006033', '2026-11-13 01:09:46.006039', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000715, 'projects.subtitle', '前后端双仓库通过每个项目的“仓库交付”配置；system 是不可停用、不可归档的内置项目', '{"en-US":"Configure separate frontend and backend repositories through Repository delivery. system is a built-in project that cannot be disabled or archived."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.007441', '2026-11-13 01:09:46.007444', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000716, 'projects.systemMembers', '系统成员', '{"en-US":"System members"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.008994', '2026-11-13 01:09:46.009000', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000717, 'projects.systemRoleGrant', '系统角色授权', '{"en-US":"System role grants"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.010440', '2026-11-13 01:09:46.010443', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000718, 'projects.systemScope', '这是不可停用、不可归档的 system 内置项目。Kaiwu 平台成员、系统角色、平台菜单和登录权限全部在这里管理；权限变更会撤销受影响用户的现有会话。', '{"en-US":"This is the built-in system project and cannot be disabled or archived. Manage Kaiwu platform members, system roles, platform menus, and sign-in permissions here. Permission changes revoke affected sessions."}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.011677', '2026-11-13 01:09:46.011680', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000719, 'projects.title', '项目管理', '{"en-US":"Projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.013343', '2026-11-13 01:09:46.013351', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000720, 'projects.titleSuffix', '：{name}', '{"en-US":": {name}"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.015235', '2026-11-13 01:09:46.015244', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000721, 'projects.updated', '项目已更新', '{"en-US":"Project updated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.017233', '2026-11-13 01:09:46.017239', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000723, 'roles.actions', '操作', '{"en-US":"Actions"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.020129', '2026-11-13 01:09:46.020132', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000724, 'roles.assignMenus', '分配菜单', '{"en-US":"Assign menus"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.021964', '2026-11-13 01:09:46.021977', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000725, 'roles.assignTitle', '分配业务菜单{suffix}', '{"en-US":"Assign business menus{suffix}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.025725', '2026-11-13 01:09:46.025738', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000726, 'roles.code', '角色编码', '{"en-US":"Role code"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.028357', '2026-11-13 01:09:46.028368', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000727, 'roles.create', '新建项目角色', '{"en-US":"Create project role"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.031547', '2026-11-13 01:09:46.031560', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000728, 'roles.delete', '删除', '{"en-US":"Delete"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.034708', '2026-11-13 01:09:46.034719', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000729, 'roles.deleteConfirm', '确认删除该项目角色？', '{"en-US":"Delete this project role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.037210', '2026-11-13 01:09:46.037216', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000730, 'roles.deleted', '项目角色已删除', '{"en-US":"Project role deleted"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.039372', '2026-11-13 01:09:46.039379', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000731, 'roles.description', '描述', '{"en-US":"Description"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.040890', '2026-11-13 01:09:46.040894', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000732, 'roles.disableConfirm', '确认停用角色？', '{"en-US":"Disable this role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.042101', '2026-11-13 01:09:46.042104', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000733, 'roles.edit', '编辑', '{"en-US":"Edit"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.043228', '2026-11-13 01:09:46.043230', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000734, 'roles.editTitle', '编辑角色：{name}', '{"en-US":"Edit role: {name}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.044351', '2026-11-13 01:09:46.044354', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000735, 'roles.enableConfirm', '确认启用角色？', '{"en-US":"Enable this role?"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.045616', '2026-11-13 01:09:46.045622', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000736, 'roles.grantUpdated', '项目角色授权已更新，父节点会自动补齐', '{"en-US":"Project role grants updated; parent nodes were added automatically"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.047303', '2026-11-13 01:09:46.047310', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000737, 'roles.menuCount', '菜单数', '{"en-US":"Menu count"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.049150', '2026-11-13 01:09:46.049156', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000738, 'roles.menuOption', '{name}（{code}）', '{"en-US":"{name} ({code})"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.050766', '2026-11-13 01:09:46.050770', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000739, 'roles.name', '角色名称', '{"en-US":"Role name"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.052229', '2026-11-13 01:09:46.052233', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000740, 'roles.roleDescription', '角色描述', '{"en-US":"Role description"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.053510', '2026-11-13 01:09:46.053513', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000741, 'roles.saved', '项目角色已保存', '{"en-US":"Project role saved"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.056293', '2026-11-13 01:09:46.056296', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000742, 'roles.status', '状态', '{"en-US":"Status"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.057637', '2026-11-13 01:09:46.057640', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000743, 'scheduler.actions', '操作', '{"en-US":"Actions"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.058800', '2026-11-13 01:09:46.058803', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000744, 'scheduler.completedAt', '完成时间', '{"en-US":"Completed at"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.059899', '2026-11-13 01:09:46.059902', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000745, 'scheduler.create', '新建任务', '{"en-US":"Create job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.061119', '2026-11-13 01:09:46.061122', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000746, 'scheduler.createTitle', '新建定时任务', '{"en-US":"Create scheduled job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.062393', '2026-11-13 01:09:46.062397', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000747, 'scheduler.credentialEnv', '将它以 KAIWU_SCHEDULER_CREDENTIAL 环境变量注入该项目服务；定时任务与读取平台参数配置共用这一个凭据。', '{"en-US":"Inject it into the project service as the KAIWU_SCHEDULER_CREDENTIAL environment variable. Scheduled tasks and platform configuration reads share this one credential."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.063938', '2026-11-13 01:09:46.063943', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000748, 'scheduler.credentialOnce', '凭据只显示这一次；再次生成会立即撤销旧凭据。', '{"en-US":"The credential is shown only once. Generating another immediately revokes the old one."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.065658', '2026-11-13 01:09:46.065662', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000749, 'scheduler.credentialSaved', '我已保存', '{"en-US":"I saved it"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.067183', '2026-11-13 01:09:46.067187', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000750, 'scheduler.credentialTitle', '请立即保存项目服务凭据', '{"en-US":"Save the project service credential now"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.068519', '2026-11-13 01:09:46.068522', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000751, 'scheduler.cron', 'Cron 表达式', '{"en-US":"Cron expression"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.069852', '2026-11-13 01:09:46.069855', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000752, 'scheduler.cronTooltip', 'Spring 六段 Cron：秒 分 时 日 月 星期', '{"en-US":"Spring six-field Cron: second minute hour day month weekday"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.071159', '2026-11-13 01:09:46.071162', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000753, 'scheduler.cronZone', 'Cron / 时区', '{"en-US":"Cron / time zone"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.074157', '2026-11-13 01:09:46.074160', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000754, 'scheduler.delete', '删除', '{"en-US":"Delete"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.075441', '2026-11-13 01:09:46.075444', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000755, 'scheduler.deleteConfirm', '删除后不再产生新的触发，历史执行记录会保留。确认删除？', '{"en-US":"Deleting stops future triggers and preserves execution history. Delete this job?"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.076631', '2026-11-13 01:09:46.076634', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000756, 'scheduler.deleted', '定时任务已删除', '{"en-US":"Scheduled job deleted"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.077898', '2026-11-13 01:09:46.077902', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000757, 'scheduler.edit', '编辑', '{"en-US":"Edit"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.079308', '2026-11-13 01:09:46.079313', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000758, 'scheduler.editTitle', '编辑定时任务', '{"en-US":"Edit scheduled job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.080996', '2026-11-13 01:09:46.081003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000759, 'scheduler.emptyExecutions', '当前项目暂无执行记录', '{"en-US":"No execution records for this project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.082697', '2026-11-13 01:09:46.082701', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000760, 'scheduler.emptyJobs', '当前项目暂无定时任务', '{"en-US":"No scheduled jobs for this project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.084201', '2026-11-13 01:09:46.084205', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000761, 'scheduler.enabled', '启用', '{"en-US":"Enabled"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.085568', '2026-11-13 01:09:46.085571', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000762, 'scheduler.enabledTooltip', '建议先保存为停用，确认项目实例在线后再启用', '{"en-US":"Save disabled first, then enable after confirming a project instance is online"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.086864', '2026-11-13 01:09:46.086867', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000763, 'scheduler.executions', '执行记录', '{"en-US":"Execution records"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.088833', '2026-11-13 01:09:46.088836', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000764, 'scheduler.generateCredential', '生成项目凭据', '{"en-US":"Generate project credential"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.090123', '2026-11-13 01:09:46.090126', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000765, 'scheduler.handler', '任务处理器', '{"en-US":"Task handler"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.091357', '2026-11-13 01:09:46.091360', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000766, 'scheduler.handlerOption', '{name}（{type}）', '{"en-US":"{name} ({type})"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.092552', '2026-11-13 01:09:46.092555', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000767, 'scheduler.handlerRequired', '请选择项目已注册的任务处理器', '{"en-US":"Select a handler registered by the project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.093721', '2026-11-13 01:09:46.093724', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000768, 'scheduler.handlerTooltip', '只能选择项目服务主动上报的 Handler', '{"en-US":"Only handlers reported by the project service can be selected"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.094900', '2026-11-13 01:09:46.094903', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000769, 'scheduler.instance', '执行实例', '{"en-US":"Execution instance"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.096010', '2026-11-13 01:09:46.096013', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000770, 'scheduler.job', '任务', '{"en-US":"Job"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.097245', '2026-11-13 01:09:46.097248', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000771, 'scheduler.jobs', '任务配置', '{"en-US":"Job configuration"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.098485', '2026-11-13 01:09:46.098488', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000772, 'scheduler.lastRun', '最近执行', '{"en-US":"Last run"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.099648', '2026-11-13 01:09:46.099651', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000773, 'scheduler.name', '任务名称', '{"en-US":"Job name"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.100830', '2026-11-13 01:09:46.100832', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000774, 'scheduler.nameRequired', '请输入任务名称', '{"en-US":"Enter a job name"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.102070', '2026-11-13 01:09:46.102072', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000775, 'scheduler.noHandlers', '当前项目还没有在线任务处理器', '{"en-US":"This project has no online task handlers"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.103370', '2026-11-13 01:09:46.103374', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000776, 'scheduler.noHandlersHint', '请先部署已接入 scheduler starter 且配置了项目凭据的服务实例；实例同步后才能创建任务。', '{"en-US":"Deploy a service using scheduler starter with a project credential before creating jobs."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.104617', '2026-11-13 01:09:46.104619', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000777, 'scheduler.payload', '任务参数（JSON 对象）', '{"en-US":"Job payload (JSON object)"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.107751', '2026-11-13 01:09:46.107754', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000778, 'scheduler.payloadInvalid', '任务参数不是合法 JSON', '{"en-US":"Job payload is not valid JSON"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.109032', '2026-11-13 01:09:46.109035', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000779, 'scheduler.payloadJson', '任务参数必须是合法 JSON', '{"en-US":"Job payload must be valid JSON"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.110292', '2026-11-13 01:09:46.110294', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000780, 'scheduler.payloadObject', '任务参数必须是 JSON 对象', '{"en-US":"Job payload must be a JSON object"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.111509', '2026-11-13 01:09:46.111511', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000781, 'scheduler.payloadTooltip', '留空等同于 {}；必须是 JSON 对象，不能是数组或标量', '{"en-US":"Empty is equivalent to {}; the value must be a JSON object, not an array or scalar"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.112594', '2026-11-13 01:09:46.112596', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000782, 'scheduler.project', '项目', '{"en-US":"Project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.113706', '2026-11-13 01:09:46.113709', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000783, 'scheduler.projectOption', '{name}（{code}）', '{"en-US":"{name} ({code})"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.114824', '2026-11-13 01:09:46.114827', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000784, 'scheduler.refresh', '刷新', '{"en-US":"Refresh"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.115929', '2026-11-13 01:09:46.115932', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000785, 'scheduler.result', '结果 / 失败原因', '{"en-US":"Result / failure reason"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.117110', '2026-11-13 01:09:46.117113', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000786, 'scheduler.saved', '定时任务已保存', '{"en-US":"Scheduled job saved"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.118289', '2026-11-13 01:09:46.118292', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000787, 'scheduler.scheduledAt', '计划触发', '{"en-US":"Scheduled at"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.119634', '2026-11-13 01:09:46.119636', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000788, 'scheduler.securityDescription', '项目服务只会上报本地已注册的任务类型；System 不能下发 Java 类、Shell 或任意 URL。多实例会先向 System 抢占同一触发时间的执行租约。', '{"en-US":"Project services report only locally registered task types. System cannot send Java classes, shell commands, or arbitrary URLs. Multiple instances first claim a lease for the same trigger time."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.120921', '2026-11-13 01:09:46.120923', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000789, 'scheduler.securityTitle', '安全执行模型', '{"en-US":"Secure execution model"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.123744', '2026-11-13 01:09:46.123746', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000790, 'scheduler.selectProject', '选择项目', '{"en-US":"Select a project"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.124977', '2026-11-13 01:09:46.124980', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000791, 'scheduler.status', '状态', '{"en-US":"Status"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.126234', '2026-11-13 01:09:46.126237', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000792, 'scheduler.subtitle', 'System 统一管理调度配置与执行记录，任务代码在对应项目服务内精准执行', '{"en-US":"System manages schedules and execution records; task code runs precisely inside each project service."}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.127417', '2026-11-13 01:09:46.127419', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000793, 'scheduler.title', '项目定时任务', '{"en-US":"Project scheduler"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.128605', '2026-11-13 01:09:46.128608', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000794, 'scheduler.version', '版本', '{"en-US":"Version"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.129792', '2026-11-13 01:09:46.129795', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000795, 'scheduler.zone', '时区', '{"en-US":"Time zone"}', 'scheduler', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.130945', '2026-11-13 01:09:46.130947', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000796, 'scope.global', '全局默认', '{"en-US":"Global defaults"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.132103', '2026-11-13 01:09:46.132106', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000797, 'scope.label', '作用范围', '{"en-US":"Scope"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.133216', '2026-11-13 01:09:46.133219', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000798, 'scope.project', '{name}（{code}）', '{"en-US":"{name} ({code})"}', 'scope', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.134398', '2026-11-13 01:09:46.134401', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000799, 'security.actions', '操作', '{"en-US":"Actions"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.135686', '2026-11-13 01:09:46.135689', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000800, 'security.after', '修改后', '{"en-US":"After"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.136933', '2026-11-13 01:09:46.136935', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000801, 'security.before', '修改前', '{"en-US":"Before"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.138797', '2026-11-13 01:09:46.138800', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000802, 'security.changes', '变更', '{"en-US":"Changes"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.141186', '2026-11-13 01:09:46.141189', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000803, 'security.clientIp', '客户端 IP', '{"en-US":"Client IP"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.142475', '2026-11-13 01:09:46.142478', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000804, 'security.description', '说明', '{"en-US":"Description"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.143740', '2026-11-13 01:09:46.143743', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000805, 'security.detail', '详情', '{"en-US":"Details"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.144959', '2026-11-13 01:09:46.144962', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000806, 'security.diffOperationTitle', '变更详情 · {operation}', '{"en-US":"Change details · {operation}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.146107', '2026-11-13 01:09:46.146110', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000807, 'security.diffTitle', '变更详情', '{"en-US":"Change details"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.147236', '2026-11-13 01:09:46.147239', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000808, 'security.emptyValue', '（空）', '{"en-US":"(empty)"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.148459', '2026-11-13 01:09:46.148462', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000809, 'security.field', '字段', '{"en-US":"Field"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.149603', '2026-11-13 01:09:46.149606', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000810, 'security.forceOffline', '强制下线', '{"en-US":"Force sign-out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.150928', '2026-11-13 01:09:46.150931', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000811, 'security.lastSeen', '最后访问', '{"en-US":"Last seen"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.152200', '2026-11-13 01:09:46.152203', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000812, 'security.loginTime', '登录时间', '{"en-US":"Signed in at"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.153521', '2026-11-13 01:09:46.153524', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000813, 'security.logins', '登录日志', '{"en-US":"Sign-in logs"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.156726', '2026-11-13 01:09:46.156729', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000814, 'security.module', '模块', '{"en-US":"Module"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.157961', '2026-11-13 01:09:46.157964', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000815, 'security.noDiff', '本次操作未解析到字段级变更；如有需要参考“详情”列摘要。', '{"en-US":"No field-level change could be parsed. Refer to the Details summary if needed."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.159106', '2026-11-13 01:09:46.159109', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000816, 'security.nullValue', 'null', '{"en-US":"null"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.160391', '2026-11-13 01:09:46.160394', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000817, 'security.offlineConfirm', '确认下线', '{"en-US":"Confirm sign-out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.161626', '2026-11-13 01:09:46.161629', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000818, 'security.offlineHint', '下线后该设备的 Access Token 会在下一次请求时立即被 Gateway 拒绝。', '{"en-US":"The Gateway will reject this device’s access token on its next request."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.162763', '2026-11-13 01:09:46.162766', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000819, 'security.offlineSuccess', '会话已强制下线', '{"en-US":"Session signed out"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.163911', '2026-11-13 01:09:46.163914', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000820, 'security.offlineTitle', '强制下线：{username}', '{"en-US":"Force sign-out: {username}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.165094', '2026-11-13 01:09:46.165097', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000821, 'security.operation', '操作', '{"en-US":"Operation"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.166239', '2026-11-13 01:09:46.166242', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000822, 'security.operations', '操作日志', '{"en-US":"Operation logs"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.167457', '2026-11-13 01:09:46.167459', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000823, 'security.operator', '操作人：{username}', '{"en-US":"Operator: {username}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.168698', '2026-11-13 01:09:46.168701', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000824, 'security.reason', '处置原因（可选）', '{"en-US":"Reason (optional)"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.169960', '2026-11-13 01:09:46.169963', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000825, 'security.request', '请求', '{"en-US":"Request"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.173481', '2026-11-13 01:09:46.173483', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000826, 'security.sessionId', '会话 ID', '{"en-US":"Session ID"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.174686', '2026-11-13 01:09:46.174689', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000827, 'security.sessions', '在线会话', '{"en-US":"Online sessions"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.175796', '2026-11-13 01:09:46.175798', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000828, 'security.status', '状态', '{"en-US":"Status"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.177036', '2026-11-13 01:09:46.177039', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000829, 'security.subtitle', '统一查看登录、操作审计和在线会话；强制下线会立即撤销 Gateway 会话快照', '{"en-US":"Review sign-ins, audit operations, and online sessions. Forced sign-out immediately revokes the Gateway session snapshot."}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.178244', '2026-11-13 01:09:46.178247', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000830, 'security.summary', '摘要：{detail}', '{"en-US":"Summary: {detail}"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.179405', '2026-11-13 01:09:46.179407', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000831, 'security.targetId', '资源 ID：', '{"en-US":"Resource ID: "}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.180525', '2026-11-13 01:09:46.180527', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000832, 'security.targetType', '资源类型：', '{"en-US":"Resource type: "}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.181653', '2026-11-13 01:09:46.181656', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000833, 'security.time', '时间', '{"en-US":"Time"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.182758', '2026-11-13 01:09:46.182761', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000834, 'security.title', '安全运营中心', '{"en-US":"Security operations"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.183985', '2026-11-13 01:09:46.183988', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000835, 'security.traceId', 'Trace ID', '{"en-US":"Trace ID"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.185170', '2026-11-13 01:09:46.185172', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000836, 'security.user', '用户', '{"en-US":"User"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.186520', '2026-11-13 01:09:46.186522', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000837, 'security.view', '查看', '{"en-US":"View"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.187802', '2026-11-13 01:09:46.187805', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000838, 'starter.authenticationRequired', '未认证或认证已过期', '{"en-US":"Authentication is missing or expired"}', 'starter', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.189265', '2026-11-13 01:09:46.189268', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000839, 'starter.permissionDenied', '无操作权限', '{"en-US":"You do not have permission for this operation"}', 'starter', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.190503', '2026-11-13 01:09:46.190506', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000840, 'users.actions', '操作', '{"en-US":"Actions"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.191779', '2026-11-13 01:09:46.191782', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000841, 'users.batchDisable', '批量停用', '{"en-US":"Disable selected"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.193090', '2026-11-13 01:09:46.193093', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000842, 'users.batchDisableConfirm', '确认批量停用所选用户？', '{"en-US":"Disable the selected users?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.194357', '2026-11-13 01:09:46.194360', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000843, 'users.batchEnable', '批量启用', '{"en-US":"Enable selected"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.195480', '2026-11-13 01:09:46.195483', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000844, 'users.confirmPassword', '确认密码', '{"en-US":"Confirm password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.196731', '2026-11-13 01:09:46.196735', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000845, 'users.create', '新建用户', '{"en-US":"Create user"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.197945', '2026-11-13 01:09:46.197948', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000846, 'users.created', '用户创建成功', '{"en-US":"User created"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.199136', '2026-11-13 01:09:46.199138', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000847, 'users.createdAt', '创建时间', '{"en-US":"Created at"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.200287', '2026-11-13 01:09:46.200289', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000848, 'users.disableConfirm', '确认停用该用户？', '{"en-US":"Disable this user?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.201548', '2026-11-13 01:09:46.201550', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000849, 'users.disabled', '用户已停用', '{"en-US":"User disabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.202892', '2026-11-13 01:09:46.202894', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000850, 'users.displayName', '显示名称', '{"en-US":"Display name"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.204220', '2026-11-13 01:09:46.204223', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000851, 'users.downloadTemplate', '下载模板', '{"en-US":"Download template"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.207297', '2026-11-13 01:09:46.207300', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000852, 'users.editTitle', '编辑用户{suffix}', '{"en-US":"Edit user{suffix}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.208595', '2026-11-13 01:09:46.208598', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000853, 'users.email', '邮箱', '{"en-US":"Email"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.209810', '2026-11-13 01:09:46.209812', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000854, 'users.empty', '暂无用户，点击右上角新建', '{"en-US":"No users. Use Create in the upper right."}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.211037', '2026-11-13 01:09:46.211040', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000855, 'users.enableConfirm', '确认启用该用户？', '{"en-US":"Enable this user?"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.212138', '2026-11-13 01:09:46.212141', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000856, 'users.enabled', '用户已启用', '{"en-US":"User enabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.213292', '2026-11-13 01:09:46.213294', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000857, 'users.excelImport', 'Excel 导入', '{"en-US":"Import Excel"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.214603', '2026-11-13 01:09:46.214606', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000858, 'users.export', '导出', '{"en-US":"Export"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.215701', '2026-11-13 01:09:46.215704', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000859, 'users.exportFailed', '导出失败', '{"en-US":"Export failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.216791', '2026-11-13 01:09:46.216794', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000860, 'users.importErrorRow', '第 {row} 行 {username}：{message}', '{"en-US":"Row {row}, {username}: {message}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.217933', '2026-11-13 01:09:46.217936', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000861, 'users.importFailed', '导入失败', '{"en-US":"Import failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.219110', '2026-11-13 01:09:46.219112', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000862, 'users.importResult', '导入完成：成功 {succeeded}，失败 {failed}', '{"en-US":"Import completed: {succeeded} succeeded, {failed} failed"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.220407', '2026-11-13 01:09:46.220410', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000863, 'users.imported', '成功导入 {count} 个用户', '{"en-US":"{count} users imported"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.224054', '2026-11-13 01:09:46.224057', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000864, 'users.initialPassword', '初始密码', '{"en-US":"Initial password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.225445', '2026-11-13 01:09:46.225448', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000865, 'users.newPassword', '新密码', '{"en-US":"New password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.226739', '2026-11-13 01:09:46.226744', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000866, 'users.passwordMismatch', '两次输入的密码不一致', '{"en-US":"The passwords do not match"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.228608', '2026-11-13 01:09:46.228618', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000867, 'users.passwordReset', '密码已重置，该用户现有会话已撤销', '{"en-US":"Password reset and the user’s existing sessions revoked"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.230743', '2026-11-13 01:09:46.230750', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000868, 'users.resetPassword', '重置密码', '{"en-US":"Reset password"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.232746', '2026-11-13 01:09:46.232755', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000869, 'users.resetTitle', '重置密码{suffix}', '{"en-US":"Reset password{suffix}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.235164', '2026-11-13 01:09:46.235169', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000870, 'users.searchPlaceholder', '用户名或显示名称', '{"en-US":"Username or display name"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.236754', '2026-11-13 01:09:46.236757', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000871, 'users.selectedDisabled', '所选用户已停用', '{"en-US":"Selected users disabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.241033', '2026-11-13 01:09:46.241037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000872, 'users.selectedEnabled', '所选用户已启用', '{"en-US":"Selected users enabled"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.244626', '2026-11-13 01:09:46.244630', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000873, 'users.status', '状态', '{"en-US":"Status"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.246441', '2026-11-13 01:09:46.246451', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000874, 'users.subtitle', '只管理全局身份；平台权限请到项目管理 → 内置 system 项目分配', '{"en-US":"Manage global identities only. Assign platform permissions in Projects → built-in system project."}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.248533', '2026-11-13 01:09:46.248540', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000875, 'users.title', '用户管理', '{"en-US":"Users"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.250295', '2026-11-13 01:09:46.250299', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000876, 'users.titleSuffix', '：{username}', '{"en-US":": {username}"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.251664', '2026-11-13 01:09:46.251667', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000877, 'users.updated', '用户信息已更新', '{"en-US":"User information updated"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.252987', '2026-11-13 01:09:46.252990', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000878, 'users.user', '用户', '{"en-US":"User"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.254357', '2026-11-13 01:09:46.254360', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000879, 'users.username', '用户名', '{"en-US":"Username"}', 'users', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.257421', '2026-11-13 01:09:46.257424', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000901, 'api.common.badRequest', '请求参数错误', '{"en-US":"Invalid request parameters"}', 'api', 0, 1, 'ENABLED', '未细分的参数校验安全回退', 1, '2026-11-13 01:09:46.258861', '2026-11-13 01:09:46.258865', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000902, 'api.common.notFound', '请求的资源不存在', '{"en-US":"The requested resource was not found"}', 'api', 0, 1, 'ENABLED', '未细分的资源不存在安全回退', 1, '2026-11-13 01:09:46.261264', '2026-11-13 01:09:46.261268', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000903, 'api.common.conflict', '当前操作与资源状态冲突', '{"en-US":"The operation conflicts with the current resource state"}', 'api', 0, 1, 'ENABLED', '未细分的状态冲突安全回退', 1, '2026-11-13 01:09:46.262555', '2026-11-13 01:09:46.262559', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000904, 'api.common.internalError', '服务处理失败，请稍后重试', '{"en-US":"The service could not process the request. Try again later."}', 'api', 0, 1, 'ENABLED', '内部错误安全回退', 1, '2026-11-13 01:09:46.263886', '2026-11-13 01:09:46.263889', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000905, 'api.common.unauthorized', '未登录或登录已过期', '{"en-US":"Sign-in is required or has expired"}', 'api', 0, 1, 'ENABLED', '认证失败安全回退', 1, '2026-11-13 01:09:46.265120', '2026-11-13 01:09:46.265123', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000906, 'api.common.upstreamFailed', '上游服务响应异常', '{"en-US":"An upstream service returned an invalid response"}', 'api', 0, 1, 'ENABLED', '上游错误安全回退', 1, '2026-11-13 01:09:46.266326', '2026-11-13 01:09:46.266330', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000907, 'api.common.serviceUnavailable', '服务暂时不可用，请稍后重试', '{"en-US":"The service is temporarily unavailable. Try again later."}', 'api', 0, 1, 'ENABLED', '服务不可用安全回退', 1, '2026-11-13 01:09:46.267535', '2026-11-13 01:09:46.267538', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000908, 'api.common.forbidden', '无操作权限', '{"en-US":"You do not have permission for this operation"}', 'api', 0, 1, 'ENABLED', '授权失败安全回退', 1, '2026-11-13 01:09:46.268757', '2026-11-13 01:09:46.268760', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000909, 'api.common.operationFailed', '操作失败，请稍后重试', '{"en-US":"The operation failed. Try again later."}', 'api', 0, 1, 'ENABLED', '未知业务错误安全回退', 1, '2026-11-13 01:09:46.270021', '2026-11-13 01:09:46.270024', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000913, 'i18n.localeCoverage', '语言开放状态', '{"en-US":"Language availability"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.271335', '2026-11-13 01:09:46.271338', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000914, 'i18n.available', '可选择', '{"en-US":"Available"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.274407', '2026-11-13 01:09:46.274410', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000915, 'i18n.notConfigured', '目录未开放', '{"en-US":"Not enabled in directory"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.275658', '2026-11-13 01:09:46.275661', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000916, 'i18n.missingResources', '资源 {count}', '{"en-US":"Resources {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.276883', '2026-11-13 01:09:46.276886', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000917, 'i18n.missingMenus', '菜单 {count}', '{"en-US":"Menus {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.278143', '2026-11-13 01:09:46.278146', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000918, 'i18n.missingDictionaries', '字典 {count}', '{"en-US":"Dictionary items {count}"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.279368', '2026-11-13 01:09:46.279371', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000919, 'api.i18n.htmlForbidden', '国际化资源只允许纯文本', '{"en-US":"Internationalization resources must be plain text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.280566', '2026-11-13 01:09:46.280569', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000920, 'api.i18n.jsonInvalid', '多语言译文必须是合法 JSON 对象', '{"en-US":"Translations must be a valid JSON object"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.281912', '2026-11-13 01:09:46.281916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000921, 'api.i18n.keyExists', '国际化资源 key 已存在', '{"en-US":"The internationalization resource key already exists"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.283127', '2026-11-13 01:09:46.283130', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000922, 'api.i18n.keyImmutable', '国际化资源 key 创建后不可修改', '{"en-US":"The internationalization resource key cannot be changed after creation"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.284362', '2026-11-13 01:09:46.284365', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000923, 'api.i18n.localeInvalid', '包含未启用或重复默认语言', '{"en-US":"Translations contain an unavailable locale or duplicate the default locale"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.285605', '2026-11-13 01:09:46.285608', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000924, 'api.i18n.notFound', '国际化资源不存在', '{"en-US":"The internationalization resource was not found"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.286926', '2026-11-13 01:09:46.286928', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000925, 'api.i18n.placeholderMismatch', '译文占位符与默认文案不一致', '{"en-US":"Translation placeholders do not match the default text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.291449', '2026-11-13 01:09:46.291452', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000926, 'api.i18n.publicKeyInvalid', '该资源不允许匿名公开', '{"en-US":"This resource cannot be exposed anonymously"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.292836', '2026-11-13 01:09:46.292840', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000927, 'api.i18n.translationInvalid', '译文必须是非空文本', '{"en-US":"A translation must be non-empty text"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.294167', '2026-11-13 01:09:46.294170', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000928, 'api.i18n.versionConflict', '资源已被其他人修改，请刷新后重试', '{"en-US":"The resource was changed by someone else. Refresh and try again"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.295368', '2026-11-13 01:09:46.295371', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000929, 'api.i18n.versionRequired', '更新资源必须携带版本', '{"en-US":"Updating a resource requires its version"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.296504', '2026-11-13 01:09:46.296507', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000930, 'api.locale.codeInvalid', '语言代码必须是规范 BCP 47 标签', '{"en-US":"The locale must be a canonical BCP 47 language tag"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.297659', '2026-11-13 01:09:46.297662', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000931, 'api.i18n.defaultTextTooLong', '默认文案不能超过 2000 个字符', '{"en-US":"Default text cannot exceed 2000 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.298789', '2026-11-13 01:09:46.298792', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000932, 'api.i18n.descriptionTooLong', '说明不能超过 512 个字符', '{"en-US":"Description cannot exceed 512 characters"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.299992', '2026-11-13 01:09:46.299995', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000933, 'api.i18n.keyInvalid', '资源 key 格式不正确', '{"en-US":"The resource key format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.301294', '2026-11-13 01:09:46.301297', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000934, 'api.i18n.moduleInvalid', '模块代码格式不正确', '{"en-US":"The module code format is invalid"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.302680', '2026-11-13 01:09:46.302683', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000935, 'api.i18n.statusInvalid', '资源状态必须是 ENABLED 或 DISABLED', '{"en-US":"Resource status must be ENABLED or DISABLED"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.304051', '2026-11-13 01:09:46.304054', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000936, 'api.validation.required', '必填项不能为空', '{"en-US":"This field is required"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.307722', '2026-11-13 01:09:46.307725', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000937, 'dicts.localeSelectable', '覆盖完整后允许用户选择', '{"en-US":"Allow users to select after coverage is complete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.309010', '2026-11-13 01:09:46.309013', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000938, 'dicts.localeSelectableTip', '即使开启，也只有在资源、菜单和字典译文全部补齐后才会出现在语言选择器', '{"en-US":"Even when enabled, the language appears only after resource, menu, and dictionary translations are complete"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.310268', '2026-11-13 01:09:46.310271', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000939, 'api.i18n.requiredTranslationMissing', '覆盖必需资源必须为已开放语言 {locales} 提供译文', '{"en-US":"A required resource must provide translations for the available languages: {locales}"}', 'api', 0, 1, 'ENABLED', '阻止管理员用一条缺译资源让整门语言不可选', 1, '2026-11-13 01:09:46.311518', '2026-11-13 01:09:46.311521', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000940, 'api.i18n.defaultLocaleNotTranslatable', '默认语言使用原文，无需导入译文', '{"en-US":"The default language uses the source text and needs no translation import"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.312712', '2026-11-13 01:09:46.312715', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000941, 'api.i18n.exportFailed', '导出译文失败', '{"en-US":"Failed to export translations"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.313816', '2026-11-13 01:09:46.313819', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000942, 'api.i18n.importFileInvalid', '无法解析该 Excel 文件，请确认文件未损坏且大小在 10MB 以内', '{"en-US":"The Excel file could not be parsed. Check that it is not corrupted and is under 10MB."}', 'api', 0, 1, 'ENABLED', '同时用于文件大小超限和解析失败', 1, '2026-11-13 01:09:46.314954', '2026-11-13 01:09:46.314957', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000943, 'api.i18n.importSheetMissing', '文件中没有可识别的工作表，请使用导出的模板填写', '{"en-US":"The file contains no recognizable sheet. Fill in the exported template instead."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.316093', '2026-11-13 01:09:46.316095', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000944, 'api.i18n.importTooManyRows', '单个工作表不能超过 {limit} 行，请拆分后分批导入', '{"en-US":"A single sheet cannot exceed {limit} rows. Split the file and import in batches."}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.317218', '2026-11-13 01:09:46.317220', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000951, 'dicts.localeCodeTip', '使用 BCP 47 标签，例如 zh-CN、en-US、ko-KR', '{"en-US":"Use a BCP 47 tag, for example zh-CN, en-US, or ko-KR"}', 'dicts', 0, 1, 'ENABLED', '语言字典取值输入提示', 1, '2026-11-13 01:09:46.318388', '2026-11-13 01:09:46.318390', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000952, 'dicts.localeCodeInvalid', '语言代码必须是规范 BCP 47 标签，例如 ko-KR', '{"en-US":"The locale code must be a canonical BCP 47 tag, for example ko-KR"}', 'dicts', 0, 1, 'ENABLED', '语言字典取值前端校验提示', 1, '2026-11-13 01:09:46.319735', '2026-11-13 01:09:46.319738', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000961, 'i18n.selectLocale', '选择语言', '{"en-US":"Select a language"}', 'i18n', 0, 1, 'ENABLED', '译文导入导出的目标语言选择', 1, '2026-11-13 01:09:46.321184', '2026-11-13 01:09:46.321188', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000962, 'i18n.exportTranslations', '导出译文', '{"en-US":"Export translations"}', 'i18n', 0, 1, 'ENABLED', '导出待翻译内容', 1, '2026-11-13 01:09:46.324146', '2026-11-13 01:09:46.324149', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000963, 'i18n.importTranslations', '导入译文', '{"en-US":"Import translations"}', 'i18n', 0, 1, 'ENABLED', '导入已翻译内容', 1, '2026-11-13 01:09:46.325375', '2026-11-13 01:09:46.325378', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000000964, 'i18n.importDone', '已导入 {applied} 条译文', '{"en-US":"Imported {applied} translations"}', 'i18n', 0, 1, 'ENABLED', '导入成功提示', 1, '2026-11-13 01:09:46.326589', '2026-11-13 01:09:46.326591', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002101, 'i18nKey.enable', '启用国际化', '{"en-US":"Enable localization"}', 'i18n', 0, 0, 'DISABLED', '引用式国际化开关', 2, '2026-11-13 01:09:46.351584', '2026-11-13 01:09:46.351586', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002102, 'i18nKey.change', '更换资源', '{"en-US":"Change resource"}', 'i18n', 0, 0, 'DISABLED', '更换引用的资源', 2, '2026-11-13 01:09:46.352844', '2026-11-13 01:09:46.352848', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002103, 'i18nKey.pickTitle', '选择国际化资源', '{"en-US":"Select a localization resource"}', 'i18n', 0, 0, 'DISABLED', '资源选择弹窗标题', 2, '2026-11-13 01:09:46.354230', '2026-11-13 01:09:46.354233', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002104, 'i18nKey.key', '资源 key', '{"en-US":"Resource key"}', 'i18n', 0, 0, 'DISABLED', '资源 key 列', 2, '2026-11-13 01:09:46.358186', '2026-11-13 01:09:46.358189', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002105, 'i18nKey.defaultText', '默认文案', '{"en-US":"Default text"}', 'i18n', 0, 0, 'DISABLED', '默认文案列', 2, '2026-11-13 01:09:46.359497', '2026-11-13 01:09:46.359500', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002106, 'i18nKey.module', '模块', '{"en-US":"Module"}', 'i18n', 0, 0, 'DISABLED', '模块列与筛选', 2, '2026-11-13 01:09:46.360793', '2026-11-13 01:09:46.360796', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002107, 'i18nKey.searchPlaceholder', '搜索 key 或文案', '{"en-US":"Search key or text"}', 'i18n', 0, 0, 'DISABLED', '资源搜索占位', 2, '2026-11-13 01:09:46.362037', '2026-11-13 01:09:46.362041', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002108, 'i18nKey.create', '新建资源', '{"en-US":"New resource"}', 'i18n', 0, 0, 'DISABLED', '就地新建资源', 2, '2026-11-13 01:09:46.363427', '2026-11-13 01:09:46.363431', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002109, 'i18nKey.created', '资源已创建', '{"en-US":"Resource created"}', 'i18n', 0, 0, 'DISABLED', '新建成功提示', 2, '2026-11-13 01:09:46.365457', '2026-11-13 01:09:46.365464', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002110, 'i18nKey.cancel', '取消', '{"en-US":"Cancel"}', 'i18n', 0, 0, 'DISABLED', '弹窗取消', 2, '2026-11-13 01:09:46.367002', '2026-11-13 01:09:46.367005', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002111, 'i18nKey.loadFailed', '国际化资源加载失败', '{"en-US":"Failed to load localization resources"}', 'i18n', 0, 0, 'DISABLED', '资源加载失败提示', 2, '2026-11-13 01:09:46.368287', '2026-11-13 01:09:46.368290', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002112, 'configs.i18nKey', '国际化文案', '{"en-US":"Localized text"}', 'configs', 0, 0, 'DISABLED', '配置引用资源字段', 2, '2026-11-13 01:09:46.369486', '2026-11-13 01:09:46.369489', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002113, 'configs.i18nKeyHint', '只对直接展示给用户的文案有效；限额、阈值、开关等参与后端校验的值不要启用。', '{"en-US":"Only for text shown to users. Do not enable it for limits, thresholds or switches validated on the server."}', 'configs', 0, 1, 'ENABLED', '配置国际化适用范围说明', 1, '2026-11-13 01:09:46.370785', '2026-11-13 01:09:46.370788', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002114, 'menus.i18nKey', '国际化文案', '{"en-US":"Localized text"}', 'menus', 0, 0, 'DISABLED', '菜单引用资源字段', 2, '2026-11-13 01:09:46.374699', '2026-11-13 01:09:46.374702', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002115, 'menus.i18nKeyHint', '内置菜单的译文统一在国际化资源里维护，不在这里逐语言填写。', '{"en-US":"Built-in menu translations are maintained in localization resources, not filled in per language here."}', 'menus', 0, 1, 'ENABLED', '菜单国际化说明', 1, '2026-11-13 01:09:46.375993', '2026-11-13 01:09:46.375996', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002200, 'localizedName.modeFixed', '独立填写', '{"en-US":"Enter directly","ja-JP":"直接入力"}', 'i18n', 0, 1, 'ENABLED', '录入模式：固定文案', 3, '2026-11-13 01:09:46.377249', '2026-11-13 01:09:46.377252', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002201, 'localizedName.modeReferenced', '引用国际化资源', '{"en-US":"Reference a localization resource","ja-JP":"国際化リソースを参照"}', 'i18n', 0, 1, 'ENABLED', '录入模式：引用资源', 2, '2026-11-13 01:09:46.378466', '2026-11-13 01:09:46.378469', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002202, 'localizedName.fallbackRequired', '请填写默认文案', '{"en-US":"Please provide the default text","ja-JP":"デフォルトのテキストを入力してください"}', 'i18n', 0, 1, 'ENABLED', '兜底文案必填校验', 2, '2026-11-13 01:09:46.379709', '2026-11-13 01:09:46.379712', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002203, 'localizedName.referenced', '已引用', '{"en-US":"Referenced","ja-JP":"参照中"}', 'i18n', 0, 1, 'ENABLED', '引用状态标签', 2, '2026-11-13 01:09:46.381058', '2026-11-13 01:09:46.381061', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002204, 'localizedName.change', '更换资源', '{"en-US":"Change resource","ja-JP":"リソースを変更"}', 'i18n', 0, 1, 'ENABLED', '更换引用的资源', 2, '2026-11-13 01:09:46.382204', '2026-11-13 01:09:46.382207', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002205, 'localizedName.pickResource', '选择资源', '{"en-US":"Select a resource","ja-JP":"リソースを選択"}', 'i18n', 0, 1, 'ENABLED', '空态：打开选择器', 2, '2026-11-13 01:09:46.383307', '2026-11-13 01:09:46.383309', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002206, 'localizedName.createResource', '新建资源', '{"en-US":"New resource","ja-JP":"リソースを作成"}', 'i18n', 0, 1, 'ENABLED', '就地新建资源', 2, '2026-11-13 01:09:46.384480', '2026-11-13 01:09:46.384482', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002207, 'localizedName.pickTitle', '选择国际化资源', '{"en-US":"Select a localization resource","ja-JP":"国際化リソースを選択"}', 'i18n', 0, 1, 'ENABLED', '资源选择弹窗标题', 2, '2026-11-13 01:09:46.385653', '2026-11-13 01:09:46.385656', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002208, 'localizedName.pickKey', '资源 key', '{"en-US":"Resource key","ja-JP":"リソースキー"}', 'i18n', 0, 1, 'ENABLED', '资源 key 列', 2, '2026-11-13 01:09:46.386912', '2026-11-13 01:09:46.386916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002209, 'localizedName.pickDefault', '默认文案', '{"en-US":"Default text","ja-JP":"デフォルトのテキスト"}', 'i18n', 0, 1, 'ENABLED', '默认文案列', 2, '2026-11-13 01:09:46.390639', '2026-11-13 01:09:46.390642', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002210, 'localizedName.pickModule', '模块', '{"en-US":"Module","ja-JP":"モジュール"}', 'i18n', 0, 1, 'ENABLED', '模块列与筛选', 2, '2026-11-13 01:09:46.391903', '2026-11-13 01:09:46.391906', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002211, 'localizedName.pickSearchPlaceholder', '搜索 key 或文案', '{"en-US":"Search key or text","ja-JP":"キーまたはテキストを検索"}', 'i18n', 0, 1, 'ENABLED', '资源搜索占位', 2, '2026-11-13 01:09:46.393195', '2026-11-13 01:09:46.393198', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002212, 'localizedName.cancel', '取消', '{"en-US":"Cancel","ja-JP":"キャンセル"}', 'i18n', 0, 1, 'ENABLED', '弹窗取消', 2, '2026-11-13 01:09:46.394478', '2026-11-13 01:09:46.394481', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002213, 'localizedName.defaultPreview', '默认显示', '{"en-US":"Default","ja-JP":"既定"}', 'i18n', 0, 1, 'ENABLED', '默认文案预览标签', 2, '2026-11-13 01:09:46.395711', '2026-11-13 01:09:46.395714', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002214, 'localizedName.translationsPreview', '其他语言', '{"en-US":"Other languages","ja-JP":"他の言語"}', 'i18n', 0, 1, 'ENABLED', '其他语言译文预览标签', 2, '2026-11-13 01:09:46.397086', '2026-11-13 01:09:46.397089', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002215, 'localizedName.loadFailed', '国际化资源加载失败', '{"en-US":"Failed to load localization resources","ja-JP":"国際化リソースの読み込みに失敗しました"}', 'i18n', 0, 1, 'ENABLED', '资源加载失败提示', 2, '2026-11-13 01:09:46.398388', '2026-11-13 01:09:46.398391', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002216, 'localizedName.createDone', '资源已创建', '{"en-US":"Resource created","ja-JP":"リソースを作成しました"}', 'i18n', 0, 1, 'ENABLED', '新建成功提示', 2, '2026-11-13 01:09:46.399727', '2026-11-13 01:09:46.399730', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002217, 'localizedName.createFailed', '资源创建失败', '{"en-US":"Failed to create resource","ja-JP":"リソースの作成に失敗しました"}', 'i18n', 0, 1, 'ENABLED', '新建失败提示', 2, '2026-11-13 01:09:46.401132', '2026-11-13 01:09:46.401136', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002218, 'localizedName.createKeyPlaceholder', '例如：module.subject.usage', '{"en-US":"e.g. module.subject.usage","ja-JP":"例：module.subject.usage"}', 'i18n', 0, 1, 'ENABLED', '新建资源 key 输入占位', 2, '2026-11-13 01:09:46.402738', '2026-11-13 01:09:46.402740', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002300, 'dict.common.tag_color.success', '成功（绿）', '{"en-US":"Success (green)","ja-JP":"成功（緑）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.404009', '2026-11-13 01:09:46.404012', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002301, 'dict.common.tag_color.processing', '处理中（蓝）', '{"en-US":"Processing (blue)","ja-JP":"処理中（青）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.407603', '2026-11-13 01:09:46.407605', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002302, 'dict.common.tag_color.warning', '警告（橙）', '{"en-US":"Warning (orange)","ja-JP":"警告（オレンジ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.408851', '2026-11-13 01:09:46.408854', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002303, 'dict.common.tag_color.error', '失败（红）', '{"en-US":"Error (red)","ja-JP":"エラー（赤）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.410036', '2026-11-13 01:09:46.410038', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002304, 'dict.common.tag_color.default', '默认（灰）', '{"en-US":"Default (grey)","ja-JP":"デフォルト（グレー）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.411303', '2026-11-13 01:09:46.411305', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002305, 'dict.common.tag_color.purple', '紫（类别）', '{"en-US":"Purple (category)","ja-JP":"パープル（カテゴリ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.412433', '2026-11-13 01:09:46.412436', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002306, 'dict.common.tag_color.cyan', '青（类别）', '{"en-US":"Cyan (category)","ja-JP":"シアン（カテゴリ）"}', 'dict', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.413622', '2026-11-13 01:09:46.413625', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002310, 'dicts.extraKey', '键', '{"en-US":"Key","ja-JP":"キー"}', 'dicts', 0, 1, 'ENABLED', '扩展配置键输入占位', 2, '2026-11-13 01:09:46.414818', '2026-11-13 01:09:46.414821', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002311, 'dicts.extraValue', '值', '{"en-US":"Value","ja-JP":"値"}', 'dicts', 0, 1, 'ENABLED', '扩展配置值输入占位', 2, '2026-11-13 01:09:46.415949', '2026-11-13 01:09:46.415952', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000002312, 'dicts.extraAdd', '添加一项', '{"en-US":"Add entry","ja-JP":"項目を追加"}', 'dicts', 0, 1, 'ENABLED', '扩展配置新增按钮', 2, '2026-11-13 01:09:46.417099', '2026-11-13 01:09:46.417102', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000003001, 'dict.platform.locale.zh-CN', '简体中文', '{"en-US":"Simplified Chinese"}', 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, '2026-11-13 01:09:46.418302', '2026-11-13 01:09:46.418304', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000003002, 'dict.platform.locale.en-US', '英语（美国）', '{"en-US":"English (US)"}', 'dict', 0, 0, 'ENABLED', '字典项标签，由 ADR 0015 从 label_i18n 迁移', 1, '2026-11-13 01:09:46.419525', '2026-11-13 01:09:46.419528', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000003101, 'api.i18n.keyNotFound', '国际化资源不存在：{key}', '{"en-US":"The internationalization resource does not exist: {key}","ja-JP":"国際化リソースが存在しません：{key}"}', 'api', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.420763', '2026-11-13 01:09:46.420766', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102900, 'dictType.ai.test.status', '大模型连通测试状态', '{"en-US":"AI connectivity test status","ja-JP":"AI 接続テスト状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：ai.test.status', 1, '2026-11-13 01:09:46.424054', '2026-11-13 01:09:46.424056', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102901, 'dictType.common.boolean_enabled', '是否启用', '{"en-US":"Enabled option","ja-JP":"有効化するか"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.boolean_enabled', 1, '2026-11-13 01:09:46.425276', '2026-11-13 01:09:46.425279', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102902, 'dictType.common.status', '通用启停状态', '{"en-US":"General enablement status","ja-JP":"共通有効・無効状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.status', 1, '2026-11-13 01:09:46.426571', '2026-11-13 01:09:46.426574', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102903, 'dictType.common.tag_color', '标签颜色', '{"en-US":"Tag color","ja-JP":"タグの色"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：common.tag_color', 1, '2026-11-13 01:09:46.427873', '2026-11-13 01:09:46.427876', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102904, 'dictType.config.value.type', '配置值类型', '{"en-US":"Configuration value type","ja-JP":"設定値の種類"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：config.value.type', 1, '2026-11-13 01:09:46.429000', '2026-11-13 01:09:46.429003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102906, 'dictType.notification.type', '站内信分类', '{"en-US":"Notification type","ja-JP":"通知の種類"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：notification.type', 1, '2026-11-13 01:09:46.431341', '2026-11-13 01:09:46.431344', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102907, 'dictType.platform.locale', '平台语言', '{"en-US":"Platform language","ja-JP":"プラットフォーム言語"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.locale', 1, '2026-11-13 01:09:46.432482', '2026-11-13 01:09:46.432484', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102908, 'dictType.platform.menu.type', '平台菜单类型', '{"en-US":"Platform menu type","ja-JP":"プラットフォームメニュー種別"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：platform.menu.type', 1, '2026-11-13 01:09:46.433666', '2026-11-13 01:09:46.433669', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102909, 'dictType.project.generation.mode', '项目生成方式', '{"en-US":"Project generation mode","ja-JP":"プロジェクト生成方式"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.mode', 1, '2026-11-13 01:09:46.434872', '2026-11-13 01:09:46.434875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102910, 'dictType.project.generation.status', '项目生成状态', '{"en-US":"Project generation status","ja-JP":"プロジェクト生成状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.generation.status', 1, '2026-11-13 01:09:46.436086', '2026-11-13 01:09:46.436089', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102912, 'dictType.project.member.status', '项目成员状态', '{"en-US":"Project member status","ja-JP":"プロジェクトメンバー状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.member.status', 1, '2026-11-13 01:09:46.441643', '2026-11-13 01:09:46.441646', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102914, 'dictType.project.status', '业务项目状态', '{"en-US":"Business project status","ja-JP":"業務プロジェクト状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：project.status', 1, '2026-11-13 01:09:46.444216', '2026-11-13 01:09:46.444218', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102915, 'dictType.scheduler.execution.status', '定时任务执行状态', '{"en-US":"Scheduled task execution status","ja-JP":"定期タスク実行状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：scheduler.execution.status', 1, '2026-11-13 01:09:46.445384', '2026-11-13 01:09:46.445387', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102916, 'dictType.security.login.status', '登录日志状态', '{"en-US":"Sign-in log status","ja-JP":"ログイン履歴状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.login.status', 1, '2026-11-13 01:09:46.446481', '2026-11-13 01:09:46.446484', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102917, 'dictType.security.session.status', '在线会话状态', '{"en-US":"Online session status","ja-JP":"オンラインセッション状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.session.status', 1, '2026-11-13 01:09:46.447682', '2026-11-13 01:09:46.447685', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102918, 'dictType.user.status', '平台用户状态', '{"en-US":"Platform user status","ja-JP":"プラットフォームユーザー状態"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：user.status', 1, '2026-11-13 01:09:46.448947', '2026-11-13 01:09:46.448950', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102921, 'menu.system.permission.system.platform.read', '验证平台访问', '{"en-US":"Validate platform access","ja-JP":"プラットフォームアクセスを検証"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:platform:read', 1, '2026-11-13 01:09:46.450124', '2026-11-13 01:09:46.450126', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102922, 'menu.system.permission.system.user.list', '查询用户', '{"en-US":"View users","ja-JP":"ユーザーを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:list', 1, '2026-11-13 01:09:46.451264', '2026-11-13 01:09:46.451267', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102923, 'menu.system.permission.system.user.create', '创建用户', '{"en-US":"Create user","ja-JP":"ユーザーを作成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:create', 1, '2026-11-13 01:09:46.452447', '2026-11-13 01:09:46.452449', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102924, 'menu.system.permission.system.user.update', '编辑用户', '{"en-US":"Edit user","ja-JP":"ユーザーを編集"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:update', 1, '2026-11-13 01:09:46.453636', '2026-11-13 01:09:46.453639', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102925, 'menu.system.permission.system.user.status', '启停用户', '{"en-US":"Enable or disable user","ja-JP":"ユーザーを有効または無効にする"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:status', 1, '2026-11-13 01:09:46.455178', '2026-11-13 01:09:46.455181', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102926, 'menu.system.permission.system.user.reset-password', '重置密码', '{"en-US":"Reset password","ja-JP":"パスワードをリセット"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:user:reset-password', 1, '2026-11-13 01:09:46.456701', '2026-11-13 01:09:46.456704', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102927, 'menu.system.permission.system.project.list', '查询项目', '{"en-US":"View projects","ja-JP":"プロジェクトを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:list', 1, '2026-11-13 01:09:46.457918', '2026-11-13 01:09:46.457921', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102928, 'menu.system.permission.system.project.create', '创建项目', '{"en-US":"Create project","ja-JP":"プロジェクトを作成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:create', 1, '2026-11-13 01:09:46.459131', '2026-11-13 01:09:46.459134', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102929, 'menu.system.permission.system.project.update', '编辑项目', '{"en-US":"Edit project","ja-JP":"プロジェクトを編集"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:update', 1, '2026-11-13 01:09:46.460484', '2026-11-13 01:09:46.460487', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102930, 'menu.system.permission.system.project.status', '变更项目状态', '{"en-US":"Change project status","ja-JP":"プロジェクト状態を変更"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:status', 1, '2026-11-13 01:09:46.461802', '2026-11-13 01:09:46.461806', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102931, 'menu.system.permission.system.project.member', '管理项目成员', '{"en-US":"Manage project members","ja-JP":"プロジェクトメンバーを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:member', 1, '2026-11-13 01:09:46.463034', '2026-11-13 01:09:46.463037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102932, 'menu.system.permission.system.project.role', '管理项目角色', '{"en-US":"Manage project roles","ja-JP":"プロジェクトロールを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:role', 1, '2026-11-13 01:09:46.464265', '2026-11-13 01:09:46.464268', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102933, 'menu.system.permission.system.project.menu', '管理项目菜单', '{"en-US":"Manage project menus","ja-JP":"プロジェクトメニューを管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:menu', 1, '2026-11-13 01:09:46.465507', '2026-11-13 01:09:46.465510', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102934, 'menu.system.permission.system.config.list', '查询配置', '{"en-US":"View configurations","ja-JP":"設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:list', 1, '2026-11-13 01:09:46.466865', '2026-11-13 01:09:46.466869', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102935, 'menu.system.permission.system.config.save', '保存配置', '{"en-US":"Save configuration","ja-JP":"設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:save', 1, '2026-11-13 01:09:46.468081', '2026-11-13 01:09:46.468084', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102936, 'menu.system.permission.system.config.delete', '删除配置', '{"en-US":"Delete configuration","ja-JP":"設定を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:config:delete', 1, '2026-11-13 01:09:46.469399', '2026-11-13 01:09:46.469402', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102937, 'menu.system.permission.system.dict.list', '查询字典', '{"en-US":"View dictionaries","ja-JP":"辞書を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:list', 1, '2026-11-13 01:09:46.470661', '2026-11-13 01:09:46.470663', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102938, 'menu.system.permission.system.dict.save', '保存字典', '{"en-US":"Save dictionary","ja-JP":"辞書を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:save', 1, '2026-11-13 01:09:46.473894', '2026-11-13 01:09:46.473897', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102939, 'menu.system.permission.system.dict.delete', '删除字典', '{"en-US":"Delete dictionary","ja-JP":"辞書を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:dict:delete', 1, '2026-11-13 01:09:46.475102', '2026-11-13 01:09:46.475104', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102940, 'menu.system.permission.system.project-factory.list', '查看项目生成', '{"en-US":"View project generations","ja-JP":"プロジェクト生成を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:list', 1, '2026-11-13 01:09:46.476303', '2026-11-13 01:09:46.476306', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102941, 'menu.system.permission.system.project-factory.generate', '生成项目', '{"en-US":"Generate project","ja-JP":"プロジェクトを生成"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:generate', 1, '2026-11-13 01:09:46.477541', '2026-11-13 01:09:46.477544', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102942, 'menu.system.permission.system.project-factory.download', '下载项目制品', '{"en-US":"Download project artifact","ja-JP":"プロジェクト成果物をダウンロード"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:download', 1, '2026-11-13 01:09:46.478800', '2026-11-13 01:09:46.478803', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102943, 'menu.system.permission.system.project-factory.push', '初始推送 GitLab', '{"en-US":"Initial GitLab push","ja-JP":"GitLab へ初回プッシュ"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project-factory:push', 1, '2026-11-13 01:09:46.480053', '2026-11-13 01:09:46.480056', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102944, 'menu.system.permission.system.ai.list', '查看大模型配置', '{"en-US":"View AI provider configuration","ja-JP":"AI プロバイダー設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:list', 1, '2026-11-13 01:09:46.481273', '2026-11-13 01:09:46.481275', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102945, 'menu.system.permission.system.ai.save', '保存大模型配置', '{"en-US":"Save AI provider configuration","ja-JP":"AI プロバイダー設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:save', 1, '2026-11-13 01:09:46.482565', '2026-11-13 01:09:46.482568', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102946, 'menu.system.permission.system.ai.test', '测试大模型连接', '{"en-US":"Test AI provider connection","ja-JP":"AI プロバイダー接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:ai:test', 1, '2026-11-13 01:09:46.483832', '2026-11-13 01:09:46.483835', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102947, 'menu.system.permission.system.git.list', '查看 GitLab 配置', '{"en-US":"View GitLab configuration","ja-JP":"GitLab 設定を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:list', 1, '2026-11-13 01:09:46.485008', '2026-11-13 01:09:46.485010', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102948, 'menu.system.permission.system.git.save', '保存 GitLab 配置', '{"en-US":"Save GitLab configuration","ja-JP":"GitLab 設定を保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:save', 1, '2026-11-13 01:09:46.486278', '2026-11-13 01:09:46.486281', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102949, 'menu.system.permission.system.git.test', '测试 GitLab 连接', '{"en-US":"Test GitLab connection","ja-JP":"GitLab 接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:git:test', 1, '2026-11-13 01:09:46.487672', '2026-11-13 01:09:46.487675', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102950, 'menu.system.permission.system.scheduler.list', '查看定时任务', '{"en-US":"View scheduled tasks","ja-JP":"定期タスクを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:list', 1, '2026-11-13 01:09:46.489429', '2026-11-13 01:09:46.489431', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102951, 'menu.system.permission.system.scheduler.save', '保存定时任务', '{"en-US":"Save scheduled task","ja-JP":"定期タスクを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:save', 1, '2026-11-13 01:09:46.490660', '2026-11-13 01:09:46.490662', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102952, 'menu.system.permission.system.scheduler.credential', '轮换项目调度凭据', '{"en-US":"Rotate project scheduler credential","ja-JP":"プロジェクトスケジューラー認証情報をローテーション"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:scheduler:credential', 1, '2026-11-13 01:09:46.491906', '2026-11-13 01:09:46.491909', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102953, 'menu.system.permission.system.audit.list', '查看审计日志', '{"en-US":"View audit logs","ja-JP":"監査ログを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:audit:list', 1, '2026-11-13 01:09:46.493112', '2026-11-13 01:09:46.493115', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102954, 'menu.system.permission.system.session.list', '查看在线会话', '{"en-US":"View online sessions","ja-JP":"オンラインセッションを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:session:list', 1, '2026-11-13 01:09:46.494287', '2026-11-13 01:09:46.494289', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102955, 'menu.system.permission.system.session.force-offline', '强制用户下线', '{"en-US":"Force user sign-out","ja-JP":"ユーザーを強制ログアウト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:session:force-offline', 1, '2026-11-13 01:09:46.495424', '2026-11-13 01:09:46.495426', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102956, 'menu.system.permission.system.org.list', '查看组织架构', '{"en-US":"View organization","ja-JP":"組織を表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:list', 1, '2026-11-13 01:09:46.496592', '2026-11-13 01:09:46.496595', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102957, 'menu.system.permission.system.org.save', '维护部门', '{"en-US":"Maintain department","ja-JP":"部門を管理"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:save', 1, '2026-11-13 01:09:46.497778', '2026-11-13 01:09:46.497781', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102958, 'menu.system.permission.system.org.delete', '删除部门', '{"en-US":"Delete department","ja-JP":"部門を削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:delete', 1, '2026-11-13 01:09:46.499097', '2026-11-13 01:09:46.499100', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102959, 'menu.system.permission.system.org.assign', '分配用户部门', '{"en-US":"Assign users to department","ja-JP":"ユーザーを部門に割り当て"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:org:assign', 1, '2026-11-13 01:09:46.500436', '2026-11-13 01:09:46.500439', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102960, 'menu.system.permission.system.i18n.list', '查询国际化资源', '{"en-US":"View internationalization resources","ja-JP":"国際化リソースを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:list', 1, '2026-11-13 01:09:46.501765', '2026-11-13 01:09:46.501768', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102961, 'menu.system.permission.system.i18n.save', '保存国际化资源', '{"en-US":"Save internationalization resources","ja-JP":"国際化リソースを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:save', 1, '2026-11-13 01:09:46.503184', '2026-11-13 01:09:46.503187', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102962, 'menu.system.permission.system.i18n.delete', '删除国际化资源', '{"en-US":"Delete internationalization resources","ja-JP":"国際化リソースを削除"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:i18n:delete', 1, '2026-11-13 01:09:46.504542', '2026-11-13 01:09:46.504546', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000102963, 'menu.system.permission.system.project.health', '项目体检', '{"en-US":"Project health check","ja-JP":"プロジェクト健全性チェック"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:project:health', 1, '2026-11-13 01:09:46.507750', '2026-11-13 01:09:46.507754', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103000, 'dictType.security.audit.module', '审计模块', '{"en-US":"Audit module","ja-JP":"監査モジュール"}', 'dict', 0, 1, 'ENABLED', '内置字典类型名称：security.audit.module', 1, '2026-11-13 01:09:46.509042', '2026-11-13 01:09:46.509045', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103001, 'dict.security.audit.module.user', '用户管理', '{"en-US":"Users","ja-JP":"ユーザー管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.510390', '2026-11-13 01:09:46.510393', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103002, 'dict.security.audit.module.role', '角色管理', '{"en-US":"Roles","ja-JP":"ロール管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.511692', '2026-11-13 01:09:46.511695', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103003, 'dict.security.audit.module.menu', '菜单管理', '{"en-US":"Menus","ja-JP":"メニュー管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.512860', '2026-11-13 01:09:46.512862', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103004, 'dict.security.audit.module.org', '组织架构', '{"en-US":"Organization","ja-JP":"組織構成"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.513969', '2026-11-13 01:09:46.513972', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103005, 'dict.security.audit.module.metadata', '配置与字典', '{"en-US":"Configuration and dictionaries","ja-JP":"設定と辞書"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.515257', '2026-11-13 01:09:46.515260', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103006, 'dict.security.audit.module.i18n', '国际化资源', '{"en-US":"Localization resources","ja-JP":"多言語リソース"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.516459', '2026-11-13 01:09:46.516462', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103007, 'dict.security.audit.module.project', '项目管理', '{"en-US":"Projects","ja-JP":"プロジェクト管理"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.517673', '2026-11-13 01:09:46.517676', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103008, 'dict.security.audit.module.project-factory', '项目工厂', '{"en-US":"Project factory","ja-JP":"プロジェクトファクトリ"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.518857', '2026-11-13 01:09:46.518860', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103009, 'dict.security.audit.module.scheduler', '定时任务', '{"en-US":"Scheduled tasks","ja-JP":"定期タスク"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.520115', '2026-11-13 01:09:46.520118', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103010, 'dict.security.audit.module.gitlab', 'GitLab 配置', '{"en-US":"GitLab configuration","ja-JP":"GitLab 設定"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.522708', '2026-11-13 01:09:46.522710', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103011, 'dict.security.audit.module.ai', '大模型配置', '{"en-US":"AI provider configuration","ja-JP":"AI プロバイダー設定"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.524030', '2026-11-13 01:09:46.524032', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9100000000000103012, 'dict.security.audit.module.security', '安全运营', '{"en-US":"Security operations","ja-JP":"セキュリティ運用"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.525268', '2026-11-13 01:09:46.525270', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000000001, 'dicts.dragSort', '拖动调整顺序', '{"en-US":"Drag to reorder","ja-JP":"ドラッグして並べ替え"}', 'dicts', 0, 1, 'ENABLED', '字典管理拖拽手柄的提示', 1, '2026-11-13 01:09:46.526491', '2026-11-13 01:09:46.526493', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000000002, 'dicts.sortSaved', '顺序已保存', '{"en-US":"Order saved","ja-JP":"並び順を保存しました"}', 'dicts', 0, 1, 'ENABLED', '字典管理拖拽排序成功提示', 1, '2026-11-13 01:09:46.527733', '2026-11-13 01:09:46.527735', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004001, 'projects.serviceUrl', '服务地址', '{"en-US":"Service URL","ja-JP":"サービス URL"}', 'projects', 0, 1, 'ENABLED', 'Gateway PROJECT 路由上游', 1, '2026-11-13 01:09:46.546068', '2026-11-13 01:09:46.546070', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004002, 'projects.serviceUrlHelp', '按部署形态填写：K8s/Compose 用服务名，单实例用 http://主机:端口，Nacos 用 lb://服务名', '{"en-US":"Depends on deployment: service DNS for K8s/Compose, http://host:port for a single instance, lb://name for Nacos","ja-JP":"デプロイ形態に応じて入力してください"}', 'projects', 0, 1, 'ENABLED', '服务地址填写说明', 1, '2026-11-13 01:09:46.547250', '2026-11-13 01:09:46.547252', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004003, 'api.project.serviceUrlRequired', '请先登记项目的服务地址', '{"en-US":"Register the project service URL first","ja-JP":"先にサービス URL を登録してください"}', 'api', 0, 1, 'ENABLED', '生成 Gateway 路由前置校验', 1, '2026-11-13 01:09:46.548408', '2026-11-13 01:09:46.548410', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004010, 'projects.gatewayRoute', '网关路由', '{"en-US":"Gateway route","ja-JP":"ゲートウェイルート"}', 'projects', 0, 1, 'ENABLED', '查看该项目的显式路由片段', 1, '2026-11-13 01:09:46.549589', '2026-11-13 01:09:46.549592', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004011, 'projects.gatewayRoute.hint', '把下面的片段放进受管 Gateway 配置的 routes 下。服务注册不等于对外发布，没有这段显式路由的服务不能从外部访问。', '{"en-US":"Add the snippet below to the routes of the managed Gateway config. Registering a service does not publish it; without an explicit route it stays unreachable from outside.","ja-JP":"以下の断片を管理対象 Gateway 設定の routes に追加してください。"}', 'projects', 0, 1, 'ENABLED', '路由片段说明', 1, '2026-11-13 01:09:46.550733', '2026-11-13 01:09:46.550735', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004012, 'projects.gatewayRoute.copy', '复制片段', '{"en-US":"Copy snippet","ja-JP":"断片をコピー"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.551889', '2026-11-13 01:09:46.551892', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004013, 'projects.gatewayRoute.copied', '已复制到剪贴板', '{"en-US":"Copied to clipboard","ja-JP":"クリップボードにコピーしました"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.553105', '2026-11-13 01:09:46.553108', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004014, 'projects.gatewayRoute.copyFailed', '复制失败，请手动选中复制', '{"en-US":"Copy failed, please select and copy manually","ja-JP":"コピーに失敗しました"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.554414', '2026-11-13 01:09:46.554416', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004020, 'layout.project.openMode.inline', '当前页面', '{"en-US":"Current page"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.562444', '2026-11-13 01:09:46.562448', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004021, 'layout.project.openMode.newTab', '新标签页', '{"en-US":"New tab"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.563642', '2026-11-13 01:09:46.563645', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004022, 'layout.project.loadingEntry', '正在进入项目后台…', '{"en-US":"Opening the project console…"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.564839', '2026-11-13 01:09:46.564842', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004023, 'layout.project.entryUnavailable', '该项目暂无可用的后台入口', '{"en-US":"This project has no console entry yet"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.565955', '2026-11-13 01:09:46.565958', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004024, 'layout.project.backToPlatform', '返回 Kaiwu 平台', '{"en-US":"Back to the Kaiwu platform"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.567141', '2026-11-13 01:09:46.567144', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004030, 'menu.system.permission.system.agent.ask', 'AI 助手', '{"en-US":"AI assistant"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.568401', '2026-11-13 01:09:46.568404', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004031, 'agent.dock.title', 'AI 助手', '{"en-US":"AI assistant"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.569798', '2026-11-13 01:09:46.569801', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004032, 'agent.dock.placeholder', '问点什么，例如：我参与的项目这周有哪些生成失败', '{"en-US":"Ask something, e.g. which generation tasks failed this week"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.571329', '2026-11-13 01:09:46.571332', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004033, 'agent.dock.send', '发送', '{"en-US":"Send"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.574244', '2026-11-13 01:09:46.574247', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004034, 'agent.dock.thinking', '正在查询…', '{"en-US":"Working on it…"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.575550', '2026-11-13 01:09:46.575553', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004035, 'agent.dock.empty', '可以问我平台上的项目、生成任务和定时任务。', '{"en-US":"Ask me about projects, generation tasks and scheduled jobs."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.576794', '2026-11-13 01:09:46.576797', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004036, 'agent.dock.dataAt', '数据时间', '{"en-US":"Data as of"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.578095', '2026-11-13 01:09:46.578098', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004037, 'agent.degraded.PROVIDER_UNAVAILABLE', 'AI 助手当前不可用，请联系管理员配置大模型 Provider。', '{"en-US":"The AI assistant is unavailable. Ask an administrator to configure a model provider."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.579300', '2026-11-13 01:09:46.579303', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004038, 'agent.degraded.RATE_LIMITED', '请求过于频繁，请稍后再试。', '{"en-US":"Too many requests. Please try again shortly."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.580517', '2026-11-13 01:09:46.580520', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004039, 'agent.degraded.PLAN_INVALID', '没能理解这个问题，换个说法试试。', '{"en-US":"I could not work out what to query. Try rephrasing."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.581713', '2026-11-13 01:09:46.581715', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004040, 'agent.degraded.PARTIAL_CAPABILITY_FAILURE', '部分数据暂时取不到，以下是已取到的结果。', '{"en-US":"Some data could not be retrieved. Here is what came back."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.582846', '2026-11-13 01:09:46.582849', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004100, 'agent.registry.entry', 'Agent 能力', '{"en-US":"Agent capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.584008', '2026-11-13 01:09:46.584011', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004101, 'agent.registry.title', 'Agent 能力：{name}', '{"en-US":"Agent capabilities: {name}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.585151', '2026-11-13 01:09:46.585153', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004102, 'agent.registry.intro', '仅目标项目管理员可管理能力。先签发独立凭据并配置到业务服务，再核对清单、逐版审批。', '{"en-US":"Only target project administrators can manage capabilities. Issue a credential, configure the service, then review each manifest version."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.586332', '2026-11-13 01:09:46.586335', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004103, 'agent.registry.boundary', '能力需逐版审批；聊天执行还受在线状态、项目权限和部署开关控制。', '{"en-US":"Review each capability version. Chat execution also requires an online handler, project permission, and deployment switches."}', 'agent', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.587744', '2026-11-13 01:09:46.587747', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004104, 'agent.registry.empty', '尚无能力注册。业务服务启用 Agent 客户端并声明能力后会出现在这里。', '{"en-US":"No capabilities registered. Enable the Agent client and declare capabilities in the business service."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.589170', '2026-11-13 01:09:46.589173', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004105, 'agent.registry.refresh', '刷新状态', '{"en-US":"Refresh"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.590749', '2026-11-13 01:09:46.590751', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004106, 'agent.registry.issue', '签发 / 轮换凭据', '{"en-US":"Issue / rotate credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.591941', '2026-11-13 01:09:46.591944', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004107, 'agent.registry.rotateConfirm', '轮换后旧凭据立即失效，已批准能力需要重新注册和审批。继续？', '{"en-US":"Rotation invalidates the previous credential and resets approvals. Continue?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.593105', '2026-11-13 01:09:46.593108', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004108, 'agent.registry.revokeCredential', '撤销注册凭据', '{"en-US":"Revoke credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.594264', '2026-11-13 01:09:46.594267', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004109, 'agent.registry.revokeCredentialConfirm', '撤销凭据及该项目所有能力？业务服务将停止注册。', '{"en-US":"Revoke the credential and all project capabilities? The service will stop registering."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.595463', '2026-11-13 01:09:46.595465', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004110, 'agent.registry.credentialTitle', '保存注册凭据', '{"en-US":"Save registration credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.596626', '2026-11-13 01:09:46.596629', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004111, 'agent.registry.credentialHint', '凭据只在本次响应提供。请保存到业务服务的秘密配置中，关闭后无法再次查看；轮换后需更新配置并重启客户端。', '{"en-US":"This credential is returned once. Save it in service secret configuration. After rotation, update configuration and restart the client."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.597828', '2026-11-13 01:09:46.597831', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004112, 'agent.registry.credentialLabel', 'Agent 注册凭据', '{"en-US":"Agent registration credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.598966', '2026-11-13 01:09:46.598969', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004113, 'agent.registry.copy', '复制凭据', '{"en-US":"Copy credential"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.600157', '2026-11-13 01:09:46.600161', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004114, 'agent.registry.copied', '凭据已复制', '{"en-US":"Credential copied"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.601336', '2026-11-13 01:09:46.601338', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004115, 'agent.registry.close', '关闭', '{"en-US":"Close"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.602548', '2026-11-13 01:09:46.602550', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004116, 'agent.registry.code', '能力编码', '{"en-US":"Capability code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.603882', '2026-11-13 01:09:46.603885', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004117, 'agent.registry.version', '版本', '{"en-US":"Version"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.606048', '2026-11-13 01:09:46.606050', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004118, 'agent.registry.status', '审批状态', '{"en-US":"Review status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.607472', '2026-11-13 01:09:46.607475', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004119, 'agent.registry.online', '连接状态', '{"en-US":"Connection"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.608709', '2026-11-13 01:09:46.608712', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004120, 'agent.registry.lastSeen', '最近心跳', '{"en-US":"Last heartbeat"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.609841', '2026-11-13 01:09:46.609844', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004121, 'agent.registry.actions', '操作', '{"en-US":"Actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.611053', '2026-11-13 01:09:46.611056', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004122, 'agent.registry.detail', '查看清单 / 审核', '{"en-US":"View / review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.612282', '2026-11-13 01:09:46.612285', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004123, 'agent.registry.manifest', '完整能力清单', '{"en-US":"Full capability manifest"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.613533', '2026-11-13 01:09:46.613535', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004124, 'agent.registry.hash', '清单摘要', '{"en-US":"Manifest digest"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.614741', '2026-11-13 01:09:46.614744', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004125, 'agent.registry.approve', '批准只读能力', '{"en-US":"Approve read-only capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.615912', '2026-11-13 01:09:46.615914', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004126, 'agent.registry.approveConfirm', '已核对权限、参数和输出字段，并确认该实现只读取数据？', '{"en-US":"Have you checked permissions, parameters and output fields, and confirmed the implementation is read-only?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.617009', '2026-11-13 01:09:46.617012', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004127, 'agent.registry.revoke', '撤销能力', '{"en-US":"Revoke capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.618222', '2026-11-13 01:09:46.618225', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004128, 'agent.registry.revokeConfirm', '撤销这一版能力？客户端需停止，重新开放后还需重新审批。', '{"en-US":"Revoke this capability version? Restart the client after reopening and review again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.619525', '2026-11-13 01:09:46.619528', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004129, 'agent.registry.reopen', '重新开放待审核', '{"en-US":"Reopen for review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.620854', '2026-11-13 01:09:46.620857', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004130, 'agent.registry.reopenConfirm', '恢复为待审核？请重启客户端刷新心跳，再重新核对清单。', '{"en-US":"Restore pending review? Restart the client to refresh heartbeat, then review the manifest again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.622357', '2026-11-13 01:09:46.622360', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004131, 'agent.registry.approvalHint', '只有在线的待审核清单可以批准。操作绑定当前展示的版本及摘要，变更后请刷新重审。', '{"en-US":"Only online, pending manifests can be approved. Approval binds to the displayed version and digest; refresh and review again after a change."}', 'agent', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:46.623806', '2026-11-13 01:09:46.623809', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004132, 'agent.registry.updated', '操作成功，状态已更新', '{"en-US":"Operation succeeded"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.625217', '2026-11-13 01:09:46.625221', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004133, 'agent.registry.failed', '操作失败，请刷新状态后再试', '{"en-US":"Operation failed. Refresh the state before trying again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.626460', '2026-11-13 01:09:46.626463', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004134, 'agent.registry.loadFailed', '无法读取能力，请确认你同时具备平台项目权限和本项目管理员角色。', '{"en-US":"Cannot load capabilities. Check platform project permission and target project administrator membership."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.627681', '2026-11-13 01:09:46.627684', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004135, 'agent.registry.unknownOutcome', '请求失败，凭据可能已经轮换。请重新签发并更新业务服务配置，不要继续使用旧凭据。', '{"en-US":"The request failed and the credential may have rotated. Issue a new one and update the service configuration."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.628835', '2026-11-13 01:09:46.628837', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004136, 'dict.agent.capability.status.PENDING', '待审核', '{"en-US":"Pending"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.629919', '2026-11-13 01:09:46.629922', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004137, 'dict.agent.capability.status.APPROVED', '已批准', '{"en-US":"Approved"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.631058', '2026-11-13 01:09:46.631061', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004138, 'dict.agent.capability.status.REVOKED', '已撤销', '{"en-US":"Revoked"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.632172', '2026-11-13 01:09:46.632174', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004139, 'dict.agent.capability.connection.ONLINE', '在线', '{"en-US":"Online"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.633309', '2026-11-13 01:09:46.633312', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004140, 'dict.agent.capability.connection.OFFLINE', '离线', '{"en-US":"Offline"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.634560', '2026-11-13 01:09:46.634563', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004200, 'agent.action.title', '创建项目预览', '{"en-US":"Project creation preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.635738', '2026-11-13 01:09:46.635741', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004201, 'agent.action.projectName', '项目名称', '{"en-US":"Project name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.636979', '2026-11-13 01:09:46.636981', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004202, 'agent.action.projectCode', '项目编码', '{"en-US":"Project code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.641114', '2026-11-13 01:09:46.641116', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004203, 'agent.action.packageName', '基础包名', '{"en-US":"Base package"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.642514', '2026-11-13 01:09:46.642517', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004204, 'agent.action.description', '描述', '{"en-US":"Description"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.643760', '2026-11-13 01:09:46.643763', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004205, 'agent.action.impact', '将创建一个项目，并将当前用户设为该项目管理员。', '{"en-US":"Creates one project and makes the current user its project administrator."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.645064', '2026-11-13 01:09:46.645068', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004206, 'agent.action.pendingHint', '尚未执行。请核对以上信息，点击确认才会创建；在聊天中回复“确认”不会执行。', '{"en-US":"Not executed. Review these details and click Confirm to create. A chat reply does not execute the action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.646439', '2026-11-13 01:09:46.646441', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004207, 'agent.action.noToken', '此预览已不能再次确认。请先取消，再重新提问生成预览。', '{"en-US":"This preview cannot be confirmed again. Cancel it before requesting a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.647745', '2026-11-13 01:09:46.647748', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004208, 'agent.action.expiresIn', '{seconds} 秒后过期', '{"en-US":"Expires in {seconds} seconds"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.648924', '2026-11-13 01:09:46.648926', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004209, 'agent.action.confirm', '确认创建项目', '{"en-US":"Confirm project creation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.650009', '2026-11-13 01:09:46.650011', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004210, 'agent.action.cancel', '取消此操作', '{"en-US":"Cancel this action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.651137', '2026-11-13 01:09:46.651139', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004211, 'agent.action.refresh', '查询操作状态', '{"en-US":"Check action status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.652307', '2026-11-13 01:09:46.652309', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004212, 'agent.action.projects', '前往项目管理', '{"en-US":"Open project management"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.653515', '2026-11-13 01:09:46.653517', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004213, 'agent.action.unknownHint', '操作正在执行或结果尚不明确。请查询状态或前往项目管理核验，不要重复提交。', '{"en-US":"The action is executing or its outcome is uncertain. Check its status or project management; do not resubmit."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.655723', '2026-11-13 01:09:46.655726', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004214, 'agent.action.conflict', '项目编码已存在，本次没有创建新项目。请核验项目列表后再决定是否使用其他编码。', '{"en-US":"The project code already exists; no new project was created. Check the project list before choosing another code."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.657118', '2026-11-13 01:09:46.657121', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004215, 'agent.action.failedHint', '操作未完成。请核验当前权限和项目状态，再重新发起预览。', '{"en-US":"The action did not complete. Check permissions and project status before requesting another preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.658517', '2026-11-13 01:09:46.658520', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004216, 'agent.action.expiredHint', '预览已过期，请重新提问生成新预览。', '{"en-US":"This preview has expired. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.659808', '2026-11-13 01:09:46.659811', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004217, 'agent.action.successHint', '项目已创建，可前往项目管理继续配置。', '{"en-US":"Project created. Continue configuring it in project management."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.661196', '2026-11-13 01:09:46.661199', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004218, 'agent.action.requestFailed', '请求失败，请查询操作状态。', '{"en-US":"Request failed. Check the action status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.662400', '2026-11-13 01:09:46.662403', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004219, 'api.agent.actionUnavailable', '操作状态暂不可用，请查询状态，勿重复创建', '{"en-US":"Action state is unavailable. Check status; do not repeat project creation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.663567', '2026-11-13 01:09:46.663571', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004220, 'api.agent.actionForbidden', '当前无权执行此操作，请重新发起', '{"en-US":"You are not currently authorized to perform this action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.664800', '2026-11-13 01:09:46.664803', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004221, 'api.agent.actionNotFound', '操作不存在或不可用，请重新发起', '{"en-US":"Action not found or unavailable. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.666001', '2026-11-13 01:09:46.666003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004222, 'api.agent.actionParameters', '项目参数不完整或格式错误，请补充项目编码与名称', '{"en-US":"Project parameters are missing or invalid. Provide a valid project code and name."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.667266', '2026-11-13 01:09:46.667269', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004223, 'dict.agent.action.status.PENDING', '待确认', '{"en-US":"Pending confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.668557', '2026-11-13 01:09:46.668560', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004224, 'dict.agent.action.status.EXECUTING', '执行中', '{"en-US":"Executing"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.669971', '2026-11-13 01:09:46.669974', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004225, 'dict.agent.action.status.SUCCEEDED', '已创建', '{"en-US":"Created"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.671441', '2026-11-13 01:09:46.671444', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004226, 'dict.agent.action.status.FAILED', '执行失败', '{"en-US":"Failed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.674250', '2026-11-13 01:09:46.674253', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004227, 'dict.agent.action.status.CANCELLED', '已取消', '{"en-US":"Cancelled"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.675498', '2026-11-13 01:09:46.675500', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004228, 'dict.agent.action.status.EXPIRED', '已过期', '{"en-US":"Expired"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.676754', '2026-11-13 01:09:46.676757', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004229, 'dict.agent.action.status.REJECTED', '已拒绝', '{"en-US":"Rejected"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.677971', '2026-11-13 01:09:46.677974', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004230, 'dict.agent.action.status.UNKNOWN', '结果待核验', '{"en-US":"Outcome uncertain"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.679115', '2026-11-13 01:09:46.679118', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004400, 'agent.remoteAction.title', '子项目操作预览', '{"en-US":"Project action preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.680306', '2026-11-13 01:09:46.680309', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004401, 'agent.remoteAction.project', '所属项目', '{"en-US":"Project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.681573', '2026-11-13 01:09:46.681576', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004402, 'agent.remoteAction.affectedCount', '预计影响数量', '{"en-US":"Estimated affected items"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.682823', '2026-11-13 01:09:46.682826', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004403, 'agent.remoteAction.pendingHint', '此操作尚未执行', '{"en-US":"This action has not run"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.684038', '2026-11-13 01:09:46.684041', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004404, 'agent.remoteAction.reviewHint', '请核对业务系统返回的预览，再点击确认；在聊天中回复“确认”不会执行。', '{"en-US":"Review the business preview before confirming. A chat reply does not execute the action."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.685273', '2026-11-13 01:09:46.685276', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004405, 'agent.remoteAction.noToken', '确认凭证已失效，请重新发起预览。', '{"en-US":"Confirmation is no longer available. Request a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.686576', '2026-11-13 01:09:46.686579', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004406, 'agent.remoteAction.strongPrompt', '输入确认语', '{"en-US":"Type confirmation phrase"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.687976', '2026-11-13 01:09:46.687979', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004407, 'agent.remoteAction.strongPlaceholder', '请输入：{phrase}', '{"en-US":"Type: {phrase}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.689386', '2026-11-13 01:09:46.689389', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004408, 'agent.remoteAction.expiresIn', '{seconds} 秒后过期', '{"en-US":"Expires in {seconds} seconds"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.690642', '2026-11-13 01:09:46.690645', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004409, 'agent.remoteAction.unknownHint', '执行结果尚未确认。只能查询状态，不要重复提交。', '{"en-US":"The outcome is uncertain. Check status; do not submit again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.691831', '2026-11-13 01:09:46.691833', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004410, 'agent.remoteAction.failedHint', '操作未完成，请核验权限及业务状态后重新发起预览。', '{"en-US":"The action did not complete. Check permissions and business state before requesting a new preview."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.693080', '2026-11-13 01:09:46.693083', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004411, 'agent.remoteAction.expiredHint', '预览已过期，请重新发起。', '{"en-US":"The preview expired. Request a new one."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.694401', '2026-11-13 01:09:46.694404', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004412, 'agent.remoteAction.successHint', '操作已完成。', '{"en-US":"Action completed."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.695607', '2026-11-13 01:09:46.695610', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004413, 'agent.remoteAction.result', '执行结果', '{"en-US":"Result"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.696742', '2026-11-13 01:09:46.696745', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004414, 'agent.remoteAction.confirm', '确认执行', '{"en-US":"Confirm action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.697944', '2026-11-13 01:09:46.697947', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004415, 'agent.remoteAction.cancel', '取消操作', '{"en-US":"Cancel action"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.699163', '2026-11-13 01:09:46.699166', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004416, 'agent.remoteAction.refresh', '查询操作状态', '{"en-US":"Check action status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.700412', '2026-11-13 01:09:46.700415', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004417, 'agent.remoteAction.projects', '前往项目管理', '{"en-US":"Open project management"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.701654', '2026-11-13 01:09:46.701657', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004418, 'agent.remoteAction.requestFailed', '请求失败，请查询操作状态。', '{"en-US":"Request failed. Check action status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.702973', '2026-11-13 01:09:46.702975', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004419, 'dict.agent.remote_action.status.PENDING', '待确认', '{"en-US":"Pending confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.704202', '2026-11-13 01:09:46.704204', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004420, 'dict.agent.remote_action.status.EXECUTING', '执行中', '{"en-US":"Executing"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.707151', '2026-11-13 01:09:46.707153', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004421, 'dict.agent.remote_action.status.SUCCEEDED', '已完成', '{"en-US":"Completed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.708371', '2026-11-13 01:09:46.708373', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004422, 'dict.agent.remote_action.status.FAILED', '执行失败', '{"en-US":"Failed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.709554', '2026-11-13 01:09:46.709557', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004423, 'dict.agent.remote_action.status.CANCELLED', '已取消', '{"en-US":"Cancelled"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.710863', '2026-11-13 01:09:46.710867', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004424, 'dict.agent.remote_action.status.EXPIRED', '已过期', '{"en-US":"Expired"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.712305', '2026-11-13 01:09:46.712309', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004425, 'dict.agent.remote_action.status.REJECTED', '已拒绝', '{"en-US":"Rejected"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.713695', '2026-11-13 01:09:46.713698', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004426, 'dict.agent.remote_action.status.UNKNOWN', '结果待核验', '{"en-US":"Outcome uncertain"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.715005', '2026-11-13 01:09:46.715008', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004500, 'agent.registry.approveWrite', '批准写能力', '{"en-US":"Approve write capability"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.716298', '2026-11-13 01:09:46.716302', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004501, 'agent.registry.approveWriteConfirm', '已核对业务实现、权限、预览、确认和同事务幂等账本，批准此版本写能力？实际执行仍需单独启用。', '{"en-US":"Have you reviewed the handler, authorization, preview, confirmation, and transactional idempotency ledger? Approve this version? Execution still requires separate enablement."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.717623', '2026-11-13 01:09:46.717626', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004502, 'agent.registry.writeApprovalHint', '批准写能力前，须核对业务 Handler 的领域权限、只读预览、同事务幂等账本和确认等级。批准不会打开执行开关。', '{"en-US":"Before approving a write capability, review the handler authorization, read-only preview, transactional idempotency ledger, and confirmation level. Approval does not enable execution."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.719013', '2026-11-13 01:09:46.719018', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004700, 'agent.registry.batchApprove', '批量批准只读能力（{count}）', '{"en-US":"Approve read-only capabilities ({count})"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.741811', '2026-11-13 01:09:46.741814', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004701, 'agent.registry.batchReviewTitle', '批量审核 {count} 项能力', '{"en-US":"Review {count} capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.742992', '2026-11-13 01:09:46.742994', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004702, 'agent.registry.batchReviewHint', '请逐项展开并核对权限、参数、输出字段和只读实现。整批绑定当前版本及摘要；任一项变化则整批不批准。写能力仍需逐项审核。', '{"en-US":"Expand and review each permission, parameter, output field, and read-only implementation. The batch binds to current versions and digests; any change rejects the whole batch. Review write capabilities individually."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.744283', '2026-11-13 01:09:46.744286', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004703, 'agent.registry.batchAcknowledge', '我已逐项核对以上完整清单，同意批准所选只读能力', '{"en-US":"I have reviewed every full manifest and approve these read-only capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.745541', '2026-11-13 01:09:46.745544', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004704, 'agent.registry.batchChanged', '所选能力已变化或包含非只读能力，请刷新后重新选择', '{"en-US":"A selected capability changed or is not read-only. Refresh and select again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.746727', '2026-11-13 01:09:46.746730', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004705, 'agent.registry.batchMax', '每次最多审核 50 项能力', '{"en-US":"Review at most 50 capabilities at a time"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.747929', '2026-11-13 01:09:46.747932', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004800, 'agent.local.intro', 'System 是内置项目，Agent 能力由平台代码提供，无需签发项目凭据或逐项审批。', '{"en-US":"System is built in. Its Agent capabilities are provided by platform code and require no project credential or approval."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.749087', '2026-11-13 01:09:46.749090', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004801, 'agent.local.scope', '下表仅列出已实现的 System 能力。聊天只会看到当前账号有权使用的能力；具体操作执行前还会重新鉴权。', '{"en-US":"This table lists implemented System capabilities. Chat only sees capabilities allowed for this account; permission is checked again before execution."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.750230', '2026-11-13 01:09:46.750232', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004802, 'agent.local.refresh', '刷新', '{"en-US":"Refresh"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.751392', '2026-11-13 01:09:46.751394', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004803, 'agent.local.loadFailed', '加载 System Agent 能力失败', '{"en-US":"Failed to load System Agent capabilities"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.752629', '2026-11-13 01:09:46.752631', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004804, 'agent.local.empty', '暂无已实现的 System Agent 能力', '{"en-US":"No System Agent capabilities implemented yet"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.754536', '2026-11-13 01:09:46.754539', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004805, 'agent.local.code', '能力编码', '{"en-US":"Capability code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.756426', '2026-11-13 01:09:46.756429', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004806, 'agent.local.description', '功能', '{"en-US":"Function"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.757633', '2026-11-13 01:09:46.757636', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004807, 'agent.local.permission', '所需权限', '{"en-US":"Required permission"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.758779', '2026-11-13 01:09:46.758782', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004808, 'agent.local.mode', '执行方式', '{"en-US":"Execution mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.759968', '2026-11-13 01:09:46.759970', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004809, 'agent.local.readOnly', '只读', '{"en-US":"Read-only"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.761187', '2026-11-13 01:09:46.761190', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004810, 'agent.local.confirmation', '确认后执行', '{"en-US":"Requires confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.762277', '2026-11-13 01:09:46.762280', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004811, 'agent.local.availability', '当前账号', '{"en-US":"This account"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.763438', '2026-11-13 01:09:46.763440', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004812, 'agent.local.allowed', '有权限', '{"en-US":"Allowed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.764612', '2026-11-13 01:09:46.764615', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004813, 'agent.local.denied', '无权限', '{"en-US":"No permission"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.765819', '2026-11-13 01:09:46.765822', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004814, 'agent.local.note', '没有对应权限时，直接向 AI 助手提出该操作会收到无权限提示。', '{"en-US":"Asking the AI assistant to perform an unauthorized operation returns a permission denial."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.766972', '2026-11-13 01:09:46.766975', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004900, 'agent.input.title', '补充项目信息', '{"en-US":"Complete project information"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.768184', '2026-11-13 01:09:46.768187', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004901, 'agent.input.hint', '填写后生成创建预览，核对并确认后才会创建项目。', '{"en-US":"Fill in the form to preview the project. Creation requires a separate confirmation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.769394', '2026-11-13 01:09:46.769397', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004902, 'agent.input.projectCode', '项目编码', '{"en-US":"Project code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.770644', '2026-11-13 01:09:46.770647', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004903, 'agent.input.projectName', '项目名称', '{"en-US":"Project name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.772230', '2026-11-13 01:09:46.772233', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004904, 'agent.input.packageName', '基础包名（选填）', '{"en-US":"Base package (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.774121', '2026-11-13 01:09:46.774124', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004905, 'agent.input.description', '描述（选填）', '{"en-US":"Description (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.775443', '2026-11-13 01:09:46.775446', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004906, 'agent.input.required', '请填写此项', '{"en-US":"This field is required"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.776654', '2026-11-13 01:09:46.776657', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004907, 'agent.input.projectCodeInvalid', '使用 2–64 位小写字母、数字或连字符，以字母开头', '{"en-US":"Use 2–64 lowercase letters, digits or hyphens, starting with a letter"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.777936', '2026-11-13 01:09:46.777939', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004908, 'agent.input.packageNameInvalid', '请输入有效包名，例如 com.example.orders', '{"en-US":"Enter a valid package name, e.g. com.example.orders"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.779078', '2026-11-13 01:09:46.779081', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004909, 'agent.input.submit', '生成预览', '{"en-US":"Preview project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.780214', '2026-11-13 01:09:46.780216', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004910, 'agent.input.cancel', '取消填写', '{"en-US":"Cancel form"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.781456', '2026-11-13 01:09:46.781459', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004911, 'agent.input.cancelled', '已取消填写，可重新提出操作请求。', '{"en-US":"Form cancelled. You can start a new request."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.782617', '2026-11-13 01:09:46.782620', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004912, 'agent.input.denied', '无权限操作', '{"en-US":"You do not have permission to perform this operation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.783790', '2026-11-13 01:09:46.783793', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000004913, 'agent.input.failed', '未能生成预览，请检查填写内容后重试。', '{"en-US":"Unable to generate a preview. Check the form and try again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.784990', '2026-11-13 01:09:46.784992', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005000, 'agent.projects.title', '查看项目列表', '{"en-US":"View project list"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.786237', '2026-11-13 01:09:46.786240', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005001, 'agent.projects.search', '搜索项目名称或编码', '{"en-US":"Search project name or code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.787549', '2026-11-13 01:09:46.787552', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005002, 'agent.projects.failed', '加载项目列表失败，请重试', '{"en-US":"Unable to load projects. Please retry."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.790943', '2026-11-13 01:09:46.790945', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005003, 'agent.projects.created', '项目已创建，可在聊天中查看项目列表和详情。', '{"en-US":"Project created. View its list and details in this chat."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.792224', '2026-11-13 01:09:46.792227', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005100, 'agent.chat.sessions', '会话与记录', '{"en-US":"Conversations"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.793406', '2026-11-13 01:09:46.793409', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005101, 'agent.chat.new', '新建会话', '{"en-US":"New conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.794698', '2026-11-13 01:09:46.794701', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005102, 'agent.chat.untitled', '新会话', '{"en-US":"New conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.795916', '2026-11-13 01:09:46.795919', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005103, 'agent.chat.rename', '会话名称', '{"en-US":"Conversation title"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.797162', '2026-11-13 01:09:46.797165', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005104, 'agent.chat.save', '保存', '{"en-US":"Save"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.798383', '2026-11-13 01:09:46.798386', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005105, 'agent.chat.cancel', '取消', '{"en-US":"Cancel"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.799530', '2026-11-13 01:09:46.799532', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005106, 'agent.chat.delete', '删除', '{"en-US":"Delete"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.800672', '2026-11-13 01:09:46.800674', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005107, 'agent.chat.deleteConfirm', '删除此会话及全部聊天记录？此操作无法撤销。', '{"en-US":"Delete this conversation and all its messages? This cannot be undone."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.801823', '2026-11-13 01:09:46.801826', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005108, 'agent.chat.empty', '暂无会话，发送消息即可开始', '{"en-US":"No conversations yet. Send a message to start."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.803058', '2026-11-13 01:09:46.803060', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005109, 'agent.chat.failed', '操作失败，请重试', '{"en-US":"Operation failed. Please retry."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.804301', '2026-11-13 01:09:46.804304', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005110, 'agent.chat.history', '历史记录仅保留问答文本，业务数据和操作状态请重新查询。', '{"en-US":"History contains text only. Query again for current data and operation status."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.807566', '2026-11-13 01:09:46.807569', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005111, 'agent.chat.interrupted', '此条消息未收到完整回复，请检查操作状态后重新提问。', '{"en-US":"No complete reply was received. Check operation status before asking again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.808765', '2026-11-13 01:09:46.808768', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005112, 'agent.chat.older', '加载更早记录', '{"en-US":"Load earlier messages"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.809940', '2026-11-13 01:09:46.809942', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005113, 'agent.chat.loading', '正在加载聊天记录', '{"en-US":"Loading conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.811075', '2026-11-13 01:09:46.811078', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005114, 'agent.chat.useMemory', '本会话使用记忆', '{"en-US":"Use memories in this conversation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.812150', '2026-11-13 01:09:46.812153', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005115, 'agent.chat.required', '请填写内容', '{"en-US":"Please enter a value"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.813260', '2026-11-13 01:09:46.813263', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005116, 'agent.chat.refresh', '刷新记录', '{"en-US":"Refresh history"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.814395', '2026-11-13 01:09:46.814397', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005117, 'agent.memory.title', '个人记忆', '{"en-US":"Personal memories"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.815525', '2026-11-13 01:09:46.815528', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005118, 'agent.memory.hint', '仅保存你手动填写的偏好，最多20条，每条500字。启用的记忆用于后续对话，不会授予权限或代替操作确认；请勿填写密码、令牌等秘密。删除会话不会删除个人记忆。', '{"en-US":"Only preferences you explicitly save are remembered (20 entries, 500 characters each). Enabled memories apply to future messages, never grant permissions or replace confirmation. Do not save secrets. Deleting a conversation does not delete memories."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.816667', '2026-11-13 01:09:46.816670', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005119, 'agent.memory.content', '记忆内容', '{"en-US":"Memory content"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.817872', '2026-11-13 01:09:46.817875', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005120, 'agent.memory.add', '添加记忆', '{"en-US":"Add memory"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.819079', '2026-11-13 01:09:46.819082', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005121, 'agent.memory.edit', '编辑', '{"en-US":"Edit"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.820343', '2026-11-13 01:09:46.820345', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005122, 'agent.memory.enabled', '启用记忆', '{"en-US":"Enable memory"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.821876', '2026-11-13 01:09:46.821878', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005123, 'agent.memory.empty', '暂无个人记忆', '{"en-US":"No personal memories"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.823931', '2026-11-13 01:09:46.823933', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005124, 'agent.memory.deleteConfirm', '确定删除这条记忆？', '{"en-US":"Delete this memory?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.825293', '2026-11-13 01:09:46.825296', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005125, 'api.agent.personalNotFound', '记录不存在或无权限访问', '{"en-US":"Record not found or access denied"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.826444', '2026-11-13 01:09:46.826447', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005126, 'api.agent.conversationLimit', '最多保存100个会话，请删除不再需要的会话', '{"en-US":"Limit of 100 conversations reached. Delete unused conversations."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.827668', '2026-11-13 01:09:46.827671', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005127, 'api.agent.memoryLimit', '最多保存20条记忆，请删除或编辑现有记忆', '{"en-US":"Limit of 20 memories reached. Delete or edit existing memories."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.828797', '2026-11-13 01:09:46.828799', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005128, 'api.agent.conversationBusy', '此会话正在处理消息或已更新，请稍后刷新记录', '{"en-US":"This conversation is busy or has changed. Refresh history shortly."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.829912', '2026-11-13 01:09:46.829915', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005129, 'api.agent.messageDuplicate', '这条消息已提交，请刷新聊天记录，不要重复执行', '{"en-US":"This message was already submitted. Refresh history instead of repeating the operation."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.831084', '2026-11-13 01:09:46.831087', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005200, 'agent.navigation.previous', '上一页', '{"en-US":"Previous page"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.832245', '2026-11-13 01:09:46.832248', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005201, 'agent.navigation.next', '下一页', '{"en-US":"Next page"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.833384', '2026-11-13 01:09:46.833387', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005202, 'agent.navigation.page', '第 {page} 页', '{"en-US":"Page {page}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.834570', '2026-11-13 01:09:46.834573', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005203, 'agent.navigation.actions', '操作', '{"en-US":"Actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.835913', '2026-11-13 01:09:46.835916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005300, 'agent.mode.exit', '返回菜单', '{"en-US":"Back to menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.837099', '2026-11-13 01:09:46.837102', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005301, 'agent.mode.autoOpen', '登录后默认进入 AI 助手', '{"en-US":"Open AI assistant after sign-in"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.840905', '2026-11-13 01:09:46.840908', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005400, 'agent.input.dictTypeCreateTitle', '创建字典类型', '{"en-US":"Create dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.842126', '2026-11-13 01:09:46.842129', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005401, 'agent.input.dictCode', '字典编码', '{"en-US":"Dictionary code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.843371', '2026-11-13 01:09:46.843374', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005402, 'agent.input.dictName', '字典名称', '{"en-US":"Dictionary name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.844567', '2026-11-13 01:09:46.844570', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005403, 'agent.action.genericTitle', '操作预览', '{"en-US":"Operation preview"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.845622', '2026-11-13 01:09:46.845624', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005404, 'agent.action.completed', '操作已完成', '{"en-US":"Operation completed"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.846720', '2026-11-13 01:09:46.846722', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005405, 'agent.action.genericImpact', '此操作会修改平台数据，请核对下方内容。', '{"en-US":"This operation will change platform data. Review the details below."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.847936', '2026-11-13 01:09:46.847939', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005406, 'agent.action.genericPendingHint', '尚未执行。点击确认后才会保存；在聊天中回复“确认”不会执行。', '{"en-US":"Not executed yet. Click Confirm to save; replying in chat does not execute it."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.849106', '2026-11-13 01:09:46.849108', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005407, 'agent.action.genericConfirm', '确认执行', '{"en-US":"Confirm operation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.850248', '2026-11-13 01:09:46.850251', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005408, 'agent.input.userDisplayNameUpdateTitle', '修改用户显示名称', '{"en-US":"Update user display name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.851500', '2026-11-13 01:09:46.851503', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005409, 'agent.input.targetUserId', '目标用户 ID', '{"en-US":"Target user ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.852849', '2026-11-13 01:09:46.852851', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005410, 'agent.input.displayName', '显示名称', '{"en-US":"Display name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.854241', '2026-11-13 01:09:46.854244', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005411, 'agent.input.username', '登录用户名', '{"en-US":"Login username"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.858046', '2026-11-13 01:09:46.858048', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005412, 'agent.input.userCreateTitle', '创建平台用户', '{"en-US":"Create platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.859339', '2026-11-13 01:09:46.859342', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005413, 'agent.input.email', '邮箱（选填）', '{"en-US":"Email (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.860524', '2026-11-13 01:09:46.860527', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005414, 'agent.action.oneTimePassword', '一次性初始密码', '{"en-US":"One-time initial password"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.861659', '2026-11-13 01:09:46.861661', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005415, 'agent.action.oneTimePasswordHint', '请现在复制并通过安全渠道交给新用户；关闭或刷新后无法再次查看。首次登录必须修改密码。', '{"en-US":"Copy now and deliver securely. It cannot be viewed again after closing or refreshing. The user must change it on first sign-in."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.862813', '2026-11-13 01:09:46.862816', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005420, 'agent.input.dictItemCreateTitle', '新增字典项', '{"en-US":"Add dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.863989', '2026-11-13 01:09:46.863991', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005421, 'agent.input.typeId', '字典类型 ID', '{"en-US":"Dictionary type ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.865173', '2026-11-13 01:09:46.865175', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005422, 'agent.input.itemLabel', '字典项标签', '{"en-US":"Item label"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.866286', '2026-11-13 01:09:46.866288', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005423, 'agent.input.itemValue', '字典项值', '{"en-US":"Item value"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.867599', '2026-11-13 01:09:46.867603', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005424, 'agent.input.sortNo', '排序序号', '{"en-US":"Sort order"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.868998', '2026-11-13 01:09:46.869001', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005425, 'agent.input.defaultItem', '设为默认项', '{"en-US":"Default item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.870323', '2026-11-13 01:09:46.870325', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005426, 'agent.input.color', '颜色', '{"en-US":"Color"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.874753', '2026-11-13 01:09:46.874756', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005427, 'agent.input.labelI18nKey', '标签国际化资源键', '{"en-US":"Label localization key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.876038', '2026-11-13 01:09:46.876042', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005428, 'agent.input.status', '状态', '{"en-US":"Status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.877259', '2026-11-13 01:09:46.877262', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005429, 'agent.input.departmentCreateTitle', '创建部门', '{"en-US":"Create department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.878495', '2026-11-13 01:09:46.878498', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005430, 'agent.input.departmentName', '部门名称', '{"en-US":"Department name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.879640', '2026-11-13 01:09:46.879642', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005431, 'agent.input.departmentCode', '部门编码', '{"en-US":"Department code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.880806', '2026-11-13 01:09:46.880808', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005432, 'agent.input.parentDepartmentId', '上级部门 ID（选填）', '{"en-US":"Parent department ID (optional)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.881928', '2026-11-13 01:09:46.881931', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005433, 'agent.input.userStatusUpdateTitle', '启停平台用户', '{"en-US":"Enable or disable platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.883079', '2026-11-13 01:09:46.883082', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005434, 'agent.input.currentStatus', '当前状态', '{"en-US":"Current status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.884694', '2026-11-13 01:09:46.884698', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005435, 'agent.input.configCreateTitle', '创建非敏感参数配置', '{"en-US":"Create non-secret configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.886086', '2026-11-13 01:09:46.886089', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005436, 'agent.input.configKey', '配置键', '{"en-US":"Configuration key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.887914', '2026-11-13 01:09:46.887916', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005437, 'agent.input.configValue', '配置值（非敏感）', '{"en-US":"Configuration value (non-secret)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.890631', '2026-11-13 01:09:46.890633', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005438, 'agent.input.valueType', '值类型', '{"en-US":"Value type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.891894', '2026-11-13 01:09:46.891896', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005439, 'agent.input.dictTypeRenameTitle', '修改字典类型名称', '{"en-US":"Rename dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.893108', '2026-11-13 01:09:46.893111', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005440, 'agent.input.currentName', '当前名称', '{"en-US":"Current name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.894281', '2026-11-13 01:09:46.894284', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005441, 'agent.input.dictItemRenameTitle', '修改字典项标签', '{"en-US":"Rename dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.895443', '2026-11-13 01:09:46.895446', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005442, 'agent.input.itemId', '字典项 ID', '{"en-US":"Dictionary item ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.896606', '2026-11-13 01:09:46.896608', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005443, 'agent.input.currentLabel', '当前标签', '{"en-US":"Current label"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.897776', '2026-11-13 01:09:46.897779', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005444, 'agent.input.departmentRenameTitle', '修改部门名称', '{"en-US":"Rename department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.899126', '2026-11-13 01:09:46.899129', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005445, 'agent.input.departmentId', '部门 ID', '{"en-US":"Department ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.900489', '2026-11-13 01:09:46.900493', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005446, 'agent.input.departmentStatusUpdateTitle', '启停部门', '{"en-US":"Enable or disable department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.901856', '2026-11-13 01:09:46.901858', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005447, 'agent.input.projectStatusUpdateTitle', '变更项目状态', '{"en-US":"Change project status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.903327', '2026-11-13 01:09:46.903330', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005448, 'agent.input.projectId', '项目 ID', '{"en-US":"Project ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.904676', '2026-11-13 01:09:46.904678', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005449, 'agent.input.dictItemDeleteTitle', '删除字典项', '{"en-US":"Delete dictionary item"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.907969', '2026-11-13 01:09:46.907972', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005450, 'agent.input.configDeleteTitle', '删除平台配置', '{"en-US":"Delete platform configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.909210', '2026-11-13 01:09:46.909212', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005451, 'agent.input.configId', '配置 ID', '{"en-US":"Configuration ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.910472', '2026-11-13 01:09:46.910475', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005452, 'agent.input.secret', '敏感配置', '{"en-US":"Secret configuration"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.911747', '2026-11-13 01:09:46.911749', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005453, 'agent.input.projectRenameTitle', '修改项目名称', '{"en-US":"Rename project"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.912914', '2026-11-13 01:09:46.912917', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005454, 'agent.input.dictTypeDeleteTitle', '删除字典类型', '{"en-US":"Delete dictionary type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.914084', '2026-11-13 01:09:46.914086', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005455, 'agent.input.projectRoleCreateTitle', '创建项目角色', '{"en-US":"Create project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.915193', '2026-11-13 01:09:46.915196', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005456, 'agent.input.newRoleCode', '新角色编码', '{"en-US":"New role code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.916290', '2026-11-13 01:09:46.916293', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005457, 'agent.input.roleName', '角色名称', '{"en-US":"Role name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.917444', '2026-11-13 01:09:46.917446', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005458, 'agent.input.projectRoleUpdateTitle', '修改项目角色', '{"en-US":"Edit project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.918666', '2026-11-13 01:09:46.918669', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005459, 'agent.input.targetRoleId', '目标角色编号', '{"en-US":"Target role ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.919939', '2026-11-13 01:09:46.919942', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005460, 'agent.input.projectRoleDeleteTitle', '删除项目角色', '{"en-US":"Delete project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.921316', '2026-11-13 01:09:46.921319', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005461, 'agent.input.projectRoleStatusTitle', '启停项目角色', '{"en-US":"Enable or disable project role"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.924068', '2026-11-13 01:09:46.924071', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005462, 'agent.input.targetMenuId', '目标菜单编号', '{"en-US":"Target menu ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.925382', '2026-11-13 01:09:46.925384', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005463, 'agent.input.projectMenuStatusTitle', '启停项目菜单', '{"en-US":"Enable or disable project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.926737', '2026-11-13 01:09:46.926739', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005464, 'agent.input.projectMenuDeleteTitle', '删除项目菜单', '{"en-US":"Delete project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.928039', '2026-11-13 01:09:46.928042', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005465, 'agent.input.menuIds', '菜单编号（可输入多个）', '{"en-US":"Menu IDs (multiple allowed)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.929273', '2026-11-13 01:09:46.929276', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005466, 'agent.input.projectRoleMenuGrantTitle', '设置项目角色菜单', '{"en-US":"Set project role menus"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.930445', '2026-11-13 01:09:46.930447', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005467, 'agent.input.roleIds', '项目角色编号（可输入多个）', '{"en-US":"Project role IDs (multiple allowed)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.931600', '2026-11-13 01:09:46.931602', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005468, 'agent.input.projectMemberSaveTitle', '设置项目成员', '{"en-US":"Set project member"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.932666', '2026-11-13 01:09:46.932668', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005469, 'agent.input.projectMemberDeleteTitle', '移除项目成员', '{"en-US":"Remove project member"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.933908', '2026-11-13 01:09:46.933910', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005470, 'agent.input.departmentDeleteTitle', '删除部门', '{"en-US":"Delete department"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.935174', '2026-11-13 01:09:46.935177', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005471, 'agent.input.departmentIds', '部门编号（首项为主部门，可输入多个）', '{"en-US":"Department IDs (first is primary)"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.936499', '2026-11-13 01:09:46.936502', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005472, 'agent.input.userDepartmentAssignTitle', '设置用户部门归属', '{"en-US":"Set user departments"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.938420', '2026-11-13 01:09:46.938423', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005473, 'agent.input.parentId', '上级菜单编号', '{"en-US":"Parent menu ID"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.939952', '2026-11-13 01:09:46.939954', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005474, 'agent.input.menuName', '菜单名称', '{"en-US":"Menu name"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.941182', '2026-11-13 01:09:46.941185', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005475, 'agent.input.menuNameKey', '菜单国际化资源 Key', '{"en-US":"Menu translation key"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.942498', '2026-11-13 01:09:46.942501', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005476, 'agent.input.menuType', '菜单类型', '{"en-US":"Menu type"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.943653', '2026-11-13 01:09:46.943656', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005477, 'agent.input.routePath', '路由路径', '{"en-US":"Route path"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.944834', '2026-11-13 01:09:46.944836', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005478, 'agent.input.componentPath', '组件路径', '{"en-US":"Component path"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.945893', '2026-11-13 01:09:46.945895', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005479, 'agent.input.permissionCode', '权限码', '{"en-US":"Permission code"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.947034', '2026-11-13 01:09:46.947038', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005480, 'agent.input.icon', '菜单图标', '{"en-US":"Menu icon"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.948223', '2026-11-13 01:09:46.948226', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005481, 'agent.input.visible', '是否显示', '{"en-US":"Visible"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.949369', '2026-11-13 01:09:46.949372', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005482, 'agent.input.projectMenuCreateTitle', '创建项目菜单', '{"en-US":"Create project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.950724', '2026-11-13 01:09:46.950729', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005483, 'agent.input.projectMenuUpdateTitle', '编辑项目菜单', '{"en-US":"Edit project menu"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.952123', '2026-11-13 01:09:46.952126', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005484, 'agent.input.userProfileUpdateTitle', '编辑平台用户资料', '{"en-US":"Edit platform user profile"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.953691', '2026-11-13 01:09:46.953694', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005485, 'agent.input.userPasswordResetTitle', '重置平台用户密码', '{"en-US":"Reset platform user password"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.957370', '2026-11-13 01:09:46.957373', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005900, 'agent.mode.classic', '传统模式', '{"en-US":"Classic mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.958650', '2026-11-13 01:09:46.958653', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005901, 'agent.mode.enter', 'AI 助手模式', '{"en-US":"AI assistant mode"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.959985', '2026-11-13 01:09:46.959989', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005902, 'agent.mode.classicHint', '已切换到传统模式，随时可以点左侧菜单底部的「AI 助手模式」切换回来。', '{"en-US":"Switched to classic mode. Use \"AI assistant mode\" at the bottom of the left menu to switch back anytime."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.961235', '2026-11-13 01:09:46.961238', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005903, 'agent.setup.greeting', '你好，我是 Kaiwu AI 助手。先接入一个大模型，之后就能用一句话创建项目、查询和管理平台。暂时不想配置？点右上角「传统模式」回到菜单界面，随时可以再切回来。', '{"en-US":"Hi, I am the Kaiwu AI assistant. Connect a model first, then you can create projects and manage the platform in plain language. Not now? Use \"Classic mode\" at the top right to return to the menus, and switch back anytime."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.962323', '2026-11-13 01:09:46.962325', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005904, 'agent.setup.title', '接入大模型', '{"en-US":"Connect a model"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.963413', '2026-11-13 01:09:46.963415', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005905, 'agent.setup.hint', '支持任何 OpenAI 兼容接口。API Key 只在这个表单中填写并加密保存，不会出现在聊天记录里。', '{"en-US":"Any OpenAI-compatible API works. The API key is entered only in this form, stored encrypted, and never appears in the chat history."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.964559', '2026-11-13 01:09:46.964561', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005906, 'agent.setup.preset', '服务商', '{"en-US":"Provider"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.965696', '2026-11-13 01:09:46.965699', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005907, 'agent.setup.preset.deepseek', 'DeepSeek', '{"en-US":"DeepSeek"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.966855', '2026-11-13 01:09:46.966858', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005908, 'agent.setup.preset.qwen', '通义千问', '{"en-US":"Qwen"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.968080', '2026-11-13 01:09:46.968083', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005909, 'agent.setup.preset.openai', 'OpenAI', '{"en-US":"OpenAI"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.969396', '2026-11-13 01:09:46.969399', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005910, 'agent.setup.preset.custom', '其他兼容服务', '{"en-US":"Other compatible"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.970637', '2026-11-13 01:09:46.970640', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005911, 'agent.setup.submit', '保存并测试连接', '{"en-US":"Save and test connection"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.972003', '2026-11-13 01:09:46.972006', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005912, 'agent.setup.success', '已接入 {model}，连接正常。现在可以直接提问，或者试试下面的问题。', '{"en-US":"Connected to {model}. Ask anything, or try one of the questions below."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.973285', '2026-11-13 01:09:46.973288', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005913, 'agent.setup.testFailed', '配置已保存，但连接测试没有通过：{reason}。请检查地址、模型和 API Key 后重试。', '{"en-US":"Saved, but the connection test failed: {reason}. Check the URL, model and API key, then try again."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.974505', '2026-11-13 01:09:46.974507', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005914, 'agent.setup.noPermission', '平台还没有接入大模型，AI 助手暂时无法回答。请联系管理员配置，或者先切换到传统模式操作。', '{"en-US":"No model is connected yet, so the AI assistant cannot answer. Ask an administrator to configure one, or switch to classic mode for now."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.975737', '2026-11-13 01:09:46.975740', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005915, 'agent.suggest.title', '可以这样问', '{"en-US":"Try asking"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.976894', '2026-11-13 01:09:46.976896', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005916, 'agent.suggest.createProject', '帮我创建一个订单管理项目', '{"en-US":"Create an order management project for me"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.978064', '2026-11-13 01:09:46.978066', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005917, 'agent.suggest.listProjects', '平台上现在有哪些项目？', '{"en-US":"Which projects are on the platform?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.979147', '2026-11-13 01:09:46.979150', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005918, 'agent.suggest.failedGenerations', '最近有哪些项目生成失败了？', '{"en-US":"Which project generations failed recently?"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.980317', '2026-11-13 01:09:46.980320', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005919, 'agent.projects.continueGeneration', '继续生成第一版', '{"en-US":"Generate the first version"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.981474', '2026-11-13 01:09:46.981476', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005920, 'agent.page.related', '可以在这些页面里操作：', '{"en-US":"You can do this on these pages:"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.982634', '2026-11-13 01:09:46.982636', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005930, 'home.guide.run.title', '本机一条命令跑起来', '{"en-US":"Run it locally in one command"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.983751', '2026-11-13 01:09:46.983754', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005931, 'home.guide.run.desc', '在 Kaiwu 入口目录执行下面的命令，前后端会自动接入平台；完成后回到工作台点「进入」。', '{"en-US":"From the Kaiwu entry directory, run the command below to wire both repositories into the platform, then click Open on the workbench."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.984954', '2026-11-13 01:09:46.984958', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005932, 'home.guide.run.command', './kaiwu project-up ../business/<项目编码>-service', '{"en-US":"./kaiwu project-up ../business/<project-code>-service"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.986374', '2026-11-13 01:09:46.986377', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005940, 'gateway.projectAccessDenied', '无权访问该项目', '{"en-US":"You do not have access to this project"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.987887', '2026-11-13 01:09:46.987890', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005941, 'gateway.projectMismatch', '项目标识与授权不一致', '{"en-US":"The project identifier does not match the authorization"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.989621', '2026-11-13 01:09:46.989625', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005942, 'gateway.routeProjectMissing', '路由缺少项目绑定', '{"en-US":"The route is not bound to a project"}', 'gateway', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.991153', '2026-11-13 01:09:46.991156', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005950, 'home.guide.enter.title', '进入项目并验收', '{"en-US":"Open the project and check it"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.992436', '2026-11-13 01:09:46.992439', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000005951, 'home.guide.enter.desc', '在下方「我参与的项目」点击项目卡片：不用再次登录就能打开业务后台，页面和接口正常即接入成功。', '{"en-US":"Click the project card under My projects below. The business admin opens without signing in again; if its pages and APIs work, the project is connected."}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.993711', '2026-11-13 01:09:46.993713', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006000, 'layout.workspace', '工作空间', '{"en-US":"Workspace"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.995034', '2026-11-13 01:09:46.995037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006001, 'layout.search.jump', '搜索与跳转', '{"en-US":"Search or jump"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.996189', '2026-11-13 01:09:46.996191', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006002, 'layout.assistant.try', '试试 AI 助手', '{"en-US":"Try the AI assistant"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.997312', '2026-11-13 01:09:46.997315', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006003, 'layout.assistant.desc', '项目查询、创建任务、代码生成与交付，都可以用自然语言完成。', '{"en-US":"Query projects, create tasks, generate and deliver code, all in plain language."}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.998498', '2026-11-13 01:09:46.998501', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006004, 'layout.assistant.enter', '进入 AI 助手', '{"en-US":"Open AI assistant"}', 'layout', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:46.999619', '2026-11-13 01:09:46.999621', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006005, 'home.pipeline.title', '工程交付链路', '{"en-US":"Delivery pipeline"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.000804', '2026-11-13 01:09:47.000807', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006006, 'home.pipeline.desc', '从项目定义到第一版源码交付、本机跑通', '{"en-US":"From project definition to first-version source delivery and a local run"}', 'home', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:47.002121', '2026-11-13 01:09:47.002124', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006007, 'home.pipeline.define', '定义项目', '{"en-US":"Define project"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.003508', '2026-11-13 01:09:47.003511', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006008, 'home.pipeline.defineNote', '需求 · 权限 · 数据边界', '{"en-US":"Requirements · permissions · data scope"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.007736', '2026-11-13 01:09:47.007739', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006009, 'home.pipeline.generate', 'AI 生成', '{"en-US":"AI generation"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.008920', '2026-11-13 01:09:47.008923', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006010, 'home.pipeline.generateNote', 'SQL · 前端 · 后端', '{"en-US":"SQL · frontend · backend"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.010148', '2026-11-13 01:09:47.010151', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006011, 'home.pipeline.deliver', '仓库交付', '{"en-US":"Repository delivery"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.011385', '2026-11-13 01:09:47.011388', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006012, 'home.pipeline.deliverNote', 'GitLab · 初始推送', '{"en-US":"GitLab · initial push"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.012481', '2026-11-13 01:09:47.012483', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006013, 'home.pipeline.iterate', '持续迭代', '{"en-US":"Iterate"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.013566', '2026-11-13 01:09:47.013568', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006014, 'home.pipeline.iterateNote', 'AI 协作 · CI/CD', '{"en-US":"AI collaboration · CI/CD"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.014736', '2026-11-13 01:09:47.014739', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006015, 'home.pipeline.open', '进入项目工厂', '{"en-US":"Open project factory"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.015919', '2026-11-13 01:09:47.015921', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006016, 'home.todo.heading', '待办与提醒', '{"en-US":"To-dos and reminders"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.017283', '2026-11-13 01:09:47.017289', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006017, 'home.todo.desc', '你需要关注的下一步', '{"en-US":"What needs your attention next"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.018849', '2026-11-13 01:09:47.018852', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006018, 'home.todo.countTag', '{count} 项待处理', '{"en-US":"{count} pending"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.020219', '2026-11-13 01:09:47.020222', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006019, 'home.projects.heading', '正在使用的项目', '{"en-US":"Projects in use"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.024888', '2026-11-13 01:09:47.024891', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006020, 'home.projects.desc', '从这里进入业务后台或查看项目配置', '{"en-US":"Open a business console or review project settings"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.026637', '2026-11-13 01:09:47.026644', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006021, 'home.projects.manageAll', '管理全部', '{"en-US":"Manage all"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.029942', '2026-11-13 01:09:47.029953', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006022, 'home.stat.ai.title', 'AI 服务状态', '{"en-US":"AI service"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.032828', '2026-11-13 01:09:47.032839', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006023, 'home.stat.ai.ok', '运行正常', '{"en-US":"Running"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.037204', '2026-11-13 01:09:47.037227', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006024, 'home.stat.ai.off', '未启用', '{"en-US":"Not enabled"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.041570', '2026-11-13 01:09:47.041579', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006025, 'agent.workspace.title', 'AI 工作空间', '{"en-US":"AI workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.043345', '2026-11-13 01:09:47.043350', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006026, 'agent.workspace.subtitle', '可理解项目、生成任务并发起操作', '{"en-US":"Understands projects, creates tasks and starts actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.044741', '2026-11-13 01:09:47.044745', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006027, 'agent.workspace.model', 'Agent · {model}', '{"en-US":"Agent · {model}"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.045997', '2026-11-13 01:09:47.046000', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006028, 'agent.welcome.title', '告诉开物，你想完成什么', '{"en-US":"Tell Kaiwu what you want to get done"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.047306', '2026-11-13 01:09:47.047309', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006029, 'agent.welcome.line1', '从项目查询、代码生成到平台管理，用自然语言描述任务。', '{"en-US":"From project queries to code generation and platform administration, describe the task in plain language."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.048578', '2026-11-13 01:09:47.048581', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006030, 'agent.welcome.line2', '涉及业务数据变更时，你可以先预览，再确认执行。', '{"en-US":"When business data would change, you preview it first and confirm before it runs."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.049826', '2026-11-13 01:09:47.049830', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006031, 'agent.suggest.start', '你可以从这里开始', '{"en-US":"Start here"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.051519', '2026-11-13 01:09:47.051525', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006032, 'agent.suggest.projects.title', '了解我的项目', '{"en-US":"Know my projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.053340', '2026-11-13 01:09:47.053345', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006033, 'agent.suggest.projects.desc', '查询平台项目与运行状态', '{"en-US":"Query platform projects and their status"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.056098', '2026-11-13 01:09:47.056105', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006034, 'agent.suggest.failures.title', '检查交付异常', '{"en-US":"Check delivery issues"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.057787', '2026-11-13 01:09:47.057791', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006035, 'agent.suggest.failures.desc', '查找生成失败与仓库交付问题', '{"en-US":"Find failed generations and repository delivery problems"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.059428', '2026-11-13 01:09:47.059431', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006036, 'agent.suggest.user.title', '创建平台用户', '{"en-US":"Create a platform user"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.060706', '2026-11-13 01:09:47.060709', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006037, 'agent.suggest.user.desc', '生成操作预览，人工确认后执行', '{"en-US":"Preview the change, then confirm it yourself"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.061912', '2026-11-13 01:09:47.061915', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006038, 'agent.suggest.createUser', '帮我创建一个平台用户', '{"en-US":"Create a platform user for me"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.063036', '2026-11-13 01:09:47.063039', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006039, 'agent.suggest.generate.title', '发起项目生成', '{"en-US":"Start a project generation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.064168', '2026-11-13 01:09:47.064171', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006040, 'agent.suggest.generate.desc', '从需求描述开始定义业务系统', '{"en-US":"Define a business system from a requirement description"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.065386', '2026-11-13 01:09:47.065389', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006041, 'agent.chat.recent', '最近会话', '{"en-US":"Recent conversations"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.066507', '2026-11-13 01:09:47.066509', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006042, 'agent.chat.footerTitle', '个人记忆与历史对话', '{"en-US":"Personal memories and history"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.067689', '2026-11-13 01:09:47.067692', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006043, 'agent.chat.footerDesc', '与你的传统模式账号共享', '{"en-US":"Shared with your classic-mode account"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.068884', '2026-11-13 01:09:47.068887', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006044, 'agent.inspector.title', '上下文与操作', '{"en-US":"Context and actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.071247', '2026-11-13 01:09:47.071260', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006045, 'agent.inspector.desc', 'AI 理解你的当前项目、权限与业务上下文，敏感操作由你审核。', '{"en-US":"The AI works within your projects, permissions and business context. You review sensitive actions."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.073685', '2026-11-13 01:09:47.073690', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006046, 'agent.inspector.scope', '01 · 项目范围', '{"en-US":"01 · Project scope"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.075233', '2026-11-13 01:09:47.075236', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006047, 'agent.inspector.current', '当前上下文', '{"en-US":"Current context"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.076516', '2026-11-13 01:09:47.076518', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006048, 'agent.inspector.workspace', '{name} 工作空间', '{"en-US":"{name} workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.077723', '2026-11-13 01:09:47.077726', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006049, 'agent.inspector.account', '账号：{name} · {count} 个可访问项目', '{"en-US":"Account: {name} · {count} accessible projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.078840', '2026-11-13 01:09:47.078843', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006050, 'agent.inspector.range', '当前查询范围：', '{"en-US":"Query scope: "}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.079961', '2026-11-13 01:09:47.079963', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006051, 'agent.inspector.allProjects', '全部项目', '{"en-US":"All projects"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.081168', '2026-11-13 01:09:47.081170', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006052, 'agent.inspector.pending', '待确认操作', '{"en-US":"Pending actions"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.082401', '2026-11-13 01:09:47.082405', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006053, 'agent.inspector.pendingDesc', '所有变更先展示操作内容，并在你确认后提交。', '{"en-US":"Every change is previewed first and submitted only after you confirm."}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.083569', '2026-11-13 01:09:47.083572', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006054, 'agent.inspector.empty', '暂无待审核任务', '{"en-US":"Nothing to review"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.084783', '2026-11-13 01:09:47.084786', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006055, 'agent.inspector.emptyHint', '从左侧输入框发起操作', '{"en-US":"Start an action from the message box"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.086239', '2026-11-13 01:09:47.086243', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006056, 'agent.inspector.view', '查看并确认', '{"en-US":"Review and confirm"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.087753', '2026-11-13 01:09:47.087756', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006057, 'agent.inspector.settings', '助手设置', '{"en-US":"Assistant settings"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.090681', '2026-11-13 01:09:47.090684', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006058, 'agent.composer.placeholder', '向开物提问，或描述你要完成的任务…', '{"en-US":"Ask Kaiwu, or describe the task you want done…"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.092099', '2026-11-13 01:09:47.092102', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006059, 'agent.composer.scope', '当前工作空间', '{"en-US":"Current workspace"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.093491', '2026-11-13 01:09:47.093494', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006060, 'agent.composer.confirm', '操作需确认', '{"en-US":"Actions need confirmation"}', 'agent', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.094706', '2026-11-13 01:09:47.094708', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006061, 'home.pipeline.run', '本机运行', '{"en-US":"Run locally"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.095841', '2026-11-13 01:09:47.095844', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006062, 'home.pipeline.runNote', '一条命令接入平台', '{"en-US":"One command to connect"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.097040', '2026-11-13 01:09:47.097043', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006063, 'menu.system.i18n-resources', '国际化资源', '{"en-US":"Internationalization resources","ja-JP":"国際化リソース"}', 'menu', 0, 1, 'ENABLED', '内置菜单名称：/i18n-resources', 1, '2026-11-13 01:09:47.098236', '2026-11-13 01:09:47.098239', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006067, 'roles.menuSearch', '搜索菜单名称或权限码', '{"en-US":"Search menu name or permission code","ja-JP":"メニュー名または権限コードで検索"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.099470', '2026-11-13 01:09:47.099473', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006068, 'roles.menuSelected', '已选 {selected} / {total}', '{"en-US":"{selected} / {total} selected","ja-JP":"{selected} / {total} 件選択"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.100660', '2026-11-13 01:09:47.100664', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006069, 'roles.menuSelectAll', '全选', '{"en-US":"Select all","ja-JP":"すべて選択"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.102582', '2026-11-13 01:09:47.102589', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006070, 'roles.menuNoMatch', '没有匹配的菜单', '{"en-US":"No matching menus","ja-JP":"一致するメニューはありません"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.105305', '2026-11-13 01:09:47.105318', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006071, 'projectSelect.title', '选择要进入的项目', '{"en-US":"Choose a project","ja-JP":"入るプロジェクトを選択"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.107195', '2026-11-13 01:09:47.107199', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006072, 'projectSelect.subtitle', '以下是你有权访问的项目', '{"en-US":"Projects you have access to","ja-JP":"アクセス権のあるプロジェクト"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.108512', '2026-11-13 01:09:47.108515', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006073, 'projectSelect.denied', '你没有访问「{project}」的权限，或该项目未启用、尚未配置后台入口。请从下方选择其他项目。', '{"en-US":"You do not have access to \"{project}\", or the project is disabled or has no admin entry. Please choose another project below.","ja-JP":"「{project}」へのアクセス権がないか、プロジェクトが無効、または管理画面の入口が未設定です。下から別のプロジェクトを選択してください。"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.109716', '2026-11-13 01:09:47.109719', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006074, 'projectSelect.emptyTitle', '还没有可访问的项目', '{"en-US":"No accessible projects yet","ja-JP":"アクセスできるプロジェクトはまだありません"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.110817', '2026-11-13 01:09:47.110820', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006075, 'projectSelect.emptyDesc', '请联系项目管理员把你加入项目，或换一个账号登录。', '{"en-US":"Ask a project administrator to add you to a project, or sign in with another account.","ja-JP":"プロジェクト管理者に追加を依頼するか、別のアカウントでサインインしてください。"}', 'projectSelect', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.111998', '2026-11-13 01:09:47.112000', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006076, 'home.todo.overdue', '已逾期', '{"en-US":"Overdue","ja-JP":"期限切れ"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.113097', '2026-11-13 01:09:47.113099', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006077, 'home.todo.dueAt', '截止 {time}', '{"en-US":"Due {time}","ja-JP":"期限 {time}"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.114327', '2026-11-13 01:09:47.114331', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006078, 'home.todo.more', '还有 {count} 项未显示', '{"en-US":"{count} more not shown","ja-JP":"ほか {count} 件は非表示"}', 'home', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.115647', '2026-11-13 01:09:47.115651', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006100, 'projects.totalCount', '共 {count} 个项目', '{"en-US":"{count} projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.117060', '2026-11-13 01:09:47.117067', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006101, 'projects.resetSearch', '重置', '{"en-US":"Reset"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.118925', '2026-11-13 01:09:47.118931', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006200, 'projects.tab.all', '全部项目', '{"en-US":"All projects"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.120386', '2026-11-13 01:09:47.120391', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006201, 'projects.tab.active', '已启用', '{"en-US":"Enabled"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.122103', '2026-11-13 01:09:47.122111', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006202, 'projects.tab.builtIn', '平台内置', '{"en-US":"Built-in"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.123483', '2026-11-13 01:09:47.123486', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006203, 'projects.generation.title', '生成与交付', '{"en-US":"Generation & delivery"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.124700', '2026-11-13 01:09:47.124703', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006204, 'projects.generation.builtIn', '系统内置', '{"en-US":"Built-in system"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.125832', '2026-11-13 01:09:47.125835', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006205, 'projects.generation.none', '尚未生成', '{"en-US":"Not generated"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.127014', '2026-11-13 01:09:47.127017', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006206, 'projects.generation.running', '生成中', '{"en-US":"Generating"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.128209', '2026-11-13 01:09:47.128212', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006207, 'projects.generation.failed', '生成失败', '{"en-US":"Generation failed"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.129380', '2026-11-13 01:09:47.129384', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006209, 'projects.generation.done', '交付完成', '{"en-US":"Delivered"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.131612', '2026-11-13 01:09:47.131615', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006210, 'projects.backendNotConfigured', '尚未配置', '{"en-US":"Not configured"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.132703', '2026-11-13 01:09:47.132706', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006211, 'projects.openAdmin', '打开管理后台', '{"en-US":"Open admin site"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:47.133809', '2026-11-13 01:09:47.133812', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006212, 'dicts.localeHelp.open', '查看 BCP 47 规范', '{"en-US":"View BCP 47 rules","ja-JP":"BCP 47 の規則を見る"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.314269', '2026-11-13 01:09:48.314269', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006213, 'dicts.localeHelp.title', 'BCP 47 语言标签规范', '{"en-US":"BCP 47 language tag rules","ja-JP":"BCP 47 言語タグの規則"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.327194', '2026-11-13 01:09:48.327194', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006214, 'dicts.localeHelp.intro', '语言代码会用于界面语言包、日期与数字格式化以及 Accept-Language 请求头，必须写成规范的 BCP 47 标签，大小写也要符合规范。', '{"en-US":"Locale codes drive UI language packs, date and number formatting, and the Accept-Language header, so they must be canonical BCP 47 tags with the correct letter case.","ja-JP":"言語コードは UI の言語パック、日付・数値の書式、Accept-Language ヘッダーに使われるため、大文字・小文字も含めて正規の BCP 47 タグで記述してください。"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.338630', '2026-11-13 01:09:48.338630', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006215, 'dicts.localeHelp.structure', '标签结构', '{"en-US":"Tag structure","ja-JP":"タグの構造"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.349334', '2026-11-13 01:09:48.349334', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006216, 'dicts.localeHelp.pattern', '语言[-文字][-地区]', '{"en-US":"language[-Script][-REGION]","ja-JP":"言語[-文字][-地域]"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.361554', '2026-11-13 01:09:48.361554', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006217, 'dicts.localeHelp.part.language', '语言：2–3 位小写字母（ISO 639），如 zh、en、ja', '{"en-US":"Language: 2–3 lowercase letters (ISO 639), e.g. zh, en, ja","ja-JP":"言語：小文字 2～3 文字（ISO 639）、例：zh、en、ja"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.373909', '2026-11-13 01:09:48.373909', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006218, 'dicts.localeHelp.part.script', '文字（可选）：4 位字母、首字母大写（ISO 15924），如 Hans、Hant', '{"en-US":"Script (optional): 4 letters, first letter uppercase (ISO 15924), e.g. Hans, Hant","ja-JP":"文字（任意）：先頭のみ大文字の 4 文字（ISO 15924）、例：Hans、Hant"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.385146', '2026-11-13 01:09:48.385146', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006219, 'dicts.localeHelp.part.region', '地区（可选）：2 位大写字母（ISO 3166-1）或 3 位数字（UN M.49），如 CN、US、419', '{"en-US":"Region (optional): 2 uppercase letters (ISO 3166-1) or 3 digits (UN M.49), e.g. CN, US, 419","ja-JP":"地域（任意）：大文字 2 文字（ISO 3166-1）または数字 3 桁（UN M.49）、例：CN、US、419"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.396464', '2026-11-13 01:09:48.396464', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006220, 'dicts.localeHelp.common', '常用标签', '{"en-US":"Common tags","ja-JP":"よく使うタグ"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.407271', '2026-11-13 01:09:48.407271', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006221, 'dicts.localeHelp.colCode', '标签', '{"en-US":"Tag","ja-JP":"タグ"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.417280', '2026-11-13 01:09:48.417280', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006222, 'dicts.localeHelp.colName', '语言', '{"en-US":"Language","ja-JP":"言語"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.428282', '2026-11-13 01:09:48.428282', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006223, 'dicts.localeHelp.colAction', '操作', '{"en-US":"Actions","ja-JP":"操作"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.438553', '2026-11-13 01:09:48.438553', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006224, 'dicts.localeHelp.use', '使用', '{"en-US":"Use","ja-JP":"使用"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.448377', '2026-11-13 01:09:48.448377', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006225, 'dicts.localeHelp.mistakes', '常见错误', '{"en-US":"Common mistakes","ja-JP":"よくある誤り"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.458109', '2026-11-13 01:09:48.458109', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006226, 'dicts.localeHelp.colWrong', '错误写法', '{"en-US":"Wrong","ja-JP":"誤り"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.467818', '2026-11-13 01:09:48.467818', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006227, 'dicts.localeHelp.colRight', '正确写法', '{"en-US":"Correct","ja-JP":"正しい表記"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.478252', '2026-11-13 01:09:48.478252', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006228, 'dicts.localeHelp.colReason', '原因', '{"en-US":"Reason","ja-JP":"理由"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.488094', '2026-11-13 01:09:48.488094', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006229, 'dicts.localeHelp.reason.underscore', '子标签之间用连字符 -，不能用下划线 _', '{"en-US":"Separate subtags with a hyphen (-), not an underscore (_)","ja-JP":"サブタグの区切りはハイフン（-）で、アンダースコア（_）は使えません"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.498120', '2026-11-13 01:09:48.498120', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006230, 'dicts.localeHelp.reason.regionCase', '地区子标签必须大写', '{"en-US":"The region subtag must be uppercase","ja-JP":"地域サブタグは大文字で記述します"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.508357', '2026-11-13 01:09:48.508357', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006231, 'dicts.localeHelp.reason.scriptCase', '文字子标签首字母大写，地区子标签全大写', '{"en-US":"Capitalize the script subtag and uppercase the region subtag","ja-JP":"文字サブタグは先頭のみ大文字、地域サブタグはすべて大文字です"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.517497', '2026-11-13 01:09:48.517497', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006232, 'dicts.localeHelp.reason.language', 'jp 是国家/地区代码，日语的语言代码是 ja', '{"en-US":"jp is a country code; the language code for Japanese is ja","ja-JP":"jp は国・地域コードで、日本語の言語コードは ja です"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.526894', '2026-11-13 01:09:48.526894', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006233, 'dicts.localeHelp.registry', '完整子标签清单：IANA Language Subtag Registry', '{"en-US":"Full subtag list: IANA Language Subtag Registry","ja-JP":"サブタグの全一覧：IANA Language Subtag Registry"}', 'dicts', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.535646', '2026-11-13 01:09:48.535646', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006234, 'dict.project.generation.mode.DDL_SCAFFOLD', 'DDL 确定性生成', '{"en-US":"Deterministic from DDL","ja-JP":"DDL から確定的に生成"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.826322', '2026-11-13 01:09:48.826322', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006235, 'dictType.security.session.source', '会话来源', '{"en-US":"Session source","ja-JP":"セッションの発行元"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.837450', '2026-11-13 01:09:48.837450', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006236, 'dict.security.session.source.WEB', '网页登录', '{"en-US":"Web sign-in","ja-JP":"Web ログイン"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.849166', '2026-11-13 01:09:48.849166', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006237, 'dict.security.session.source.CLI', 'CLI 授权', '{"en-US":"CLI authorization","ja-JP":"CLI 認可"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.860312', '2026-11-13 01:09:48.860312', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006238, 'device.title', '授权命令行工具', '{"en-US":"Authorize a command-line tool","ja-JP":"コマンドラインツールを認可"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.870129', '2026-11-13 01:09:48.870129', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006239, 'device.intro', '允许后，该工具将以你的身份操作平台，权限与你本人相同，最长 7 天后需要重新授权。只允许你自己刚刚发起的请求。', '{"en-US":"Once allowed, the tool acts on the platform as you, with the same permissions, for at most 7 days. Only allow a request you just started yourself.","ja-JP":"許可すると、このツールはあなたと同じ権限で最長 7 日間プラットフォームを操作します。自分で開始したリクエストだけを許可してください。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.880860', '2026-11-13 01:09:48.880860', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006240, 'device.codeLabel', '授权码', '{"en-US":"Authorization code","ja-JP":"認可コード"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.890915', '2026-11-13 01:09:48.890915', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006241, 'device.codePlaceholder', '输入命令行里显示的授权码，例如 WDJB-MJHT', '{"en-US":"Enter the code shown in your terminal, e.g. WDJB-MJHT","ja-JP":"ターミナルに表示されたコードを入力（例：WDJB-MJHT）"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.900698', '2026-11-13 01:09:48.900698', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006242, 'device.lookup', '查看请求', '{"en-US":"Look up request","ja-JP":"リクエストを確認"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.910721', '2026-11-13 01:09:48.910721', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006243, 'device.client', '客户端', '{"en-US":"Client","ja-JP":"クライアント"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.920061', '2026-11-13 01:09:48.920061', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006244, 'device.requestIp', '发起地址', '{"en-US":"Requested from","ja-JP":"要求元"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.930237', '2026-11-13 01:09:48.930237', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006245, 'device.requestedAt', '发起时间', '{"en-US":"Requested at","ja-JP":"要求日時"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.939954', '2026-11-13 01:09:48.939954', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006246, 'device.approve', '允许', '{"en-US":"Allow","ja-JP":"許可"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.948664', '2026-11-13 01:09:48.948664', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006247, 'device.deny', '拒绝', '{"en-US":"Deny","ja-JP":"拒否"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.958341', '2026-11-13 01:09:48.958341', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006248, 'device.approved', '已允许，可以回到命令行继续操作。', '{"en-US":"Allowed. You can return to the terminal.","ja-JP":"許可しました。ターミナルに戻って続行できます。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.967938', '2026-11-13 01:09:48.967938', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006249, 'device.denied', '已拒绝，该工具不会获得访问权限。', '{"en-US":"Denied. The tool will not get access.","ja-JP":"拒否しました。このツールはアクセスできません。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.978392', '2026-11-13 01:09:48.978392', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006250, 'device.notFound', '授权码不存在或已过期，请回到命令行重新执行 kaiwu login。', '{"en-US":"The code does not exist or has expired. Run kaiwu login again in your terminal.","ja-JP":"コードが存在しないか期限切れです。ターミナルで kaiwu login を再実行してください。"}', 'device', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.987926', '2026-11-13 01:09:48.987926', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006251, 'security.sessionSource', '来源', '{"en-US":"Source","ja-JP":"発行元"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:48.997285', '2026-11-13 01:09:48.997285', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000006252, 'security.clientName', '客户端', '{"en-US":"Client","ja-JP":"クライアント"}', 'security', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:49.006849', '2026-11-13 01:09:49.006849', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007100, 'dictType.storage.provider.type', '对象存储类型', '{"en-US":"Object storage type","ja-JP":"オブジェクトストレージ種別"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:49.937023', '2026-11-13 01:09:49.937023', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007101, 'dict.storage.provider.type.ALIYUN_OSS', '阿里云 OSS', '{"en-US":"Alibaba Cloud OSS","ja-JP":"Alibaba Cloud OSS"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:49.956230', '2026-11-13 01:09:49.956230', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007102, 'dict.storage.provider.type.S3_COMPATIBLE_STS', 'S3 兼容（STS）', '{"en-US":"S3 compatible (STS)","ja-JP":"S3 互換（STS）"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:49.973164', '2026-11-13 01:09:49.973164', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007103, 'dictType.storage.binding.status', '项目存储绑定状态', '{"en-US":"Project storage binding status","ja-JP":"プロジェクトストレージ割り当て状態"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:49.989466', '2026-11-13 01:09:49.989466', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007104, 'dict.storage.binding.status.ACTIVE', '生效', '{"en-US":"Active","ja-JP":"有効"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.005093', '2026-11-13 01:09:50.005093', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007105, 'dict.storage.binding.status.READ_ONLY', '只读', '{"en-US":"Read only","ja-JP":"読み取り専用"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.020926', '2026-11-13 01:09:50.020926', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007106, 'dict.storage.binding.status.DISABLED', '停用', '{"en-US":"Disabled","ja-JP":"無効"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.038410', '2026-11-13 01:09:50.038410', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007110, 'menu.system.storage', '对象存储', '{"en-US":"Object storage","ja-JP":"オブジェクトストレージ"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.054399', '2026-11-13 01:09:50.054399', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007111, 'menu.system.permission.system.storage.list', '查看对象存储', '{"en-US":"View object storage","ja-JP":"オブジェクトストレージを表示"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:list', 1, '2026-11-13 01:09:50.071695', '2026-11-13 01:09:50.071695', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007112, 'menu.system.permission.system.storage.save', '保存对象存储', '{"en-US":"Save object storage","ja-JP":"オブジェクトストレージを保存"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:save', 1, '2026-11-13 01:09:50.087461', '2026-11-13 01:09:50.087461', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007113, 'menu.system.permission.system.storage.test', '测试对象存储连接', '{"en-US":"Test object storage connection","ja-JP":"オブジェクトストレージ接続をテスト"}', 'menu', 0, 1, 'ENABLED', '内置按钮菜单名称：system:storage:test', 1, '2026-11-13 01:09:50.103983', '2026-11-13 01:09:50.103983', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007120, 'storage.title', '对象存储', '{"en-US":"Object storage","ja-JP":"オブジェクトストレージ"}', 'storage', 0, 1, 'ENABLED', '页面标题', 1, '2026-11-13 01:09:50.120956', '2026-11-13 01:09:50.120956', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007121, 'storage.subtitle', '登记存储账号并绑定到项目。业务项目只拿到限定在自身前缀的临时凭证，长期密钥不离开平台。', '{"en-US":"Register storage accounts and bind them to projects. Projects only receive short-lived credentials scoped to their own prefix; long-term keys never leave the platform.","ja-JP":"ストレージアカウントを登録してプロジェクトに割り当てます。プロジェクトは自身のプレフィックスに限定された一時認証情報のみを受け取り、長期キーはプラットフォームの外に出ません。"}', 'storage', 0, 1, 'ENABLED', '页面副标题', 1, '2026-11-13 01:09:50.137103', '2026-11-13 01:09:50.137103', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007122, 'storage.tab.accounts', '存储账号', '{"en-US":"Accounts","ja-JP":"アカウント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.152782', '2026-11-13 01:09:50.152782', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007123, 'storage.tab.bindings', '项目绑定', '{"en-US":"Project bindings","ja-JP":"プロジェクト割り当て"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.168297', '2026-11-13 01:09:50.168297', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007124, 'storage.account.add', '新增账号', '{"en-US":"Add account","ja-JP":"アカウントを追加"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.183666', '2026-11-13 01:09:50.183666', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007125, 'storage.account.edit', '编辑账号', '{"en-US":"Edit account","ja-JP":"アカウントを編集"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.200204', '2026-11-13 01:09:50.200204', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007126, 'storage.account.test', '测试连接', '{"en-US":"Test connection","ja-JP":"接続テスト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.216643', '2026-11-13 01:09:50.216643', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007127, 'storage.account.name', '名称', '{"en-US":"Name","ja-JP":"名前"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.232037', '2026-11-13 01:09:50.232037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007128, 'storage.account.code', '编码', '{"en-US":"Code","ja-JP":"コード"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.247999', '2026-11-13 01:09:50.247999', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007129, 'storage.account.providerType', '存储类型', '{"en-US":"Type","ja-JP":"種別"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.263712', '2026-11-13 01:09:50.263712', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007130, 'storage.account.endpoint', '存储地址', '{"en-US":"Endpoint","ja-JP":"エンドポイント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.279692', '2026-11-13 01:09:50.279692', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007131, 'storage.account.region', '区域', '{"en-US":"Region","ja-JP":"リージョン"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.295586', '2026-11-13 01:09:50.295586', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007132, 'storage.account.bucket', '桶名', '{"en-US":"Bucket","ja-JP":"バケット"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.310978', '2026-11-13 01:09:50.310978', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007133, 'storage.account.pathStyle', 'Path-style 访问', '{"en-US":"Path-style access","ja-JP":"パススタイルアクセス"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.326145', '2026-11-13 01:09:50.326145', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007134, 'storage.account.stsEndpoint', 'STS 地址', '{"en-US":"STS endpoint","ja-JP":"STS エンドポイント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.341706', '2026-11-13 01:09:50.341706', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007135, 'storage.account.roleArn', '角色 ARN', '{"en-US":"Role ARN","ja-JP":"ロール ARN"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.357200', '2026-11-13 01:09:50.357200', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007136, 'storage.account.accessKeyId', 'AccessKey ID', '{"en-US":"AccessKey ID","ja-JP":"AccessKey ID"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.373519', '2026-11-13 01:09:50.373519', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007137, 'storage.account.accessKeySecret', 'AccessKey Secret', '{"en-US":"AccessKey secret","ja-JP":"AccessKey シークレット"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.389674', '2026-11-13 01:09:50.389674', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007138, 'storage.account.secretKeep', '已配置，留空表示不修改', '{"en-US":"Configured. Leave blank to keep it.","ja-JP":"設定済み。空欄のままにすると変更しません。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.405858', '2026-11-13 01:09:50.405858', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007139, 'storage.account.ttl', '凭证有效期（秒）', '{"en-US":"Credential lifetime (seconds)","ja-JP":"認証情報の有効期間（秒）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.422422', '2026-11-13 01:09:50.422422', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007140, 'storage.account.enabled', '状态', '{"en-US":"Status","ja-JP":"状態"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.438017', '2026-11-13 01:09:50.438017', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007141, 'storage.account.bindingCount', '绑定数', '{"en-US":"Bindings","ja-JP":"割り当て数"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.454374', '2026-11-13 01:09:50.454374', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007142, 'storage.account.lastTest', '最近测试', '{"en-US":"Last test","ja-JP":"最終テスト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.470741', '2026-11-13 01:09:50.470741', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007143, 'storage.account.saved', '账号已保存', '{"en-US":"Account saved","ja-JP":"アカウントを保存しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.488480', '2026-11-13 01:09:50.488480', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007144, 'storage.account.testSuccess', '连接成功，用时 {latency} ms', '{"en-US":"Connected in {latency} ms","ja-JP":"{latency} ms で接続しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.503935', '2026-11-13 01:09:50.503935', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007145, 'storage.account.testFailed', '连接失败：{message}', '{"en-US":"Connection failed: {message}","ja-JP":"接続に失敗しました：{message}"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.521038', '2026-11-13 01:09:50.521038', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007146, 'storage.account.aliyunHint', '阿里云：存储地址填 https://oss-<区域>.aliyuncs.com，STS 地址填 https://sts.<区域>.aliyuncs.com，并填写可被扮演的 RAM 角色 ARN。所填主机必须在 kaiwu.storage.allowed-hosts 白名单内。', '{"en-US":"Alibaba Cloud: use https://oss-<region>.aliyuncs.com as the endpoint, https://sts.<region>.aliyuncs.com as the STS endpoint, and an assumable RAM role ARN. Hosts must be listed in kaiwu.storage.allowed-hosts.","ja-JP":"Alibaba Cloud：エンドポイントに https://oss-<リージョン>.aliyuncs.com、STS エンドポイントに https://sts.<リージョン>.aliyuncs.com を指定し、引き受け可能な RAM ロール ARN を入力してください。ホストは kaiwu.storage.allowed-hosts に登録されている必要があります。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.537449', '2026-11-13 01:09:50.537449', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007147, 'storage.binding.add', '绑定项目', '{"en-US":"Bind project","ja-JP":"プロジェクトを割り当て"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.554505', '2026-11-13 01:09:50.554505', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007148, 'storage.binding.project', '项目', '{"en-US":"Project","ja-JP":"プロジェクト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.569929', '2026-11-13 01:09:50.569929', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007149, 'storage.binding.storageName', '存储名', '{"en-US":"Storage name","ja-JP":"ストレージ名"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.588789', '2026-11-13 01:09:50.588789', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007150, 'storage.binding.account', '存储账号', '{"en-US":"Storage account","ja-JP":"ストレージアカウント"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.605094', '2026-11-13 01:09:50.605094', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007151, 'storage.binding.status', '状态', '{"en-US":"Status","ja-JP":"状態"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.622382', '2026-11-13 01:09:50.622382', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007152, 'storage.binding.maxObjectSize', '单文件上限（MB）', '{"en-US":"Max file size (MB)","ja-JP":"最大ファイルサイズ（MB）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.637595', '2026-11-13 01:09:50.637595', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007153, 'storage.binding.contentTypes', '允许的类型', '{"en-US":"Allowed types","ja-JP":"許可する種類"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.654138', '2026-11-13 01:09:50.654138', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007154, 'storage.binding.contentTypesAll', '不限', '{"en-US":"Any","ja-JP":"制限なし"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.671902', '2026-11-13 01:09:50.671902', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007155, 'storage.binding.prefix', '对象前缀', '{"en-US":"Object prefix","ja-JP":"オブジェクトプレフィックス"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.687566', '2026-11-13 01:09:50.687566', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007156, 'storage.binding.storageRef', '存储引用', '{"en-US":"Storage ref","ja-JP":"ストレージ参照"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.703196', '2026-11-13 01:09:50.703196', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007157, 'storage.binding.createdAt', '创建时间', '{"en-US":"Created at","ja-JP":"作成日時"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.720107', '2026-11-13 01:09:50.720107', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007158, 'storage.binding.saved', '绑定已保存', '{"en-US":"Binding saved","ja-JP":"割り当てを保存しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.736723', '2026-11-13 01:09:50.736723', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007159, 'storage.binding.switchHint', '该存储名已有生效绑定且账号不同时，旧绑定会转为只读，历史文件仍可读取。', '{"en-US":"If this storage name already has an active binding to another account, the old binding becomes read-only so existing files stay readable.","ja-JP":"このストレージ名に別アカウントの有効な割り当てがある場合、古い割り当ては読み取り専用になり、既存ファイルは引き続き読み取れます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.755118', '2026-11-13 01:09:50.755118', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007160, 'storage.binding.makeActive', '设为生效', '{"en-US":"Activate","ja-JP":"有効にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.773083', '2026-11-13 01:09:50.773083', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007161, 'storage.binding.makeReadOnly', '改为只读', '{"en-US":"Make read-only","ja-JP":"読み取り専用にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.789491', '2026-11-13 01:09:50.789491', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007162, 'storage.binding.disable', '停用', '{"en-US":"Disable","ja-JP":"無効にする"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.805312', '2026-11-13 01:09:50.805312', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007163, 'storage.binding.statusUpdated', '状态已更新', '{"en-US":"Status updated","ja-JP":"状態を更新しました"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.821476', '2026-11-13 01:09:50.821476', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007164, 'storage.binding.disableConfirm', '停用后该绑定不再签发任何凭证，使用它的历史文件将无法读取。确定停用？', '{"en-US":"A disabled binding issues no credentials, so files stored through it can no longer be read. Disable it?","ja-JP":"無効にした割り当てでは認証情報が発行されず、それを通じて保存したファイルは読み取れなくなります。無効にしますか？"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.838190', '2026-11-13 01:09:50.838190', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007165, 'storage.actions', '操作', '{"en-US":"Actions","ja-JP":"操作"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.853884', '2026-11-13 01:09:50.853884', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007166, 'storage.account.empty', '还没有存储账号。先新增一个阿里云 OSS 或 MinIO 账号，再把项目绑定到它。', '{"en-US":"No storage accounts yet. Add an Alibaba Cloud OSS or MinIO account, then bind projects to it.","ja-JP":"ストレージアカウントがまだありません。Alibaba Cloud OSS または MinIO のアカウントを追加してから、プロジェクトを割り当ててください。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.870806', '2026-11-13 01:09:50.870806', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007167, 'storage.binding.empty', '还没有项目绑定。绑定后，业务项目通过 starter 即可读写自己前缀下的文件。', '{"en-US":"No project bindings yet. Once bound, a project reads and writes files under its own prefix through the starter.","ja-JP":"プロジェクトの割り当てがまだありません。割り当て後、プロジェクトは starter を通じて自身のプレフィックス配下のファイルを読み書きできます。"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.888926', '2026-11-13 01:09:50.888926', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007168, 'storage.binding.allProjects', '全部项目', '{"en-US":"All projects","ja-JP":"すべてのプロジェクト"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.905332', '2026-11-13 01:09:50.905332', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007169, 'storage.binding.contentTypesPlaceholder', '如 image/png，回车添加；留空不限制', '{"en-US":"e.g. image/png, press Enter to add; leave empty for any","ja-JP":"例：image/png（Enter で追加。空欄なら制限なし）"}', 'storage', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:50.922050', '2026-11-13 01:09:50.922050', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007200, 'org.bulkAdd', '批量添加人员', '{"en-US":"Add members"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.202967', '2026-11-13 01:09:51.202967', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007201, 'org.bulkTitle', '添加人员到 {name}', '{"en-US":"Add members to {name}"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.215551', '2026-11-13 01:09:51.215551', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007202, 'org.bulkHint', '选择要添加的用户，最多 100 人。已有主部门保持不变；没有归属的用户将以该部门为主部门。', '{"en-US":"Select up to 100 users. Existing primary departments stay unchanged; this becomes the primary department for unassigned users."}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.225328', '2026-11-13 01:09:51.225328', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007203, 'org.bulkAdded', '已添加 {count} 人', '{"en-US":"Added {count} members"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.234209', '2026-11-13 01:09:51.234209', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007204, 'org.bulkSelected', '已选择 {count} 人（最多 100 人）', '{"en-US":"{count} selected (maximum 100)"}', 'org', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.243505', '2026-11-13 01:09:51.243505', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007300, 'dictType.project.handover.status', '配置移交记录状态', '{"en-US":"Config handover record status"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.552941', '2026-11-13 01:09:51.552941', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007301, 'dict.project.handover.status.SUCCESS', '成功', '{"en-US":"Succeeded"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.562797', '2026-11-13 01:09:51.562797', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007302, 'dict.project.handover.status.FAILED', '失败', '{"en-US":"Failed"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.572107', '2026-11-13 01:09:51.572107', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007303, 'dictType.project.handover.action', '配置移交动作', '{"en-US":"Config handover action"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.582551', '2026-11-13 01:09:51.582551', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007304, 'dict.project.handover.action.CREATE', '新增', '{"en-US":"Add"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.591496', '2026-11-13 01:09:51.591496', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007305, 'dict.project.handover.action.UPDATE', '更新', '{"en-US":"Update"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.600412', '2026-11-13 01:09:51.600412', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007306, 'dict.project.handover.action.REMOVED_AT_SOURCE', '源环境已删除', '{"en-US":"Removed at source"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.609428', '2026-11-13 01:09:51.609428', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007307, 'dict.project.handover.action.DRIFT', '仅目标环境有', '{"en-US":"Only in target"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.625447', '2026-11-13 01:09:51.625447', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007308, 'dictType.project.handover.resource', '配置移交资源类型', '{"en-US":"Config handover resource type"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.634968', '2026-11-13 01:09:51.634968', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007309, 'dict.project.handover.resource.DICT', '字典', '{"en-US":"Dictionary"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.645063', '2026-11-13 01:09:51.645063', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007310, 'dict.project.handover.resource.DICT_ITEM', '字典项', '{"en-US":"Dictionary item"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.654797', '2026-11-13 01:09:51.654797', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007311, 'dict.project.handover.resource.CONFIG', '参数配置', '{"en-US":"Config"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.664427', '2026-11-13 01:09:51.664427', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007312, 'dict.project.handover.resource.MENU', '菜单', '{"en-US":"Menu"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.673851', '2026-11-13 01:09:51.673851', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007313, 'dict.project.handover.resource.I18N', '国际化资源', '{"en-US":"I18n resource"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.682697', '2026-11-13 01:09:51.682697', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007314, 'dict.project.handover.resource.ROLE', '角色', '{"en-US":"Role"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.692073', '2026-11-13 01:09:51.692073', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007315, 'dict.project.handover.resource.ROLE_GRANT', '角色授权', '{"en-US":"Role grant"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.702306', '2026-11-13 01:09:51.702306', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007316, 'projects.configHandover', '配置移交', '{"en-US":"Config handover"}', 'projects', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.712415', '2026-11-13 01:09:51.712415', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007317, 'configHandover.export.title', '导出移交包', '{"en-US":"Export handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.722655', '2026-11-13 01:09:51.722655', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007318, 'configHandover.export.desc', '导出当前项目的字典、参数配置、菜单、自定义角色授权、定时任务和国际化资源，到另一个环境导入。包里不含成员、密钥和敏感配置；定时任务在目标环境新建时默认停用。', '{"en-US":"Export this project''s dictionaries, configs, menus, custom role grants, scheduled jobs and i18n resources to import in another environment. The package contains no members, secrets or sensitive configs; scheduled jobs are created disabled in the target."}', 'configHandover', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:51.731677', '2026-11-13 01:09:52.233399', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007319, 'configHandover.export.button', '导出并下载', '{"en-US":"Export and download"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.741409', '2026-11-13 01:09:51.741409', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007320, 'configHandover.export.done', '已导出 {name}', '{"en-US":"Exported {name}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.750285', '2026-11-13 01:09:51.750285', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007321, 'configHandover.export.stats', '字典 {dicts} · 配置 {configs} · 菜单 {menus} · 角色 {roles} · 定时任务 {jobs} · 国际化 {i18n}', '{"en-US":"Dictionaries {dicts} · Configs {configs} · Menus {menus} · Roles {roles} · Jobs {jobs} · I18n {i18n}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 2, '2026-11-13 01:09:51.760255', '2026-11-13 01:09:52.236942', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007322, 'configHandover.export.warnings', '导出时有 {count} 项需要注意', '{"en-US":"{count} items need attention"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.769319', '2026-11-13 01:09:51.769319', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007323, 'configHandover.import.title', '导入移交包', '{"en-US":"Import handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.782003', '2026-11-13 01:09:51.782003', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007324, 'configHandover.import.desc', '上传从其他环境导出的移交包，先预览差异，确认后再执行。授权与删除默认不执行，需要逐项勾选。', '{"en-US":"Upload a package exported from another environment, preview the differences, then run it. Access and deletions are off by default and need explicit selection."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.791543', '2026-11-13 01:09:51.791543', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007325, 'configHandover.import.upload', '点击或拖拽移交包（.json）到此处', '{"en-US":"Click or drag a handover package (.json) here"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.800911', '2026-11-13 01:09:51.800911', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007326, 'configHandover.import.invalid', '不是有效的移交包', '{"en-US":"Not a valid handover package"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.810753', '2026-11-13 01:09:51.810753', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007327, 'configHandover.import.versionUnsupported', '不支持的移交包版本 {version}', '{"en-US":"Unsupported package version {version}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.820548', '2026-11-13 01:09:51.820548', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007328, 'configHandover.import.projectMismatch', '移交包属于项目 {packageProject}，当前项目是 {project}', '{"en-US":"The package belongs to project {packageProject}, but the current project is {project}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.832443', '2026-11-13 01:09:51.832443', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007329, 'configHandover.import.source', '来源 {host}，导出于 {time}，导出人 {user}', '{"en-US":"Source {host}, exported at {time} by {user}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.842101', '2026-11-13 01:09:51.842101', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007330, 'configHandover.plan.missingPermissions', '当前账号缺少平台权限：{codes}，补齐后才能执行', '{"en-US":"Your account lacks platform permissions: {codes}. Grant them before running the import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.851126', '2026-11-13 01:09:51.851126', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007331, 'configHandover.plan.alreadyApplied', '这个移交包已在 {time} 导入过（执行人 {user}），再次导入只会处理仍有差异的部分', '{"en-US":"This package was already imported at {time} (by {user}). Importing again only handles what still differs"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.861045', '2026-11-13 01:09:51.861045', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007332, 'configHandover.plan.noBaseline', '这是该项目第一次通过移交包导入，无法识别「源环境已删除」的内容，从下一次导入开始才会识别。', '{"en-US":"This is the first package import for this project, so content removed at the source cannot be detected yet. Detection starts from the next import."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.870066', '2026-11-13 01:09:51.870066', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007333, 'configHandover.plan.inSync', '目标环境已和移交包一致，没有需要导入的内容', '{"en-US":"The target already matches the package. Nothing to import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.882055', '2026-11-13 01:09:51.882055', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007334, 'configHandover.plan.section.normal', '新增与更新（{count}）', '{"en-US":"Additions and updates ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.891595', '2026-11-13 01:09:51.891595', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007335, 'configHandover.plan.section.access', '授权（{count}）', '{"en-US":"Access ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.900245', '2026-11-13 01:09:51.900245', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007336, 'configHandover.plan.section.accessHint', '授权是安全决策，默认不导入。勾选后只会追加角色和授权，不会撤销目标环境已有的授权。', '{"en-US":"Access is a security decision and is not imported by default. When enabled it only adds roles and grants and never revokes existing ones."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.909804', '2026-11-13 01:09:51.909804', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007337, 'configHandover.plan.access.apply', '同时导入授权', '{"en-US":"Import access as well"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.919609', '2026-11-13 01:09:51.919609', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007338, 'configHandover.plan.section.delete', '源环境已删除（{count}）', '{"en-US":"Removed at source ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.929961', '2026-11-13 01:09:51.929961', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007339, 'configHandover.plan.section.deleteHint', '上次导入时存在，本次移交包里已没有。只删除勾选的条目；平台查不到业务数据是否还在使用某个字典值，删除前请先确认。', '{"en-US":"Present in the last import but missing from this package. Only selected items are deleted. The platform cannot tell whether business data still uses a dictionary value, so confirm before deleting."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.939811', '2026-11-13 01:09:51.939811', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007340, 'configHandover.plan.section.drift', '仅目标环境有（{count}）', '{"en-US":"Only in target ({count})"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.948915', '2026-11-13 01:09:51.948915', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007341, 'configHandover.plan.section.driftHint', '目标环境自己新增的内容，不会被删除或覆盖。', '{"en-US":"Added in the target itself. It is neither deleted nor overwritten."}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.958451', '2026-11-13 01:09:51.958451', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007342, 'configHandover.plan.column.resource', '类型', '{"en-US":"Type"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.968486', '2026-11-13 01:09:51.968486', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007343, 'configHandover.plan.column.key', '标识', '{"en-US":"Key"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.978524', '2026-11-13 01:09:51.978524', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007344, 'configHandover.plan.column.action', '动作', '{"en-US":"Action"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.988279', '2026-11-13 01:09:51.988279', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007345, 'configHandover.plan.column.detail', '说明', '{"en-US":"Details"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.997847', '2026-11-13 01:09:51.997847', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007346, 'configHandover.apply.button', '执行导入', '{"en-US":"Run import"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.006893', '2026-11-13 01:09:52.006893', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007347, 'configHandover.apply.confirm', '将新增或更新 {changes} 项，导入授权 {access} 项，删除 {deletes} 项。确认执行？', '{"en-US":"This will add or update {changes} items, import {access} access items and delete {deletes} items. Continue?"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.015814', '2026-11-13 01:09:52.015814', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007348, 'configHandover.apply.success', '导入完成：新增或更新 {changes} 项，删除 {deletes} 项', '{"en-US":"Import finished: {changes} items added or updated, {deletes} deleted"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.024731', '2026-11-13 01:09:52.024731', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007349, 'configHandover.apply.stale', '目标环境在预览之后发生了变化，已重新生成预览，请核对后再执行', '{"en-US":"The target changed after the preview. The preview was refreshed; review it before running again"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.033262', '2026-11-13 01:09:52.033262', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007350, 'configHandover.apply.nothing', '没有可执行的内容；授权和删除需要先勾选', '{"en-US":"Nothing to run. Access and deletions must be selected first"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.042790', '2026-11-13 01:09:52.042790', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007351, 'configHandover.records.title', '移交记录', '{"en-US":"Handover records"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.051639', '2026-11-13 01:09:52.051639', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007352, 'configHandover.records.time', '执行时间', '{"en-US":"Run at"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.061294', '2026-11-13 01:09:52.061294', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007353, 'configHandover.records.operator', '执行人', '{"en-US":"Run by"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.070657', '2026-11-13 01:09:52.070657', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007354, 'configHandover.records.operatorValue', '用户 {id}', '{"en-US":"User {id}"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.081884', '2026-11-13 01:09:52.081884', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007355, 'configHandover.records.source', '来源', '{"en-US":"Source"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.091230', '2026-11-13 01:09:52.091230', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007356, 'configHandover.records.exportedAt', '导出时间', '{"en-US":"Exported at"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.099927', '2026-11-13 01:09:52.099927', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007357, 'configHandover.records.result', '结果', '{"en-US":"Result"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.109122', '2026-11-13 01:09:52.109122', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007358, 'configHandover.records.changes', '新增与更新', '{"en-US":"Added or updated"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.117879', '2026-11-13 01:09:52.117879', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007359, 'configHandover.records.deletes', '删除', '{"en-US":"Deleted"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.127278', '2026-11-13 01:09:52.127278', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007360, 'configHandover.records.access', '授权', '{"en-US":"Access"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.136221', '2026-11-13 01:09:52.136221', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007361, 'configHandover.records.accessYes', '已导入', '{"en-US":"Imported"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.147021', '2026-11-13 01:09:52.147021', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007362, 'configHandover.records.accessNo', '未导入', '{"en-US":"Not imported"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.156645', '2026-11-13 01:09:52.156645', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007363, 'configHandover.records.reason', '失败原因', '{"en-US":"Failure reason"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.165912', '2026-11-13 01:09:52.165912', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007364, 'configHandover.records.detail', '条目明细', '{"en-US":"Entry details"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.176030', '2026-11-13 01:09:52.176030', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007365, 'configHandover.records.empty', '还没有移交记录', '{"en-US":"No handover records yet"}', 'configHandover', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.185170', '2026-11-13 01:09:52.185170', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007400, 'dict.project.handover.resource.JOB', '定时任务', '{"en-US":"Scheduled job"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.229704', '2026-11-13 01:09:52.229704', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007600, 'ai.models', '模型列表', '{"en-US":"Models"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.394406', '2026-11-13 01:09:52.394406', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007601, 'ai.addModel', '添加模型', '{"en-US":"Add model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.404555', '2026-11-13 01:09:52.404555', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007602, 'ai.editModel', '编辑模型', '{"en-US":"Edit model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.415014', '2026-11-13 01:09:52.415014', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007603, 'ai.modelRoutes', '用途分配', '{"en-US":"Model routes"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.425336', '2026-11-13 01:09:52.425336', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007604, 'ai.planModel', '任务识别模型', '{"en-US":"Planning model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.434828', '2026-11-13 01:09:52.434828', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007605, 'ai.answerModel', '回答模型', '{"en-US":"Answer model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.444880', '2026-11-13 01:09:52.444880', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007606, 'ai.saveRoutes', '保存分配', '{"en-US":"Save routes"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.454430', '2026-11-13 01:09:52.454430', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007607, 'ai.modelsEmpty', '暂无模型', '{"en-US":"No models configured"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.464348', '2026-11-13 01:09:52.464348', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007608, 'ai.routesSaved', '模型用途已保存', '{"en-US":"Model routes saved"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.473753', '2026-11-13 01:09:52.473753', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007609, 'ai.loadFailed', '加载模型配置失败', '{"en-US":"Failed to load models"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.482961', '2026-11-13 01:09:52.482961', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007610, 'ai.selectModel', '选择模型', '{"en-US":"Select model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.492724', '2026-11-13 01:09:52.492724', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007611, 'ai.testModel', '测试模型', '{"en-US":"Test model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.502136', '2026-11-13 01:09:52.502136', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007612, 'ai.modelSaved', '模型已保存', '{"en-US":"Model saved"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.512232', '2026-11-13 01:09:52.512232', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007613, 'ai.defaultModel', '默认模型', '{"en-US":"Default model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.522469', '2026-11-13 01:09:52.522469', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007614, 'ai.modelRoutesHint', '留空使用默认配置', '{"en-US":"Leave empty to use the default model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.531701', '2026-11-13 01:09:52.531701', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007615, 'ai.chooseModel', '选择模型', '{"en-US":"Choose a model"}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.540813', '2026-11-13 01:09:52.540813', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007616, 'ai.routesNeedModels', '未配置默认模型时，请分别选择任务识别和回答模型。', '{"en-US":"Choose both planning and answer models when no default model is configured."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.549483', '2026-11-13 01:09:52.549483', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000007617, 'ai.addressChangedKeyHint', '修改服务地址时，请重新填写 API Key，或明确清除旧密钥。', '{"en-US":"When changing the service URL, enter the API key again or explicitly clear the old key."}', 'ai', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.559491', '2026-11-13 01:09:52.559491', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008502, 'menu.system.permission.system.service-credential.list', '查看服务凭据', '{"en-US":"View service credentials","ja-JP":"サービス認証情報を表示"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.323675', '2026-11-13 01:09:53.323675', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008503, 'menu.system.permission.system.service-credential.manage', '管理服务凭据', '{"en-US":"Manage service credentials","ja-JP":"サービス認証情報を管理"}', 'menu', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.333222', '2026-11-13 01:09:53.333222', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008504, 'serviceCredential.multiDisabled', '多服务凭据尚未启用', '{"en-US":"Service credentials are not enabled","ja-JP":"サービス認証情報は有効になっていません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.342620', '2026-11-13 01:09:53.342620', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008800, 'project.members.candidateLimitExceeded', '候选人数超过上限', '{"en-US":"Candidate limit exceeded","ja-JP":"候補者数が上限を超えました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.373957', '2026-11-13 01:09:53.373957', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008900, 'api.project.backendServiceConflict', '项目后端服务冲突', '{"en-US":"Project backend service conflict","ja-JP":"プロジェクトのバックエンドサービスが競合しています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.631910', '2026-11-13 01:09:53.631910', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008901, 'api.todo.legacyConflict', '待办键已被旧待办占用', '{"en-US":"The todo key is already used by a legacy todo","ja-JP":"このキーは既存のタスクで使用されています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.525543', '2026-11-13 01:09:53.525543', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008902, 'api.todo.sequenceConflict', '待办版本与已有内容冲突', '{"en-US":"The todo version conflicts with existing content","ja-JP":"タスクのバージョンが既存の内容と競合しています"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.540013', '2026-11-13 01:09:53.540013', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008903, 'api.todo.terminalConflict', '已终结的待办不能重新打开', '{"en-US":"A terminal todo cannot be reopened","ja-JP":"終了したタスクは再開できません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.549244', '2026-11-13 01:09:53.549244', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000008904, 'api.todo.openLimitExceeded', '处理人的待办数量已达上限，请稍后重试', '{"en-US":"The recipient todo limit has been reached; try again later","ja-JP":"担当者のタスク数が上限に達しました。後ほど再試行してください"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.559084', '2026-11-13 01:09:53.559084', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009000, 'projects.backendServices.title', '后端服务', '{"en-US":"Backend services","ja-JP":"バックエンドサービス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.663577', '2026-11-13 01:09:53.663577', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009001, 'projects.backendServices.add', '新增服务', '{"en-US":"Add service","ja-JP":"サービスを追加"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.672580', '2026-11-13 01:09:53.672580', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009002, 'projects.backendServices.refresh', '刷新', '{"en-US":"Refresh","ja-JP":"更新"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.680995', '2026-11-13 01:09:53.680995', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009003, 'projects.backendServices.loadFailed', '加载后端服务失败', '{"en-US":"Failed to load backend services","ja-JP":"サービスの読み込みに失敗しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.689982', '2026-11-13 01:09:53.689982', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009004, 'projects.backendServices.saveFailed', '保存后端服务失败', '{"en-US":"Failed to save backend service","ja-JP":"サービスの保存に失敗しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.698472', '2026-11-13 01:09:53.698472', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009005, 'projects.backendServices.saved', '后端服务已更新', '{"en-US":"Backend service updated","ja-JP":"サービスを更新しました"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.707696', '2026-11-13 01:09:53.707696', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009006, 'projects.backendServices.code', '服务编码', '{"en-US":"Service code","ja-JP":"サービスコード"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.715921', '2026-11-13 01:09:53.715921', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009007, 'projects.backendServices.default', '默认服务地址', '{"en-US":"Default service address","ja-JP":"既定サービスのアドレス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.724839', '2026-11-13 01:09:53.724839', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009008, 'projects.backendServices.url', '上游地址', '{"en-US":"Upstream address","ja-JP":"接続先アドレス"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.732994', '2026-11-13 01:09:53.732994', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009009, 'projects.backendServices.status', '状态', '{"en-US":"Status","ja-JP":"状態"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.741294', '2026-11-13 01:09:53.741294', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009010, 'projects.backendServices.actions', '操作', '{"en-US":"Actions","ja-JP":"操作"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.749091', '2026-11-13 01:09:53.749091', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009011, 'projects.backendServices.edit', '修改地址', '{"en-US":"Edit address","ja-JP":"アドレスを変更"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.758232', '2026-11-13 01:09:53.758232', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009012, 'projects.backendServices.statusConfirm', '确认更改服务状态？已发布的路由需要另行撤销或更新。', '{"en-US":"Change this service status? Published routes must be removed or updated separately.","ja-JP":"状態を変更しますか？公開済みルートは別途更新してください。"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.766578', '2026-11-13 01:09:53.766578', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009013, 'projects.backendServices.disable', '停用', '{"en-US":"Disable","ja-JP":"無効化"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.774801', '2026-11-13 01:09:53.774801', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000009014, 'projects.backendServices.enable', '启用', '{"en-US":"Enable","ja-JP":"有効化"}', 'project', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.790965', '2026-11-13 01:09:53.790965', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000012900, 'api.project.dataScopeTooLarge', '数据范围过大，请联系管理员调整', '{"en-US":"Data scope is too large; ask an administrator to adjust it","ja-JP":"データ範囲が大きすぎます。管理者に調整を依頼してください"}', 'api', 0, 1, 'ENABLED', 'ADR 0044：project-access 数据范围超过 6144 字节', 1, '2026-11-13 01:09:52.693037', '2026-11-13 01:09:52.693037', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000012901, 'api.project.dataScopeInvalid', '数据范围配置无效', '{"en-US":"Invalid data scope configuration","ja-JP":"データ範囲の設定が無効です"}', 'api', 0, 1, 'ENABLED', 'ADR 0044：保存角色数据范围校验失败', 1, '2026-11-13 01:09:52.702570', '2026-11-13 01:09:52.702570', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013100, 'dictType.project.data_scope.type', '数据范围类型', '{"en-US":"Data scope type"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.831332', '2026-11-13 01:09:52.831332', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013101, 'dict.project.data_scope.type.ALL', '全部', '{"en-US":"All"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.840540', '2026-11-13 01:09:52.840540', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013102, 'dict.project.data_scope.type.DEPT_AND_CHILD', '本部门及下级', '{"en-US":"Own department and sub-departments"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.849232', '2026-11-13 01:09:52.849232', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013103, 'dict.project.data_scope.type.DEPT', '本部门', '{"en-US":"Own department"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.858261', '2026-11-13 01:09:52.858261', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013104, 'dict.project.data_scope.type.SELF', '仅本人', '{"en-US":"Own data only"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.867379', '2026-11-13 01:09:52.867379', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013105, 'dict.project.data_scope.type.CUSTOM_DEPT', '指定部门', '{"en-US":"Specific departments"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.876768', '2026-11-13 01:09:52.876768', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013106, 'dict.project.handover.resource.DATA_SCOPE', '受控资源', '{"en-US":"Controlled resource"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.885555', '2026-11-13 01:09:52.885555', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013107, 'dict.project.handover.resource.ROLE_DATA_SCOPE', '角色数据范围', '{"en-US":"Role data scope"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.895291', '2026-11-13 01:09:52.895291', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013108, 'dict.project.handover.action.REENABLE', '重新启用', '{"en-US":"Re-enable"}', 'dict', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.904961', '2026-11-13 01:09:52.904961', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013109, 'roles.dataScope', '数据范围', '{"en-US":"Data scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.914217', '2026-11-13 01:09:52.914217', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013110, 'roles.grantTitle', '角色授权{suffix}', '{"en-US":"Role grants{suffix}"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.923833', '2026-11-13 01:09:52.923833', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013111, 'roles.tab.menus', '菜单授权', '{"en-US":"Menus"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.932910', '2026-11-13 01:09:52.932910', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013112, 'roles.tab.dataScope', '数据范围', '{"en-US":"Data scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.942379', '2026-11-13 01:09:52.942379', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013113, 'dataScope.column.resource', '资源', '{"en-US":"Resource"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.951151', '2026-11-13 01:09:52.951151', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013114, 'dataScope.column.scope', '可见范围', '{"en-US":"Visibility"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.960835', '2026-11-13 01:09:52.960835', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013115, 'dataScope.column.departments', '部门', '{"en-US":"Departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.970073', '2026-11-13 01:09:52.970073', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013116, 'dataScope.includeChild', '含下级', '{"en-US":"Include sub-departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.981525', '2026-11-13 01:09:52.981525', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013117, 'dataScope.defaultSelf', '仅本人（默认）', '{"en-US":"Own data only (default)"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:52.991417', '2026-11-13 01:09:52.991417', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013118, 'dataScope.builtIn', '全部（内置角色）', '{"en-US":"All (built-in role)"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.000164', '2026-11-13 01:09:53.000164', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013119, 'dataScope.confirmAllTitle', '授予「全部」范围', '{"en-US":"Grant the \"All\" scope"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.009837', '2026-11-13 01:09:53.009837', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013120, 'dataScope.confirmAll', '该角色将看到本项目全部{resource}', '{"en-US":"This role will see all {resource} in the project"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.018395', '2026-11-13 01:09:53.018395', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013121, 'dataScope.empty', '该项目尚未声明受控资源。请在业务仓 kaiwu/data-scopes.yml 中声明并同步。', '{"en-US":"No controlled resources declared yet. Declare them in kaiwu/data-scopes.yml and sync."}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.027571', '2026-11-13 01:09:53.027571', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013122, 'dataScope.pickDepartments', '选择部门', '{"en-US":"Select departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.036462', '2026-11-13 01:09:53.036462', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013123, 'dataScope.departmentsRequired', '请选择至少一个部门', '{"en-US":"Select at least one department"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.047811', '2026-11-13 01:09:53.047811', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013124, 'dataScope.maxDepartments', '最多选择 {max} 个部门', '{"en-US":"Select at most {max} departments"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.057059', '2026-11-13 01:09:53.057059', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013125, 'dataScope.saved', '数据范围已保存', '{"en-US":"Data scope saved"}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.065670', '2026-11-13 01:09:53.065670', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000013126, 'dataScope.sizeWarning', '所选部门过多，用户可能因数据范围过大而无法进入本项目。请改用「全部」或缩小指定部门。', '{"en-US":"Too many departments selected; users may be unable to enter the project because the data scope is too large. Use \"All\" or narrow the departments."}', 'roles', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:53.074631', '2026-11-13 01:09:53.074631', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110001, 'i18n.scope', '所属范围', '{"en-US":"Scope","ja-JP":"適用範囲"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.085287', '2026-11-13 01:09:51.085287', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110002, 'i18n.scopePlatform', '平台', '{"en-US":"Platform","ja-JP":"プラットフォーム"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.101693', '2026-11-13 01:09:51.101693', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110003, 'i18n.scopeProjectHint', '项目文案由项目管理员维护，不参与平台语言开放校验', '{"en-US":"Project copy is maintained by project admins and does not affect platform language availability checks.","ja-JP":"プロジェクトの文言はプロジェクト管理者が管理し、プラットフォームの言語公開チェックには影響しません。"}', 'i18n', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.118041', '2026-11-13 01:09:51.118041', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110004, 'api.i18n.builtInProjectForbidden', '内置项目的文案属于平台资源', '{"en-US":"Built-in project copy is a platform resource","ja-JP":"組み込みプロジェクトの文言はプラットフォームのリソースです"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.134189', '2026-11-13 01:09:51.134189', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110005, 'api.i18n.projectInactive', '项目未启用', '{"en-US":"The project is not enabled","ja-JP":"プロジェクトが有効ではありません"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.149506', '2026-11-13 01:09:51.149506', 0);
INSERT INTO "sys_i18n_message" ("id", "message_key", "default_text", "translations_json", "module_code", "public_visible", "required_resource", "status", "description", "VERSION", "created_at", "updated_at", "scope_id") VALUES
(9200000000000110006, 'api.i18n.projectAdminRequired', '只有目标项目的有效项目管理员可以维护项目文案', '{"en-US":"Only active project administrators of the target project can maintain project copy","ja-JP":"対象プロジェクトの有効なプロジェクト管理者のみがプロジェクトの文言を管理できます"}', 'api', 0, 1, 'ENABLED', NULL, 1, '2026-11-13 01:09:51.164781', '2026-11-13 01:09:51.164781', 0);
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(1, NULL, '验证平台访问', 'BUTTON', NULL, NULL, 'system:platform:read', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.136045', '2026-11-13 01:09:47.136049');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(100, NULL, '用户管理', 'MENU', '/users', NULL, NULL, 'UserOutlined', 10, 1, 'ENABLED', '2026-11-13 01:09:47.138106', '2026-11-13 01:09:47.138117');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(101, 100, '查询用户', 'BUTTON', NULL, NULL, 'system:user:list', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.139521', '2026-11-13 01:09:47.139525');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(102, 100, '创建用户', 'BUTTON', NULL, NULL, 'system:user:create', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.140768', '2026-11-13 01:09:47.140772');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(103, 100, '编辑用户', 'BUTTON', NULL, NULL, 'system:user:update', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.141921', '2026-11-13 01:09:47.141924');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(104, 100, '启停用户', 'BUTTON', NULL, NULL, 'system:user:status', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.143126', '2026-11-13 01:09:47.143129');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(105, 100, '重置密码', 'BUTTON', NULL, NULL, 'system:user:reset-password', NULL, 0, 1, 'ENABLED', '2026-11-13 01:09:47.144347', '2026-11-13 01:09:47.144350');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(400, NULL, '项目管理', 'MENU', '/projects', NULL, NULL, 'AppstoreOutlined', 40, 1, 'ENABLED', '2026-11-13 01:09:47.145462', '2026-11-13 01:09:47.145465');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(401, 400, '查询项目', 'BUTTON', NULL, NULL, 'system:project:list', NULL, 10, 1, 'ENABLED', '2026-11-13 01:09:47.146617', '2026-11-13 01:09:47.146620');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(402, 400, '创建项目', 'BUTTON', NULL, NULL, 'system:project:create', NULL, 20, 1, 'ENABLED', '2026-11-13 01:09:47.147795', '2026-11-13 01:09:47.147799');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(403, 400, '编辑项目', 'BUTTON', NULL, NULL, 'system:project:update', NULL, 30, 1, 'ENABLED', '2026-11-13 01:09:47.148944', '2026-11-13 01:09:47.148947');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(404, 400, '变更项目状态', 'BUTTON', NULL, NULL, 'system:project:status', NULL, 40, 1, 'ENABLED', '2026-11-13 01:09:47.150138', '2026-11-13 01:09:47.150143');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(405, 400, '管理项目成员', 'BUTTON', NULL, NULL, 'system:project:member', NULL, 50, 1, 'ENABLED', '2026-11-13 01:09:47.151576', '2026-11-13 01:09:47.151580');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(406, 400, '管理项目角色', 'BUTTON', NULL, NULL, 'system:project:role', NULL, 60, 1, 'ENABLED', '2026-11-13 01:09:47.152840', '2026-11-13 01:09:47.152843');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(407, 400, '管理项目菜单', 'BUTTON', NULL, NULL, 'system:project:menu', NULL, 70, 1, 'ENABLED', '2026-11-13 01:09:47.154174', '2026-11-13 01:09:47.154177');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(500, NULL, '参数配置', 'MENU', '/configs', NULL, NULL, 'SettingOutlined', 50, 1, 'ENABLED', '2026-11-13 01:09:47.157441', '2026-11-13 01:09:47.157444');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(501, 500, '查询配置', 'BUTTON', NULL, NULL, 'system:config:list', NULL, 10, 1, 'ENABLED', '2026-11-13 01:09:47.158611', '2026-11-13 01:09:47.158614');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(502, 500, '保存配置', 'BUTTON', NULL, NULL, 'system:config:save', NULL, 20, 1, 'ENABLED', '2026-11-13 01:09:47.159752', '2026-11-13 01:09:47.159755');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(503, 500, '删除配置', 'BUTTON', NULL, NULL, 'system:config:delete', NULL, 30, 1, 'ENABLED', '2026-11-13 01:09:47.160874', '2026-11-13 01:09:47.160877');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(600, NULL, '字典管理', 'MENU', '/dictionaries', NULL, NULL, 'BookOutlined', 60, 1, 'ENABLED', '2026-11-13 01:09:47.162037', '2026-11-13 01:09:47.162040');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(601, 600, '查询字典', 'BUTTON', NULL, NULL, 'system:dict:list', NULL, 10, 1, 'ENABLED', '2026-11-13 01:09:47.163094', '2026-11-13 01:09:47.163097');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(602, 600, '保存字典', 'BUTTON', NULL, NULL, 'system:dict:save', NULL, 20, 1, 'ENABLED', '2026-11-13 01:09:47.164186', '2026-11-13 01:09:47.164189');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(603, 600, '删除字典', 'BUTTON', NULL, NULL, 'system:dict:delete', NULL, 30, 1, 'ENABLED', '2026-11-13 01:09:47.165301', '2026-11-13 01:09:47.165303');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(700, NULL, '项目工厂', 'MENU', '/project-factory', NULL, NULL, 'CodeOutlined', 70, 1, 'ENABLED', '2026-11-13 01:09:47.166348', '2026-11-13 01:09:47.166350');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(701, 700, '查看项目生成', 'BUTTON', NULL, NULL, 'system:project-factory:list', NULL, 10, 1, 'ENABLED', '2026-11-13 01:09:47.167485', '2026-11-13 01:09:47.167487');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(702, 700, '生成项目', 'BUTTON', NULL, NULL, 'system:project-factory:generate', NULL, 20, 1, 'ENABLED', '2026-11-13 01:09:47.168659', '2026-11-13 01:09:47.168661');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(703, 700, '下载项目制品', 'BUTTON', NULL, NULL, 'system:project-factory:download', NULL, 30, 1, 'ENABLED', '2026-11-13 01:09:47.169894', '2026-11-13 01:09:47.169897');
INSERT INTO "sys_menu" ("id", "parent_id", "menu_name", "menu_type", "route_path", "component_path", "permission_code", "icon", "sort_no", "VISIBLE", "status", "created_at", "updated_at") VALUES
(704, 700, '初始推送 GitLab', 'BUTTON', NULL, NULL, 'system:project-factory:push', NULL, 40, 1, 'ENABLED', '2026-11-13 01:09:47.171609', '2026-11-13 01:09:47.171611');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8201, 8101, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.402420', '2026-11-13 01:09:44.402424', NULL, 'dict.common.status.ENABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8202, 8101, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.404088', '2026-11-13 01:09:44.404092', NULL, 'dict.common.status.DISABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8203, 8102, '是', 'true', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.407469', '2026-11-13 01:09:44.407472', NULL, 'dict.common.boolean_enabled.true');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8204, 8102, '否', 'false', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.408933', '2026-11-13 01:09:44.408936', NULL, 'dict.common.boolean_enabled.false');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8401, 8301, '启用', 'ENABLED', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.410187', '2026-11-13 01:09:44.410190', NULL, 'dict.user.status.ENABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8402, 8301, '停用', 'DISABLED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.411372', '2026-11-13 01:09:44.411375', NULL, 'dict.user.status.DISABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8403, 8302, '已启用', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.412606', '2026-11-13 01:09:44.412608', NULL, 'dict.project.status.ACTIVE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8404, 8302, '已停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.413761', '2026-11-13 01:09:44.413764', NULL, 'dict.project.status.DISABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8405, 8302, '已归档', 'ARCHIVED', 30, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.415073', '2026-11-13 01:09:44.415075', NULL, 'dict.project.status.ARCHIVED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8406, 8303, '有效', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.416311', '2026-11-13 01:09:44.416314', NULL, 'dict.project.member.status.ACTIVE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8407, 8303, '停用', 'DISABLED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.417572', '2026-11-13 01:09:44.417575', NULL, 'dict.project.member.status.DISABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8408, 8304, '目录', 'DIR', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.418906', '2026-11-13 01:09:44.418908', NULL, 'dict.platform.menu.type.DIR');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8409, 8304, '菜单', 'MENU', 20, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.420322', '2026-11-13 01:09:44.420325', NULL, 'dict.platform.menu.type.MENU');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8410, 8304, '按钮', 'BUTTON', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.423788', '2026-11-13 01:09:44.423791', NULL, 'dict.platform.menu.type.BUTTON');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8411, 8305, '文本', 'STRING', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.425218', '2026-11-13 01:09:44.425221', NULL, 'dict.config.value.type.STRING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8412, 8305, '数值', 'NUMBER', 20, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:44.426418', '2026-11-13 01:09:44.426420', NULL, 'dict.config.value.type.NUMBER');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8413, 8305, '布尔值', 'BOOLEAN', 30, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.427671', '2026-11-13 01:09:44.427673', NULL, 'dict.config.value.type.BOOLEAN');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8414, 8305, 'JSON', 'JSON', 40, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.428801', '2026-11-13 01:09:44.428804', NULL, 'dict.config.value.type.JSON');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8415, 8306, '连接成功', 'SUCCESS', 10, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.429990', '2026-11-13 01:09:44.429992', NULL, 'dict.ai.test.status.SUCCESS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8416, 8306, '连接失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.431232', '2026-11-13 01:09:44.431234', NULL, 'dict.ai.test.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8419, 8308, 'AI 生成项目', 'AI_PROJECT', 10, 1, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.434798', '2026-11-13 01:09:44.434801', NULL, 'dict.project.generation.mode.AI_PROJECT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8420, 8308, '基础空脚手架', 'BASIC_SCAFFOLD', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.436054', '2026-11-13 01:09:44.436065', NULL, 'dict.project.generation.mode.BASIC_SCAFFOLD');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8421, 8309, '等待生成', 'PENDING', 10, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.437370', '2026-11-13 01:09:44.437373', NULL, 'dict.project.generation.status.PENDING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8422, 8309, '正在生成', 'RUNNING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.439842', '2026-11-13 01:09:44.439845', NULL, 'dict.project.generation.status.RUNNING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8423, 8309, '生成成功', 'SUCCESS', 30, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.441152', '2026-11-13 01:09:44.441154', NULL, 'dict.project.generation.status.SUCCESS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8424, 8309, '生成失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.442348', '2026-11-13 01:09:44.442351', NULL, 'dict.project.generation.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8434, 8313, '系统通知', 'SYSTEM', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.448386', '2026-11-13 01:09:44.448388', NULL, 'dict.notification.type.SYSTEM');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8435, 8313, '项目消息', 'PROJECT', 20, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.449594', '2026-11-13 01:09:44.449597', NULL, 'dict.notification.type.PROJECT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8436, 8313, '任务提醒', 'TASK', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.450777', '2026-11-13 01:09:44.450780', NULL, 'dict.notification.type.TASK');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8437, 8314, '成功', 'SUCCESS', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.452189', '2026-11-13 01:09:44.452192', NULL, 'dict.security.login.status.SUCCESS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8438, 8314, '失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.453540', '2026-11-13 01:09:44.453543', NULL, 'dict.security.login.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8439, 8315, '在线', 'ONLINE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.456301', '2026-11-13 01:09:44.456304', NULL, 'dict.security.session.status.ONLINE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8440, 8315, '已撤销', 'REVOKED', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.457645', '2026-11-13 01:09:44.457647', NULL, 'dict.security.session.status.REVOKED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8441, 8314, '退出', 'LOGOUT', 30, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.458918', '2026-11-13 01:09:44.458921', NULL, 'dict.security.login.status.LOGOUT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8442, 8316, '执行中', 'RUNNING', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.460110', '2026-11-13 01:09:44.460112', NULL, 'dict.scheduler.execution.status.RUNNING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8443, 8316, '成功', 'SUCCESS', 20, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.461367', '2026-11-13 01:09:44.461369', NULL, 'dict.scheduler.execution.status.SUCCESS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8444, 8316, '失败', 'FAILED', 30, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.462462', '2026-11-13 01:09:44.462465', NULL, 'dict.scheduler.execution.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8501, 8317, '简体中文', 'zh-CN', 10, 1, NULL, '{"selectable":true,"antdLocale":"zh-CN","dateLocale":"zh-CN"}', 'ENABLED', '2026-11-13 01:09:44.463558', '2026-11-13 01:09:44.463561', NULL, 'dict.platform.locale.zh-CN');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8502, 8317, 'English (US)', 'en-US', 20, 0, NULL, '{"selectable":true,"antdLocale":"en-US","dateLocale":"en-US"}', 'ENABLED', '2026-11-13 01:09:44.464795', '2026-11-13 01:09:44.464798', NULL, 'dict.platform.locale.en-US');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8531, 8321, '成功（绿）', 'success', 10, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.471324', '2026-11-13 01:09:44.471327', NULL, 'dict.common.tag_color.success');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8532, 8321, '处理中（蓝）', 'processing', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.474007', '2026-11-13 01:09:44.474011', NULL, 'dict.common.tag_color.processing');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8533, 8321, '警告（橙）', 'warning', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.475317', '2026-11-13 01:09:44.475319', NULL, 'dict.common.tag_color.warning');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8534, 8321, '失败（红）', 'error', 40, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.476638', '2026-11-13 01:09:44.476641', NULL, 'dict.common.tag_color.error');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8535, 8321, '默认（灰）', 'default', 50, 1, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.477960', '2026-11-13 01:09:44.477963', NULL, 'dict.common.tag_color.default');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8536, 8321, '紫（类别）', 'purple', 60, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.479102', '2026-11-13 01:09:44.479105', NULL, 'dict.common.tag_color.purple');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8537, 8321, '青（类别）', 'cyan', 70, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:44.480253', '2026-11-13 01:09:44.480256', NULL, 'dict.common.tag_color.cyan');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8541, 8331, '用户管理', 'user', 10, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.481485', '2026-11-13 01:09:44.481488', NULL, 'dict.security.audit.module.user');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8542, 8331, '角色管理', 'role', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.482621', '2026-11-13 01:09:44.482623', NULL, 'dict.security.audit.module.role');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8543, 8331, '菜单管理', 'menu', 30, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.483730', '2026-11-13 01:09:44.483732', NULL, 'dict.security.audit.module.menu');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8544, 8331, '组织架构', 'org', 40, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.484976', '2026-11-13 01:09:44.484979', NULL, 'dict.security.audit.module.org');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8545, 8331, '配置与字典', 'metadata', 50, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.486520', '2026-11-13 01:09:44.486523', NULL, 'dict.security.audit.module.metadata');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8546, 8331, '国际化资源', 'i18n', 60, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:44.489629', '2026-11-13 01:09:44.489632', NULL, 'dict.security.audit.module.i18n');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8547, 8331, '项目管理', 'project', 70, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:44.490985', '2026-11-13 01:09:44.490987', NULL, 'dict.security.audit.module.project');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8548, 8331, '项目工厂', 'project-factory', 80, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:44.492350', '2026-11-13 01:09:44.492354', NULL, 'dict.security.audit.module.project-factory');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8549, 8331, '定时任务', 'scheduler', 90, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:44.493528', '2026-11-13 01:09:44.493531', NULL, 'dict.security.audit.module.scheduler');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8550, 8331, 'GitLab 配置', 'gitlab', 100, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.494721', '2026-11-13 01:09:44.494724', NULL, 'dict.security.audit.module.gitlab');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8551, 8331, '大模型配置', 'ai', 110, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.496001', '2026-11-13 01:09:44.496004', NULL, 'dict.security.audit.module.ai');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8552, 8331, '安全运营', 'security', 120, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.497241', '2026-11-13 01:09:44.497244', NULL, 'dict.security.audit.module.security');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8553, 8308, 'DDL 确定性生成', 'DDL_SCAFFOLD', 30, 0, 'cyan', NULL, 'ENABLED', '2026-11-13 01:09:48.789179', '2026-11-13 01:09:48.789179', NULL, 'dict.project.generation.mode.DDL_SCAFFOLD');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8554, 8343, '网页登录', 'WEB', 10, 1, 'default', NULL, 'ENABLED', '2026-11-13 01:09:48.800595', '2026-11-13 01:09:48.800595', NULL, 'dict.security.session.source.WEB');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8555, 8343, 'CLI 授权', 'CLI', 20, 0, 'purple', NULL, 'ENABLED', '2026-11-13 01:09:48.812447', '2026-11-13 01:09:48.812447', NULL, 'dict.security.session.source.CLI');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8570, 8340, '待审核', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.498444', '2026-11-13 01:09:44.498447', NULL, 'dict.agent.capability.status.PENDING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8571, 8340, '已批准', 'APPROVED', 20, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.499615', '2026-11-13 01:09:44.499617', NULL, 'dict.agent.capability.status.APPROVED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8572, 8340, '已撤销', 'REVOKED', 30, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.500792', '2026-11-13 01:09:44.500794', NULL, 'dict.agent.capability.status.REVOKED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8573, 8341, '在线', 'ONLINE', 40, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.502044', '2026-11-13 01:09:44.502046', NULL, 'dict.agent.capability.connection.ONLINE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8574, 8341, '离线', 'OFFLINE', 50, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.503371', '2026-11-13 01:09:44.503374', NULL, 'dict.agent.capability.connection.OFFLINE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8575, 8342, '待确认', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.506728', '2026-11-13 01:09:44.506731', NULL, 'dict.agent.action.status.PENDING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8576, 8342, '执行中', 'EXECUTING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.508001', '2026-11-13 01:09:44.508004', NULL, 'dict.agent.action.status.EXECUTING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8577, 8342, '已创建', 'SUCCEEDED', 30, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.509252', '2026-11-13 01:09:44.509255', NULL, 'dict.agent.action.status.SUCCEEDED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8578, 8342, '执行失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.510453', '2026-11-13 01:09:44.510455', NULL, 'dict.agent.action.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8579, 8342, '已取消', 'CANCELLED', 50, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.511758', '2026-11-13 01:09:44.511760', NULL, 'dict.agent.action.status.CANCELLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8580, 8342, '已过期', 'EXPIRED', 60, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.512860', '2026-11-13 01:09:44.512863', NULL, 'dict.agent.action.status.EXPIRED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8581, 8342, '已拒绝', 'REJECTED', 70, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.514110', '2026-11-13 01:09:44.514112', NULL, 'dict.agent.action.status.REJECTED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(8582, 8342, '结果待核验', 'UNKNOWN', 80, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.515304', '2026-11-13 01:09:44.515307', NULL, 'dict.agent.action.status.UNKNOWN');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004301, 9200000000000004300, '待确认', 'PENDING', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.516428', '2026-11-13 01:09:44.516431', NULL, 'dict.agent.remote_action.status.PENDING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004302, 9200000000000004300, '执行中', 'EXECUTING', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:44.517707', '2026-11-13 01:09:44.517710', NULL, 'dict.agent.remote_action.status.EXECUTING');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004303, 9200000000000004300, '已完成', 'SUCCEEDED', 30, 0, 'success', NULL, 'ENABLED', '2026-11-13 01:09:44.518974', '2026-11-13 01:09:44.518977', NULL, 'dict.agent.remote_action.status.SUCCEEDED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004304, 9200000000000004300, '执行失败', 'FAILED', 40, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.520249', '2026-11-13 01:09:44.520251', NULL, 'dict.agent.remote_action.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004305, 9200000000000004300, '已取消', 'CANCELLED', 50, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.523974', '2026-11-13 01:09:44.523977', NULL, 'dict.agent.remote_action.status.CANCELLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004306, 9200000000000004300, '已过期', 'EXPIRED', 60, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:44.525284', '2026-11-13 01:09:44.525287', NULL, 'dict.agent.remote_action.status.EXPIRED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004307, 9200000000000004300, '已拒绝', 'REJECTED', 70, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:44.526464', '2026-11-13 01:09:44.526466', NULL, 'dict.agent.remote_action.status.REJECTED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000004308, 9200000000000004300, '结果待核验', 'UNKNOWN', 80, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:44.527611', '2026-11-13 01:09:44.527614', NULL, 'dict.agent.remote_action.status.UNKNOWN');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007010, 9200000000000007000, '阿里云 OSS', 'ALIYUN_OSS', 10, 1, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:49.862737', '2026-11-13 01:09:49.862737', '{"en-US":"Alibaba Cloud OSS"}', 'dict.storage.provider.type.ALIYUN_OSS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007011, 9200000000000007000, 'S3 兼容（STS）', 'S3_COMPATIBLE_STS', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:49.875105', '2026-11-13 01:09:49.875105', '{"en-US":"S3 compatible (STS)"}', 'dict.storage.provider.type.S3_COMPATIBLE_STS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007020, 9200000000000007001, '生效', 'ACTIVE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:49.888536', '2026-11-13 01:09:49.888536', '{"en-US":"Active"}', 'dict.storage.binding.status.ACTIVE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007021, 9200000000000007001, '只读', 'READ_ONLY', 20, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:49.905522', '2026-11-13 01:09:49.905522', '{"en-US":"Read only"}', 'dict.storage.binding.status.READ_ONLY');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007022, 9200000000000007001, '停用', 'DISABLED', 30, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:49.917398', '2026-11-13 01:09:49.917398', '{"en-US":"Disabled"}', 'dict.storage.binding.status.DISABLED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007251, 9200000000000007250, '成功', 'SUCCESS', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:51.422483', '2026-11-13 01:09:51.422483', '{"en-US":"Succeeded"}', 'dict.project.handover.status.SUCCESS');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007252, 9200000000000007250, '失败', 'FAILED', 20, 0, 'error', NULL, 'ENABLED', '2026-11-13 01:09:51.432440', '2026-11-13 01:09:51.432440', '{"en-US":"Failed"}', 'dict.project.handover.status.FAILED');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007254, 9200000000000007253, '新增', 'CREATE', 10, 1, 'success', NULL, 'ENABLED', '2026-11-13 01:09:51.443599', '2026-11-13 01:09:51.443599', '{"en-US":"Add"}', 'dict.project.handover.action.CREATE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007255, 9200000000000007253, '更新', 'UPDATE', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:51.453914', '2026-11-13 01:09:51.453914', '{"en-US":"Update"}', 'dict.project.handover.action.UPDATE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007256, 9200000000000007253, '源环境已删除', 'REMOVED_AT_SOURCE', 30, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:51.464247', '2026-11-13 01:09:51.464247', '{"en-US":"Removed at source"}', 'dict.project.handover.action.REMOVED_AT_SOURCE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007257, 9200000000000007253, '仅目标环境有', 'DRIFT', 40, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.474561', '2026-11-13 01:09:51.474561', '{"en-US":"Only in target"}', 'dict.project.handover.action.DRIFT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007259, 9200000000000007258, '字典', 'DICT', 10, 1, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.483877', '2026-11-13 01:09:51.483877', '{"en-US":"Dictionary"}', 'dict.project.handover.resource.DICT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007260, 9200000000000007258, '字典项', 'DICT_ITEM', 20, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.493750', '2026-11-13 01:09:51.493750', '{"en-US":"Dictionary item"}', 'dict.project.handover.resource.DICT_ITEM');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007261, 9200000000000007258, '参数配置', 'CONFIG', 30, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.503970', '2026-11-13 01:09:51.503970', '{"en-US":"Config"}', 'dict.project.handover.resource.CONFIG');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007262, 9200000000000007258, '菜单', 'MENU', 40, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.514080', '2026-11-13 01:09:51.514080', '{"en-US":"Menu"}', 'dict.project.handover.resource.MENU');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007263, 9200000000000007258, '国际化资源', 'I18N', 50, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.523931', '2026-11-13 01:09:51.523931', '{"en-US":"I18n resource"}', 'dict.project.handover.resource.I18N');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007264, 9200000000000007258, '角色', 'ROLE', 60, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.533343', '2026-11-13 01:09:51.533343', '{"en-US":"Role"}', 'dict.project.handover.resource.ROLE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007265, 9200000000000007258, '角色授权', 'ROLE_GRANT', 70, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:51.543383', '2026-11-13 01:09:51.543383', '{"en-US":"Role grant"}', 'dict.project.handover.resource.ROLE_GRANT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000007266, 9200000000000007258, '定时任务', 'JOB', 80, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:52.219790', '2026-11-13 01:09:52.219790', '{"en-US":"Scheduled job"}', 'dict.project.handover.resource.JOB');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013001, 9200000000000013000, '全部', 'ALL', 10, 0, 'warning', NULL, 'ENABLED', '2026-11-13 01:09:52.753553', '2026-11-13 01:09:52.753553', '{"en-US":"All"}', 'dict.project.data_scope.type.ALL');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013002, 9200000000000013000, '本部门及下级', 'DEPT_AND_CHILD', 20, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:52.763818', '2026-11-13 01:09:52.763818', '{"en-US":"Own department and sub-departments"}', 'dict.project.data_scope.type.DEPT_AND_CHILD');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013003, 9200000000000013000, '本部门', 'DEPT', 30, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:52.773124', '2026-11-13 01:09:52.773124', '{"en-US":"Own department"}', 'dict.project.data_scope.type.DEPT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013004, 9200000000000013000, '仅本人', 'SELF', 40, 1, 'default', NULL, 'ENABLED', '2026-11-13 01:09:52.782014', '2026-11-13 01:09:52.782014', '{"en-US":"Own data only"}', 'dict.project.data_scope.type.SELF');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013005, 9200000000000013000, '指定部门', 'CUSTOM_DEPT', 50, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:52.793242', '2026-11-13 01:09:52.793242', '{"en-US":"Specific departments"}', 'dict.project.data_scope.type.CUSTOM_DEPT');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013006, 9200000000000007258, '受控资源', 'DATA_SCOPE', 90, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:52.803026', '2026-11-13 01:09:52.803026', '{"en-US":"Controlled resource"}', 'dict.project.handover.resource.DATA_SCOPE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013007, 9200000000000007258, '角色数据范围', 'ROLE_DATA_SCOPE', 100, 0, 'default', NULL, 'ENABLED', '2026-11-13 01:09:52.812896', '2026-11-13 01:09:52.812896', '{"en-US":"Role data scope"}', 'dict.project.handover.resource.ROLE_DATA_SCOPE');
INSERT INTO "sys_dict_item" ("id", "dict_type_id", "item_label", "item_value", "sort_no", "default_item", "color", "extra_json", "status", "created_at", "updated_at", "label_i18n", "label_i18n_key") VALUES
(9200000000000013008, 9200000000000007253, '重新启用', 'REENABLE', 50, 0, 'processing', NULL, 'ENABLED', '2026-11-13 01:09:52.822142', '2026-11-13 01:09:52.822142', '{"en-US":"Re-enable"}', 'dict.project.handover.action.REENABLE');
