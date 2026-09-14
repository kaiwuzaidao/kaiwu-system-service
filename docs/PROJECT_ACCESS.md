# 让生成项目对外可访问

生成项目跑起来之后，还要两件事它才能被外部访问：

1. **登记服务地址** —— Gateway 往哪转发；
2. **登记显式路由** —— 这个前缀允许从外部进来。

第二件事不能省。服务注册到注册中心、或者在 K8s 里有了 Service，都只说明"它在那儿"，
不说明"它该对外开放"。Kaiwu 里**授予入口是平台侧的动作**（`ARCHITECTURE.md` §7）。

三层责任分开看：

| 谁 | 回答什么问题 |
|---|---|
| 部署环境（DNS / 注册中心） | 服务在哪台机器上 |
| 平台登记的 route | 这个前缀允不允许从外部进来 |
| Gateway 入口授权 | 这个用户是不是这个项目的成员 |

---

## 一、先配一次：入口授权凭据

Gateway 要向 System 查"某人是不是某项目的 ACTIVE 成员"，这条内部调用需要共享凭据。

**本地开发不用管**：`./scripts/kaiwu.sh up` 会自动生成 `KAIWU_GATEWAY_INTERNAL_TOKEN`
并注入两个容器。

**部署环境必须显式配置**，两端同值：

| 组件 | 配置项 |
|---|---|
| System | `kaiwu.gateway-access.internal-token` |
| Gateway | `kaiwu.gateway.project-access.internal-token` 和 `system-base-url` |

没配的话，PROJECT 请求一律返回 **503 `gateway.projectAuthUnavailable`**。
这是有意的失败关闭——「没配好」必须表现为拒绝服务，而不是表现为不鉴权。
看到这个错误码，先查这两项配置，不要去查成员关系。

---

## 二、按部署形态填服务地址

在 Kaiwu「项目管理 → 编辑项目 → 服务地址」填写。这个字段和「业务后台入口」不是一回事：
后者是浏览器跳转的链接，前者是 Gateway 的转发目标。

| 部署形态 | 服务地址填什么 | 业务项目要做什么 |
|---|---|---|
| **Kubernetes** | `http://kaiwu-{code}-service:8080`（Service DNS） | 什么都不用做 |
| **Docker Compose** | `http://{code}-service:8080`（容器名） | 什么都不用做 |
| **单实例固定地址** | `http://192.0.2.10:8080` | 什么都不用做 |
| **VM 多实例 / 无编排器** | `lb://kaiwu-{code}-service` | 自行接入 Nacos 注册，见生成仓库 README |
| **本地开发** | 不用填，见下方第四节 | 什么都不用做 |

只接受 `http` / `https` / `lb` 三种 scheme，其它写法会被表单和后端一起拒绝——
这个值是 Gateway 的转发目标，放开 scheme 等于允许把网关指向任意协议的内网端点。

### 为什么前三种不需要注册中心

K8s 的 Service 已经提供了稳定域名、实例列表（按 readiness 探针维护）和请求级负载均衡；
Compose 的容器名由 Docker 网络解析。这些正是注册中心提供的能力。
在 K8s 上再叠一层注册中心，会出现两份"谁还活着"的事实，典型症状是请求打到已被摘除的
实例上超时——比直接报错更难排查。

只有在**没有编排器又需要动态实例列表**时才需要注册中心。因此生成项目默认不带这个依赖：
它会进 jar、进供应链扫描面，还会让业务团队的 Spring Boot 升级节奏受制于第三方 BOM 的发版节奏。

---

## 三、登记路由

填好服务地址后，取平台生成的片段：

```bash
curl -H "Authorization: Bearer <你的 access token>" \
  http://<平台地址>/api/projects/<项目ID>/gateway-route
```

得到的内容形如：

```yaml
- id: order-center-project
  uri: http://kaiwu-order-center-service:8080
  predicates:
    - Path=/order-center-api/**
  filters:
    - RewritePath=/order-center-api/(?<segment>.*), /${segment}
  metadata:
    accessMode: PROJECT
    audience: kaiwu-order-center-service
    projectCode: order-center
```

