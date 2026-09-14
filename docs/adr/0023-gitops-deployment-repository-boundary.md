# ADR 0023：GitOps 部署仓边界

> 2026-08-14 补充：业务项目进入同一部署仓后的目录、namespace、所有权与 Gateway 路由边界
> 由 ADR 0026 细化；本 ADR 关于 chart、环境值、不可变镜像和 Secret 的决策继续有效。

- 状态：Accepted
- 日期：2026-08-13
- 决策范围：Kaiwu 四仓的 Kubernetes 交付路径、`kaiwu-deploy` 仓
- 补充：ADR 0002 的多仓边界、ADR 0020 §3 的分支策略

## 背景

`docs/KUBERNETES.md` 与 `deploy/helm/kaiwu` 已经描述了如何把 Kaiwu 装进 Kubernetes，
但只覆盖到"操作者在本机执行 `helm upgrade`"。真正持续运行一个环境还缺三类声明：

- 各环境的 values（镜像版本、副本、外部 MySQL/Redis 地址、Ingress）；
- ArgoCD 的 `Application` 与 `AppProject`；
- 运行密钥 `kaiwu-runtime` 从哪里来。

这三类声明必须放在某个 Git 仓库里才能被 ArgoCD 消费。放哪里不是组织偏好问题：它决定了
chart 版本能否保持不可变，也决定了迁移 SQL 的一致性门禁是否继续有效。

## 决策

### 1. chart 留在 `kaiwu-system-service`

Helm chart 继续位于 `kaiwu-system-service/deploy/helm/kaiwu`，不单独成仓。

理由是 chart 的 `files/migrations/` 必须与 `sql/increment/` 逐字一致，该一致性由本仓
`.gitlab-ci.yml` 的 `verify:sql` 校验。chart 一旦拆出去，这条门禁就跨了仓库边界而失效，
迁移副本会静默漂移——而漂移的后果是 initContainer 执行了与源码不同的 SQL。

### 2. 环境值与 ArgoCD 声明放独立的 `kaiwu-deploy` 仓

新增第五个独立仓 `kaiwu-deploy`，承载 `envs/<env>/values.yaml`、`apps/`、`projects/`。

决定性理由是**不可变性**，不是权限分离。若把环境值并入应用仓，改一行副本数就需要打一个
新 tag，实践中这会迫使 `Application.targetRevision` 指向可变分支；而分支是会动的，
ArgoCD 会在无人察觉时同步一个不同的 chart。分成两个仓后，chart 版本按不可变 tag 演进、
环境值按 `main` 演进，各自的节奏不再互相绑架。

ArgoCD 以 multi-source 消费：chart source 指向应用仓的 tag，`ref: values` source 指向
本仓 `main`，用 `$values/envs/<env>/values.yaml` 引用。

权限分离是这个划分的附带收益，当前不构成理由——平台尚无独立运维角色。

### 3. 镜像只在 tag 上产出，并固定到 digest

三个应用仓的 CI 各有 `package` 阶段，仅在 tag 触发，不推 `latest`。生产 values 使用
`images.<component>.digest` 固定到不可变摘要。tag pipeline 必须运行全部 verify 与
security 门禁：tag 可以打在任意 commit 上，不能假设它指向已验证过的提交。

`kaiwu-system-service` 的镜像构建上下文是工作区根（同时需要 starter 与 service 源码），
因此四仓必须打同一个 tag；CI 取 starter 的同名 tag，缺失即失败，防止镜像混入未验证的 SDK。

### 4. 运行密钥永不进 Git

`kaiwu-runtime` 的 11 个键不以任何形式提交到任一仓库，包括加密前的 values 与渲染产物。
chart 只通过 `runtimeSecret.existingSecret` 引用已存在的 Secret，自身不创建 Secret；
`AppProject` 把 `Secret` 列入 `namespaceResourceBlacklist`，即使有人误提交明文，
ArgoCD 也不会将其同步进集群。

密钥来源按环境能力选择，且只影响 `kaiwu-deploy`，chart 侧无需改动：接入密钥系统时增加
`ExternalSecret` 或 `SealedSecret` 声明；尚未接入时由操作者用
`scripts/kaiwu-k8s-secret.sh` 手工创建，并承担密钥不被追踪、重建环境需重做的代价。

### 5. 工作区从四仓变为五仓

工作区根仍不得创建 `.git`。`kaiwu-deploy` 与其余四仓一样独立版本化，默认分支 `main`，
按 ADR 0020 §3 不绑定特定开发分支名。

## 后果

- 环境值变更不再触发应用仓的全量 CI，也不再需要为改配置打版本 tag。
- 一次升级需要动两个仓：应用仓打 tag，`kaiwu-deploy` 回填 digest 与 `targetRevision`。
  digest 目前由人工从 CI 日志回填，是已知的手工环节。
- 本地渲染审查需要同时具备两个仓的工作副本，`scripts/render.sh` 用 `CHART_DIR`
  指向 sibling 目录处理这一点。
- 迁移 SQL 的一致性门禁保持在单仓内，未被削弱。
- 若将来 chart 需要被 Kaiwu 之外的项目复用，应重新评估第 1 条：届时把 chart 打包为 OCI
  制品推送到 Harbor，比拆仓更能同时满足复用与门禁。

## 不做什么

- 不引入 ApplicationSet 或环境模板生成器。两个环境用两份显式声明更易读，出现第三、第四个
  环境且确实重复时再抽象。
- 不把 Nacos 纳入 Kubernetes 启动路径。chart 当前直接注入配置，`docs/KUBERNETES.md`
  已声明 Nacos 不是 Kubernetes 部署的前置条件；接入统一 Nacos 治理需要先评审配置边界，
  属于另一个决策。
- 不建立共享部署模式。每个业务项目仍独立生成、独立部署、独立数据库与 GitOps 路径。
