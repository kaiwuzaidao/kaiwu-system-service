-- 字典类型的显示顺序。
--
-- 字典项一直有 sort_no，字典类型没有，列表只能按 dict_name 排——中文名的字典序既不是
-- 业务上的重要程度，也不稳定（改个名字整列就跳位）。管理端要做拖拽排序，必须有一列
-- 可持久化的顺序。
--
-- 存量行一律为 0：排序键退化成 (0, dict_name, dict_code, id)，即与改造前完全一致的顺序，
-- 直到第一次拖拽才产生差异，不需要回填。

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_dict_type'
          AND COLUMN_NAME = 'sort_no'
    ),
    'ALTER TABLE sys_dict_type ADD COLUMN sort_no INT NOT NULL DEFAULT 0 AFTER inherit_global',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    NOT EXISTS(
        SELECT 1 FROM information_schema.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'sys_dict_type'
          AND INDEX_NAME = 'idx_sys_dict_type_scope_sort'
    ),
    'CREATE INDEX idx_sys_dict_type_scope_sort ON sys_dict_type (scope_id, sort_no)',
    'DO NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 拖拽排序的界面文案。
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

UPDATE sys_i18n_catalog_revision
SET revision = revision + 1, updated_at = CURRENT_TIMESTAMP
WHERE catalog_code = 'platform';
