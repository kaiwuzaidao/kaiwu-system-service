# ${projectName} 后端

本仓库由 Kaiwu 项目工厂按脚手架版本 `${templateVersion}` 一次性生成。生成后由本仓库
独立维护，Kaiwu 不会再次覆盖。

## ⚠️ 交付后必做的两件事

流水线全绿 **不代表**这两件事做完了——它们都不在任何门禁的检查范围里，漏掉的表现是
「页面能打开，但按钮和下拉框都是空的」，很难从报错里看出来。

**1. 导入菜单与权限种子。** 生成的 `sql/menu.sql` 进的是 **Kaiwu System 平台库**，不是
业务库，且不会自动生效：

```bash
cd <kaiwu 开源入口目录>
./kaiwu import-project-menu <本仓路径>/sql/menu.sql
```

不导入 → 平台里看不到本项目的菜单，页面上所有权限按钮都不显示。

**2. 按需种入受管字典。** 见 `sql/dict.sql`，里面有可直接复制的完整示例和导入命令。
脚手架不猜业务枚举，所以初始是零字典。注意 `pnpm check:dict` 在零字典时**是通过的**，
门禁绿灯不代表字典可用。

不种 → 用到 `ManagedDictSelect` 的下拉框是空的，`ManagedDictText` 原样显示字典值。

## 快速开始（第一次运行）

**前置要求**：JDK 21、Maven 3.9+、MySQL 8，以及 **Kaiwu 平台已在本机跑起来**
（`kaiwu-system-service` + `kaiwu-gateway-service`）——业务后端启动时需要用到 Gateway
签发 Kaiwu Context 的 RSA 公钥。

### 推荐：用本地启动助手

仓库自带独立的 MySQL 8 Compose 和环境检查，不会连接 Kaiwu 平台库。先从正在运行的
Kaiwu 工作区读取 **Context 公钥**（公钥不是 Secret），再执行启动脚本：

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export DB_PASSWORD=<业务库开发密码>
export KAIWU_LOCAL_DB_ROOT_PASSWORD=<本地 MySQL root 密码>
export KAIWU_CONTEXT_PUBLIC_KEY="$(cd <kaiwu-system-service路径> && ./scripts/kaiwu.sh context-public-key)"

bash scripts/dev.sh
```

脚本会检查 JDK/Maven/Docker、在宿主机 `${localDbPort}` 启动本项目独立 MySQL、打包，
最后在 `${localServerPort}` 启动后端（端口由项目编码派生，同机多项目不撞车）。密码只从当前进程环境读取，不写入仓库或 Compose 文件。
如需人工控制，继续按下面步骤执行。

### 1. 建业务库（一次性）

```bash
mysql -uroot -p -e "CREATE DATABASE kaiwu_${normalizedProjectCode} DEFAULT CHARSET utf8mb4;"
```

首次启动时内嵌 Flyway 会自动建表和写入 seed，不需要手动导入 SQL。

### 2. 获取 Kaiwu Context 公钥（本地开发）

Kaiwu 平台的 `scripts/dev-run.sh` 每次启动会**当场生成一对 RSA 密钥**并 export 到当前
终端的 `KAIWU_CONTEXT_PRIVATE_KEY` / `KAIWU_CONTEXT_PUBLIC_KEY`。**同一终端**继续启动
业务后端即可直接读到，不用复制粘贴。

如果业务后端要在**另一个终端**起，把 Kaiwu 平台那个终端的 `KAIWU_CONTEXT_PUBLIC_KEY`
完整值 export 过来即可。生产环境由部署者预先生成密钥对，Gateway 拿私钥，各业务后端
分别持有公钥（长期固定）。

### 3. 启动服务

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export MAVEN_SKIP_RC=1

# 数据库
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_NAME=kaiwu_${normalizedProjectCode}
export DB_USER=root
export DB_PASSWORD=<你的 MySQL 密码>

# Kaiwu Context 公钥（步骤 2 拿到的完整 PEM）
export KAIWU_CONTEXT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----"

# 端口：默认 8080 会跟 Kaiwu system-service 撞，本机同时跑必须换一个
export SERVER_PORT=${localServerPort}

mvn verify
mvn -pl kaiwu-${projectCode}-boot spring-boot:run
```

