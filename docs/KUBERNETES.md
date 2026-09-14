# Kaiwu Kubernetes 部署与升级

本文用于把已经在本地体验过的 Kaiwu 部署到 Kubernetes。Helm Chart 位于
`deploy/helm/kaiwu`，继续使用 Compose 中相同的 System、Gateway 和 Web 镜像。

只做一次 Helm 演示不需要额外仓库；准备采用 ArgoCD/GitOps 时，再从开源入口获取部署仓：

```bash
cd <kaiwu-开源入口目录>
./kaiwu deploy-init
cd workspace/kaiwu-deploy
```

`kaiwu-deploy` 中的 Git 地址、镜像仓库、数据库地址、域名和 digest 都是显式占位符，必须按
自己的环境替换后才能通过渲染检查。

## 1. 部署边界

Chart 管理：

- System、Gateway、Web Deployment 和 Service；
- Flyway 数据库迁移 initContainer；
- 生成制品 PVC；
- 可选 Ingress；
- 仅用于演示的 MySQL、Redis StatefulSet。

Chart 不创建运行密钥。部署前必须准备 `kaiwu-runtime` Secret。生产数据库、Redis、
镜像仓库、Ingress Controller、TLS 证书和备份由部署环境提供。

Secret 使用以下键：

| 键 | 用途 |
| --- | --- |
| `mysql-root-password` | 仅内置演示 MySQL 初始化 |
| `database-password` | Flyway 与 System 数据库账号 |
| `redis-password` | System、Gateway 和 Redis |
| `bootstrap-admin-password` | 空库首次创建 admin |
| `config-encryption-key` | 32 字节 Base64 AES 密钥 |
| `access-private-key` / `access-public-key` | 登录令牌签名与验证 |
| `context-private-key` / `context-public-key` | 服务上下文签名与验证 |
| `notification-delivery-token` | 可选投递集成；未使用时也保留空键 |
| `gateway-internal-token` | Gateway 查询项目入口授权的内部凭据（ADR 0022）；**缺失时 PROJECT 路由一律 503** |

用外部数据库或 Redis 时，`database-password` 与 `redis-password` 必须与实例上已有的
密码一致。`kaiwu-k8s-secret.sh` 默认随机生成这两项，那只适用于内置演示实例；
外部实例要先读进环境变量再调用，否则 Flyway 会停在 `Access denied`，
而报错本身看不出根因是密钥与实例不一致：

```bash
read -r -s -p 'DB password: ' KAIWU_DATABASE_PASSWORD; export KAIWU_DATABASE_PASSWORD
read -r -s -p 'Redis password: ' KAIWU_REDIS_PASSWORD; export KAIWU_REDIS_PASSWORD
./scripts/kaiwu-k8s-secret.sh <namespace>
```

先读进变量而不是写在命令行里，是为了不让密码进 shell 历史。

Nacos 不是 Kubernetes 启动的前置条件。Chart 默认通过 Secret、values 和集群 DNS 直接注入
配置；已有统一 Nacos 治理要求时可在审查配置边界后另行接入。

服务寻址由 URI scheme 表达（ADR 0024），不存在部署模式开关。默认走 `http://`，
即 Gateway 经 CoreDNS 和 Service 找到 System——Kubernetes 的 Service 本身就是服务发现与
负载均衡，在其上再叠一层应用层发现是更重的路径。确有理由改走注册中心时：

```yaml
serviceAddressing:
  systemServiceUri: "lb://kaiwu-system-service"
  discoveryEnabled: true
  extraEnv:                       # DiscoveryClient 的连接配置由使用方提供
    - name: NACOS_SERVER_ADDR
      value: "nacos.internal:8848"
```

`discoveryEnabled` 对 System 与 Gateway 同时生效，但两者角色相反：System 是被调用方，
必须注册自己；Gateway 是外部入口，不需要被发现，chart 会自动为它追加
`SPRING_CLOUD_NACOS_DISCOVERY_REGISTER_ENABLED=false`。

配了 `lb://` 却缺少 LoadBalancer 或 DiscoveryClient 实现时，Gateway 会在装配出站客户端时
**启动失败**并打印所需依赖，不会留到运行时才表现为 PROJECT 路由 503。

## 2. 准备镜像

先将三个应用镜像构建并推送到集群可访问的镜像仓库：

```text
<registry>/kaiwu-system-service:<version>
<registry>/kaiwu-gateway-service:<version>
<registry>/kaiwu-system-web:<version>
```

生产部署使用不可变版本号或 `images.<component>.digest` 镜像摘要，不要使用 `latest`。
设置 digest 后 Chart 会忽略对应 tag。私有仓库需要提前创建 imagePullSecret，并通过
`imagePullSecrets` 引用。

