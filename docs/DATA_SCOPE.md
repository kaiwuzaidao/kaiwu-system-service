# Data Scope 契约

决策见 [ADR 0044](adr/0044-project-data-scope.md)（Proposed）。本文是 System、Gateway、Starter、Web 四个仓库共同遵守的接口契约：
实现者只读本文即可各自独立开发，字段、取值、规范化规则与 ADR 冲突时以 ADR 为准并回头修订本文。

适用范围仅限 **PROJECT 请求**。PLATFORM 请求不携带 `ds`，System 自身的组织范围仍由 System 本地处理。

## 1. 术语

| 术语 | 含义 |
|---|---|
| 受控资源 | 业务项目在 `kaiwu/data-scopes.yml` 里声明的一张业务表及其两个归属列 |
| 资源码 | 受控资源的稳定标识，格式同权限前缀「模块:资源」，例如 `crm:customer` |
| 范围类型 | `ALL`、`DEPT_AND_CHILD`、`DEPT`、`SELF`、`CUSTOM_DEPT` 五种固定值 |
| 部门字典 | `ds.depts`，本次 Context 中出现过的部门 ID 去重列表；规则用下标引用它 |
| 归约结果 | 某用户在某资源上的最终范围：`all`，或一个部门下标集合（隐含本人） |

所有 ID 在 JSON 中使用字符串（ADR 0003 §7）。

## 2. `kaiwu/data-scopes.yml`

位于业务后端仓 `kaiwu/` 目录，与 `dicts.yml`、`configs.yml`、`menus.yml` 并列，随 ADR 0036 的 manifest plan/apply 同步。
同一文件由 Boot 模块打包到 classpath 的 `META-INF/kaiwu/data-scopes.yml`，供 `kaiwu-data-scope` 运行时读取。

```yaml
resources:
  - code: crm:customer
    name: 客户
    table: crm_customer
    ownerUserColumn: owner_user_id
    ownerDeptColumn: owner_dept_id
    allowedScopes: [ALL, DEPT_AND_CHILD, DEPT, SELF, CUSTOM_DEPT]

exempt:
  - { table: crm_industry, reason: 行业字典，全员共享 }
```

### 字段

`resources[]`：

| 字段 | 类型 | 必填 | 约束 |
|---|---|---|---|
| `code` | string | 是 | 1–128 字符；`^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$`；清单内唯一；模块部分须与 `docs/kaiwu-project-blueprint.json` 登记的 `permissionPrefix` 一致 |
| `name` | string | 是 | 1–100 字符，管理端展示名 |
| `table` | string | 是 | 1–64 字符；`^[a-z][a-z0-9_]*$`；清单内唯一；不得同时出现在 `exempt` |
| `ownerUserColumn` | string | 否 | 默认 `owner_user_id`；规则同 `table` |
| `ownerDeptColumn` | string | 否 | 默认 `owner_dept_id`；规则同 `table`；不得与 `ownerUserColumn` 相同 |
| `allowedScopes` | string[] | 是 | 取值于五种范围类型；去重；**必须包含 `SELF`**；最多 5 项 |

`exempt[]`：

| 字段 | 类型 | 必填 | 约束 |
|---|---|---|---|
| `table` | string | 是 | 规则同上；不得出现在 `resources` |
| `reason` | string | 是 | 1–255 字符，非空白 |

### 明确不存在的字段

清单**不得**出现 `defaultScope`、`defaultScopes`、`roles`、`grants` 或任何授权相关字段；解析遇到未知字段一律报错，
不静默忽略。理由：授权不随代码自动扩散（ADR 0036、ADR 0042）。

### 同步语义

- 只新增和更新，不删除：清单里消失的资源在平台侧保持 `ENABLED`，计划里作为「漂移」展示，由人决定下线（置 `DISABLED`）。
- 同步不产生任何角色授权变化。`allowedScopes` 收窄后，已有配置超出新范围的角色在计划中标出，
  这些配置按 `SELF` 生效，需管理员重新选择。
- 计入 plan 的摘要哈希与 409 并发保护，规则同 ADR 0036。

## 3. 范围类型与归约

### 3.1 五种类型

| 类型 | 配置 | 归约结果（对一个用户） |
|---|---|---|
| `ALL` | 无 | `all = true` |
| `DEPT_AND_CHILD` | 无 | 用户全部所属部门，及这些部门的全部下级 |
| `DEPT` | 无 | 用户全部所属部门（不含下级） |
| `SELF` | 无 | 空集合 |
| `CUSTOM_DEPT` | 部门列表 + `includeChild` | 配置的部门；`includeChild=true` 时再加这些部门的全部下级 |

