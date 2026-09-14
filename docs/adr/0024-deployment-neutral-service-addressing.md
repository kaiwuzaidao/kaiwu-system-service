# ADR 0024：部署形态中立的服务寻址

- 状态：Accepted
- 日期：2026-08-14
- 决策范围：Gateway 出站调用与路由、Starter 出站调用、Helm chart、生成项目模板
- 补充：ADR 0001 的显式路由、ADR 0003 的 Gateway 中心化认证、ADR 0022 的项目入口授权
- 依据：本文「验证证据」章节记录的两轮 spike

## 背景

Kaiwu 的 Kubernetes 交付路径（ADR 0023）默认所有服务寻址都通过 Kubernetes Service DNS
完成，`deploy/helm/kaiwu` 中 `SPRING_CLOUD_NACOS_DISCOVERY_ENABLED` 被硬编码为 `false`。
这对上了 `docs/KUBERNETES.md` 的边界，但也把平台钉死在一种部署形态上。

真实需求证据：并非所有采用方都运行 Kubernetes。规模较小的团队把服务部署到几台服务器、
用 Nacos 做注册发现，是完全合理且常见的形态。Kaiwu 既然要生成可交付给不同团队的业务项目，
就不应当要求对方先具备 Kubernetes。

直觉解法是加一个部署模式开关（`kaiwu.discovery.mode=nacos|k8s`），但那正是本工作区
明令禁止的双轨逻辑：两条路径都要测、都会漂移，且模式名会把实现细节固化进配置契约。

## 决策

**Kaiwu 不引入全局服务发现模式；服务寻址能力由 URI scheme 表达，具体发现机制由运行时依赖提供。**

### 1. 两种 scheme 的语义

| scheme | 语义 |
|---|---|
| `http(s)://` | 目标地址可由底层网络直接解析，平台不参与应用层服务发现 |
| `lb://` | 目标是逻辑服务名，由 Spring Cloud LoadBalancer 通过当前可用的服务发现实现解析 |

语义定义的是**解析责任归属**，不绑定具体基础设施。**不得**把 `http://` 记作
"Kubernetes 模式"、把 `lb://` 记作 "Nacos 模式"——`lb://` 背后可以是 Nacos、
Spring Cloud Kubernetes、Consul 或任何 `DiscoveryClient` 实现；`http://` 背后可以是
固定地址、内网 DNS，也可以是 Kubernetes Service DNS。

同一份配置因此可以覆盖三种形态，唯一变量是环境变量的取值：

```
本地开发    http://127.0.0.1:8080
Kubernetes  http://kaiwu-kaiwu-system:8080      经 CoreDNS 与 Service
服务器集群  lb://kaiwu-system-service           经 LoadBalancer 与 DiscoveryClient
```

### 2. Kubernetes 默认使用 `http://`

Kubernetes 的 Service 与 CoreDNS 本身就是服务发现与负载均衡。在其之上再叠
`lb://` → Spring Cloud LoadBalancer → DiscoveryClient → Spring Cloud Kubernetes →
Kubernetes API，是一条明显更重的路径，且引入了应用对集群 API 的依赖。

该路径在技术上成立，采用方有特殊理由（例如需要基于实例元数据做灰度）时可以选择，
但**不作为 Kaiwu 的默认值**。chart 默认继续保持不启用 Nacos discovery。

### 3. scheme 判断只允许存在一个地方

散落的 `if (uri.startsWith("lb://")) ... else ...` 与模式开关等价，同样是双轨。
每个出站客户端的**装配点**是唯一允许做 scheme 判断的位置：解析一次，装配对应的
连接方式，此后调用方只持有已经可用的客户端。

配置为 `lb://` 但 classpath 缺少 `spring-cloud-starter-loadbalancer` 或任何
`DiscoveryClient` 实现时，**必须启动即失败**，并在错误信息中直接给出需要添加的依赖。
不得留到运行时才表现为 5xx——这与 ADR 0020 登记的 secret fail-fast 是同一条原则。

### 4. 契约必须在所有出站调用点一致实现

Gateway 的路由 uri 与 `kaiwu.gateway.project-access.system-base-url` 读取同一个环境变量
`KAIWU_SYSTEM_SERVICE_URI`。spike 证实：只让路由支持 `lb://` 而出站 WebClient 不支持，
会产生**部分可用**——PUBLIC 与 PLATFORM 路由正常、PROJECT 路由全部 503。

部分可用比完全不可用更难排查，且该 503 与「`gateway-internal-token` 缺失」的症状完全
一致（见 `kaiwu-gateway-service/CLAUDE.md`），必然误导排查方向。

因此：**在所有出站调用点都实现之前，不得对外宣称支持 `lb://`。** 当前范围包括
Gateway 的 `ProjectAccessResolver`，以及 Starter 的通知、项目配置、调度控制面三个客户端。

### 5. `lb://` 仅限显式路由；locator 自动路由仍然禁止

`lb://` 与 DiscoveryClient locator 会产出同样形状的 URI，但安全含义相反：前者是
逐条显式声明的路由，后者把注册表中所有服务自动暴露成入口路由。

