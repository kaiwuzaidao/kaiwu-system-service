# Kaiwu 第一阶段需求基线

> 文档版本：0.3
> 状态：Accepted，作为第一阶段需求基线
> 范围：只描述第一阶段，未写入本文的能力不进入开发

## 1. 产品目标

Kaiwu 是通用后台管理平台，负责两类事情：

1. 管理平台自身：登录、用户，以及内置 system 项目中的成员、角色、权限、菜单、字典、
   配置、审计和组织架构。
2. 管理独立业务项目：登记项目、配置成员/项目角色/项目菜单，并生成可独立构建、独立部署、独立使用数据库的业务前后端仓库。

第一阶段完成后，用户应能在五分钟内启动平台，登录后完成平台管理、项目权限配置，并让
AI 在 Kaiwu 脚手架约束内生成一个可编译的独立业务后台第一版。已有项目可以粘贴 DDL
或临时连接 MySQL 导入结构；每个项目只允许成功生成一次。

## 2. 用户角色

| 角色 | 职责 |
|---|---|
| 平台管理员 | 作为 system 项目管理员，管理平台用户、成员、角色、菜单、字典、配置、组织和审计 |
| 项目负责人 | 管理指定项目的成员、项目角色、项目菜单和代码生成任务 |
| 项目成员 | 只查看自己加入的项目，并按项目角色获得菜单和按钮权限 |
| 开发者 | 下载生成产物，或从 GitLab 初始提交继续开发 |

全局只有用户身份；角色都属于项目。system 项目角色控制 Kaiwu 平台权限，不能直接充当
其他项目角色。

## 3. 仓库硬约束

### 3.1 开源入口与平台仓库

公开发行提供一个名为 `kaiwu` 的薄入口仓。它只包含主页、仓库地图、贡献/安全说明、统一命令
入口和静态自检，不包含产品源码、部署配置、Secret、migration 或生成模板。用户第一次启动只需
克隆该入口；运行仓放入入口忽略的 `workspace/`。

以下五个产品项目各自拥有独立 Git 仓库、CI、版本和发布周期，其中 Deploy 只在 Kubernetes/
GitOps 阶段按需获取：

| 仓库 | 类型 | 职责 |
|---|---|---|
| `kaiwu-gateway-service` | 可部署 Java 服务 | 外部 API 入口、统一认证、会话检查、项目入口授权和显式路由 |
| `kaiwu-system-service` | 可部署 Java 服务 | 平台控制面后端和代码生成控制面 |
| `kaiwu-system-web` | 可部署前端 | 平台管理 UI |
| `kaiwu-system-starter` | Maven SDK | 本地验证 Gateway Context、建立请求上下文并执行权限注解 |
| `kaiwu-deploy` | GitOps 声明 | 平台、项目与 Gateway Route 的环境期望状态；不保存 Secret |

入口不得复制产品启动或部署逻辑，不得把五个产品仓合并成源码 monorepo，也不得要求普通用户
通过 Git submodule 才能安装。正式发行时，入口与五个产品仓必须提供同名 tag；任一必需仓缺少
该 tag 时初始化失败，不得静默混用默认分支。完整边界见 ADR 0027。

### 3.2 生成业务项目

每个业务项目固定生成两个独立仓库：

```text
kaiwu-{projectCode}-service
kaiwu-{projectCode}-web
```

两个仓库必须满足：

- 各自拥有 `.git`、`CLAUDE.md`、`AGENTS.md`、README、CI 和构建命令。
- 后端仓库不包含 `admin-web/`，前端仓库不包含 Java 模块。
- 可分别构建、发布、扩容、回滚和授权仓库成员。
- 不引用 `kaiwu-system-service` 源码，只能依赖发布到 Nexus 的稳定契约或 Starter。
- Starter 自包含 Context/权限注解契约，不反向依赖 `kaiwu-system-api`。
- 使用独立业务数据库，不在平台库创建业务表。

## 4. 功能需求

### 4.1 登录与当前用户

