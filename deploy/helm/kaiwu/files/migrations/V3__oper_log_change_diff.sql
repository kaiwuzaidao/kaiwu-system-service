-- 审计日志加"字段级变更 diff"：target_type / target_id 定位目标资源，
-- change_json 存 [{field, before, after}] JSON。旧调用点不写这三列，字段允许 NULL。
-- MySQL 8 不支持 ADD COLUMN IF NOT EXISTS，通过 information_schema 判断实现幂等。

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_oper_log'
          AND COLUMN_NAME = 'target_type'
    ),
    'ALTER TABLE sys_oper_log ADD COLUMN target_type VARCHAR(64) NULL COMMENT ''目标资源类型''',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_oper_log'
          AND COLUMN_NAME = 'target_id'
    ),
    'ALTER TABLE sys_oper_log ADD COLUMN target_id VARCHAR(64) NULL COMMENT ''目标资源 ID''',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_oper_log'
          AND COLUMN_NAME = 'change_json'
    ),
    'ALTER TABLE sys_oper_log ADD COLUMN change_json TEXT NULL COMMENT ''字段级变更 JSON: [{field, before, after}]''',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_oper_log'
          AND INDEX_NAME = 'idx_sys_oper_log_target'
    ),
    'ALTER TABLE sys_oper_log ADD KEY idx_sys_oper_log_target (target_type, target_id, created_at)',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
