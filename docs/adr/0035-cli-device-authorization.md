# ADR 0035：CLI 设备授权，让 AI 编码工具代用户开通和取回项目

- 状态：Accepted
- 日期：2026-10-28
- 决策范围：`kaiwu-system-service`、`kaiwu-system-web`、`kaiwu-gateway-service`、`kaiwu` 入口仓
- 补充：ADR 0003、ADR 0006、ADR 0019

## 背景

P0 实测（2026-10-28，Trae、CodeBuddy、Codex）证明，AI 编码工具能从空目录把 Kaiwu 启动到可登录。
但启动之后，"生成一个业务项目并在本机跑起来"这条链路，前半段全在浏览器里：
登录、建项目、生成、下载两个 ZIP。AI 工具接不上，用户只能自己点完再把文件交回给 AI。
后半段（`import-project-menu`、`project-up`）早已是命令行。

ADR 0006 的 GitLab 一次推送原本承担"生成物落到开发者手里"的职责。但它只支持 GitLab，
对 AI 工具也没有缩短路径，已降级为可选能力。

让 AI 工具驱动浏览器界面不可取：界面一改就失效，各工具的浏览器能力不一，而且 AI 必须经手用户密码。
网页的每个操作背后本来就有受 Gateway 保护的 API，缺的只是一种不经手密码的命令行授权方式。

## 决策

### 1. 设备授权流程

参照 OAuth 2.0 Device Authorization Grant（RFC 8628）的交互形态，但签发的是 Kaiwu 现有的登录会话，
不引入新的令牌类型：

1. `POST /api/auth/device/start`（PUBLIC）：System 生成高熵 `device_code` 和便于人工核对的短
   `user_code`（例如 `KWAI-7F3Q`），10 分钟过期。响应包含 `verification_uri`（`/device`）、
   `user_code`、轮询间隔，以及 CLI 在发起时声明的客户端名称（例如 `Trae`）。
2. 用户在**已登录**的平台页面 `/device` 输入或确认 `user_code`，页面显示客户端名称、发起时间和
   "将以你的身份操作平台"的说明。用户点击允许或拒绝，对应受保护的
   `POST /api/auth/device/approve` 或 `/deny`。
3. `POST /api/auth/device/token`（PUBLIC，按 `device_code` 轮询）：用户允许后，System 以该用户身份
   创建一个**普通在线会话**，返回 Access Token，并按 ADR 0019 下发 Refresh Cookie。
   `device_code` 一次性消费。被拒绝或过期时返回明确的错误码。

### 2. CLI 会话即普通会话

- 权限与用户本人相同。不新增会话级权限范围，RBAC 仍是唯一的授权事实源。
- 会话记录新增来源字段 `source = CLI` 和客户端名称。安全运营中心的在线会话列表据此展示，
  并可强制下线。
- 生命周期完全沿用 ADR 0019：Access Token 15 分钟，Refresh Token 每次轮换，绝对有效期 7 天、
  轮换不续期。过期后重新执行 `kaiwu login`。
- 用户被禁用、重置密码、强制下线时，CLI 会话与浏览器会话一并失效。
- 操作审计记录会话来源，用于区分哪些操作经由 CLI 或 AI 执行。

### 3. CLI 命令

由 System 仓的 `scripts/kaiwu.sh` 实现（入口仓只转发，遵守 ADR 0027）。Refresh Cookie 存在工作区外的
`.kaiwu/cli-session`（权限 0600），不进入任何 Git 仓库，不打印到终端。

| 命令 | 作用 |
|---|---|
| `kaiwu login` / `logout` / `whoami` | 设备授权登录、注销当前 CLI 会话、查看当前身份 |
| `kaiwu project new <code> --name <名称> --ddl <文件>` | 登记项目并发起确定性生成；当前用户按现有开通规则成为项目管理员 |
| `kaiwu project status <code> [--wait]` | 查询或等待生成完成 |
| `kaiwu project pull <code> [--dir <目录>]` | 下载两个 ZIP，解压到 `<目录>/<code>-service` 与 `<code>-web`，各自 `git init` 并做首次提交；目标目录已存在时拒绝覆盖 |

`project new` 只接受 DDL 输入。表结构由 AI 编码工具在本地设计，平台不需要配置自己的 AI 提供方。

### 4. 新增确定性生成模式 `DDL_SCAFFOLD`

现有两种模式都不满足上面的要求：`BASIC_SCAFFOLD` 不读 DDL；`AI_PROJECT` 读 DDL，但强制要求平台已配置
并启用 AI，且必须填写业务描述。项目工厂新增第三种模式：

- `DDL_SCAFFOLD`：必须提供 DDL，业务描述可选。DDL 经现有解析器与规模校验后，直接进入确定性脚手架，
  不调用任何 AI，也不读取 AI 配置。元数据补全使用现有的 `DETERMINISTIC_FALLBACK` 结果。
- 一次生成、一次交付与 owner 校验等 ADR 0006 的约束全部不变。
- 网页上的"AI 生成项目"和"基础空项目"入口保持不变；是否在网页上开放 `DDL_SCAFFOLD`，另行决定。