- 「所属部门」取 `sys_user_department` 中该用户的全部记录，不论是否主部门。
- 「下级」沿 `sys_department.parent_id` 递归。
- 状态为停用的部门仍参与归约，部门是否停用不改变业务数据的归属；被删除的部门（已无记录）自然不在结果中。

### 3.2 谓词形态

除 `ALL` 外，所有类型都**隐含本人数据**。归约结果只有两种形态，Starter 据此生成唯一一种谓词：

| 归约结果 | 谓词 |
|---|---|
| `all = true` | 不追加条件 |
| 部门集合 D 非空 | `(owner_user_id = :uid OR owner_dept_id IN (D))` |
| 部门集合 D 为空 | `owner_user_id = :uid` |

### 3.3 多角色与特殊角色

用户在项目中可有多个有效角色，对每个资源：

1. 任一角色解析为 `ALL` → 结果 `ALL`；
2. 否则取各角色部门集合的并集；
3. 某角色在该资源上没有配置 → 该角色贡献 `SELF`（空集合）；
4. 内置角色 `project-admin` 在所有资源上固定为 `ALL`，**不读取也不写入** `sys_project_role_data_scope`；
5. 用户没有任何所属部门时，`DEPT`、`DEPT_AND_CHILD` 退化为 `SELF`。

### 3.4 真值表

| 用户角色（该资源上的配置） | 用户所属部门 | 归约结果 |
|---|---|---|
| `project-admin` | 任意 | `ALL` |
| 无配置 | 任意 | `SELF`（D = ∅） |
| `SELF` | 任意 | D = ∅ |
| `DEPT` | {A} | D = {A} |
| `DEPT` | {A, B} | D = {A, B} |
| `DEPT` | 无 | D = ∅ |
| `DEPT_AND_CHILD` | {A}，A 的下级为 {A1, A2} | D = {A, A1, A2} |
| `DEPT_AND_CHILD` | 无 | D = ∅ |
| `CUSTOM_DEPT`（{X}，不含下级） | 任意 | D = {X} |
| `CUSTOM_DEPT`（{X}，含下级，X 的下级为 {X1}） | 任意 | D = {X, X1} |
| `ALL` | 任意 | `ALL` |
| `DEPT`（角色 1）+ `CUSTOM_DEPT` {X}（角色 2） | {A} | D = {A, X} |
| `DEPT`（角色 1）+ `ALL`（角色 2） | {A} | `ALL` |
| `DEPT`（角色 1）+ 无配置（角色 2） | {A} | D = {A} |

## 4. 项目权限快照中的 `dataScope`

沿用 ADR 0022 的内部接口，不新增接口：

```http
GET /api/internal/gateway/project-access?projectCode=<code>&userId=<id>
X-Kaiwu-Internal-Token: <KAIWU_GATEWAY_INTERNAL_TOKEN>
```

响应 `Result<ProjectAccessView>` 的 `data` 在现有字段（`projectId`、`projectCode`、`permissions`、`projectRoleCodes`）之外
新增可选字段 `dataScope`。**项目没有任何 `ENABLED` 的受控资源时，字段不出现**，响应与改动前字节一致。

### 4.1 结构

```json
{
  "projectId": "9001",
  "projectCode": "demo",
  "permissions": ["crm:customer:list"],
  "projectRoleCodes": ["sales-manager"],
  "dataScope": {
    "v": 1,
    "primaryDeptId": "101",
    "depts": ["101", "102", "105"],
    "rules": {
      "crm:contract": { "all": true },
      "crm:customer": { "set": [0, 1, 2] },
      "crm:followup": { "set": [] }
    },
    "fp": "d361b479f54b4be2"
  }
}
```

### 4.2 JSON schema

```json
{
  "type": "object",
  "required": ["v", "depts", "rules", "fp"],
  "additionalProperties": false,
  "properties": {
    "v": { "const": 1 },
    "primaryDeptId": { "type": "string", "pattern": "^[0-9]{1,19}$" },
    "depts": {
      "type": "array",
      "uniqueItems": true,
      "items": { "type": "string", "pattern": "^[0-9]{1,19}$" }
    },
    "rules": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$" },
      "additionalProperties": {
        "oneOf": [
          {
            "type": "object", "required": ["all"], "additionalProperties": false,
            "properties": { "all": { "const": true } }
          },
          {
            "type": "object", "required": ["set"], "additionalProperties": false,
            "properties": {
              "set": {
                "type": "array", "uniqueItems": true,
                "items": { "type": "integer", "minimum": 0 }
              }
            }
          }
        ]
      }
    },
    "fp": { "type": "string", "pattern": "^[0-9a-f]{16}$" }
  }
}
```

