# 项目工厂 v23：授权菜单与本人待办

此前生成侧栏直接使用 config 路由，成员/角色权限仅在页面内检查，导致无权限菜单可见；且业务后台未提供统一待办入口。

v23 复用 ProjectAccessProvider 已有 access 响应中的 menus：业务导航由平台授权结果驱动，不再回退静态路由。成员、角色和文件入口额外要求对应 list 权限，隐藏停用、不可见和空目录；config 只维护路由组件映射。主页和 /todos 是本人自服务入口。菜单链接保留 projectId。

新增待办页调用现有 GET /api/current/todos，projectCode 由生成项目确定，状态 OPEN，按 current/size 分页。服务端按当前用户筛选，不接受用户 ID。支持加载、空态、错误重试、刷新；只允许当前项目的安全工作台深链接进入办理，不增加完成/关闭接口。

原授权、令牌桥接、权限注解均不修改。手输无权限页面仍拒绝，任务操作仍由业务服务最终授权。

既有生成项目不覆盖、不重新生成、不改历史 ZIP。维护者按本 MR 手动更新 app、ProjectAccessProvider、projectMenu 工具、Todos 页面与 service、config 和语言包。版本 v22→v23；v21 站内信修复 !207 是另一项未合入工作，本 MR 不取代它。

验证：System Maven Domain 813 项（1 项既有跳过）、Boot 14 项（13 项既有条件跳过）与真实 MySQL/Flyway通过；生成器 11 项通过；当前生成业务后端、业务前端与空模板前端 verify 通过；verify-generated-home.mjs 验证真实页面的授权菜单、待办入口及空态、权限拒绝/重试、保留项目上下文通过。模板排版与一次未设置 Docker socket 的验证失败已修正后分别复验。