### 5. 安全边界

- AI 工具在任何环节都接触不到用户密码，授权动作只发生在用户自己的已登录浏览器里。
- `device/start` 与 `device/token` 是新的 PUBLIC 端点，必须在 Gateway 显式白名单中逐条登记，
  并按客户端 IP 限流。`device_code` 只以摘要形式存储。
- `/device` 页面必须展示客户端名称和 `user_code`，由用户核对后再允许，防止诱导用户授权他人发起的请求。
- 不提供"记住此设备"或长期令牌，7 天绝对有效期即上限。

## 被否决方案

- **AI 驱动浏览器操作界面**：脆弱、依赖工具能力，并且需要 AI 经手密码。
- **CLI 用账号密码登录**：AI 工具会接触并可能记录用户密码。
- **本机专用静态令牌（写在 `.kaiwu/dev.env`）**：只适用于本机部署，服务器部署仍需另一套方案；
  静态令牌不随用户禁用或改密失效，与现有会话治理割裂。
- **个人访问令牌（PAT）**：需要新的令牌类型、存储、吊销界面和 Gateway 校验路径，与 ADR 0003 的
  单一外部令牌模型并行。设备授权复用现有会话即可满足需求，PAT 等出现服务器间集成需求时再评估。
- **会话级权限范围**：需要扩展 RBAC 与 Gateway Context。第一版用审计标记、可强制下线和 7 天上限控制风险。

## 后果

- AI 工具可以完成"一句话生成业务项目并在本机跑起来"：`login`、`project new`、`project pull`、
  `import-project-menu`、`project-up`，最后在浏览器打开。
- 新增设备授权端点、一个确认页面、会话来源字段、`DDL_SCAFFOLD` 生成模式（一次 Flyway 增量）及其测试。
- 第一版 CLI 基于 bash，覆盖 Mac、Linux、WSL。Windows 原生 PowerShell 可在后续以 Node 版 CLI
  实现同一套命令，接口不变。
- 入口仓 `AGENTS.md` 需要把这套流程写成标准路径。

## 补充：CLI 会话的权限范围

CLI 会话与用户本人同账号，但只需要「生成并取回项目、同步清单」。签发和刷新时，会话权限收窄为
用户权限与固定范围的交集（`CliSessionScope`）：

- 项目工厂：`system:project-factory:generate`、`list`、`download`；
- 项目：`system:project:list`、`system:project:create`（`project new` 先登记项目再生成）、`system:project:member`、`system:project:role`（`access` 命令只服务平台管理员）；
- 清单同步写入：`system:dict:save`、`system:config:save`、`system:project:menu`。
- 对象存储（ADR 0040）：`system:storage:list`、`system:storage:save`、`system:storage:test`（`storage` 命令；账号的创建与修改由 `StorageController` 对 CLI 会话直接拒绝）。

不在范围内的权限（用户、角色、系统配置、仓库推送、项目修改与状态变更等）不进入 CLI 会话的快照，
因此网关与 system 的权限检查都不会放行。用户在范围内本来没有的权限不会被补上；网页会话不受影响。
新增 CLI 命令需要新权限时，必须同步修改 `CliSessionScope` 并在评审中说明理由。

### 项目内成员与角色授权命令

`./kaiwu access ...` 管理业务项目的成员与角色（`members`、`roles`、`permissions`、`member-set`、
`member-remove`、`role-create`、`role-grant`），走 `/api/current/projects/{id}/access-admin/**`。
这组接口按调用者**在该项目里**的 `access:member:*`、`access:role:*` 权限码把关（`ProjectAccessGuard`），
网页「项目成员」「角色授权」页面的项目管理员据此使用。**命令行会话只服务平台管理员**：CLI 会话的权限快照带有
标记权限 `cli:session`（`CliSessionScope.MARKER`），守卫认出它之后，除了项目内权限码，还要求会话持有平台级
`system:project:member`（成员相关）或 `system:project:role`（角色与授权相关）；这两个权限已纳入 CLI 会话范围。
所以业务项目的普通管理员不能用 CLI 管成员，仍在网页里管；平台管理员两边都能用。审计照常记录。
命令用登录名、角色编码、
权限码作参数，由服务端解析成 ID，AI 工具不需要认识内部 ID。

## 迁移与回滚

- 纯新增能力，不改变现有登录、刷新与会话语义。
- 回滚时停用 Gateway 白名单中的两个 PUBLIC 端点并下线 `/device` 页面即可。已签发的 CLI 会话可在
  安全运营中心批量强制下线，或等待 7 天自然过期。

### 已登记业务项目的工作区入口

使用 `kaiwu project entry <项目编码> <入口名称> <服务根地址>` 设置工作区入口并同步默认后端服务。例如：

    kaiwu project entry life-story-admin 人生故事管理 http://kaiwu-life-story-admin-service:8080

服务端根据项目编码生成同源路径。设备会话刷新时，仅对本人原有 `system:project:update` 权限派生 `cli:project:entry`。该权限仅供入口接口使用。项目必须启用且属于业务项目，登记和审计在同一事务内完成。入口配置读回后仍需通过工作区验证前端和服务部署。
