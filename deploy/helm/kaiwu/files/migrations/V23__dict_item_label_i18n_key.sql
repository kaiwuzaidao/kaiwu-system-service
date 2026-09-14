-- ADR 0014：字典项标签引用国际化资源，退役客户端隐式覆盖。
--
-- 只加一个可空 key 列，不加布尔开关：非空即启用，与 menu_name_key / value_i18n_key 同构。

SET @dict_item_key_exists = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'sys_dict_item'
      AND COLUMN_NAME = 'label_i18n_key'
);
SET @dict_item_key_sql = IF(
    @dict_item_key_exists = 0,
    'ALTER TABLE sys_dict_item ADD COLUMN label_i18n_key VARCHAR(160) NULL'
        ' COMMENT ''引用的国际化资源 key；非空即启用引用式国际化'' AFTER label_i18n',
    'SELECT 1'
);
PREPARE dict_item_key_stmt FROM @dict_item_key_sql;
EXECUTE dict_item_key_stmt;
DEALLOCATE PREPARE dict_item_key_stmt;

-- 把已存在的 dict.{dictCode}.{itemValue} 约定 key 提升为显式引用。
--
-- 这些资源本就是 check:i18n 的 checkDictionaryCoverage() 强制要求存在的（对应前端
-- DICT_FALLBACK 覆盖的字典），此前只被前端 useDict 的客户端 formatMessage 隐式消费、
-- 服务端从未读取。这里不新建任何资源、不改译文内容，只是把「谁在用这个 key」从
-- 客户端约定变成字典项行上的显式外键，和 ADR 0013 里 menu.system.* 的复用方式一致。
--
-- 只处理 scope_id=0（全局字典）：项目范围字典项不会撞上这套编译期已知的约定 key。
UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = CONCAT('dict.', type.dict_code, '.', item.item_value)
SET item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND item.label_i18n_key IS NULL;