按环境放进受管 Gateway 配置：

- 本地 Compose / 单机服务器：保存为 `kaiwu-system-service/routes.managed.d/{code}.yml`，
  执行 `./scripts/kaiwu.sh reload-routes`；
- Kubernetes GitOps：由 `kaiwu-deploy/gateway-routes/<env>` 保存逐项目 Route，平台 Helm 通过
  `gateway.managedRoutesExistingConfigMap` 挂载；不使用 GitOps 时才把列表项追加到
  `gateway.managedRoutes`；
- 自管 Nacos：经部署评审合并到 `kaiwu-gateway-service-{env}.yml` 的显式 routes。

**不要手写这段。** `metadata` 三项是权限事实：漏掉 `accessMode` 会让路由被拒
（`gateway.routePolicyMissing`），漏掉 `projectCode` 会让 PROJECT 路由失去项目绑定
（`gateway.routeProjectMissing`）。生成的片段这三项都齐。

平台只生成或交付 route，不自动写入部署环境。自动读改写 Nacos Data ID 或 GitOps values 会
引入并发覆盖与越权部署；当前由部署仓评审、应用和回滚（ADR 0022、0025）。

---

## 四、本地开发

本地不走上面第二、三节，也**不需要 Nacos**：

```bash
# 1. 启动业务后端（端口由项目编码派生，同机多项目不撞车）
cd kaiwu-{code}-service && bash scripts/dev.sh

# 2. 把生成仓库自带的路由文件放进 Gateway 的本地路由目录
cp docs/gateway-route-local.yml <kaiwu-gateway-service路径>/routes.local.d/{code}.yml

# 3. Gateway 已在运行时，重启本机 Gateway 进程使其加载
```

`routes.local.d/` 只在 Gateway 的 `local` profile 加载，且不进版本库。
文件里的 `uri` 指向 `127.0.0.1:<派生端口>`，其余字段与部署环境完全一致——
**本地和线上只差 `uri` 一个字段**，因此本地验证到的鉴权行为和线上是同一套。

若平台使用 Docker Compose、业务项目也使用生成的 `deploy/server/compose.yml`，则直接复制
`deploy/server/gateway-route.yml` 到平台 `routes.managed.d/`，无需使用本地 `127.0.0.1` route。

业务前端还需要同源静态入口：本机 `kaiwu.sh dev` 可通过
`KAIWU_LOCAL_PROJECT_WEB_PROXY='{code}=http://127.0.0.1:<前端端口>'` 显式代理一个当前项目；
单机和 K8s 分别使用生成前端仓的 Nginx location 与 Ingress。

---

## 五、排错

| 现象 | 含义 | 先查什么 |
|---|---|---|
| 503 `gateway.projectAuthUnavailable` | 入口授权未配置，或 System 不可达 | 第一节的两项配置；System 是否健康 |
| 503 `gateway.routeProjectMissing` | 路由是 PROJECT 但没绑 `projectCode` | 用生成的片段替换手写的 |
| 503 `gateway.routePolicyMissing` | 路由缺 `accessMode` 或 `audience` | 同上 |
| 403 `gateway.projectAccessDenied` | 不是该项目的 ACTIVE 成员 | 项目成员列表；成员状态是否 ACTIVE |
| 403 `gateway.projectMismatch` | 请求里的 `X-Project-Id` 与权威 ID 不一致 | 前端是否手工拼了这个头，去掉即可 |
| 404 | 没有匹配的 route | 路由是否已登记、前缀是否写对 |

**成员变更最长 30 秒生效**：Gateway 对入口授权结论有 30 秒本地缓存。
需要立即失效的场景（例如停用用户）由 System 撤销会话兜底，那条路径不经过这个缓存。

---

## 相关文档

- `docs/adr/0022-project-entry-authorization-and-addressing.md` —— 为什么这样设计
- `docs/adr/0003-gateway-centric-authentication.md` —— 认证与分层授权
- 生成仓库的 `README.md` —— 本地启动、环境变量清单、接入注册中心