| 编号 | 需求 | 验收 |
|---|---|---|
| AUTH-001 | 支持用户名和密码登录 | 正确凭据返回 JWT；错误凭据返回统一错误 |
| AUTH-002 | 支持查询当前用户 | 携带有效 JWT 返回用户和从 system 项目角色解析的平台权限 |
| AUTH-003 | 登录失败必须记录登录日志 | 日志包含用户、结果、时间、IP、traceId，不保存密码或 token |
| AUTH-004 | Secret 缺失时启动失败 | 一次性列出全部缺失环境变量名 |
| AUTH-005 | Gateway 统一验证外部访问令牌 | 除精确 PUBLIC 白名单外，所有外部 API 都在 Gateway 验证 issuer、audience、签名和过期时间 |
| AUTH-006 | 在线会话与撤销 | 注销、禁用用户、重置密码或强制下线后，旧会话立即被 Gateway 拒绝 |
| AUTH-007 | Access/Refresh 分离 | Access JWT 15 分钟且只驻留前端内存；Refresh Token 只通过 HttpOnly、SameSite=Strict Cookie 携带，轮换且服务端只保存摘要；会话绝对有效期 7 天；页面刷新后安全恢复会话 |
| AUTH-008 | 外部与内部令牌分离 | 外部 JWT 只能由 Gateway 接受；目标服务只接受 Gateway 签发、绑定 audience 的 60 秒 Context |
| AUTH-009 | 客户端身份头不可信 | Gateway 清除客户端提交的 Context、用户、角色和权限头 |

第一阶段不接入 OIDC、SSO 或第三方身份源。

### 4.2 平台管理

| 编号 | 需求 | 验收 |
|---|---|---|
| SYS-USER-001 | 用户 CRUD、启停、重置密码 | 禁用用户不能登录；用户名唯一 |
| SYS-USER-002 | 用户 Excel 批量运营 | 模板下载、逐行校验回执、无密码导出和最多 200 人批量启停 |
| SYS-ROLE-001 | system 项目角色 CRUD | 在 system 权限中心为角色分配平台菜单和按钮权限 |
| SYS-MENU-001 | system 平台菜单树管理 | 在 system 权限中心支持目录、菜单、按钮三类节点 |
| SYS-PROJECT-001 | system 内置项目 | 初始化时幂等创建，始终 ACTIVE，不可停用、归档或删除 |
| SYS-SESSION-001 | 权限变更即时失效 | system 成员、角色或菜单变化后撤销受影响用户现有会话 |
| SYS-PERM-001 | 平台接口权限校验 | 前端隐藏不能替代后端授权 |
| SYS-DICT-001 | 字典类型和字典项 CRUD | 状态、枚举全部走字典；未知值原样显示 |
| SYS-CONFIG-001 | 平台配置 CRUD | 只管理非敏感配置；疑似密码、token、secret 的 key 必须拒绝保存 |
| SYS-AUDIT-001 | 登录日志和操作日志查询 | 新增、修改、删除和授权操作可追溯 |
| SYS-ORG-001 | 部门树和用户归属 | 支持部门增删改查、树形展示和用户绑定 |
| SYS-SESSION-002 | 安全运营中心 | 分页查询登录/操作日志与在线会话；强制下线立即撤销会话 |
| SYS-SEARCH-001 | 全局搜索 | 按当前权限和项目成员关系搜索项目、交付任务和平台用户 |
| SYS-WORKBENCH-001 | 工作台 | 展示当前用户可见的项目数和最近项目 |
| SYS-AI-001 | 受管大模型 Provider | OpenAI-compatible Base URL、模型、超时、启停和加密 API Key；支持连接测试且密钥不回传 |
| SYS-GIT-001 | 受管 GitLab 配置 | Base URL、默认 Group、启停和加密 Token；支持连接测试且 Token 不回传 |

### 4.3 项目管理

