# ADR 0044：项目数据范围（Data Scope）

- 状态：Accepted（D0–D6 已合入 dev；可选组件的公开发行随平台 0.2.0）
- 日期：2026-11-03
- 决策范围：`kaiwu-system-service`（表、清单同步、配置移交、权限快照、项目模板）、`kaiwu-gateway-service`（Context）、
  `kaiwu-system-starter`（`KaiwuContext` 与新增 `kaiwu-data-scope` 模块）、`kaiwu-system-web`（角色页）
- 部分取代：ADR 0003 §5 末段「第一阶段 PROJECT Context 不携带通用 DataScope」，以及 `docs/ARCHITECTURE.md` §8.4 的同一句
- 修订：ADR 0030「`dataScope` 只能使用 `ALL`、`MEMBER_PROJECTS`、`SELF`」，增加 `ROLE_SCOPED`
- 补充：ADR 0017（MyBatis-Plus）、ADR 0036（清单同步）、ADR 0038（约束兜住 AI 产出）、ADR 0048（MySQL 与达梦）、
  ADR 0042（配置移交）
- 契约文档：[docs/DATA_SCOPE.md](../DATA_SCOPE.md)

## 背景

菜单与 `@RequirePermission` 只回答「能不能用这个功能」，回答不了「能看、能改哪些行」。
同一项目里，销售只看自己的客户、经理看本部门及下级、总监看全部，是业务系统的常见需求。

现状：

1. ADR 0003 §5 把「数据归属」留给目标服务，并写明 PROJECT Context 不携带通用 DataScope，
   出现真实需求时「再单独提交 ADR，不能用普通 Header 临时扩展」（`docs/adr/0003-gateway-centric-authentication.md:132`，
   同句见 `docs/ARCHITECTURE.md:462`）。本 ADR 即是这次提交。
2. 工程约束 `auth.resource-ownership`（`docs/kaiwu-constraints.json`）要求生成与业务 CRUD 显式声明
   `PROJECT_WIDE` 或 `OWNER_ONLY` 并有越权反例测试。它只覆盖「本项目全部 / 仅本人」两档，没有部门这一层，
   也没有可由管理员配置的角色差异。本 ADR 是它的扩展，不取代它：未引入本模块的项目继续按该约束执行。
3. 数据由 AI 工具编写（ADR 0038）。AI 很容易只做菜单权限而漏掉行级范围，且列表、详情、导出、统计、Agent 查询
   各写一份，口径必然不一致。
4. Agent 能力的 `DataScope` 枚举（Starter 与 System 各一份，见下）曾有 `ORG`，因「平台没有基于组织的数据权限实现」被删除。
   本 ADR 落地后才有可执行实现。
5. System 已有 `sys_department`（含 `parent_id`）与 `sys_user_department`（含 `primary_department`），
   `sys_project_role` / `sys_project_member_role` 承载项目角色，部门 ID 由 `OrgServiceImpl.nextId()` 生成
   （`kaiwu-system-domain/.../identity/service/impl/OrgServiceImpl.java:339`）。

## 决策

### 1. 不新增服务，三段式落地

System 计算范围，Gateway 在已签名的内部 Context 中携带，业务服务由可选模块在 SQL 层强制执行。
请求路径不新增任何网络调用，不违反「正常业务请求不得回调 System」。

### 2. 范围类型是固定枚举

`ALL`、`DEPT_AND_CHILD`、`DEPT`、`SELF`、`CUSTOM_DEPT`（可选含下级）。不接受自定义字符串、表达式或 SQL。

- 除 `ALL` 外均隐含本人数据，所有类型归约为「`ALL`」或「本人 ∪ 部门集合 D」。
- 多角色取并集。多部门用户的 `DEPT` 类范围取全部所属部门，写入时的归属部门取主部门。
- 角色未配置时一律为 `SELF`，由平台固定；内置 `project-admin` 固定为 `ALL`，不可配置。

### 3. 受控资源由业务仓库声明，授权不随代码下发

业务仓 `kaiwu/data-scopes.yml` 声明资源码、表名、归属人列、归属部门列和允许的范围（用于收窄可选项，必须包含 `SELF`）。
清单纳入 ADR 0036 的 plan/apply 同步，只新增不删除。同一文件打包进业务服务 classpath，供运行时读取，是两侧唯一的事实源。
清单**不包含任何默认范围或授权**，遵守 ADR 0036「授权属于安全决策，不跟随代码自动扩散」。

受控表的归属列必须 `NOT NULL`、无默认值，并各自建单列索引。存的是归属部门 ID 而不是部门路径，部门树调整不需要回刷业务数据。
部门 ID 来自平台库，重建平台库或迁移安装时必须保留。

可见性以归属人为准：调部门不自动改写业务数据，原归属人会一直可见，直到业务侧通过 `DataScopes.reassign` 转移归属。
受控资源须提供按归属人批量转移的接口，用于调岗和离职交接。

### 3a. 随配置移交（ADR 0042）

角色的数据范围属于授权，随 `roles.yml` 移交。`CUSTOM_DEPT` 以 `dept_code` 表示；导入时归入授权组，默认不执行；
目标环境缺少部门或资源时标红，不能勾选。`project-admin` 不进移交包（`ProjectManifestParser.java` 的 `role()` 已拒绝它），
其固定 `ALL` 语义由平台保证。

### 4. System 解析，随项目权限快照下发

