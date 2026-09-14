# ADR 0025：首个业务项目的部署交接与同源入口

- 状态：Accepted
- 日期：2026-08-14
- 决策范围：生成项目模板、Gateway 显式路由、平台项目入口、单机与 Kubernetes 示例
- 补充：ADR 0002 的多仓边界、ADR 0003 的鉴权边界、ADR 0022 的项目入口、ADR 0023 的部署仓边界

## 背景

项目工厂已经能交付两个独立源码仓、Dockerfile 和本地开发脚本，但首次使用链路仍有三个断点：

1. 生成仓没有单机或 Kubernetes 的可执行部署骨架，使用者需要从 Dockerfile 反推网络、密钥、
   Service 和 Ingress；
2. 部署环境没有读取逐条显式业务路由的标准入口，项目管理生成的 route 片段仍需人工改写
   Gateway 配置；
3. 生成前端只接受同源 opener/parent 的令牌桥接，平台首页却在当前窗口跳转，项目管理页又用
   `noreferrer` 打开，导致设计存在但真实入口无法完成握手。

这不是增加发布中心或共享部署模式的理由。需要补的是一次生成后的可交付起点，以及平台到
业务项目的安全接入缝隙。

## 决策

### 1. 部署骨架随业务仓交付，后续归业务团队维护

生成后端仓提供单机 Compose、Kubernetes Deployment/Service/Kustomize 和 Gateway route；
生成前端仓提供单机 Compose、宿主机 Nginx location、Kubernetes Deployment/Service/Ingress。

这些文件与源码一样只由项目工厂生成一次。平台不保存业务环境状态、不执行部署，也不在
SUCCESS 后回写；镜像地址、Secret、namespace、副本数和资源额度进入各项目自己的部署评审。

### 2. Gateway 只增加受管的“显式路由目录”

部署者可通过 `kaiwu.gateway.managed-routes-dir` 挂载逐条审查的业务路由。它不是服务发现：
discovery locator 继续关闭，注册中心里的服务不会自动成为外部入口。

受管目录采用失败关闭：目录不存在、YAML 损坏、路由 id 重复、缺少 predicate，或缺少
`accessMode=PROJECT`、`audience`、`projectCode`，Gateway 都拒绝启动。本地开发目录仍保持
单文件错误只跳过该文件的行为，避免一个草稿阻断所有项目联调。

### 3. 业务静态入口留在边缘层，API 仍只进 Gateway

同一平台域名下，边缘 Nginx/Ingress 按路径分流：

- `/apps/{projectCode}/` → 对应业务前端；
- `/{projectCode}-api/` → Kaiwu Gateway；
- 其它路径 → Kaiwu 平台前端。

Gateway 不承担业务静态文件托管，业务 API 也不得从边缘层直连业务后端。这样令牌、项目入口
授权、Context 签发和最终本地授权仍经过 ADR 0003 定义的完整链路。

### 4. 同源入口保留 opener，跨源入口显式隔离

平台打开同源业务入口时使用新窗口并保留 opener，使生成前端可以用同源、随机 nonce 约束的
`postMessage` 协议取得内存 Access Token。令牌不进入 URL、Cookie、localStorage 或
sessionStorage。

若项目登记的是跨源 URL，平台用 `noopener,noreferrer` 打开且不提供令牌桥接。跨源单点登录
需要独立 ADR 和协议，不能通过放宽 origin 校验临时实现。

### 5. 两种部署方式共享安全与寻址契约

单机 Compose 默认通过显式共享网络解析业务服务；Kubernetes 默认通过 Service DNS 解析。
两者的 route 形状、PROJECT 元数据、Context 公钥和 audience 完全一致。需要 Nacos 等注册中心
时仍遵循 ADR 0024，以 `lb://` 表达解析责任，不能新增部署模式分支。

## 后果

- 第一次生成后不再需要从零手写 Compose、K8s、Ingress 和 Gateway 接入文件；使用者仍必须
  审查并填入自己环境的镜像、Secret、域名和资源配置。
- Gateway route 变更需要部署配置变更和 Gateway rollout；当前不做热更新，也不由平台写 Nacos。
- 同源是平台向生成前端派发内存令牌的明确前提；跨源入口可打开，但不会自动登录。
- 既有 SUCCESS 项目不会被平台回写，需要业务团队按新模板文件自行择需迁移。

## 不做什么

- 不新增发布中心、共享业务部署、自动 Nacos 写入、服务发现自动路由或任意命令执行。
- 不把业务项目 manifests 收进平台 chart；业务项目继续拥有独立 GitOps 路径。
- 不在示例中保存真实密码、token、私钥或证书。
- 不承诺示例就是生产最终配置；高可用、备份、证书、监控和容量由目标环境部署仓负责。