| 编号 | 需求 | 验收 |
|---|---|---|
| PROJECT-001 | 项目 CRUD | `projectCode` 创建后不可修改且全局唯一 |
| PROJECT-002 | 项目仓库登记 | 一个项目分别登记 BACKEND、FRONTEND 两条仓库记录 |
| PROJECT-003 | 项目成员管理 | 只能从平台用户中选择；支持启用和停用成员 |
| PROJECT-004 | 项目角色管理 | 项目角色只在所属项目内有效 |
| PROJECT-005 | 成员多角色 | 一个项目成员可拥有一个或多个项目角色 |
| PROJECT-006 | 项目菜单管理 | 支持目录、菜单、按钮，并绑定项目角色 |
| PROJECT-007 | 按人过滤项目 | 普通用户只能看到自己是有效成员的项目 |
| PROJECT-008 | 按人过滤菜单 | 返回成员角色并集对应的有效项目菜单 |
| PROJECT-009 | 当前项目权限 | 返回字符串 permission code 集合，供 Starter 和前端使用 |
| PROJECT-010 | 项目开通向导 | 一次串联项目、基础成员角色、初始成员和生成任务 |

### 4.4 权限统一契约

认证与授权链路以 ADR 0003 为准：

1. System Service 是全局用户和所有项目权限事实源；Kaiwu 自身也登记为内置 system 项目。
2. Gateway 验证外部 JWT 与在线会话，并按显式 Route Binding 执行项目入口授权。
3. PLATFORM 请求由 Gateway 签发身份 Context，System 从本地事实源执行平台权限和资源授权。
4. PROJECT 请求由 Gateway 从 System 内部接口读取并短缓存项目权限快照，签发短期、目标服务绑定的 Context。
5. System Starter 在目标服务本地验证 Context 并执行 `@RequirePermission`。
6. 目标服务负责数据归属和资源状态等最终授权；System 的组织范围由 System 本地处理。
7. 正常业务请求不得由 Starter 同步回调 System。

同一操作的权限码只能从一份生成元数据派生，并同时出现在：

```text
后端：@RequirePermission("module:resource:action")
前端：<PermissionButton permission="module:resource:action">
SQL： menu.sql 中 BUTTON 节点的 permission_code
```

验收时必须覆盖：

1. 未登录。
2. 缺少项目 ID。
3. 不是项目成员。
4. 是成员但没有权限。
5. 是成员且拥有权限。
6. 项目 ID 与 System 根据 Gateway Route 项目码解析出的权威 ID 不一致。
7. Context audience 与目标服务不一致。
8. 外部 Token 绕过 Gateway 直连业务服务。

前四种情况以及第 6～8 种情况必须失败关闭。

### 4.5 AI 优先的一次性项目生成

| 编号 | 需求 | 验收 |
|---|---|---|
| GEN-001 | AI 描述生成 | 默认以业务描述生成受约束 `ProjectBlueprint` 和 MySQL schema，再由确定性模板渲染第一版项目 |
| GEN-002 | 已有结构生成 | 可粘贴 MySQL `CREATE TABLE` DDL，并结合业务描述生成模块、字段展示和 CRUD |
| GEN-003 | 生成后端服务 | 与 System 一致的 `api/domain/boot` 三模块、单一 Boot 可部署制品，`mvn verify` 通过 |
| GEN-004 | 生成独立管理前端 | Umi Max + AntD 5 + ProComponents，typecheck/build 通过 |
| GEN-005 | 生成 CRUD | Controller、Service、Mapper、Entity、API、页面和请求文件完整 |
| GEN-006 | 生成权限契约 | 后端注解、PermissionButton、menu.sql 三处同码；AI 生成时每个业务菜单使用简洁中文名，不暴露表名或技术前缀，并幂等登记到目标项目权限菜单 |
| GEN-007 | 生成 SQL | 后端仓库包含 `sql/schema.sql` 与 Boot 模块的 `src/main/resources/db/migration/V1__*.sql` |
| GEN-008 | 生成 AI 协作契约 | 两个仓库都带 CLAUDE.md、AGENTS.md、构建命令、确定性本地启动辅助和常见坑 |
| GEN-009 | 生成独立制品 | 后端 ZIP 和前端 ZIP 分开下载，不生成混合仓库 ZIP |
| GEN-010 | 模板质量门禁 | 清空旧样例后验证生成后端 Maven 构建和生成前端 frozen install/typecheck/build；失败版本不得发布 |
| GEN-011 | 确定性 | 相同输入和模板版本产生相同源码；时间戳不进入业务源码 |
| GEN-012 | 管理壳层 | 生成前端按 components/hooks/providers/services/utils 分层，内置 ProjectAccessProvider、PermissionButton、统一 requestJson 和受管字典组件 |
| GEN-013 | 结构化 AI 边界 | 模型只返回受校验的蓝图/schema/展示元数据；源码、权限、路由、CI 和 SQL 文件由版本化模板生成 |
| GEN-014 | 基础脚手架兜底 | 用户可明确选择 `BASIC_SCAFFOLD`，不调用 AI 生成空项目 |
| GEN-015 | 一项目一次生成 | `project_id` 数据库唯一；SUCCESS 后永久拒绝再次生成 |
| GEN-016 | 失败重试 | FAILED 只允许 owner 重试同一任务；PENDING/RUNNING/SUCCESS 均拒绝重复提交 |
| GEN-017 | 临时 MySQL 结构导入 | 只读查询 `information_schema` 并返回 DDL；密码不落库、不进日志、不进入异步任务 |
| GEN-018 | 资源归属 | 每张表在蓝图中声明 `PROJECT_WIDE` 或 `OWNER_ONLY`；OWNER_ONLY 的查询和写入绑定 Gateway Context 用户，并有越权反例测试 |
| GEN-019 | 可靠投递 | 生成与初始推送被有界执行器拒绝时补偿为可重试失败状态，不能遗留 PENDING/PUSHING |

