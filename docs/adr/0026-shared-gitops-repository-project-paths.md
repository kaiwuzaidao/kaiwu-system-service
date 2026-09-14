# ADR 0026：单一部署仓中的项目 GitOps 路径

> 2026-08-14 补充：ADR 0027 新增的 `kaiwu` 只是开源分发入口，不承载 GitOps 配置；
> 本 ADR 的 `kaiwu-deploy` 边界保持不变。

- 状态：Accepted
- 日期：2026-08-14
- 决策范围：`kaiwu-deploy`、生成项目 Kubernetes 交付、Gateway 受管路由
- 补充：ADR 0002、ADR 0006、ADR 0023、ADR 0025

## 背景

ADR 0023 已决定用独立的 `kaiwu-deploy` 保存 Kaiwu 平台环境值和 ArgoCD 声明；ADR 0025
要求每个业务项目拥有独立 GitOps 路径。仍未固定的是多个业务项目进入同一组织后如何管理配置。

两个极端都不合适：

1. 把所有平台和项目配置平铺在仓库根目录，会让所有权、环境、应用和路由混在一起，项目数量
   增长后难以评审和归档；
2. 为每个业务项目强制创建第三个 Git 仓库，会把一次项目交付从两个源码仓扩成三个仓，增加
   权限、Webhook、分支保护和日常同步成本，也改变 ADR 0006 的双仓一次性交付边界。

需要的是物理仓库数量与项目隔离之间的中间层：配置集中版本化，但每个项目保持独立目录、
ArgoCD Application、namespace、Secret 和审查范围。

## 决策

### 1. 继续使用一个 `kaiwu-deploy`，不强制每项目配置仓

`kaiwu-deploy` 采用以下顶层边界：

```text
kaiwu-deploy/
├── platform/                         # Kaiwu 平台自身
│   ├── apps/
│   ├── envs/
│   └── argocd/
├── projects/                         # projects/<projectCode>/...
├── gateway-routes/                   # 平台审核的 PROJECT 外部入口
└── scripts/
```

业务项目的硬约束是独立 GitOps **路径**，不是独立 Git **仓库**。只有出现独立组织权限、合规
隔离、外部团队移交或单仓规模成为真实瓶颈时，项目团队才把自己的目录迁成独立部署仓。

### 2. 每个业务项目独立 Application 与 namespace

项目路径固定为 `projects/<projectCode>/`，项目编码沿用平台不可变 `projectCode`。每个环境拥有
独立 ArgoCD Application，并部署到 `kaiwu-<projectCode>-<env>` namespace。

项目 Application 只允许引用登记的前端、后端源码仓和本部署仓路径；镜像使用不可变 tag 或
digest。基础 Deployment、Service、Ingress 和 Kustomize 文件仍随生成源码仓交付，部署仓只保存
环境选择、版本、镜像、域名、资源与补丁，不复制业务源码。

真实 `CODEOWNERS` 主体由采用组织配置：业务目录由项目团队负责，平台运维可作为必需审核方。
Kaiwu 示例不能猜测组织的 GitLab 用户或 Group，因此仓库提供可复制的 CODEOWNERS 模板和结构
校验，不提交一个看似生效但主体不存在的规则。

### 3. 业务项目 Secret 按 namespace 隔离且永不明文入 Git

每个项目环境引用自己的 runtime Secret。数据库密码、Gateway Context 公钥、证书和 Token 不得
写入 values、Application、Kustomize patch、日志或渲染产物。接入 External Secrets 或 Sealed
Secrets 时，只允许提交引用声明或可安全入 Git 的密文制品。

### 4. Gateway PROJECT 路由仍由平台路径统一审核

业务项目可以维护自己的副本数、镜像和数据库地址，但不能自行决定是否成为外部入口。
`gateway-routes/<env>/routes/<projectCode>.yaml` 由平台审核，逐条声明 Path、目标 Service DNS、
`accessMode=PROJECT`、`audience` 与 `projectCode`。

平台 Helm Chart 支持引用部署仓生成的外部 ConfigMap；内联 `gateway.managedRoutes` 继续用于
简单部署，但两种来源互斥。Gateway 仍失败关闭，且不启用 discovery locator。

### 5. 跨 namespace 前端通过本地 Gateway 别名接入

Kubernetes Ingress 的 Service backend 只能引用同 namespace Service。生成前端因此增加一个
`ExternalName` Gateway 别名 Service，Ingress 的业务 API 路径指向该本地别名；环境配置将别名
目标设为平台 Gateway 的完整集群 DNS。

业务 API 仍只进入 Kaiwu Gateway，不能由业务 Ingress 直连业务后端。该别名只解决 Kubernetes
namespace 寻址，不改变 ADR 0003 的认证和授权链路。

### 6. 项目工厂仍只生成两个源码仓

项目工厂继续只生成 BACKEND 与 FRONTEND 两个制品，只向两个空源码仓执行一次初始推送。
它可以生成部署骨架和部署仓接入说明，但不获得 `kaiwu-deploy` 写权限，也不在 SUCCESS 后创建、
修改或补偿任何 GitOps 配置。

项目接入由部署仓脚本建立受审查的初始目录，之后完全归业务团队与平台运维的 Git 流程维护。

## 后果

- 平台和多个业务项目可以从同一个部署仓获得统一视角，又不会平铺混杂。
- 项目不会因为环境配置而被强制增加第三个 Git 仓库。
- 新项目上线需要一个业务目录变更和一个平台 Gateway 路由变更，可以在同一 MR 中共同评审。
- 每项目 namespace 增加资源对象和 DNS 长度，但显著缩小误操作与 Secret 的影响范围。
- `kaiwu-deploy` 的 CI 必须按项目路径校验编码、namespace、Application 目标与路由元数据，避免
  目录隔离只停留在命名约定。
- 已有平台配置从根 `apps/`、`envs/`、`projects/` 迁入 `platform/`，ArgoCD Application 的
  multi-source values 路径需要同步更新。

## 不做什么

- 不创建第三个生成制品或第三条项目工厂 GitLab 推送记录。
- 不引入 ApplicationSet、配置生成服务、发布中心或平台自动提交部署仓。
- 不允许一个项目目录管理另一个项目 namespace。
- 不把业务 manifests 收进平台 Helm Chart。
- 不把 Secret 明文、私钥或运行凭据提交到任何 Git 仓库。
