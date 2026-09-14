# 用 Nacos 管理运行配置

## 目标与边界

`dev` profile 的运行配置只维护在部署方指定的 Nacos 命名空间：

| Data ID | 作用 |
| --- | --- |
| `kaiwu-system-service-dev.yml` | System 的端口、MySQL/Redis 地址、代码生成与 Starter 参数 |
| `kaiwu-gateway-service-dev.yml` | Gateway 的端口、Redis 地址和显式 allowlist 路由 |

每条 Gateway 路由仍须显式声明 `accessMode` 和 `audience`。即便服务注册到 Nacos，禁止启用
discovery locator 自动暴露服务。

基础 `application.yml` 只负责获取 Nacos：应用名、active profile、Config import、Nacos 地址、
用户、密码和 config/discovery namespace。业务运行配置不再放在基础文件；`application-local.yml`
仅服务于不依赖 Nacos 的本地 Compose 黄金路径。

## Secret 规则

源码、Git 和文档不保存任何运行 Secret。开发命名空间中受权限保护的 Data ID 是 dev 运行值的
权威来源，包含 MySQL/Redis、管理员首启密码和配置加密密钥；日常启动脚本只读取它们，不在终端
要求逐个传入。Nacos bootstrap 密码与两套 RSA 私钥例外：前者由当前进程环境传入，后者由启动
脚本仅在内存生成并注入本次进程。

AI Provider 出站默认关闭。启用时必须同时配置
`kaiwu.ai-provider.allowed-hosts`（逗号分隔的精确目标 DNS 主机名，不接受 IP 或通配符）
和 `kaiwu.ai-provider.egress-proxy-uri`（受控 HTTP 出站代理，例如
`http://ai-egress-proxy:3128`）。应用只连接该代理，不直接解析或连接模型域名，以避免
DNS 重绑定的 resolve-then-connect 竞态。代理必须再次执行目标域名白名单，并拒绝私网、
回环、链路本地、云元数据及重定向目标。等价环境变量为
`KAIWU_AI_PROVIDER_ALLOWED_HOSTS` 和 `KAIWU_AI_PROVIDER_EGRESS_PROXY_URI`
（Spring relaxed binding）。

本地开发用 Compose 里的 `ai-egress-proxy`（squid）充当这个受控代理，配置在
`docker/ai-egress-proxy/`。它放在独立的 `ai-egress` profile 中，只在设置了
`KAIWU_AI_PROVIDER_ALLOWED_HOSTS` 时由 `scripts/kaiwu.sh` 与 `scripts/dev-run.sh`
自动拉起；未设置时整条 AI 出站保持关闭，一键启动行为不变。代理侧的域名白名单由该环境变量
在容器启动时生成，与应用侧同一个来源；白名单为空则容器直接退出，不会变成开放代理。
启用本地 AI：

```bash
export KAIWU_AI_PROVIDER_ALLOWED_HOSTS=your-model-host.example.com
export KAIWU_AI_PROVIDER_EGRESS_PROXY_URI=http://ai-egress-proxy:3128
./scripts/kaiwu.sh up
```

Nacos 模式下，在 `kaiwu-compose-dev.yml` 的 `kaiwu.dev-compose` 中配置同一份目标和代理，
`dev-nacos-run.sh` 会把值同时注入 System 与代理容器，并自动启用 `ai-egress` profile：

```yaml
kaiwu:
  dev-compose:
    ai-provider-allowed-hosts: your-model-host.example.com
    ai-provider-egress-proxy-uri: http://ai-egress-proxy:3128
```

`kaiwu-system-service-dev.yml` 中的 `kaiwu.ai-provider` 仍应保留相同配置。两处必须一致，
前者负责 Compose 进程与代理白名单，后者是 dev 应用配置的权威记录。
代理默认使用 `223.5.5.5` 和 `119.29.29.29` 解析目标域名；需要使用企业 DNS 时，可在启动
环境设置 `KAIWU_AI_PROVIDER_DNS_PRIMARY` 和 `KAIWU_AI_PROVIDER_DNS_SECONDARY` 覆盖。

## 一键启动

先在当前 shell 注入必需 Secret（仅环境变量，不要写入仓库或 shell 历史），再执行：

