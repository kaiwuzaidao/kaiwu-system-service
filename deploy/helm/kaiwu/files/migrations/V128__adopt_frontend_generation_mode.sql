INSERT IGNORE INTO sys_dict_item(id,dict_type_id,item_label,item_value,sort_no,default_item,color,status,label_i18n_key,created_at,updated_at) VALUES
(16800,8308,'沿用已有前端','ADOPT_FRONTEND',40,0,'blue','ENABLED','dict.project.generation.mode.ADOPT_FRONTEND',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);
INSERT IGNORE INTO sys_i18n_message(id,message_key,default_text,translations_json,module_code,public_visible,required_resource,status,version,created_at,updated_at) VALUES
(9200000000000009100,'dict.project.generation.mode.ADOPT_FRONTEND','沿用已有前端',JSON_OBJECT('en-US','Existing frontend','ja-JP','既存フロントエンド'),'dict',0,1,'ENABLED',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);
UPDATE sys_i18n_catalog_revision SET revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE catalog_code='platform';