## 3. 在开发集群快速安装

需要 `kubectl`、Helm 3、OpenSSL、默认 StorageClass，以及可用的 Kubernetes 集群。

以下脚本只适合首次演示：它会生成随机密码、AES 密钥和两套 RSA 密钥，并创建 Secret。
脚本检测到同名 Secret 时会拒绝覆盖，防止升级时意外轮换密钥。

```bash
./scripts/kaiwu-k8s-secret.sh kaiwu
```

安装 Chart，并显式指定三个镜像：

```bash
helm upgrade --install kaiwu deploy/helm/kaiwu \
  --namespace kaiwu \
  --create-namespace \
  --set images.system.repository=<registry>/kaiwu-system-service \
  --set images.system.tag=<version> \
  --set images.gateway.repository=<registry>/kaiwu-gateway-service \
  --set images.gateway.tag=<version> \
  --set images.web.repository=<registry>/kaiwu-system-web \
  --set images.web.tag=<version> \
  --wait \
  --timeout 10m
```

默认 values 会启动单实例 MySQL 和 Redis，只能用于开发或演示。查看状态：

```bash
kubectl get pods -n kaiwu
kubectl get jobs,statefulsets,deployments -n kaiwu
kubectl rollout status deployment/kaiwu-kaiwu-system -n kaiwu
kubectl rollout status deployment/kaiwu-kaiwu-gateway -n kaiwu
kubectl rollout status deployment/kaiwu-kaiwu-web -n kaiwu
```

本机访问：

```bash
kubectl port-forward service/kaiwu-kaiwu-web 8000:80 -n kaiwu
```

打开 `http://127.0.0.1:8000`。用户名为 `admin`，初始密码是创建 Secret 时脚本打印的值。
若当时已安全保存，也可按组织的 Secret 读取权限流程获取。首次登录后必须修改密码。

## 4. 生产部署

`deploy/helm/kaiwu/values-production.yaml` 是需要复制和审查的示例，不是可直接套用的生产承诺。
至少完成以下准备：

1. 创建空的 MySQL 8.4 数据库和专用最小权限账号；
2. 准备高可用 Redis；
3. 通过 External Secrets、Sealed Secrets 或平台密钥系统维护 `kaiwu-runtime`；
4. 配置数据库备份、恢复演练和监控告警；
5. 准备 TLS Ingress、DNS 和镜像拉取凭据；
6. 将所有镜像固定到已验证的不可变版本；
7. 为资源限制、StorageClass、节点调度和可用区策略设定环境值。

复制示例后替换所有占位符：

```bash
cp deploy/helm/kaiwu/values-production.yaml kaiwu-production.yaml
```

不要提交包含密码或私钥的 values 文件。部署前先渲染审查：

```bash
helm lint deploy/helm/kaiwu
helm template kaiwu deploy/helm/kaiwu \
  --namespace kaiwu \
  -f kaiwu-production.yaml > kaiwu-rendered.yaml
```

确认渲染文件中没有明文 Secret，然后部署：

```bash
helm upgrade --install kaiwu deploy/helm/kaiwu \
  --namespace kaiwu \
  --create-namespace \
  -f kaiwu-production.yaml \
  --atomic \
  --wait \
  --timeout 15m
```

System 当前把生成制品写入 ReadWriteOnce PVC，因此默认保持一个副本并使用 `Recreate` 更新。
Gateway 和 Web 无状态，可增加副本。只有把制品迁移到共享文件系统或对象存储并完成并发验证后，
才应扩容 System。

## 5. 部署生成的业务项目

生成的前后端仓各自包含 `deploy/k8s/`，业务项目不进入平台 Chart，也不与其它项目共享数据库。
正式环境由 `kaiwu-deploy` 为每个项目、每个环境创建独立 namespace，例如
`kaiwu-order-center-test`；平台 test/prod 则分别位于 `kaiwu-test`、`kaiwu-prod`。

### 5.1 后端、独立数据库与 Context 公钥

先用组织密钥系统创建 `kaiwu-{projectCode}-runtime` Secret，包含业务数据库连接和平台
`context-public-key`；不要把 Secret 值写进 manifests 或命令历史。修改生成后端仓
`deploy/k8s/kustomization.yaml` 的镜像后：

```bash
kubectl apply -k <业务后端仓>/deploy/k8s -n kaiwu-<projectCode>-test
kubectl rollout status deployment/kaiwu-<projectCode>-service -n kaiwu-<projectCode>-test
```

### 5.2 显式接入 Gateway