AI 生成的工程含义以 ADR 0006 为准：AI 决定受约束的第一版业务蓝图，Kaiwu 模板把蓝图
变为可执行源码。模型输出不得作为任意文件树或命令直接执行。

### 4.6 GitLab 交付

| 编号 | 需求 | 验收 |
|---|---|---|
| GIT-001 | 创建或绑定两个仓库 | 后端、前端分别创建或绑定同一受管 GitLab 实例中的空仓库 |
| GIT-002 | 不覆盖已有代码 | 非空仓库必须拒绝 |
| GIT-003 | 初始分支 | 新仓库默认 `main`，可由项目管理员配置；平台只向配置分支做一次初始提交，不规定后续分支策略 |
| GIT-004 | 一次初始推送 | 每个仓库只允许一次初始提交；成功后平台永久退出仓库写入权 |
| GIT-005 | 任务授权 | 任务详情、日志、重试和 ZIP 下载必须校验任务创建人 |
| GIT-006 | Token 边界 | 只向配置的 GitLab 实例发送 token；日志、ZIP、commit message 不含 token |
| GIT-007 | 本地交付 | 未配置 GitLab 时仍可生成并下载两个 ZIP |
| GIT-008 | 分仓补偿 | 一侧已推送、另一侧失败时，只允许补推未成功的一侧，已成功仓库不可重写 |
| GIT-009 | 项目工厂交付验收 | 项目工厂统一汇总生成、双制品、双仓推送状态并提供下载、重试、仓库入口和双仓本地 AI Coding 初始化命令，不再设置重复的交付中心 |

### 4.7 CI 与 GitOps

- Kaiwu 只负责生成首版仓库和一次初始推送，不建设发布中心。
- 后续 CI 统一由 GitLab CI 执行，CD 统一由 Argo CD 按 GitOps 仓库期望状态执行。
- Java 仓库只引用公司统一 Java CI 模板。
- Web 仓库只引用公司统一 Node CI 模板。
- CI 至少执行 test/typecheck/build，再构建镜像并更新 GitOps。
- 每个生成项目拥有独立 GitOps 路径：

```text
projects/{projectCode}/argocd/project.yaml
projects/{projectCode}/apps/{test,prod}.yaml
gateway-routes/{env}/routes/{projectCode}.yaml
```

- 业务项目路径可集中在一个部署仓，但必须拥有独立 AppProject、Application、namespace、数据库、
  Secret 与回滚记录；不能因集中存储而共享运行边界。
