-- 用户界面语言由 System 持久化，跨浏览器登录时从用户快照恢复。
-- 这是向后兼容的增量：旧应用会忽略新列，存量用户使用默认中文。

SET @locale_column_exists = (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_user'
      AND COLUMN_NAME = 'locale'
);
SET @locale_column_sql = IF(
    @locale_column_exists = 0,
    'ALTER TABLE sys_user ADD COLUMN locale VARCHAR(16) NOT NULL DEFAULT ''zh-CN'' AFTER status',
    'SELECT 1'
);
PREPARE locale_column_statement FROM @locale_column_sql;
EXECUTE locale_column_statement;
DEALLOCATE PREPARE locale_column_statement;

SET @locale_check_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_user'
      AND CONSTRAINT_NAME = 'chk_sys_user_locale'
      AND CONSTRAINT_TYPE = 'CHECK'
);
SET @locale_check_sql = IF(
    @locale_check_exists = 0,
    'ALTER TABLE sys_user ADD CONSTRAINT chk_sys_user_locale CHECK (locale IN (''zh-CN'', ''en-US''))',
    'SELECT 1'
);
PREPARE locale_check_statement FROM @locale_check_sql;
EXECUTE locale_check_statement;
DEALLOCATE PREPARE locale_check_statement;
