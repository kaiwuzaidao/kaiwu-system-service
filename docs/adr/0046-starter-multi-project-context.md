# ADR 0046：能力应用的多项目 Context 校验

- 状态：Accepted（2026-11-04，与 ADR 0045、Workflow D09 联合复审通过）
- 日期：2026-11-04
- 配套决策：Workflow D09「默认共用、可选独占的多项目部署」（Workflow 仓 `docs/adr/D09-shared-tenancy.md`）（T0-a）

## 背景

同一个能力应用实例可以承接多个业务项目的显式 Gateway 路由。每条路由仍绑定自己的项目和 audience。Starter 现有的固定项目编码和 audience 配置适用于单项目实例。共用实例需要为每次请求校验目标项目是否已在本实例启用，以及该项目对应的 audience。

## 1. 模式与启动校验

补充 [ADR 0003](0003-gateway-centric-authentication.md)「目标服务最终授权」第 3 项。Starter 新增 `kaiwu.starter.tenancy=multi-project`。未配置时沿用单项目模式，包括现有配置、固定 audience、项目绑定和错误语义。Workflow 独占实例继续使用 Starter 单项目模式。System 的 PLATFORM 校验沿用 ADR 0003。

多项目模式只允许平台安装的能力应用启用。System 在 `install` 或 `enable --dedicated` 时分配唯一 `deploymentId`，将其写入部署配置及签名证明。部署身份是平台分配给该应用部署的标识，部署下的副本共用该身份。Starter 从受控部署配置获取本地部署身份和发行摘要，启动时离线验签并比对。

- 证明采用 JWS compact，受保护头为 `typ=kaiwu-app-deployment+jwt`、`alg=RS256`、`kid`。签名密钥和公钥分发沿用 ADR 0045 的应用生命周期专用体系。Gateway Context 密钥独立。
- 签名载荷必含 `iss=kaiwu-system`、`appCode`、`appProjectId`、`deploymentId`、`tenancy`、`releaseDigest`、`iat`。其中 `appCode` 是平台 `app_code` 标记在证明中的唯一来源。Starter 启动时无需查 System。
- `tenancy` 必须授权当前模式。 `releaseDigest` 为目录中应用发行整包的 SHA-256，须与实际运行发行物对应的受控部署摘要一致。缺失证明、未知 `kid`、验签失败、部署或发行摘要错配、Registry 未装配或模式未知均拒绝启动。普通清单、环境开关和请求头无法授予多项目模式。
- 证明无短期过期要求，升级时按新发行摘要重新签发。卸载或吊销部署资格时，应用须使该部署 Registry 对所有项目返回 `DENY`，按第 3 节失效，覆盖仍持有旧证明的副本。

## 2. 请求验证与登记契约

1. 沿用 ADR 0003 对 Gateway Context 的本地验证，包括大小限制、RS256、`typ`、issuer、必需声明和有效期。仅用验签后的非空 `projectCode` 查询本实例的 `TrustedProjectRegistry`。路径、请求体、查询参数和普通头不能作为查询或授权依据。
2. Registry 是应用提供的 SPI，输入为已验签 Context 的项目编码，输出为该编码的可信登记结果，包含规范 `projectId`、唯一预期 audience、登记 `revision` 和准入枚举 `admission = FULL | DRAIN | READ_ONLY | DENY`。未登记视为 `DENY`，已存在的记录返回其权威 revision。登记按部署隔离。`projectId` 和 audience 只能通过平台生命周期 write 写入启用登记。audience 等于平台为项目登记的路由 audience。同一实例内 `projectCode`、`projectId`、audience 一一对应，任一值重复绑定时拒绝登记。Starter 不内置登记存储，也不向 System 发起逐请求授权查询。
3. Context 的 `projectId` 必须与登记完全相等，`aud` 必须是唯一且与登记完全相等的 audience。Context 携带 `serviceCode` 时，必须与应用自身的服务编码一致。缺省时沿用现有路由规则。通过校验且准入为 `FULL`、`DRAIN` 或 `READ_ONLY` 后，Starter 才建立请求级 `StarterContext`，并携带已验证的准入枚举。应用按枚举和当前状态执行操作约束，同时检查权限和资源归属。请求结束后照常清理。
4. 缺失项目声明、未登记、禁止进入、记录不完整、audience 或项目 ID 错配、登记超时或异常均失败关闭，按无效内部 Context 返回 401。没有默认项目、通配 audience、过期缓存兜底或单项目配置回退。错误和日志不得暴露 Context、凭据或登记明细。

此模式针对普通 Gateway PROJECT Context。D06 的 S2S 来源 Context、完整委托元组、用途和发起权限校验继续适用。Agent 等其他用途的 Context 继续执行各自的入口及绑定约束。领域层和仓储显式传递已经验证的项目，后台任务从可信任务归属确定项目。

## 3. 缓存与停用时限