日志出现 `Started ${applicationClass}` 即启动成功。

### 4. 验证跑起来了

```bash
curl -sS http://127.0.0.1:${r"${SERVER_PORT:-"}${localServerPort}}/actuator/health
# 应返回 {"status":"UP"}
```

`/actuator/health` 不经过 Starter 校验器，可以直接访问。**业务接口一律需要 Kaiwu
Context**，直连业务后端会 401，属正常——真实业务流量必须走 Gateway。

### 5.（可选）通过 Gateway 调业务接口

生成的业务后端**尚未自动注册到 Kaiwu Gateway**。本地联调时把路由文件放进 Gateway 的
本地路由目录即可，不用改它的 `application-local.yml`：

```bash
cp docs/gateway-route-local.yml <kaiwu-gateway-service路径>/routes.local.d/${projectCode}.yml
```

该目录只在 Gateway 的 `local` profile 加载，且不进版本库；路由仍是逐条显式声明，
不是服务发现。片段已包含正确的路径重写和安全元数据：

**部署环境**不用这个文件：在 Kaiwu 项目管理里填好「服务地址」后，平台会按你的部署形态
生成对应的 route 片段（`GET /api/projects/{id}/gateway-route`），由运维放进受管 Gateway 配置。
服务地址按部署形态填，Kaiwu 不做假设：

| 部署形态 | 服务地址填什么 | 业务服务要做什么 |
|---|---|---|
| K8s | `http://kaiwu-${projectCode}-service:8080`（Service DNS） | 什么都不用做 |
| Docker Compose | `http://${projectCode}-service:8080`（容器名） | 什么都不用做 |
| 单实例固定地址 | `http://192.0.2.10:8080` | 什么都不用做 |
| VM 多实例 / 无编排器 | `lb://kaiwu-${projectCode}-service` | 见下方「接入注册中心」 |

前三种靠运行环境自带的 DNS 解析和负载均衡，**不需要注册中心**。K8s 的 Service 已经提供了
稳定域名、实例列表和请求级负载均衡，再叠一层注册中心会出现两份「谁还活着」的事实，
典型症状是请求打到已被摘除的实例上超时。

### 接入注册中心（可选）

只有在没有编排器、需要动态实例列表时才需要。本项目默认**不带**注册中心依赖，
以免让你的 Spring Boot 升级节奏受制于第三方 BOM 的发版节奏。需要时自行加：

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
```

并在配置里显式声明地址与命名空间（凭据只走环境变量）：

```yaml
spring:
  cloud:
    nacos:
      discovery:
        enabled: ${r"${KAIWU_NACOS_DISCOVERY_ENABLED:false}"}
        server-addr: ${r"${KAIWU_NACOS_SERVER_ADDR:}"}
        namespace: ${r"${KAIWU_NACOS_NAMESPACE:}"}
