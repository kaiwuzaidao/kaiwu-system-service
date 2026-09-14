-- ADR 0015 补偿：GitLab 连通状态 SUCCESS 的资源早已存在，但历史升级库遗漏了字典项引用。
-- 只修复该稳定业务键；不覆盖资源正文或任何运营译文。
UPDATE sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
JOIN sys_i18n_message resource
  ON resource.message_key = 'dict.gitlab.test.status.SUCCESS'
 AND resource.status = 'ENABLED'
SET item.label_i18n = NULL,
    item.label_i18n_key = resource.message_key,
    item.updated_at = CURRENT_TIMESTAMP
WHERE type.scope_id = 0
  AND type.dict_code = 'gitlab.test.status'
  AND item.item_value = 'SUCCESS';