- 后端和前端仍使用独立 Deployment、Service 和镜像，Application 通过 multi-source 同时引用
  两个源码仓的 `deploy/k8s/`。
- Gateway Route 由平台入口路径统一评审；项目工厂不得自动提交部署仓。
- 数据库名称、账号和密码只通过部署环境注入。

### 4.8 本地一键启动

用户克隆 `kaiwu` 入口并执行 `./kaiwu up` 后，入口应准备四个运行仓并委托 System 的版本化
启动器。底层 `docker compose up` 应启动：

- MySQL 8。
- Redis。
- `kaiwu-system-service`。
- `kaiwu-gateway-service`。
- `kaiwu-system-web`。

`kaiwu-system-starter` 是 SDK，只需完成构建或本地安装，不运行容器。

五分钟黄金路径：

1. `./kaiwu doctor` 给出可理解的环境检查结果。
2. `./kaiwu up` 获取兼容版本的运行仓并使服务健康。
3. 打开 8000。
4. 使用管理员登录。
5. 创建用户和项目。
6. 将用户加入项目并分配项目角色。
7. 当前用户只能看到已加入项目及其菜单。

### 4.9 平台国际化

国际化以 ADR 0011 为准。`zh-CN` 与 `en-US` 是初始完整语言；其它语言由
`platform.locale` 和数据库译文扩展，覆盖门禁通过后才对用户开放。

| 编号 | 需求 | 验收 |
|---|---|---|
| I18N-001 | 用户语言偏好 | System 在 `sys_user` 持久化 locale；登录、刷新和当前用户接口返回该值 |
| I18N-002 | 跨浏览器恢复 | 用户在任意全新浏览器登录后自动应用服务端语言设置，不依赖浏览器语言或 Local Storage |
| I18N-003 | 安全修改 | 登录用户只能修改自己的 locale；服务端只接受 `platform.locale` 中启用且覆盖完整的规范 BCP 47 locale，客户端不能指定 userId |
| I18N-004 | 无刷新切换 | 保存成功后当前页面无刷新切换语言，Access/Refresh Token 仍只驻留内存且登录态不丢失 |
| I18N-005 | 动态菜单 | `sys_project_menu.menu_name_i18n` 保存 locale→文本 JSON；System 按用户 locale 返回最终名称，缺翻译回退 `menu_name`，前端不推导 key、不维护第二棵菜单树 |
| I18N-006 | 显示与协议分离 | 翻译不改变权限码、字典值、状态码、19 位 ID、请求参数、JWT 或 Gateway Context |
| I18N-007 | 资源中心 | 固定 UI 与 API 提示从 `sys_i18n_message` 获取；资源管理支持动态语言字段、乐观锁、占位符一致性、纯文本校验和审计 |
| I18N-008 | 生成项目边界 | 平台国际化不回写已 SUCCESS 项目；生成项目若需国际化，必须另发脚手架版本 |
| I18N-009 | 语言开放门禁 | 只有目录配置允许且必需资源、内置菜单、全局字典译文全部覆盖的语言才出现在选择器；不得展示半翻译界面 |
| I18N-010 | 故障恢复 | Web 只保留登录与资源故障所需的最小救援包；catalog 加载失败保留上一份完整快照，不清除会话、不写入新偏好 |
| I18N-011 | 跨服务错误契约 | System、Gateway、Starter 的用户可见错误都返回稳定 `messageKey/messageArgs`；状态码和机器 code 不因语言改变 |

## 5. 数据边界

平台库只保存平台控制面数据：

```text
sys_user
sys_role / sys_menu（仅 legacy 兼容种子）
sys_dict_type / sys_dict_item / sys_config
sys_i18n_message / sys_i18n_catalog_revision
sys_login_log / sys_oper_log / sys_department / sys_user_department
sys_project / sys_project_repository
sys_project_member / sys_project_role / sys_project_member_role
sys_project_menu / sys_project_role_menu
project_create_task / task_step_log
sys_runtime_task
sys_project_generation
sys_gitlab_config
```

`sys_project_*` 是运行态角色、菜单和权限授权的权威模型；`sys_role/sys_menu` 仅为早期版本
兼容表与 system 首次迁移种子，新功能不得继续写入第二套平台角色权限事实。