```

注册成功不等于对外可访问：仍然要有平台登记的显式 route，Gateway 才会转发。

以下是本地用的片段：

```yaml
- id: ${projectCode}-project-local
  uri: http://127.0.0.1:${r"${SERVER_PORT:-"}${localServerPort}}
  predicates:
    - Path=/${projectCode}-api/**
  filters:
    - RewritePath=/${projectCode}-api/(?<segment>.*), /${r"${segment}"}
  metadata:
    accessMode: PROJECT
    audience: kaiwu-${projectCode}-service
    projectCode: ${projectCode}
```

网关重启后即可通过 `curl -H "Authorization: Bearer <access_token>" \
http://127.0.0.1:8088/${projectCode}-api/api/xxx` 访问；网关会验证 access token、
签发短期 Context，业务后端本地验签放行。

## 部署交付

仓库已经带好两套最小部署骨架；它们属于本业务仓，生成后由业务团队继续维护，Kaiwu 不会
回写。两种方式都要求先准备长期固定的 Context 公钥和独立业务数据库。

### 单台服务器（Docker Compose）

先启动 Kaiwu 平台，确认它的 Compose 网络名（默认 `kaiwu_default`），再执行：

```bash
export DB_PASSWORD='<业务库密码>'
export DB_ROOT_PASSWORD='<业务库 root 密码>'
export KAIWU_CONTEXT_PUBLIC_KEY="$(cd <kaiwu-system-service路径> && \
  KAIWU_RUNTIME_ENV_FILE=<平台服务器/runtime.env路径> \
  ./scripts/kaiwu.sh context-public-key)"
docker compose -f deploy/server/compose.yml up -d --build --wait
```

把 `deploy/server/gateway-route.yml` 复制到平台仓的 `routes.managed.d/${projectCode}.yml`，平台以
`docker-compose.server.yml` 覆盖层启动或重启 Gateway 后生效。该路由通过共享 Compose 网络访问
业务服务，不开放业务 API 容器端口给公网。

### Kubernetes

`deploy/k8s/` 提供 Deployment、Service 和 Kustomize 入口。部署前必须：

1. 在目标 namespace 用密钥系统创建 `kaiwu-${projectCode}-runtime` Secret，包含
   `db-host`、`db-port`、`db-name`、`db-user`、`db-password`、`context-public-key`；
2. 在 `kustomization.yaml` 把 `newName` / `newTag` 换成已验证的业务镜像；
3. 正式 GitOps 环境把这条 Route 合并到 `kaiwu-deploy/gateway-routes/<env>/routes/`，由平台
   Helm 的 `gateway.managedRoutesExistingConfigMap` 挂载；不使用 GitOps 时，才把
   `gateway-route-values.yaml` 追加到 `gateway.managedRoutes`；
4. 执行 `kubectl apply -k deploy/k8s`，等待 Deployment Ready。

生成片段使用 `http://kaiwu-${projectCode}-service:8080`，适合前后端与 Gateway 同 namespace
的最小部署。正式 GitOps 默认使用独立业务 namespace，由部署仓把它改成完整 Service DNS；
两种方式都不需要 Nacos，也不能打开 discovery locator 代替显式接入。

## 环境变量清单

| 变量 | 必须 | 说明 | 从哪里拿 |
|---|---|---|---|
| `DB_HOST` `DB_PORT` `DB_NAME` `DB_USER` `DB_PASSWORD` | 是 | 业务库连接 | 你自己的 MySQL |
| `KAIWU_CONTEXT_PUBLIC_KEY` | 是 | Gateway 签发 Context 的 RSA 公钥 PEM | Kaiwu 平台 `dev-run.sh` 已 export；生产由运维预先生成 |
| `SERVER_PORT` | 可选 | 服务端口，默认 `${localServerPort}`（由项目编码派生） | 与其它项目撞号时覆盖，需同步改 Gateway 本地路由 |
| `KAIWU_SCHEDULER_ENABLED` | 否 | 启用项目定时任务，默认关闭 | 见下 |
| `KAIWU_SYSTEM_SERVICE_URI` | 否 | Kaiwu 平台后端地址 | 见下方「平台地址怎么填」 |
| `KAIWU_SCHEDULER_CREDENTIAL` | 否 | 定时任务上报凭据 | Kaiwu 平台"定时任务"页面 |

Secret 缺失时服务会 fail-fast，日志一次性列出所有缺失项。

### 平台地址怎么填

`KAIWU_SYSTEM_SERVICE_URI` 的 **scheme 决定由谁解析地址**（ADR 0024），本服务不需要
任何部署模式开关：

| 填法 | 由谁解析 | 适用 |
|---|---|---|
| `http://127.0.0.1:8080` | 直接连 | 本地开发 |
| `http://kaiwu-system:8080` | 集群 DNS | Kubernetes，Service 本身就是服务发现 |
| `lb://kaiwu-system-service` | Spring Cloud LoadBalancer | 服务器多实例 + 注册中心 |

前两种开箱可用。要用 `lb://` 需自行添加两个依赖——注册中心是你的基础设施选择，
Kaiwu Starter 不替你决定：

```xml
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-loadbalancer</artifactId>
</dependency>
<!-- 换成你实际使用的注册中心，如 Nacos、Consul、Spring Cloud Kubernetes -->
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
</dependency>
```

配了 `lb://` 却缺依赖时服务**启动即失败**并打印所需依赖名，不会拖到运行时才报错。

## 常见首次启动错误

| 现象 | 原因 | 处理 |
|---|---|---|
| `Unknown database 'kaiwu_${normalizedProjectCode}'` | 步骤 1 没做 | 先 `CREATE DATABASE` |
| `缺少必需配置：kaiwu.starter.context-public-key` | `KAIWU_CONTEXT_PUBLIC_KEY` 未 export 或为空 | 从 Kaiwu 平台终端复制完整 PEM 值 |
| `kaiwu.starter.context-public-key 不是有效的 RSA 公钥` | PEM 换行丢失或格式错乱 | 用带引号的多行字符串 export，保留 `\n` |
| `Access denied for user` | `DB_USER` / `DB_PASSWORD` 错误 | 核对 MySQL 凭据 |
| 端口占用 | 与其它生成项目撞号 | `SERVER_PORT=<新端口> bash scripts/dev.sh`，并同步改 `docs/gateway-route-local.yml` |
| 业务接口一律 401 | 直连业务后端不带 Context | 按步骤 5 配 Gateway route，或临时用 `/actuator/health` 验活 |

## 读取平台参数配置

在 Kaiwu「参数配置」维护的项目参数，后端通过 Starter 注入的 `ProjectConfigClient` 读取：

```java
int batchSize = projectConfigClient.getInt("order.settle.batchSize", 200);
```

限额、阈值、开关这类**参与校验的值必须由后端读**——交给前端读再传回来等于没有校验。
纯展示型参数才由前端 `useProjectConfig` 直接读。

复用与定时任务相同的项目服务凭据，因此只要配了调度就无需额外设置：

```bash
KAIWU_SYSTEM_SERVICE_URI=http://kaiwu-system-service:8001 \
KAIWU_SCHEDULER_CREDENTIAL=... \
mvn -pl kaiwu-${projectCode}-boot spring-boot:run
```

未配置凭据时客户端整体降级，所有读取返回 fallback，不影响启动与业务。
读取走内存快照，默认每 300 秒刷新一次（`kaiwu.starter.config.refresh-seconds`），
请求路径上不发网络请求。secret 类配置不会下发，密钥仍走环境变量。

## 项目定时任务

System 负责统一保存 Cron、时区、启停状态和执行记录，当前服务只执行本项目已注册的
任务处理器。先在 System 的"定时任务"页面为本项目生成一次性凭据，然后通过环境变量
启用：

```bash
KAIWU_SCHEDULER_ENABLED=true \
KAIWU_SYSTEM_SERVICE_URI=http://kaiwu-system-service:8001 \
KAIWU_SCHEDULER_CREDENTIAL=... \
mvn -pl kaiwu-${projectCode}-boot spring-boot:run
```

业务任务必须以 Spring Bean 注册，System 只能选择已上报的 `taskType`，不能远程指定
Java 类、Shell 或 URL：

```java
@Component
public class DailyReportTask implements ProjectScheduledTaskHandler {
    @Override
    public String taskType() {
        return "daily-report";
    }

    @Override
    public void execute(ProjectScheduledTaskContext context) {
        // 使用 context.payload() 读取受管 JSON 参数
    }
}
```

同一触发时间由 System 原子抢占并记录执行权，多副本部署时只会有一个实例获得执行资格。
调度语义为 at-least-once：如果业务副作用已完成但结果尚未回传时实例永久失联，租约恢复后
可能重试。业务 Handler 必须用 `context.executionId()`，或
`context.jobId() + context.scheduledAt()` 建立幂等键。

## 数据库迁移

内嵌 Flyway 在应用启动时执行，脚本目录为
`kaiwu-${projectCode}-boot/src/main/resources/db/migration/V{n}__*.sql`；
`sql/schema.sql` 只是累积快照，供审阅对照，运行时不执行。V1 仅用于全新空库，不自动接管
已有 schema。平台项目权限种子位于 `sql/menu.sql`，需导入 Kaiwu System 库，不能与业务库混用。