ADR 0001 与 ADR 0003 禁止的是后者，`kaiwu-gateway-service/.gitlab-ci.yml` 的
`verify:routing-guardrails` 亦针对后者。本 ADR **不放宽**该约束：即使采用 `lb://`，
`spring.cloud.gateway...discovery.locator.enabled` 必须保持 `false`。

### 6. 采用 `lb://` 时 Gateway 只发现、不注册

spike 中开启 discovery 后，Gateway 将自身注册进了 Nacos。Gateway 是外部入口，
不需要被其他服务发现，自注册只增加暴露面。启用 discovery 时必须同时设置
`spring.cloud.nacos.discovery.register-enabled=false`。

被调用方（System、生成的业务服务）相反，必须注册，否则 `lb://` 无实例可解析。

### 7. Starter 不决定注册中心

`kaiwu-system-starter` 提供出站调用能力与 scheme 解析契约，**不引入任何具体的
DiscoveryClient 实现**。采用方按自身基础设施自行添加：Nacos 用
`spring-cloud-starter-alibaba-nacos-discovery`，Kubernetes 用对应的 starter，
两者都不需要时保持 `http://` 即可，不引入额外依赖。

Maven `optional` 只解决"不向下传递"，不解决"选哪个实现"。真正的边界是：
**平台规定契约，不规定基础设施。**

### 8. chart 参数化

`SPRING_CLOUD_NACOS_DISCOVERY_ENABLED` 在 System 与 Gateway 两个 Deployment 中对称
硬编码为 `false`，需提到 values 层。默认值保持 `false`——Kubernetes 采用方零感知，
且不会因为参数化而悄悄变成 Nacos-first。

## 验证证据

两轮 spike 均在未改动任何生产代码与配置的前提下进行，被测为 `kaiwu-gateway-service`
（Boot 4 / Spring Cloud Gateway WebFlux），后端由 `traefik/whoami` 冒充并手工注册进
Nacos 2.4.3。唯一变量为 `KAIWU_SYSTEM_SERVICE_URI` 与 `SPRING_CLOUD_NACOS_DISCOVERY_ENABLED`。

### 第一轮：路由层

| URI | HTTP | 结论 |
|---|---|---|
| `http://127.0.0.1:8099` | 200 | 转发到指定地址 |
| `http://kaiwu-system-service` | 500 | `DnsErrorCauseException: NXDOMAIN` |
| `lb://kaiwu-system-service` | 200 | 经 `RoundRobinLoadBalancer` 解析并转发 |

第二行是**符合预期的失败**：宿主机没有该 DNS 记录，而非配置不被支持。它恰好证明
`http://` 把 host 原样交给了 DNS 解析器，应用层不介入。

结论：契约在路由层成立，且零代码改动。所需依赖 Gateway 已具备。

### 第二轮：出站调用层

构造一条 `accessMode: PROJECT` 本地路由，写入 Redis 会话并自签 RS256 Access JWT，
使请求走到 `ProjectAccessResolver`。两者均返回 503（失败关闭是设计如此），
判据为异常类型：

| `system-base-url` | 异常 |
|---|---|
| `http://192.0.2.200:8099` | `200 OK from GET ...`，随后 `UnsupportedMediaTypeException: 'text/plain'` |
| `lb://kaiwu-system-service` | `WebClientRequestException: Invalid scheme [lb]` |

前者连接层完全正常（已取得 200，仅因假后端返回非 JSON 而解析失败）；后者在连接层
即被拒绝——`WebClient` 由 `WebClient.builder()` 裸构造，底层 Netty `HttpClient`
不认识 `lb` scheme。

Starter 的三个客户端为同样的裸 HTTP 形态，其 pom 仅含 `spring-boot-starter-web`。
**未实测，按同一机制推定。**

### 一个环境侧结论

采用 `lb://` 时，Nacos 服务端必须网络可达每个注册实例。spike 中持久实例
（`ephemeral=false`）的健康状态由服务端主动探测决定，探测不通即被标记为不健康，
表现为「注册成功但调用 503」。Kubernetes Service 方案不存在此类问题。

## 后果

- 采用方可在不修改代码、不重新打包的前提下，通过环境变量在三种寻址形态间切换。
- Kaiwu 需在四处实现同一契约：Gateway 路由（已成立）、Gateway 出站 WebClient、
  Starter 三个客户端、生成项目模板。在全部完成前，`lb://` 只能视为部分支持。
- 生成项目的 `CLAUDE.md` / `AGENTS.md` 需说明该契约，否则生成产物仍隐含 Kubernetes 假设。
- 新增一处需要长期守住的边界：`lb://` 允许，locator 不允许。两者形似而安全含义相反，
  评审时需明确区分。

## 不做什么

- 不引入 `kaiwu.discovery.mode` 或任何等价的部署模式开关。
- 不放宽 discovery locator 禁令。
- 不为 4 个出站调用点建立通用的 `ServiceClient` 抽象层。收口 scheme 判断是必要的，
  在其上再封装一层调用门面则缺少消费者——业务服务之间不互相调用是既定架构约束
  （见工作区 `CLAUDE.md`），该抽象的使用方按设计并不存在。真出现业务侧调用需求时再评估。
- 不在 Kubernetes 上默认启用 Spring Cloud Kubernetes 的 `lb://` 路径。