附加约束（schema 无法表达，实现须校验，违反即视为非法）：

- `set` 中每个下标必须小于 `depts` 的长度；
- `depts` 只包含至少被一个 `set` 引用的 ID，**不包含**未被引用的 ID（`primaryDeptId` 单独存放，不要求在 `depts` 中）；
- `rules` 的键必须是该项目当前 `ENABLED` 的受控资源码；
- `primaryDeptId` 缺省表示用户没有任何所属部门，Starter 写入归属部门时取 `0`（见 §6）。

### 4.3 规范化规则

同一输入必须产出字节相同的输出，用于测试比对与 `fp`：

1. `depts` 按数值升序排列（先比位数，位数相同再按字典序）；
2. 每个 `set` 内的下标升序排列；
3. `rules` 的键按字典序排列；
4. 紧凑序列化：无空白，键顺序固定为 `v`、`primaryDeptId`（如有）、`depts`、`rules`、`fp`；规则内部固定为 `all` 或 `set`；
5. 不对部门集合做跨资源合并之外的任何优化：相同的部门集合在不同资源中共享同一组下标，即 `depts` 里每个 ID 只出现一次。

### 4.4 指纹 `fp`

`fp` 是**去掉 `fp` 字段后**按 §4.3 规范化的 `dataScope` 的 UTF-8 字节的 SHA-256 十六进制前 16 位。
Starter 的 `DataScopes.current().fingerprint()` 直接返回它，用于缓存键。`fp` 随范围内容变化，不随时间变化。

**共用测试向量**：§4.1 示例去掉 `fp` 后的规范化字节为

```text
{"v":1,"primaryDeptId":"101","depts":["101","102","105"],"rules":{"crm:contract":{"all":true},"crm:customer":{"set":[0,1,2]},"crm:followup":{"set":[]}}}
```

其指纹为 `d361b479f54b4be2`。System（生成）与 Starter（读取）的测试都应断言这一组值。

### 4.5 体积上限

- 计算口径：规范化紧凑 JSON（**含 `fp`**）的 UTF-8 字节数，编码为 JWT 声明之前。
- 上限：**6144 字节**。对外宣称「单用户可见部门不超过 **128** 个」。依据：部门 ID 由
  `currentTimeMillis × 10⁶` 生成，实际是 19 位，每个部门在字典里占约 22 字节、每次被资源引用再占约 4 字节；
  256 个部门在 1 个资源上约 6.7 KB，已超限，128 个部门被 3 个资源完全重叠引用约 4.5 KB。
  D2 用 `origin/dev` 中权限码最多的项目实测完整 Context 余量后确认，可调低不可调高。
- 完整 Context 仍受 16 KiB 上限约束（ADR 0003 §1），由 Gateway 最终校验。

### 4.6 超限错误 `DATA_SCOPE_TOO_LARGE`

超过 6144 字节时，System **不返回 `dataScope`，也不截断**，而是复用「无权访问」的协议结果，使 Gateway 沿用既有的拒绝缓存逻辑：

```json
{
  "code": 403,
  "message": "数据范围过大，请联系管理员调整",
  "messageKey": "api.project.dataScopeTooLarge",
  "messageArgs": { "reason": "DATA_SCOPE_TOO_LARGE", "limitBytes": 6144 },
  "data": null
}
```

- HTTP 状态 403，`code` 与之相同（`Result` 约定：code 与 HTTP 状态一致）。
- `messageKey` 是 i18n 资源，按「`sql/increment` + helm 副本 + `sql/schema.sql`」三处同步。
- Gateway 按 403 处理：拒绝。普通「不是成员」的拒绝沿用既有缓存时间（30 秒）；`messageArgs.reason=DATA_SCOPE_TOO_LARGE` 的拒绝是配置问题，缓存 5 秒（`kaiwu.gateway.project-access.data-scope-deny-cache-ttl-seconds`），管理员调整后很快恢复。该原因只用于写一条**不含部门 ID** 的安全日志。Gateway 自己收到超过 6144 字节的 `dataScope` 时同样按拒绝处理。
- 管理端在保存角色范围时做同样的估算并提示「改用 ALL 或缩小 CUSTOM_DEPT」，保存本身不因估算失败而拒绝，以运行时结果为准。

