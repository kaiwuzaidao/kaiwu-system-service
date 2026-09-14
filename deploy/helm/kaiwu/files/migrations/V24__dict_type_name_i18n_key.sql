-- ADR 0014：字典名称也支持引用国际化资源。
--
-- 与 label_i18n_key / menu_name_key / value_i18n_key 同构：只加一个可空 key 列，
-- 非空即启用，不加布尔开关。
--
-- 与 V23 不同，这里**没有**存量数据提升：字典名从来没有过 `dict.{code}` 之类的约定 key，
-- 也没有内联多语言列，此前只有单一的 dict_name 原文。存量字典项保持「固定文案」模式，
-- 由使用者按需在界面上改为引用。

SET @dict_type_key_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_dict_type'
      AND COLUMN_NAME = 'dict_name_key'
);
SET @dict_type_key_sql = IF(
    @dict_type_key_exists = 0,
    'ALTER TABLE sys_dict_type ADD COLUMN dict_name_key VARCHAR(160) NULL'
        ' COMMENT ''引用的国际化资源 key；非空即启用引用式国际化'' AFTER dict_name',
    'SELECT 1'
);
PREPARE dict_type_key_stmt FROM @dict_type_key_sql;
EXECUTE dict_type_key_stmt;
DEALLOCATE PREPARE dict_type_key_stmt;
