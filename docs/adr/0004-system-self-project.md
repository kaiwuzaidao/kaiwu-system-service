# ADR 0004：System 作为内置自管理项目

- 状态：Accepted
- 日期：2026-07-23

## 背景

早期实现把平台角色、平台菜单放在 `sys_role/sys_menu`，业务项目权限放在
`sys_project_*`，并分别提供顶层角色/菜单页面和项目权限中心。两套管理入口容易形成
重复角色、权限码归属不清和后续功能不知道应写哪套表的问题。

Kaiwu 自身同样是一个需要成员、角色、菜单和权限治理的项目，不应成为项目模型的例外。

## 决策

1. 幂等创建 `project_code=system`、`built_in=1` 的内置项目。
2. system 项目始终为 `ACTIVE`；后端拒绝停用、归档或删除，前端同时禁用这些操作。
3. 全局身份继续归 `sys_user`；平台成员、系统角色、平台菜单和登录权限统一归
   `sys_project_member / sys_project_role / sys_project_menu / sys_project_role_menu`。
4. 登录时只从 system 项目的有效成员、有效角色和有效菜单解析平台 permission code。
5. system 权限变化会撤销受影响用户会话，避免旧权限快照继续生效。
6. 顶层角色管理和平台菜单页面不再作为产品入口；统一进入
   “项目管理 → system → 权限中心”。
7. legacy `sys_role/sys_permission/sys_user_role/sys_role_permission/sys_menu` 暂不删表，
   只作为历史兼容和首次迁移种子；新能力不得继续建立第二套运行态权限事实。

## 后果

- 平台和业务项目共享一套项目权限模型，只通过 `project_id` 区分归属。
- system 项目管理员始终拥有 system 全部菜单节点；其他系统角色按需授权。
- 左侧导航根据登录时的 system 权限快照过滤，但后端 `@RequirePermission` 仍是安全边界。
- 全新 V1 基线直接提供当前权限结构；System 启动时幂等创建内置项目并完成权限收敛，
  不再依赖历史迁移链。