1. Registry 必须直读权威主库的已提交数据，绕过只读副本及应用缓存。登记返回 `revision`。查询超时可配置，默认 500 毫秒。超时、异常或结果已过有效期时拒绝请求。
2. 每个实例使用容量有界的本地缓存，按项目编码隔离。有效期从发起 Registry 读取前的本地单调时钟开始计算，最多 30 秒，命中不续期。「未登记」的否定结果也按同一规则缓存。跨副本通知丢失时，从登记提交开始，停用最迟 30 秒内生效，新启用项目的旧否定结果也最多保留 30 秒。
3. 登记提交后按项目向各副本主动失效或刷新。Starter 在读取前捕获该项目的失效代数，失效时递增代数。返回结果的代数已过时时丢弃结果，既不用于当前授权也不回填缓存。检查代数与回填须与失效操作协调。部署吊销须使本部署已缓存项目失效。

应用仍须在操作边界处理冻结与在途写入之间的竞争。

## 4. 与应用生命周期的衔接

[ADR 0045](0045-app-package-pluggable-installation.md) 定义平台安装、项目启用编排及 System 到应用的独立生命周期通道。只有通过短期断言、应用专用 audience、固定端点和 scope、请求绑定及防重放校验的 `app:lifecycle:write` 调用，才能执行通道内的启用登记、撤销、冻结与解冻。`app:lifecycle:read` 只读。生命周期断言独立于 Gateway 用户 Context，业务请求不得借用生命周期身份。断言的 wire 格式与专用公钥分发由 ADR 0045 的 A0 第二轮修订定稿，System 在 A1 签发，Starter 在 T1 提供 `LifecycleAssertionVerifier` 和 nonce 存储 SPI，T2 及后续应用复用。

| 应用登记状态 | Starter 准入 | 应用与路由 |
| --- | --- | --- |
| `ENABLED` | `FULL` | 正常执行业务权限和领域校验。 |
| `DRAINING` | `DRAIN` | 保留项目路由和在途办理。应用拒绝新发起和新绑定，包括 D06 入站发起。管理端隐藏新建和发起入口。worker 和项目凭据继续用于排空。 |
| `PAUSED` | `READ_ONLY` | 保留项目路由和授权只读查看。应用拒绝写入和在途办理，暂停项目 worker，保留可恢复状态。 |
| `DISABLED` 或未登记 | `DENY` | Starter 拒绝项目 Context。进入 DISABLED 后摘除项目路由并吊销该项目凭据。 |

启用或恢复写入登记，冻结、强制暂停和停用更新登记及其 revision，并触发相应缓存失效。路由摘除和凭据吊销各有独立作用。已签发 Context 仍须通过目标实例的登记准入。Workflow 的具体入口、worker 和状态转换以 D09 为准。

## 5. 与现有决策的关系

| 决策 | 衔接 |
| --- | --- |
| [ADR 0003](0003-gateway-centric-authentication.md) | 为显式启用多项目模式的能力应用补充目标项目绑定。Gateway 仍是 Context 签发方，Starter 本地验签，目标服务最终授权。 |
| [ADR 0022](0022-project-entry-authorization-and-addressing.md) | Gateway 继续按路由项目校验入口、成员和权限快照。同一上游可接多条显式项目路由，每条保持自己的项目和 audience。 |
| [ADR 0025](0025-first-project-deployment-handoff.md) | 项目路由沿用显式目录及既有配置和发布流程，Registry 只处理目标服务准入。 |
| [ADR 0036](0036-platform-manifest-sync.md) | 普通资源同步仍按目标项目鉴权。应用生命周期专用授权沿用 0045，资源清单不能授予部署资格或写入启用登记。 |
| [ADR 0042](0042-project-config-handover.md) | 配置移交继续执行原授权及确认规则。移交包不能授予多项目模式或替代生命周期授权。 |
| ADR 0045 | 平台声明能力应用并编排项目启停，0046 定义 Starter 的部署校验和 Registry 准入。 |
| Workflow D01 / D09 | D09 部分取代 D01 第 1、5 条的部署限制。审批事实、审计、outbox 和项目资源隔离由 Workflow 负责。D09 的共用实例提供 Registry，独占实例沿用单项目绑定。 |
| Workflow D03 / D04 | 服务凭据保持项目和 scope 绑定。成员查询按目标项目授权，用户 Context 和 Registry 准入不能替代服务凭据。 |
| Workflow D05 | 待办投影继续使用任务所属项目的凭据、归属和版本协议，排空期间按 D09 继续处理在途工作。 |
| Workflow D06 | 发起、回调及受限委托继续执行自身的签名、项目、用途和权限校验。 |
| Workflow D07 | Flowable 以已验证的业务项目 ID 确定租户。内部 ID 不参与 Starter 准入或 API 资源授权。 |

## 6. 实施验收

- T1 覆盖单项目兼容回归、多项目合法请求、缺失与未登记项目、项目 ID 错配、audience 错配或多值、serviceCode 错配、无效令牌、禁止状态、查询超时或异常，以及业务项目误开、同一证明复制到另一部署、发行摘要不匹配。
- T1 覆盖 T6 的主动失效、跨副本通知丢失后的 30 秒上限，以及并发旧查询不能用于授权或回填缓存。另须覆盖未登记否定缓存的主动失效与 30 秒上限。T2 在真实应用登记及生命周期路径上拒绝重复绑定并复验 T6，覆盖排空保留同一路由且仍可办理、拒绝新发起与新绑定、暂停仍可授权只读、停用和恢复，并落实 D09 的其余威胁测试。
- D09 与本 ADR 一起通过 Claude 评审后才开工 T1、T2。本 ADR 记录设计契约，运行行为以实施和验收为准。
