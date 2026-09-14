# ADR 0003：Gateway 统一认证与分层授权

- 状态：Accepted
- 日期：2026-07-23
- 决策人：Kaiwu 项目维护者
- 取代：`docs/ARCHITECTURE.md` 0.1 中“Starter 校验外部 JWT 并同步回调 System”的过渡方案

## 背景

Kaiwu 从第一天采用 Gateway 和独立微服务。认证与授权边界必须同时满足：

1. 外部请求只能从 Gateway 进入，登录态、会话撤销和项目入口策略有统一执行点。
2. `system-service` 仍是用户、平台角色、项目成员、项目角色、菜单和权限的唯一事实源。
3. 业务服务不能信任浏览器提交的 `X-Project-Id`、用户 ID、角色或权限头。
4. 业务服务被内网直连、Gateway 路由误配或权限缓存短暂陈旧时，仍有本地安全边界。
5. 正常业务请求不能由 Starter 同步回调 System，否则 System 故障会放大为所有业务请求故障。
6. 第一阶段方案必须能由一个全栈工程师理解和维护，不引入通用 IAM、策略引擎、事件总线或独立 Integration 服务。

传统实现通常由业务 Starter 校验共享 HMAC JWT，再携带用户 Token 同步调用
System 的 current-access 接口。这是可工作的迁移态，但会共享高价值签名 Secret，并把
System 变成业务请求链路上的同步依赖。Kaiwu 不继承该过渡结构。

## 决策

采用“System 身份事实源 + Gateway 统一认证和入口授权 + Starter 本地最终授权”的两级模型。

### 1. 两类令牌严格分离

#### 外部访问令牌

- 用户名和密码只由 `kaiwu-system-service` 校验。
- System 签发 RS256 用户访问 JWT，`iss=kaiwu-system-service`，
  `aud=kaiwu-gateway-service`。
- 外部 JWT 只包含稳定身份与会话声明：`sub`、`sid`、`jti`、`iat`、`exp`；
  不放平台权限、项目权限或数据范围。
- Gateway 只持有 System 公钥，不能伪造用户登录令牌。
- 业务服务不接受外部访问令牌。

#### 内部访问上下文

- Gateway 完成外部令牌和入口策略校验后，签发 RS256 短期内部 JWT。
- 内部 JWT 使用 `typ=kaiwu-context+jwt`、`iss=kaiwu-gateway-service`，
  并以目标服务码作为唯一 `aud`。
- 最小声明为：

```text
sub                用户 ID，字符串
sid                登录会话 ID
projectId          项目请求必填；平台无项目请求可缺省
projectCode        项目请求必填，由路由绑定产生
permissions        PROJECT 请求的项目权限码集合；PLATFORM 请求不携带
projectRoleCodes   PROJECT 请求的当前项目角色码集合；PLATFORM 请求不携带
authzVersion       PROJECT 权限快照的确定性摘要；PLATFORM 请求不携带
iat / exp / jti    签发、过期和唯一标识
```

- 内部 JWT 有效期固定为 60 秒，不包含姓名、手机号等无关个人信息。
- System 和业务服务只持有 Gateway 公钥，不能签发内部 Context。
- Gateway 必须删除客户端提交的 `X-Kaiwu-Context`、用户、角色和权限头，再注入自己签发的
  `X-Kaiwu-Context`。
- Gateway 在转发受保护请求前还必须删除外部 `Authorization`，目标服务不能同时看到外部 Token。
- Token 和 Context Header 必须加入 Gateway、目标服务与代理的日志脱敏名单。
- 内部 Context 序列化后不得超过 16 KiB；超限必须失败并记录不含权限明文的安全告警，
  禁止静默截断权限。Gateway、代理和目标服务的内部 Header 上限必须一致且高于该值。

两个签发私钥都只通过部署 Secret 注入。代码、配置样例、数据库、Nacos、日志和 Git 中均不得出现私钥。

### 2. 路由分级

Gateway 的每条外部 Route 必须显式声明 `accessMode`、`audience` 和可选的
`projectCode`，禁止通过 Nacos discovery locator 自动生成 Route。

| Route 类型 | 示例 | Gateway 行为 | 目标服务行为 |
|---|---|---|---|
| `PUBLIC` | 登录、刷新、健康检查 | 精确 method/path 白名单，不要求 JWT | 只处理白名单业务 |
| `PLATFORM` | `/api/**` | 校验外部 JWT、在线会话，签发绑定 System 的身份 Context | 校验 Context，从本地事实源执行平台权限和资源授权 |
| `PROJECT` | `/{code}-api/**` | 校验 JWT、会话、Route 项目绑定、有效成员，加载项目权限快照 | 校验 Context、项目和 audience，执行 `@RequirePermission` 与数据授权 |

Route 只绑定创建后不可修改、跨环境稳定的 `projectCode`，不绑定各环境可能不同的数据库
`projectId`。System 根据 `projectCode` 解析权威 `projectId` 并返回项目权限快照。客户端必须携带
`X-Project-Id` 作为前端上下文，但 Gateway 只能将它与 System 返回的权威 ID 比较；缺失、格式错误
或不一致均返回 403，不能用它决定目标项目。

