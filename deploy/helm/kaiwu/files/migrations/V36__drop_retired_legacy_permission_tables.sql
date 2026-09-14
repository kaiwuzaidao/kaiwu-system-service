-- 删除平台级角色/权限的四张 legacy 表。
--
-- 背景：权限事实源早已统一为 sys_project_*（CLAUDE.md 第 10 条）。
-- AuthMapper.findPermissionCodes 只走 sys_project -> sys_project_member ->
-- sys_project_member_role -> sys_project_role_menu -> sys_project_menu，
-- 从头到尾不查这四张表。换句话说，它们里面的授权数据**写进去也不生效**。
-- 2026-08-10 随 /api/roles、/api/menus、/api/users/{id}/roles 三组接口一起退役，
-- 代码侧的 Controller/Service/Repository/Mapper/DTO 已全部删除，此处回收结构。
--
-- 注意：sys_menu **不在删除范围内**。SystemBootstrapMapper.importLegacyMenus 仍然
-- 从它 SELECT 出平台菜单迁入 sys_project_menu，删掉会让全新库没有任何平台菜单。
--
-- 删除顺序按外键依赖自底向上：两张关联表 -> sys_role / sys_permission。
-- 全部使用 IF EXISTS，重复执行不报错（存量库可能已被手工清理过）。

DROP TABLE IF EXISTS sys_user_role;
DROP TABLE IF EXISTS sys_role_permission;
DROP TABLE IF EXISTS sys_role;
DROP TABLE IF EXISTS sys_permission;

-- sys_menu 里对应这些退役接口的种子行同样是死数据：
-- 106（分配用户角色）、200-205（/roles 角色管理）、300-305（/menus 平台菜单）。
-- importLegacyMenus 一直用 WHERE 把它们排除在迁入范围外，删掉后那段排除条件即可去掉。
-- 先删子节点再删父节点，避免留下孤儿 parent_id。
DELETE FROM sys_menu WHERE id IN (201, 202, 203, 204, 205, 301, 302, 303, 304, 305);
DELETE FROM sys_menu WHERE id IN (106, 200, 300);