- 新增 `sys_project_data_resource`、`sys_project_role_data_scope`、`sys_project_role_data_scope_dept`，
  MySQL 与达梦迁移同版本维护（ADR 0048）。只新增表，不改已有表。
- 沿用 ADR 0022 的 `GET /api/internal/gateway/project-access`，响应 `ProjectAccessView` 新增 `dataScope`：主部门、部门字典
  （每个 ID 只出现一次），以及每个资源的归约结果（`all` 或字典下标数组）和内容指纹 `fp`。项目未声明受控资源时不输出该字段。
- 收敛窗口沿用 Gateway 对该响应的 30 秒本地缓存。`authzVersion` 现为会话级平台权限摘要，本 ADR 不改变其含义。
- `dataScope` 序列化后（编码前）不超过 6 KiB，对外宣称单用户可见部门不超过 128 个。
  超限时 System 返回 403（`messageArgs.reason=DATA_SCOPE_TOO_LARGE`），Gateway 按既有拒绝处理，禁止截断；完整 Context 仍受 16 KiB 约束（ADR 0003 §1）。

### 5. Gateway 只透传

Gateway 不解释 `dataScope` 语义，原样写入内部 Context 的 `ds` 声明，包括 Agent 读写委托链路
（`AgentDelegationController`、`AgentWriteDelegationController`）。不新增 Header。

### 6. Starter 默认生效，显式旁路

`KaiwuContext` 增加可空的 `dataScope`。执行逻辑放在独立 artifact `kaiwu-data-scope`，主 Starter 不引入 MyBatis。

- 按表而不是按方法生效：触达受控表的 SELECT、UPDATE、DELETE 自动追加谓词；LEFT JOIN 的谓词放进 ON；
  `INSERT … SELECT` 的查询部分同样加谓词。拦截器必须排在分页之前，否则启动失败。
- 受控表上的 `INSERT … ON DUPLICATE KEY UPDATE`、`REPLACE`、`MERGE` 一律拒绝（`unrestricted` 内除外）。
- UPDATE 不得修改归属列，归属转移只能经 `DataScopes.reassign(reason, ...)`。源行受当前范围约束；
  新归属人须为项目有效成员，新部门须为其所属部门之一。
- 普通路径的 INSERT 由 Starter 以 Context 覆盖归属列，不信任请求值；`reassign` 或 `unrestricted` 内保留实体值，且两列必须非空。
- 没有 Context 却触达受控表、或 SQL 无法解析时抛异常；Context 中缺失某资源规则时按 `SELF` 处理。
- 唯一旁路是 `DataScopes.unrestricted(reason, ...)`，理由必填并写日志。不提供忽略注解。
- 越权的详情、修改、删除对外返回 404。

不覆盖 `JdbcTemplate`、缓存与外部检索；生成项目的 `DataScopeConventionTest` 负责拦截这些路径，
并要求权限保护的列表、导出类接口所用的表要么受控，要么在清单的 `exempt` 中写明理由。

### 7. Agent 能力增加 `ROLE_SCOPED`

Starter 的 `com.kaiwu.starter.agent.protocol.DataScope` 与 System 的
`kaiwu-system-domain/.../module/agent/protocol/DataScope.java` 两份枚举都增加 `ROLE_SCOPED`，
语义为「项目内，按调用者角色数据范围」。读取或写入受控资源的能力声明它；System 注册校验要求其权限前缀对应已同步的受控资源，
对受控资源声明 `ALL` 的能力注册时拒绝。`ALL` 继续表示「项目内全部数据」。

### 8. AI Skill 与模板随 Starter 发布

`kaiwu-data-scope` Skill 与模块同版本发布，项目工厂生成时写入 `.agents/skills/` 与 `.claude/skills/`。
生成项目 `MybatisPlusConfig` 以 `ObjectProvider` 可选注册拦截器，未引入模块时行为不变。

## 后果

- 正面：行级范围有了统一、可配置、可审计的实现；列表、统计、导出、Agent 口径一致；AI 漏写时测试或门禁会失败，而不是静默越权。
- 负面：Context 体积增加；部门很多的用户受 128 个部门的对外上限约束；调岗交接依赖业务侧主动转移；
  部门 ID 进入业务库，迁移时必须保留；手写复杂 SQL 可能被拒。
- 存量项目接入要给业务表加列并回填，属于改库，逐项目另行确认，本 ADR 不强推。
- 不变：PLATFORM 请求、System 自身组织范围、跨项目隔离、字段级权限均不在本 ADR 内。

## 被否决方案

- **独立数据权限服务**：业务请求同步回调，违反 ADR 0003 背景第 5 条。
- **Starter 定时拉取规则与部门树**：收敛周期远长于 30 秒，且在每个服务形成第二份权限事实。
- **业务行存部门路径、Context 只带直属部门**：部门调整需回刷全部业务表。
- **方法注解驱动**：漏标即越权，正是本 ADR 要防的失误。
- **清单声明默认范围**：会作用于所有未配置的角色，等同由代码授权，违反 ADR 0036。

## 迁移与回滚

- 新表只新增，不改已有表；项目未声明资源时 Context 字节级不变。
- 回滚顺序：业务服务移除模块 → Gateway 停止写 `ds` → System 停止输出 `dataScope`。表保留一个版本后另行确认清理。
- 本 ADR 为 Proposed。D1 起的实现合入前，ADR 0003 与 ARCHITECTURE 中被部分取代的句子只加注，不删原文。