### 3. 权限事实源与缓存

- System 是用户状态、平台角色、项目成员、项目角色、菜单、Permission 和组织范围的唯一事实源。
- Gateway 不建角色或权限表，不读平台数据库或业务数据库。
- PLATFORM 请求不经过权限快照接口；System 收到身份 Context 后，直接从本地事实源执行平台权限和资源授权。
- PROJECT 请求由 Gateway 通过不对外路由的 System 内部接口读取项目权限快照。
- 内部接口只接受 Gateway 签发、`typ=kaiwu-gateway-assertion+jwt`、
  `aud=kaiwu-system-internal`、最长 30 秒的服务断言。
- Gateway 使用本地有界缓存，按 `userId + audience + projectCode` 缓存快照；允许结果 TTL
  固定 30 秒，拒绝结果 TTL 固定 5 秒，不把权限快照再复制到 Redis。
- System 对排序后的成员状态、角色码和权限码计算确定性摘要作为 `authzVersion`，
  不为此新增第二套权限版本表。
- 缓存未命中时 System 不可用、超时或返回异常，Gateway 必须失败关闭，不得使用过期快照放行。
- 权限变更最多存在 30 秒收敛窗口；禁用用户、注销和强制下线不走权限缓存，必须通过在线会话立即拒绝。

### 4. 会话

- System 登录成功后在 Redis 创建在线会话，至少记录 `sid`、`userId`、状态和过期时间。
- Gateway 每次认证检查对应会话仍有效；Redis 或会话状态不可判定时失败关闭。
- 注销、禁用用户、重置密码和管理员强制下线必须撤销相关会话。
- 用户访问 JWT 第一阶段有效期 15 分钟。
- 刷新令牌使用不可预测随机值，服务端只保存摘要，刷新接口轮换旧令牌。
- Access Token 与 Refresh Token 均不写入 Cookie 或 Web Storage，只保存在前端内存；
  页面刷新后重新登录。
- Refresh Token 与在线会话第一阶段绝对有效期固定为 7 天，每次成功刷新都轮换 Token，
  但不延长这次会话的绝对到期时间。

### 5. 目标服务最终授权

`kaiwu-system-starter` 必须：

1. 只读取 Gateway 注入的 `X-Kaiwu-Context`。
2. 本地校验签名、`typ`、issuer、唯一 audience、`iat/exp`。
3. 项目 Route 同时校验 Context 中的 `projectId/projectCode` 与当前服务配置。
4. 建立请求级 `StarterContext`，请求结束后无条件清理。
5. 执行 `@RequirePermission("mod:res:act")`。
6. 缺少 Context、声明不完整、签名错误、过期、audience 错误或项目错误时失败关闭。

Starter 自包含 Context 类型与验证逻辑，不依赖 `kaiwu-system-api`，避免 System 使用 Starter 时形成
跨仓发布循环。`@RequirePermission` 通过 `PermissionResolver` 读取权限：业务服务使用默认的
Context 实现，System 注册读取本地平台权限事实的实现。

Gateway 的项目成员校验只决定“能否进入项目服务”。以下最终授权仍由目标服务负责：

- Controller 的 Permission。
- 数据归属，例如“只能修改本人创建的记录”。
- 资源当前状态，例如“已结算记录不可删除”。

System 内部的组织范围由 System 从本地事实源处理。第一阶段 PROJECT Context 不携带通用 DataScope；
出现真实的跨项目数据范围需求时再单独提交 ADR，不能用普通 Header 临时扩展。

前端 `<PermissionButton permission>` 只用于交互可见性，不能作为安全证据。

### 6. 网络边界

- Compose 只向宿主机暴露 Web 和 Gateway；System 与业务服务端口只在内部网络可见。
- 部署环境使用 NetworkPolicy/Security Group，只允许 Gateway 调用用户入口 API。
- System 的内部权限快照接口不配置外部 Route。
- 即使网络策略误配，目标服务也会因缺少有效、audience-bound Context 拒绝外部访问令牌。
- 内部批处理或服务间调用不伪装用户 Context；第一阶段若无真实需求，不提供通用 S2S 认证框架。

### 7. PROJECT 权限快照接口

System 只提供一个面向 Gateway 的内部契约：

```http
POST /internal/authz/project-access
Authorization: Bearer <gateway-assertion>
Content-Type: application/json

{
  "userId": "字符串用户ID",
  "projectCode": "route绑定的项目码"
}
```

响应：

```json
{
  "member": true,
  "projectId": "字符串项目ID",
  "projectCode": "demo",
  "projectRoleCodes": ["project_admin"],
  "permissions": ["order:record:list", "order:record:create"],
  "authzVersion": "确定性摘要"
}
```

约束：

- Gateway Assertion 的 `sub` 固定为 `kaiwu-gateway-service`，`aud` 固定为
  `kaiwu-system-internal`，System 同时校验 `typ` 和 30 秒有效期。
