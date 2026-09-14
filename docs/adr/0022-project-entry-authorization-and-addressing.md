# ADR 0022：业务项目入口授权与寻址方式

- 状态：Accepted
- 日期：2026-08-13
- 决策范围：Gateway、System、项目工厂模板与生成业务项目
- 实现：ADR 0003 的 PROJECT 分支；修订 `docs/NACOS.md` 对 `lb://` 的表述
- 补充：ADR 0001、ADR 0003、ADR 0006

## 背景

ADR 0003 规定 Gateway 负责「项目入口授权」，但 PROJECT 分支一直是个桩：
`GatewayAuthenticationFilter` 对所有 `accessMode: PROJECT` 的请求直接返回 503
「项目鉴权尚未启用」。这意味着**生成项目的整条外部访问链路从未通过**——
路由配得再对，请求走到 Gateway 也是 503，而 Starter 侧早已在校验 `projectId` /
`projectCode` claim，只是从来没收到过。

同时暴露出两个未定问题：

1. **业务服务的地址从哪来。** 路由的 `uri` 此前只有平台自身的
   `${KAIWU_SYSTEM_SERVICE_URI}`，业务项目没有对应字段。误用 `sys_project.backend_url`
   是不对的：那一列是**浏览器打开的后台入口链接**（前端 `window.location.assign` 直接用它跳转），
   与服务端到服务端的上游地址是两回事。
2. **要不要要求业务项目接入注册中心。** Kaiwu 生成的项目由别的团队部署，
   部署形态不由平台决定；假设所有人都有 K8s，或要求所有人都上 Nacos，都会挡住一部分用户。

## 决策

### 1. PROJECT 入口授权由 Gateway 执行，事实来自 System

- System 新增只读内部端点 `/api/internal/gateway/project-access`，按
  `(projectCode, userId)` 返回项目权威 ID、项目内权限码与角色码。三跳缺一不可：
  项目 ACTIVE、成员 ACTIVE、权限来自项目内启用的角色与菜单。
- 任一跳不满足返回 403，而不是「空权限的快照」。空权限通行证会让越权表现成
  「进得去但什么都点不了」，把成员关系问题伪装成权限配置问题。
- Gateway 侧带**有界本地缓存**（默认上限 1 万条、TTL 30 秒），并区分三种结果：
  有授权则签发绑定该项目的 Context；**明确无权也缓存**，否则不断重试的越权调用方
  等于拿鉴权失败做 DDoS；**拿不到结论则失败关闭返回 503**，不沿用过期快照、更不放行。
- 配置缺失时解析器不装配，PROJECT 请求一律 503。「没配好」必须表现为拒绝服务，
  而不是表现为不鉴权。
- Context 在 PROJECT 路由上携带 `projectId` / `projectCode`，且 `permissions`
  换成**项目内权限**而不是平台权限——否则平台管理员会在任意业务项目里获得越权能力。
- 客户端提交的 `X-Project-Id` 只与权威 ID 比对，不一致返回 403，且不透传给业务服务。

缓存 TTL 决定成员变更的最大生效延迟。需要立即生效的场景由 System 撤销会话兜底，
那条路径不经过本缓存。

### 2. 寻址方式由部署形态决定，平台不做假设

`sys_project` 新增 `service_url` 列，作为 Gateway PROJECT 路由的上游地址，
与 `backend_url`（浏览器后台入口）严格区分。取值形态：

| 部署形态 | `service_url` | 业务项目需要做什么 |
|---|---|---|
| K8s | `http://kaiwu-{code}-service:8080` | 无 |
| Docker Compose | `http://{code}-service:8080` | 无 |
| 单实例固定地址 | `http://192.0.2.10:8080` | 无 |
| VM 多实例 / 无编排器 | `lb://kaiwu-{code}-service` | 自行接入 Nacos 注册 |

只允许 `http` / `https` / `lb` 三种 scheme，由 Bean Validation 拒绝其它写法——
这个值会成为 Gateway 的转发目标，放开 scheme 等于允许把网关指向任意协议的内网端点。

**生成项目默认不带注册中心依赖**，只在 README 说明如何自行接入。理由是依赖会进 jar、
进供应链扫描面，并让业务团队的 Spring Boot 升级节奏受制于第三方 BOM 的发版节奏；
而真正需要它的团队加三行依赖并不难。前三种形态靠运行环境自带的 DNS 与负载均衡即可，
在 K8s 上再叠一层注册中心会产生两份「谁还活着」的事实，典型症状是请求打到已被摘除的实例上超时。

### 3. 注册不等于发布

无论地址来自 DNS 还是注册中心：

- discovery locator **始终关闭**。它会给每个注册服务自动建路由，等于把「对外发布」的权力
  交给「能往同一 namespace 注册的任何进程」，而注册是服务侧发起、平台从未批准的动作。
- `accessMode` / `audience` / `projectCode` 始终由平台生成，不从服务名或请求推导。
- `docs/NACOS.md` 原先把「禁 discovery locator」和「禁 `lb://`」写成了一件事，本 ADR 拆开：
  禁的是自动建路由，`lb://` 作为平台登记 route 的 `uri` 是允许的。

### 4. 路由片段由平台生成，写入配置仍是人工步骤

`GET /api/projects/{id}/gateway-route` 按 `projectCode` 与 `service_url` 渲染完整片段，
运维复制进受管 Gateway 配置。**暂不自动写入 Nacos Data ID**：那是对「控制全部路由的单份配置」
做读-改-写，并发写会互相覆盖，写坏一次就是整个网关不可用。要自动化必须先定并发控制与回滚策略，
届时另立 ADR。

本地开发不走这条路径：生成仓库自带的 `docs/gateway-route-local.yml` 放进 Gateway 的
`routes.local.d/` 即可，本地不引入注册中心。

## 后果

- 生成项目的外部访问链路第一次真正可用，而不是止步于 503。
- 业务团队可以在 K8s、Compose、VM 和单机之间自由选择，同一个构建产物到处运行，
  部署形态的差异全部收敛到 `service_url` 一个字段。
- Gateway 多了一条对 System 的请求路径依赖，由有界缓存和失败关闭约束；
  System 不可用时业务请求会 503 而不是被放行。
- 模板升级到 `kaiwu-project-v10`。既有 SUCCESS 项目不回写。

## 回滚

- Gateway 侧移除 `kaiwu.gateway.project-access` 配置即可回到 PROJECT 一律 503 的状态，
  不影响 PLATFORM 与 PUBLIC 路由。
- `service_url` 是新增可空列，回滚代码不需要回滚数据；按 ADR 0020 的两阶段约定，
  真要回收该列需另立停写版本。
