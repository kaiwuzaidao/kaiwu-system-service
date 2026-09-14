-- 下线独立的 CRUD 代码生成入口（/codegen）。生成能力已由项目工厂承载，
-- DdlParser / AiMetadataEnhancer / CodegenTemplateRenderer 等仍被项目工厂复用，只是不再
-- 有独立的 HTTP 入口和页面，因此其字典与权限种子一并回收。
-- V1 已发布不可修改，只能在此追加删除。

-- 字典项先于字典类型删除，避免留下孤儿行。
DELETE item FROM sys_dict_item item
JOIN sys_dict_type type ON type.id = item.dict_type_id
WHERE type.dict_code IN ('codegen.status', 'codegen.mode');

DELETE FROM sys_dict_type WHERE dict_code IN ('codegen.status', 'codegen.mode');

-- 回收权限授权关系，再回收菜单节点；顺序反过来会因外键留下悬挂授权。
DELETE role_menu FROM sys_project_role_menu role_menu
JOIN sys_project_menu menu
  ON menu.project_id = role_menu.project_id AND menu.id = role_menu.menu_id
WHERE menu.permission_code LIKE 'system:codegen:%';

DELETE FROM sys_project_menu WHERE permission_code LIKE 'system:codegen:%';

-- legacy sys_menu / sys_permission 无需处理：V1 基线从未 seed 过 codegen 权限码，
-- 这些菜单是运行期手工创建的，只存在于 sys_project_menu。

-- sys_codegen_task 保留：里面是历史生成记录，属于数据不是配置。
-- 需要清理时由运维显式执行，迁移脚本不擅自删用户数据。