- `projectCode` 必须来自匹配后的 Route metadata，不能来自 query/body/Header。
- `userId` 必须来自已验证的外部 JWT `sub`。
- 非成员、成员停用、项目停用统一返回 `member=false`，不返回角色或权限。
- 所有 ID 使用字符串。
- 该路径不进入 Gateway Route、OpenAPI 或前端 SDK。

## 请求流程

### 登录

```text
Browser -> Gateway PUBLIC /api/auth/login
Gateway -> System 校验用户名/密码
System -> Redis 创建 session
System -> Browser 返回外部 Access JWT 和轮换 Refresh Token；前端仅保存在内存
```

### 平台请求

```text
Browser -> Gateway PLATFORM + external JWT
Gateway -> 校验签名、audience、expiry、session
Gateway -> 签发 aud=kaiwu-system-service 的 60 秒身份 Context
Gateway -> System
System Starter -> 本地验签
System -> 从本地事实源执行 @RequirePermission + 资源授权
```

### 业务项目请求

```text
Browser -> Gateway PROJECT route + external JWT + X-Project-Id
Gateway -> 校验 JWT/session
Gateway -> 读取 Route Binding 的 projectCode
Gateway -> System internal 获取/缓存成员与项目权限快照及权威 projectId
Gateway -> 比对权威 projectId 与 X-Project-Id
Gateway -> 非成员直接 403
Gateway -> 签发 aud=kaiwu-{code}-service 的 60 秒 Context
Gateway -> 业务 Service
Business Starter -> 本地验签、项目绑定、@RequirePermission
Business Service -> 数据归属/状态授权
```

## 错误语义

| 场景 | HTTP |
|---|---:|
| 缺少、过期、签名错误的外部 Access Token | 401 |
| 登录会话不存在或已撤销 | 401 |
| Redis/会话依赖不可用，无法判定登录态 | 503 |
| `X-Project-Id` 缺失、错误或与 Route 不一致 | 403 |
| 不是有效项目成员 | 403 |
| 缺少接口权限 | 403 |
| 资源归属或状态不允许 | 403 |
| Gateway 无法读取有效权限快照 | 503 |
| 目标服务收到无效内部 Context | 401 |

错误响应不得泄露用户是否存在、权限全集、Token 内容或内部服务地址。

## 第一阶段验收

自动化测试至少覆盖：

1. PUBLIC 白名单精确到 method/path，未登记路径不能绕过认证。
2. 外部 Token 的 issuer、audience、签名、过期和会话撤销。
3. 客户端伪造 Context/用户/权限头被 Gateway 清除。
4. PLATFORM 与 PROJECT Route 的 audience 不能互用。
5. 项目 ID 缺失、伪造、Route 不一致、非成员、无权限和有权限。
6. 业务服务直连时，外部 Token 不能当内部 Context 使用。
7. Gateway 权限快照超时、System/Redis 不可用时失败关闭并使用 503。
8. 权限三端同码。
9. Context 过期和请求结束后 `StarterContext` 清理。
10. 注销、禁用、重置密码和强制下线后旧会话立即失效。
11. Context Header 超限时失败关闭，权限不得被截断后放行。

## 明确不做

- Gateway 维护第二套用户、角色、菜单或权限数据库。
- Gateway 查询业务库或执行资源状态、数据归属等领域规则。
- 业务服务共享 System 的 JWT 私钥或 Gateway Context 私钥。
- Starter 在正常业务请求中同步回调 System。
- 仅凭内网、Nacos 注册或任意透传 Header 建立信任。
- 第一阶段引入 OIDC、通用 IAM、ABAC/OPA 策略引擎、通用 S2S 身份平台、事件总线或自动密钥轮换平台。

## 结果

正向结果：

- 外部认证、会话撤销和项目入口策略集中在 Gateway。
- 权限事实仍只有 System 一份。
- 目标服务通过本地验签和注解保留最终安全边界。
- 外部 Token 与内部 Context 分离，单个业务服务不持有可签发用户 Token 的共享 Secret。
- System 不再是每个业务请求的同步鉴权依赖；只有 PROJECT 权限缓存未命中时，Gateway 读取快照。

需要承担的成本：

- 需要维护 System 和 Gateway 两个签名密钥对。
- Gateway 需要 Redis 会话检查和本地有界权限快照缓存。
- 路由配置必须登记 audience 与项目绑定。
- 权限变更存在最长 30 秒的入口缓存收敛窗口。
- 已签发的内部 Context 在网络边界被突破时仍可能在剩余有效期内重放，因此有效期固定为 60 秒，
  并同时依赖目标 audience 和服务网络隔离。

## 被否决方案

- **只在 Gateway 做全部授权**：无法可靠处理资源归属和业务状态，且内部直连或路由误配会绕过安全边界。
- **只在业务 Starter 做认证授权**：入口不统一，共享用户签名 Secret，并产生每请求回调 System 的可用性耦合。
- **Gateway 注入普通用户/权限 Header**：内部直连和伪造风险高，无法校验 issuer、audience 与过期时间。
- **所有服务共同验证并签发同一个 HMAC JWT**：任一业务服务泄漏 Secret 后可伪造任意用户。
- **把完整权限写入长效外部 JWT**：权限变更无法及时生效，Token 体积会随项目增长。