```bash
cd kaiwu-system-service
./scripts/dev-nacos-run.sh
```

已完成镜像构建时，可用 `./scripts/dev-nacos-run.sh --no-build --detach` 在后台启动；脚本仍会先
读取并校验 `kaiwu-compose-dev.yml`。两个应用 Data ID 必须已经存在；需要初始化模板时显式执行
`./scripts/publish-nacos-dev-config.sh --overwrite-template`。

此命令会：

1. 用环境中的 Nacos密码登录指定 dev 命名空间并读取 Compose 运行值；
2. 仅在内存生成本次 Compose 共享的两套 RSA 密钥；
3. 以 `dev` profile 启动 MySQL、Redis、System、Gateway 与 Web。

每次启动必须显式传入 Nacos 环境参数，仓库没有默认地址、命名空间或账号：
`KAIWU_NACOS_SERVER_URL`（HTTPS Console 配置读取地址）、`KAIWU_NACOS_SERVER_ADDR`
（Spring Client HTTP/gRPC 直连地址）、`KAIWU_NACOS_NAMESPACE`、`KAIWU_NACOS_USERNAME`、
`KAIWU_NACOS_PASSWORD`。HTTPS Console 域名不能替代 Client 直连地址：Nacos Client 还要连接
gRPC 端口，且当前 Docker 网络无法解析该内网域名。脚本会把 Client 地址映射为 Spring 等价参数：

```text
-Dspring.profiles.active=dev
-Dspring.cloud.nacos.server-addr=…
-Dspring.cloud.nacos.username=…
-Dspring.cloud.nacos.password=…
-Dspring.cloud.nacos.config.namespace=…
-Dspring.cloud.nacos.discovery.namespace=…
```

容器场景使用等价环境变量；直接 Java 启动可使用上述 JVM 参数。Nacos 不可达、认证失败、发布失败
或读回内容不一致时，脚本在启动应用前退出。

## 服务器部署时用 Nacos

不上 Kubernetes、用 Docker Compose 部署到服务器，同样可以把运行配置放进 Nacos，
不必把几十个环境变量堆在 `runtime.env` 里。

**profile 决定读哪两个 Data ID**，命名规则是 `<应用名>-<profile>.yml`。默认 `dev`；
服务器上用自己的 profile，例如 `prod` 对应 `kaiwu-system-service-prod.yml` 与
`kaiwu-gateway-service-prod.yml`。

### 1. 在 Nacos 里建命名空间与两份配置

**命名空间要用它的 ID，不是名字。** public 命名空间的 ID 是空串，而本项目的
`KAIWU_NACOS_NAMESPACE` 不接受空值——服务器部署本来也应该建独立命名空间，
不要用 public。

**两份配置有现成模板**，不必从零拼：

```text
deploy/nacos/kaiwu-system-service.yml.example
deploy/nacos/kaiwu-gateway-service.yml.example
```

它们由各自的 `application-local.yml` 推导而来，保留了同样的 `${KAIWU_*}` 占位符——
RSA 私钥、数据库口令、加密密钥都由进程环境注入，不会写进 Nacos。Gateway 那份含平台
的**全部四条路由**，少一条就有页面打不开，这也是不建议手写的主要原因。

可以在 Nacos 控制台粘贴，也可以用脚本首发：

```bash
export KAIWU_NACOS_SERVER_URL='http://nacos.internal:8848'
export KAIWU_NACOS_NAMESPACE='<命名空间 ID>'
export KAIWU_SPRING_PROFILE=prod
./deploy/nacos/publish-templates.sh
```

该脚本**只做首发，已存在就跳过**：改配置应当在 Nacos 控制台进行，那里有历史版本
和回滚，脚本覆盖会把这些绕过去。

发布后必须在控制台核对数据库与 Redis 地址——模板里是 `127.0.0.1` 的默认值。

### 2. 启动

