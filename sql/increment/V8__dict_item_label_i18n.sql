-- 字典项标签多语言。
--
-- 平台内置字典可以靠前端语言包按 `dict.{dictCode}.{itemValue}` 覆盖，因为那些 key 在编译期
-- 已知；用户在「字典管理」里新建的字典项是运行期录入的，语言包无法预先穷举其 key，
-- 只能把译文存进数据。
--
-- 选 JSON 单列而不是 label_en/label_ja 独立列：新增语言无需再改表结构。
-- 也不建独立翻译表：字典项按 dictCode 全量加载，不需要按语言检索，JOIN 与额外索引没有收益。
-- 结构为 {"en-US": "Enabled"}；缺失语言回退 item_label 录入原文。

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_dict_item'
          AND COLUMN_NAME = 'label_i18n'
    ),
    'ALTER TABLE sys_dict_item ADD COLUMN label_i18n JSON NULL COMMENT ''标签多语言：{"en-US":"Enabled"}，缺失回退 item_label''',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