### 4.7 与 `authzVersion` 的关系

当前实现中 `authzVersion` 是**会话级平台权限**的摘要（`RedisSessionSnapshotAdapter`），项目快照响应里没有这个字段，
本契约**不改变 `authzVersion` 的含义与计算方式**。数据范围变化的收敛靠两点：

- Gateway 对 `userId + audience + projectCode` 的 30 秒本地缓存（允许与普通拒绝均 30 秒，数据范围过大的拒绝 5 秒）；
- Context 本身 60 秒有效。

因此范围变更最长约 30 秒（缓存）后对新签发的 Context 生效，与菜单权限一致，不新增版本表或失效通知。

## 5. Context 声明 `ds`

Gateway 把 `dataScope` 对象**原样**写入内部 Context 的声明 `ds`（结构、规范化、`fp` 与 §4 完全相同）。

- 只写入 `typ=kaiwu-context+jwt` 的 PROJECT Context，包括 Agent 读写委托签发的单次 Context；
  PLATFORM 身份 Context 不带 `ds`。
- 快照没有 `dataScope` 时，Context **不写** `ds` 键，Context 与改动前字节一致。
- Gateway 不解释、不修改、不校验语义；只校验 JSON 合法与 §4.5 的体积。
- 不使用任何普通 Header 传递范围（ADR 0003 §5）。

Starter 侧 `KaiwuContext` 增加可空的 `dataScope`：

- `ds` 缺失 → `null`，所有受控资源按 `SELF`；
- `ds` 存在但不满足 §4.2 的 schema 或附加约束 → Context 验证失败，按「声明不完整」失败关闭（ADR 0003 §5 第 6 点）。

## 6. 归属列写入约定

| 列 | 类型 | 约束 |
|---|---|---|
| `owner_user_id`（可改名） | BIGINT | NOT NULL，无默认值，单列索引 |
| `owner_dept_id`（可改名） | BIGINT | NOT NULL，无默认值，单列索引 |

- 普通请求路径插入：`owner_user_id` = 当前用户 ID；`owner_dept_id` = `ds.primaryDeptId`，缺省时 `0`。
- 主部门由 System 确定：取 `sys_user_department` 中标记为主部门的记录，数值最小者；没有任何记录被标为主部门时，取全部所属部门中数值最小者；
  没有所属部门则缺省。
- `0` 是「无部门」的保留值，不对应任何真实部门；谓词中的 `IN (D)` 不会包含 `0`，因此 `owner_dept_id = 0` 的行只对归属人和 `ALL` 可见。
- 部门 ID 来自 `sys_department.id`。重建平台库或体验版迁开发版时**必须保留**部门 ID，否则业务库里的归属全部失效。

## 7. `roles.yml` 扩展（ADR 0042 配置移交）

沿用现有角色行的字段（`roleCode`、`name`、`description`、`permissions`、`routes`、`directories`），新增可选 `dataScopes`：

```yaml
- roleCode: sales-manager
  name: 销售经理
  permissions: [crm:customer:list]
  dataScopes:
    - { resource: crm:customer, scope: DEPT_AND_CHILD }
    - { resource: crm:contract, scope: CUSTOM_DEPT, depts: [sales-east, sales-north], includeChild: true }
```

| 字段 | 类型 | 必填 | 约束 |
|---|---|---|---|
| `resource` | string | 是 | 资源码；同一角色内唯一 |
| `scope` | string | 是 | 五种范围类型之一，且须在该资源的 `allowedScopes` 内 |
| `depts` | string[] | `CUSTOM_DEPT` 必填，其它类型不得出现 | 部门**编码**（`sys_department.dept_code`，格式 `[a-z][a-z0-9-]{1,63}`，即小写字母、数字、连字符），不是 ID；去重；最多 128 项 |
| `includeChild` | boolean | 否，仅 `CUSTOM_DEPT` | 默认 `false` |

- `project-admin` 不出现在 `roles.yml`（`ProjectManifestParser` 已拒绝），其 `ALL` 由平台保证，不导出也不导入。
- `scope: SELF` 允许出现并表示显式配置；省略某资源与配置 `SELF` 效果相同，导出时**省略**未配置的资源，不输出 `SELF`。
- 导入走授权组（计划里 `resource=ROLE_DATA_SCOPE`、`category=ACCESS`）：不勾选导入授权就不执行；执行方式是**覆盖**清单里出现的资源，
  角色在其它资源上的配置原样保留；要求调用者具备项目内 `ROLE_SAVE` 与 `ROLE_GRANT`（与角色授权同一道门禁）。