```bash
cd <服务器>/kaiwu/kaiwu-system-service

export KAIWU_SPRING_PROFILE=prod
export KAIWU_NACOS_SERVER_ADDR='nacos.internal:8848'   # 客户端直连端口，不是控制台 HTTPS 地址
export KAIWU_NACOS_NAMESPACE='<命名空间 ID>'
export KAIWU_NACOS_USERNAME='<账号>'
export KAIWU_NACOS_PASSWORD='<口令>'

docker compose --env-file ../.kaiwu-server/runtime.env \
  -f docker-compose.yml \
  -f docker-compose.server.yml \
  -f docker-compose.nacos.yml \
  up -d --build --wait
```

数据库和 Redis 也用自己的实例时，再叠上 `-f docker-compose.external-db.yml`
与 `-f docker-compose.external-redis.yml`（两者独立，可只用其一）并给出
`KAIWU_DB_*` / `KAIWU_REDIS_*`，详见
[SERVER-DEPLOYMENT.md](SERVER-DEPLOYMENT.md)。三个覆盖文件可以任意组合。

### 3. 确认配置真的来自 Nacos

```bash
docker compose logs system-service | grep -i "profile is active"
docker compose logs system-service | grep -i "dataId=kaiwu-system-service"
```

第一条应显示你设的 profile。第二条若出现 `is empty`，说明该命名空间下没有这个
Data ID——最常见的原因是把命名空间**名字**当成了 ID。

## 无 Docker 的本机直启

当 MySQL、Redis 和 Nacos 已由开发环境统一托管时，不需要也不应在开发机重新创建数据库或运行
Redis。先在同一 namespace 的 `DEFAULT_GROUP` 配好上表两个 Data ID：

- `kaiwu-system-service-dev.yml`：必须给出 `spring.datasource`、`spring.data.redis`、
  `kaiwu.metadata.encryption-key`、`kaiwu.auth.bootstrap-admin-password` 及 System 的 Starter 配置；
- `kaiwu-gateway-service-dev.yml`：必须给出 `spring.data.redis`、`kaiwu.gateway.auth` 和所有显式
  Gateway routes；平台自身路由的 URI 写为 `${KAIWU_SYSTEM_SERVICE_URI}`。
  **禁止打开 discovery locator**——它会给每个注册服务自动建路由，等于把「对外发布」的权力
  交给「能往同一 namespace 注册的任何进程」。业务项目路由的 `uri` 由该项目登记的服务地址决定，
  允许写成 `lb://服务名`：那只是让 Nacos 解析实例并做负载均衡，路由本身仍是平台逐条显式登记的。
  两件事必须分开看——**禁的是自动建路由，不是 `lb://` 这个写法**。

本机直启不会代替发布流程执行 Flyway，目标 MySQL 必须已完成当前版本迁移。两份 Data ID 中的
MySQL/Redis 地址和凭据由 Nacos 管理；RSA 私钥不能放入 Nacos，继续保留这些占位符：

```yaml
# kaiwu-system-service-dev.yml
kaiwu:
  auth:
    access-private-key: ${KAIWU_ACCESS_PRIVATE_KEY}
  starter:
    context-public-key: ${KAIWU_CONTEXT_PUBLIC_KEY}

# kaiwu-gateway-service-dev.yml
kaiwu:
  gateway:
    auth:
      access-public-key: ${KAIWU_ACCESS_PUBLIC_KEY}
      context-private-key: ${KAIWU_CONTEXT_PRIVATE_KEY}
```

随后在当前终端提供 Nacos bootstrap 参数并直启：

```bash
export KAIWU_NACOS_SERVER_ADDR='nacos-client.example.internal:8848'
export KAIWU_NACOS_NAMESPACE='target-namespace-id'
export KAIWU_NACOS_USERNAME='target-account'
export KAIWU_NACOS_PASSWORD='...'

./scripts/kaiwu.sh local-up
```

此命令只启动本机 System、Gateway、Web；System/Gateway 固定监听 `127.0.0.1:8080/8088`，浏览器仍通过
Web `8000` → Gateway `8088` 访问。本机 Gateway 将 `KAIWU_SYSTEM_SERVICE_URI` 设为
`http://127.0.0.1:8080`；Docker Nacos 模式设为 `http://system-service:8080`。两种模式均关闭 Nacos
服务注册/发现，仅使用 Nacos 配置读取。`local-down` 只停止这三个进程并删除本轮临时 RSA 密钥，不会改动
Nacos、MySQL、Redis 或 Flyway 历史。