正式 GitOps 流程在 `kaiwu-deploy` 执行 `scripts/new-project.sh`，由
`gateway-routes/<env>/routes/<projectCode>.yaml` 保存完整 Service DNS，并渲染为只读 ConfigMap。
平台 values 只引用 ConfigMap 名，不把所有项目 Route 混进一个 values 文件：

```bash
helm upgrade kaiwu deploy/helm/kaiwu \
  --namespace <平台环境-namespace> \
  -f <平台-values.yaml> \
  --set gateway.managedRoutesExistingConfigMap=kaiwu-project-routes \
  --atomic --wait --timeout 15m
```

本地或不使用 GitOps 的最小部署仍可把生成后端仓的 `gateway-route-values.yaml` 追加到
`gateway.managedRoutes`；它与 `managedRoutesExistingConfigMap` 不能同时配置。

这仍然是逐条显式 route：任一文件损坏、id 重复或缺少 `PROJECT` / `audience` /
`projectCode` 会使 Gateway 启动失败。Chart 不启用 discovery locator。

### 5.3 前端与同源 Ingress

修改生成前端仓 Kustomize 镜像和 Ingress 域名后执行。模板会在业务 namespace 内创建
`kaiwu-platform-gateway` ExternalName 别名；平台 release 或 namespace 不同时，只覆盖它的
`externalName`：

```bash
kubectl apply -k <业务前端仓>/deploy/k8s -n kaiwu-<projectCode>-test
kubectl rollout status deployment/kaiwu-<projectCode>-web -n kaiwu-<projectCode>-test
```

Ingress 必须把 `/apps/{projectCode}/` 送到业务 Web，把 `/{projectCode}-api/` 送到平台
Gateway；不能让 API 绕过 Gateway。平台项目的业务后台入口登记同源 `/apps/{projectCode}/`，
平台打开时会补项目 ID，并通过同源 nonce 桥接派发内存 Access Token。

菜单属于平台数据库。AI 初始生成时项目工厂已登记；后续业务仓新增菜单，或将同一业务项目
恢复到新的平台数据库时，把受审查的 `sql/menu.sql` 纳入平台数据库变更流程，不能导入业务库。

## 6. 数据库迁移

Flyway SQL 的事实源是 `sql/increment/V{n}__*.sql`。Chart 中
`files/migrations/` 保存用于 initContainer 的同版本副本，CI 会检查二者完全一致。

- 全新库从 `V1__kaiwu_baseline.sql` 建立；
- 已发布环境只追加新版本，禁止修改已经执行过的 SQL；
- 迁移必须确定、前向；不使用普遍的 `IF NOT EXISTS` 掩盖环境结构漂移，只有明确可重试步骤才要求幂等；
- System Pod 启动前，Flyway initContainer 会等待数据库并执行待迁移版本；
- 迁移失败时 System 不会启动，避免新应用连接到不兼容结构；
- 生产升级前必须备份数据库并验证恢复。

新增迁移时：

```bash
cp sql/increment/V2__example.sql \
  deploy/helm/kaiwu/files/migrations/V2__example.sql
```

版本号按实际最新版本递增。提交前运行 CI 中相同的一致性检查。

## 7. 升级

1. 阅读发行说明和迁移 SQL；
2. 备份 MySQL，并确认 Redis 和制品存储状态；
3. 推送新版本镜像，更新自己的 values；
4. 使用 `helm diff upgrade`（若安装了插件）或 `helm template` 审查差异；
5. 执行原子升级：

```bash
helm upgrade kaiwu deploy/helm/kaiwu \
  --namespace kaiwu \
  -f kaiwu-production.yaml \
  --atomic \
  --wait \
  --timeout 15m
```

升级必须复用原来的 `kaiwu-runtime` Secret：

- 改变 AES 配置加密密钥会导致已有敏感配置无法解密；
- 改变 RSA 密钥会让现有会话或服务上下文失效；
- 改变数据库、Redis 密码需要同步修改外部服务；
- bootstrap admin 密码只在空库首次初始化时生效。

## 8. 回滚

查看历史并回滚应用：

```bash
helm history kaiwu -n kaiwu
helm rollback kaiwu <revision> -n kaiwu --wait --timeout 15m
```

Flyway 迁移是前向迁移，Helm 不会自动回滚数据库。只有旧应用与新结构兼容时才能直接回滚。
发生不兼容迁移时，应使用事先演练的数据库恢复方案或追加修复迁移，不能删除
`flyway_schema_history` 或手工篡改版本。

## 9. 卸载

```bash
helm uninstall kaiwu -n kaiwu
```

Helm 卸载不应被当作数据清理命令。PVC、外部 MySQL、Redis、Secret 和备份需按环境的数据保留
策略单独处理。删除它们可能永久丢失数据。
