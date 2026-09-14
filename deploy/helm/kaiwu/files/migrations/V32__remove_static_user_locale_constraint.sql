-- 用户语言由 platform.locale 目录和 AuthService 的 selectableLocale 统一约束。
-- 旧 CHECK 只允许 zh-CN/en-US，会阻断后来已通过覆盖门禁的 ja-JP 等动态语言。
SET @user_locale_check_exists = (
    SELECT COUNT(*)
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_user'
      AND CONSTRAINT_NAME = 'chk_sys_user_locale'
      AND CONSTRAINT_TYPE = 'CHECK'
);
SET @drop_user_locale_check_sql = IF(
    @user_locale_check_exists = 1,
    'ALTER TABLE sys_user DROP CHECK chk_sys_user_locale',
    'SELECT 1'
);
PREPARE drop_user_locale_check_statement FROM @drop_user_locale_check_sql;
EXECUTE drop_user_locale_check_statement;
DEALLOCATE PREPARE drop_user_locale_check_statement;