每个生成项目使用自己的业务库。业务服务不得读写平台数据库；平台服务不得读写业务表。

`sys_project_repository` 至少包含：

- `project_id`
- `repository_type`：BACKEND 或 FRONTEND
- `gitlab_project_id`
- `web_url`
- `http_clone_url`
- `ssh_clone_url`
- `default_branch`

GitLab token、数据库密码、JWT 密钥等 Secret 不进入 `sys_config` 或其它业务表。
GitLab Token 只以 AES-GCM 密文进入 `sys_gitlab_config`；数据库导入密码完全不持久化。

## 6. 非功能需求

| 编号 | 要求 |
|---|---|
| NFR-001 | Java 21、Spring Boot 4、MyBatis-Plus、MySQL 8、Redis、Nacos |
| NFR-002 | 前端使用 `@umijs/max`、AntD 5、ProComponents |
| NFR-003 | Gateway 禁止 discovery locator，只允许显式路由 |
| NFR-004 | 19 位 ID 在 JSON 和 TypeScript 中使用字符串 |
| NFR-005 | 全新库从 `V1__kaiwu_baseline.sql` 初始化；后续 SQL 变更从 V2 开始递增并同步 `sql/schema.sql` |
| NFR-006 | Secret 不进入源码、配置样例、文档、日志、ZIP 或提交 |
| NFR-007 | 禁止直接在受保护分支实现；平台与生成项目不绑定特定个人开发分支名称 |
| NFR-008 | 每个仓库可单独 clone、build、test、deploy 和 rollback |
| NFR-009 | 失败的初始生成任务可由 owner 重试；SUCCESS 永久锁定，分仓推送只补偿未成功侧 |
| NFR-010 | 关键操作携带 traceId 并进入审计日志 |
| NFR-011 | Gateway Route 必须显式配置 accessMode、audience 和稳定的 projectCode 绑定；禁止自动发现即暴露 |
| NFR-012 | System/Gateway 分别使用独立 RS256 密钥对；私钥只通过部署 Secret 注入 |
| NFR-013 | PROJECT 权限快照使用 Gateway 本地有界缓存，允许 30 秒、拒绝 5 秒；缓存未命中且 System 不可用时失败关闭 |
| NFR-014 | Compose 不向宿主机暴露 System；部署环境只允许 Gateway 访问用户入口 API |
| NFR-015 | Gateway 与 Starter 统一输出不含 query、载荷和凭据 Header 的访问摘要；身份字段只来自已验证上下文，System 持久化审计与访问日志职责分离 |

## 7. 第一阶段明确不做

- Workflow。
- Integration 独立服务。
- AI Development Harness。
- 发布中心。
- 共享部署模式。
- 大模型返回任意源码文件树、Shell、权限或路由，或自动执行外部变更。
- OIDC/SSO。
- 通用 IAM、复杂 ABAC/OPA 策略引擎和通用 Context 平台；第一阶段只实现 ADR 0003 的最小 audience-bound Context。
- 业务服务之间的通用编排平台。

## 8. 第一阶段完成判定

只有同时满足以下条件才算完成：

1. 四个运行仓可以独立 clone 和构建，部署仓可以独立校验和发布声明。
2. 用户只克隆 `kaiwu` 入口即可执行环境检查和 Compose 五分钟黄金路径，不需要手工拼装五仓。
3. 平台管理和项目权限功能通过真实 API 与浏览器验收。
4. AI 根据描述生成一个示例项目后得到两个 Git 仓库、两个 ZIP、两个 CI 和两条 GitOps 路径。
5. 生成后端单模块构建通过，生成前端 typecheck/build 通过。
6. ADR 0003 定义的鉴权正反用例全部通过。
7. 平台库与示例业务库不存在交叉业务表。
8. 仓库和产物扫描不包含 Secret。
9. 同一示例项目第二次生成被数据库约束和服务端同时拒绝。
10. 远端仓库出现人工提交后，平台推送失败关闭且不覆盖任何文件。