- 目标环境多出的配置（清单没提到的资源）只作 `DRIFT` 展示，不撤销。
- 缺失处理：目标环境没有该资源码（含已下线）、`scope` 不在目标资源 `allowedScopes` 内、`depts` 中任一部门编码在目标环境不存在时，
  **整份计划以 400 拒绝并一次列出全部问题**，不做部分导入也不静默跳过——与引用不存在的菜单同一处理。
  资源可以来自同一个包的 `data-scopes.yml`：同一次执行会先登记资源，再导入角色。
- 部门编码到 ID 的对齐在目标环境按 `dept_code` 完成，导出包不含任何部门 ID。

## 8. 管理接口与审计（供 Web 使用）

两个入口共用同一个服务，请求与响应结构相同：

| 入口 | 路径 | 权限 |
|---|---|---|
| 平台管理员 | `GET` / `PUT /api/projects/{projectId}/roles/{roleId}/data-scopes` | `system:project:role` |
| 业务项目管理员 | `GET` / `PUT /api/current/projects/{projectId}/access-admin/roles/{roleId}/data-scopes` | `GET` 需 `ROLE_LIST`，`PUT` 需 `ROLE_GRANT` |

不新增权限码与菜单种子：数据范围是「这个角色能做什么」的授权，与角色菜单授权同一道门禁，避免出现半截授权。

`GET` 响应 `Result<ProjectRoleDataScopeView>`：

```json
{
  "roleId": "9001", "roleCode": "sales-manager", "readOnly": false,
  "items": [
    { "resourceCode": "crm:contract", "resourceName": "合同", "allowedScopes": ["CUSTOM_DEPT", "SELF"],
      "scope": "CUSTOM_DEPT", "configured": true, "includeChild": true, "deptIds": ["7001", "7002"] },
    { "resourceCode": "crm:customer", "resourceName": "客户", "allowedScopes": ["ALL", "DEPT_AND_CHILD", "SELF"],
      "scope": "SELF", "configured": false, "includeChild": false, "deptIds": [] }
  ]
}
```

- `items` 覆盖项目内全部 `ENABLED` 资源，按资源码排序；未配置的资源 `scope=SELF`、`configured=false`，前端显示「仅本人（默认）」。
- 配置的范围已不在资源 `allowedScopes` 内时，视图按未配置显示（运行时也按仅本人生效），下一次保存会清掉它。
- 内置 `project-admin`：`readOnly=true`，所有资源 `scope=ALL`、`configured=false`。

`PUT` 请求 `{"items":[{"resourceCode","scope","includeChild","deptIds"}]}`，**覆盖语义**：未出现的资源回到仅本人。校验失败一律
400，`messageKey=api.project.dataScopeInvalid`：

- 资源不存在或未启用；同一资源出现两次；
- `scope` 不是五种之一，或不在该资源 `allowedScopes` 内；
- 非 `CUSTOM_DEPT` 却带了 `deptIds` 或 `includeChild=true`；
- `CUSTOM_DEPT` 没有部门、部门 ID 格式非法或重复、超过 **128** 个、任一部门不存在。

其它规则：

- `scope=SELF` 等价于未配置，**不落库**；
- 内置角色保存一律 400（`api.common.badRequest`）；
- 保存前锁定角色行；与现有配置完全一致时不写审计、不改数据；
- 有变化时写 `SAVE_PROJECT_ROLE_DATA_SCOPE` 审计，记录逐资源的前后值（如 `DEPT_AND_CHILD`、`CUSTOM_DEPT+CHILD[7001, 7002]`）；
- 保存成功不主动失效 Gateway 缓存，最长 30 秒后生效；
- 删除角色、部门、项目时，对应配置由外键级联删除，只会让可见范围变窄。

## 9. 兼容性

| 场景 | 要求 |
|---|---|
| 项目没有受控资源 | `project-access` 响应、Context 与改动前字节一致 |
| 业务服务未引入 `kaiwu-data-scope` | 行为不变；`ds` 被 Starter 解析但不执行 |
| 业务服务引入模块但 Gateway 未升级 | Context 无 `ds`，所有受控资源按 `SELF`，并打 WARN，宁可看少不可看多 |
| 旧版 Starter 收到带 `ds` 的 Context | 无影响：`GatewayContextVerifier` 按名称读取声明，未知声明被忽略（D0 已对照 `origin/dev` 核实）；D3 须保持这一点 |
| `dataScope.v` 大于 1 | 视为非法，失败关闭；升级协议须新增 ADR |
