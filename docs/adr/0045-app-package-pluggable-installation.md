# ADR 0045：应用包与可插拔安装

- 状态：**Accepted**（2026-11-04，与 ADR 0046、Workflow D09 联合复审通过）；不是现有运行能力，A1/A3 按本 ADR 实施。
- 日期：2026-11-04；范围：A0，只有 ADR、Schema 与示例。
- 依据：同日《应用包可插拔安装》立项书、开工提示词及 Docker/CLI 修订。
- 评审门：本 ADR 复审通过且共用部署 T0（D09、平台0046）定稿后才可开 A1/A3；每卡独立 MR，目标 dev，仅 Claude 合入。
- 裁决：[设计问题](0045-app-package-pluggable-installation/design-questions.md)。原五条问题按同日裁决关闭方向；联合复审与 A1 测量等交付门仍不得跳过。

## 1. 概念与来源

应用包是一个完整应用项目的版本化交付单元：一个 service、一个 web、平台资源清单、独立数据库迁移、部署文件及接入说明。编码 `code` 是不可变、全局唯一的业务键，不能抢占 system 或已有普通项目；版本为发布 SemVer `MAJOR.MINOR.PATCH`。组件版本可独立构建，但应用发行必须固定两者 digest，不能以 latest 或浮动 tag 作为恢复依据。

清单名为 `kaiwu-app.yml`，应用后端仓根目录是源；平台发行版中的内置目录是安装时唯一来源。平台代码不按应用编码分支，也不承载审批或文档领域逻辑。能力应用默认共用、可选独占；业务项目仍拥有自己的业务数据库，不能直接访问能力应用库。

清单结构见 [JSON Schema](0045-app-package-pluggable-installation/kaiwu-app.schema.json) 与 [完整示例](0045-app-package-pluggable-installation/kaiwu-app.example.json)。JSON 示例是 YAML 的等价数据模型，域名、digest 与平台版本均为占位，不是可安装发布物。解析器先拒绝重复键、任意 YAML tag、alias/merge 扩张及超限输入，再按 JSON Schema 2020-12 校验；schema 不执行命令。

| 字段 | 语义与额外校验 |
| --- | --- |
| formatVersion | 固定 1；不认识的格式和字段拒绝，不能忽略后继续安装 |
| code/name/version | 编码 2–64 位，首位小写字母，其余为小写字母、数字或连字符（`[a-z][a-z0-9-]{1,63}`）；名称为语言映射，必含 zh-CN；版本必须来自目录 |
| platform | v1 范围语法固定 `>=x.y.z <a.b.c`，下界包含、上界不含；要求下界小于上界；禁止预发布、隐式跨主版本与降级 |
| requires | 平台能力码集合，如 todo；逐项检查当前平台实际提供且启用的能力，未知/缺失拒绝；不是应用依赖解析器 |
| components | 恰一个平台级 service 与一个平台级 web；image 固定 sha256，memory 正整数 Mi/Gi；安装启动这套共用组件 |
| tenancy | supported 声明 shared/dedicated，默认shared；能力应用专用，不改变普通业务服务默认单项目模式 |
| dedicatedTemplate | 可选独占service模板，支持dedicated时必填；不在install执行，enable --dedicated才按项目实例化；schema字段为命名基准，CLI按应用码+权威业务项目码派生独立Compose名/schema并校验碰撞，不直接复用共享schema |
| quotas | 每项目发起速率、在途数、文档并发的正整数默认值；必须随发行负载测量，不允许无上限 |
| service | port 为内部端口，health 为只读健康路径；database 指向独立 schema、migrations=true；route 必须与现有显式路由推导一致 |
| web | entry 必须匹配 `/apps/{code}/`，由边缘层同源转发；不让 Gateway 托管静态资源 |
| deployment.docker | 发行包内规范相对路径：后端 compose、web 子目录内前端 compose、gateway-route；不接受安装者路径 |
| manifests | 引用已有 kaiwu/menus、dicts、roles、configs 以及按需 i18n/jobs/data-scopes；子文件格式仍由现有 parser 决定 |
| integration.docs | 发行包内只读说明；不自动修改业务项目代码或配置 |
| uninstall.blockers | 固定 service 组件内部只读路径；不是任意URL；只接受生命周期read断言 |

路径均须 canonicalize 后仍在该目录包内，禁止符号链接越界、绝对路径、`..`、下载 URL、脚本入口；code/schema/entry/route/Compose 服务与网络实际值须交叉校验。Schema 的形状约束不能代替这些语义检查或来源校验。目录审查必须拒绝 Compose 的 build、privileged、host 网络、宿主目录随意挂载、docker.sock 与任意命令注入，密钥只引用宿主机受保护配置。应用发行物不能要求私有不可得制品。

## 1a. 三类项目、一套体系

| 类别 | 来源与代码归属 | 服务对象与下线方式 |
| --- | --- | --- |
| 平台本体 | 随平台安装，平台维护 | 整个平台；built_in项目不可停用或删除 |
| 能力应用 | 内置目录经app install安装，平台维护版本 | 多个业务项目；可停用/卸载，默认留数据 |
| 业务项目 | project new生成，使用者维护源码 | 自己的业务；项目归档，不进应用目录、不叫卸载 |

三类共用登录/Gateway、项目成员角色权限、菜单字典配置多语言及sync、待办通知、模板外壳、Docker约定。能力应用权限只管理本应用；访问目标业务项目仍必须取得该项目的成员与权限事实，不能拿应用管理员角色代替。事实源同步见ARCHITECTURE §1.1。

### 平台统一跨项目授权契约（仅定义）

新增只读 `GET /api/current/target-projects?appCode={code}` 返回当前有效用户可选的业务项目（字符串id/code/name、启用状态），有界分页；只返回用户是有效成员且应用对该项目已启用的业务项目，不含system/能力应用项目，不接受userId。`GET /api/current/target-projects/{projectCode}/access?appCode={code}`返回该项目权威projectId、projectCode、permissions、roleCodes、应用启用状态与观测时间。服务端从已验证身份和本地项目事实计算；路径是查询目标，不是授权依据，非成员/不允许目标返回403，未认证401、依赖不可判定503。返回最小权限事实，不含凭据。

前端共用 `useTargetProjects(appCode)` 与 `useTargetProjectAccess(appCode, projectCode)`；只存内存、随用户/目标/会话失效，加载/拒绝/失败不展示授权按钮，不缓存为永久许可。Hook不替代目标服务权限校验；所有目标业务API仍走绑定项目/audience的Gateway Context。A1实现平台接口，A3将能力应用门户改用统一hook；本卡不创建运行代码或公共包。

## 2. 内置目录、兼容与内存

拟随 System 同名发行 tag 发布 `distribution/apps/catalog.json` 和 `distribution/apps/{code}/{version}/`，目录索引包含 formatVersion=1、平台 release、每条 code/version、manifest 相对路径与 SHA256、整个应用文件集 SHA256。平台镜像带只读相同目录，CLI 使用同发行 tag 的目录副本；双方必须逐字比对 release 与 digest。SHA256 证明完整性，来源信任来自经审核的发行物，不能把哈希称作签名。CLI 只接受 code，不能传本地 manifest、远端地址或镜像覆盖。

目录包包含 manifest、引用的 kaiwu 文件、docs、双 Compose 与 gateway-route；前端原仓的 `deploy/server/compose.yml` 在发行包映射到 `web/deploy/server/compose.yml`，不是合并双仓。平台升级原子替换整个目录，已安装记录仍固定原版本、文件集 digest 与恢复所需副本，升级目录不触发应用自动升级；历史文件消失时拒绝继续旧操作，要求恢复可信同版发行物。不得静默切到新版本。

安装与 upgrade 均先校验 platform 范围、requires、编码/路由/schema 冲突、发行来源和整包 digest；升级只允许目录内较高 SemVer，数据库向前兼容与回滚说明必须通过目录上架检查。不支持自动 downgrade，也不保证迁移后能退旧镜像。

CLI 读取 Docker VM 的 MemTotal，按二进制换算 memory。最低需求为 **平台发行版声明的基础预算 + 所有仍占用资源的已装应用组件预算 + 目标新增/升级峰值差额**，按 code 去重；DISABLED 与容器仍在的 FAILED 都计入，UNINSTALLED_RETAINED 仅保留数据不计运行组件，迁移临时峰值计入发布预算。升级重叠运行时计入两版本同时占用部分。unknown/0/不可读容量拒绝，容量低于合计拒绝；保留现有 project-up 的低于 4GiB 拒绝及 4–6GiB 告警规则。保留现有 KAIWU_SKIP_MEMORY_CHECK；显式跳过时必须打印不足/未知容量警告，并把操作者、预算、观测与跳过原因写入审计，不能伪装容量充足。平台基础预算采用下文保守估算档位，A1必须补Docker实测并写入发行物。共享启用只登记、不增加组件预算；每个独占启用增加独占模板预算与独立数据库开销。

### 暂定保守容量档位（DQ-04，估算）

适用单机Docker、MySQL、基础平台与一个能力应用；不含AI模型/其他业务服务，后者另累加。平台+MySQL暂定6GiB；共用能力应用增2GiB（合计8GiB）；每独占业务实例再增3GiB。预算来自发行物数据，不硬编码CLI；这是保守容量估算，不是已验证最低运行要求。

2026-11-04只读test观测：System request512Mi/limit2Gi，Gateway256Mi/1Gi，Web64Mi/256Mi；PID1 RSS分别416048/293176/3676KiB。能力service512Mi/1536Mi、管理Web128Mi/256Mi，RSS314452/6304KiB。kubectl top工作集分别391/273/5/303/4Mi，不与RSS混称。瞬时低负载样本不是峰值。平台三个limit合计3.25GiB，6GiB档额外2.75GiB为未实测MySQL/Redis/迁移/首启/系统余量；能力两组件limit1.75GiB向上取2GiB；独占service1.5GiB加1.5GiB独立数据库/迁移余量取3GiB。数据库与余量是显式估算，不冒充test中MySQL Pod读数。

A1必须提供Docker测量脚本：在平台+MySQL+共用应用上采样各容器/VM峰值，包含迁移、首次启动、健康检查及代表负载；测独占增量/升级重叠，记录镜像digest、Docker容量、采样周期/持续时间/数据与退出状态。每次发行执行，将峰值+有依据余量写发行说明和只读预算字段；未通过前这些档位不作为容量已验收证据。共享登记不新增实例预算；独占才增加service/DB，不重复算管理Web。

## 3. 职责、交接与幂等恢复

CLI 在宿主机使用既有 login 会话，经 Gateway 调平台管理 API；每次操作都重新校验有效平台管理员，不以 CLI 持有文件代替授权。平台 API 只允许平台管理员，生命周期操作还必须显式持有 platform:app:manage；它只授权内置目录到本应用项目的生命周期同步，普通project sync和业务项目授权不变。

| CLI（宿主机） | 平台后端 |
| --- | --- |
| 内存检查、拉取发布镜像、Compose 起停、应用迁移容器、网络接入、只读健康检查、备份与经确认的数据删除 | 校验目录与能力、应用登记和项目标记、状态与步骤日志、项目同步、生成/审核路由登记、卸载阻塞检查与审计 |
| 复用 project-up/project-down 的编排机制、独立 Compose 项目名与保留数据规则，不调用带 --build 的旧命令整体来代替新流程 | 不执行 Docker/K8s API，不持有 docker.sock，不直读应用库，不执行应用迁移 SQL |
| 落地平台返回的经审核路由/边缘片段，执行 reload-routes 及边缘 reload，回报配置 digest 和验证结果 | 给出 desired 配置与期望 digest，只有 CLI 返回并验证相符后才推进 applied 状态 |

状态交接拟采用持久 operationId、code、command、from/toVersion、release/manifestDigest、expectedRevision、step、attempt。平台以 code 单飞锁/租约和 revision CAS 拒绝并发命令；每步先领取、再由执行方执行、最后提交同 operationId/step 的回执。相同命令和固定输入返回未完成操作；不同版本/命令冲突返回 409。新操作者续跑须仍为平台管理员，审计区分发起人与恢复人。租约到期不能证明外部动作没发生。

CLI 原子保存非秘密检查点，平台步骤台账为权威，不能只靠本地文件。执行完但响应丢失时先查远端台账和 Docker labels/config digest/迁移 history 再判定；匹配则补回执，不重复破坏动作。文件丢失也可按平台操作与可信发行物重建。未知容器、digest 漂移、外部动作无法证明时停在 FAILED，列出人工核对建议，不删除现存资源或冒报成功。平台重启依靠持久台账恢复；CLI 崩溃保持入口关闭，重跑同命令继续，不能长期伪装 RUNNING。

每次状态转移及步骤领取/成功/失败/恢复均写审计：可信 actor、operationId、code/projectId、版本和 digest、旧/新状态、步骤、attempt、时间、revision、脱敏原因和结果。平台数据变更与成功审计同事务；失败审计独立事务。Docker 回执是 CLI 的观测证据，不宣称数据库与 Docker 跨进程原子提交。不记录 token、密码、Context、完整环境、数据库连接串或业务备份内容。

## 4. 生命周期与逐步恢复

NOT_INSTALLED 是从未登记的目录条目；UNINSTALLED_RETAINED 是已经卸载并留有恢复记录与数据的条目。FAILED 必含 command、失败步骤、lastStableState、已成功步骤和资源清单，不得丢失阶段。安装未通过健康检查前不发布可用入口；终态提交必须同时满足表中回执。

| 转移/前置条件 | 逐步副作用与完成条件 | 失败后的同命令恢复与审计 |
| --- | --- | --- |
| NOT_INSTALLED 或 UNINSTALLED_RETAINED → INSTALLING；目录兼容、无冲突、管理员、容量通过 | 1 固定输入/占有操作；2 拉 digest 镜像；3 无外部入口启动组件并由应用执行独立 schema 迁移；4 登记应用项目、plan/apply 同步；5 内部健康检查；6 审核路由/入口并由 CLI reload；7 外部健康与鉴权核验 | 每步独立回执；失败进 FAILED，不开放入口。重跑 install 校验已拉镜像/组件/迁移版本、同步摘要与路由 digest，只续未确认步骤。重装复用原 projectId 与数据，不能重新分配身份 |
| INSTALLING → RUNNING；全部回执及最终健康通过 | 提交 installedVersion 和 applied 配置版本，入口可见 | 最后回执丢失查 operationId，不重复建项目/迁移/授权；审计 INSTALL_COMPLETE |
| RUNNING → INSTALLING → RUNNING；upgrade 兼容及容量通过 | 冻结目标版本、备份恢复依据、关闭入口、拉取新镜像、应用受控迁移、合并清单、恢复路由和健康检查 | 重跑 upgrade 续原版本；迁移不明确时禁止自动回旧镜像或删库；审计每个 upgrade 步骤、旧新版本 |
| RUNNING → DISABLED；管理员且无其他操作 | 关闭平台可见入口/菜单投影与项目访问，摘受管路由及边缘入口并 reload；容器可以保持运行；不删除资源数据 | 部分失败进 FAILED，继续 disable；入口关闭条件未被证明前不报 DISABLED。失效用户会话/权限缓存按既有机制收敛并验证；审计 DISABLE |
| DISABLED → RUNNING；依赖/镜像/迁移与健康可核对 | 验证保留组件，按需启动、还原已审核路由/入口并 reload，健康通过后开放 | enable 同步回执，失败保留关闭态，不偷偷升级；审计 ENABLE |
| RUNNING 或 DISABLED → UNINSTALLING；进入prepare并冻结新启用/发起，complete前完整阻塞必须为零 | 按4a先排空并允许在途办理，零阻塞后complete才摘路由/reload、停用投影、停止双Compose（不带-v） | 查询失败/不完整/有阻塞，记录拒绝，不停容器、不强制终止实例；同命令复查和续停组件；审计检查结果与 UNINSTALL 各步骤 |
| UNINSTALLING → UNINSTALLED_RETAINED；路由/入口已摘、容器停止可证明 | 隐藏入口及菜单，保留项目身份、菜单角色授权、schema、volume、对象数据、版本与台账 | 停机成功回执丢失检查容器不存在和路由 digest 后补回执；审计 UNINSTALL_COMPLETE 与 retained 清单 |
| 任一执行步骤 → FAILED；已失败或效果未知 | 关闭入口，保存安全错误码/下一步，不做自动破坏补偿 | FAILED → 原 command 的 INSTALLING/UNINSTALLING 阶段或 disable/enable 的恢复步骤；重新鉴权、固定输入、检查已发生效果；审计 RETRY，不允许任意跨态跳转 |

重复 disable/enable/install/uninstall 已达相同目标时只核对状态并返回现状；不得伪造额外成功状态变更。不存在应用卸载返回无变更，未安装不能 enable/upgrade。其他转移均拒绝并审计；FAILED 期间不同命令必须先人工对账解除，不能覆盖旧操作。项目排空、暂停与应用整体关闭是不同状态，按下节两级状态执行。

## 4a. 安装、项目启用与生命周期通道

每个安装应用有且只有一个app_code应用项目，承载管理门户、菜单、角色和权限；业务项目以启用记录关联，不能复用应用项目ID作为业务身份。平台安装状态沿用上表；另以(appCode, businessProjectId)记录启用状态/模式/版本/实例归属/回执。平台状态与应用登记以operationId和revision对账，不能两个状态各自为准。

- `install`一次启动平台级service/web和共用数据库；共用服务中的业务表按projectId、引擎tenantId隔离，不把业务项目库合并进来。
- `enable <app> --project X`默认shared：只登记该项目路由、启用记录、按项目平台凭据、S2S/回调密钥和交付片段，不起容器。`--dedicated`才按独占模板为X启动独立service/数据库，路由指向该实例；web管理门户仍复用。两模式同一镜像，独占只许一个固定项目。
- `enable <app>`不带project保留平台级DISABLED→RUNNING语义，不能与项目启用混淆。`disable-project <app> --project X`仅影响X；`--force-pause`明确冻结在途和worker，不声称已经排空。

| 项目状态/转移 | 前置与副作用、恢复与审计 |
| --- | --- |
| 未登记或DISABLED→ENABLED | 应用RUNNING、目标业务项目有效、已授权生命周期操作者；校验模式/容量，生成或复用密钥引用、安装独占组件（仅dedicated）、写应用登记、登记项目路由/reload、交付配置，逐步回执后ENABLED。失败记录目标/步骤，重跑同enable只续未完成，不重复签发/分配 |
| ENABLED→DRAINING | write冻结新发起/新绑定，摘新操作人机入口；仍允许在途操作路径和worker执行、按项目平台凭据有效，应用项目保持ACTIVE。read轮询只读阻塞，不能摘掉唯一办理路由而让排空无法完成 |
| DRAINING→DISABLED | 完整检查在途/绑定归零，再撤销项目启用、摘余路由、吊销平台凭据；保留业务分区/文件/密钥历史和台账。独占实例可以停，不能停止共享实例；失败同disable-project续跑 |
| ENABLED/DRAINING→PAUSED | 显式force-pause，拒新操作、暂停该项目worker和在途处理；保留数据和可恢复凭据引用，不能标成无在途或可卸载 |
| DRAINING/PAUSED→ENABLED | abort或恢复命令经重新鉴权，恢复原登记/路由/worker并验证密钥有效；已吊销则先受控重发，再回ENABLED；审计恢复者和原操作，不删除原冻结记录 |

每项均使用既有operationId/CAS、步骤审计与幂等恢复。项目级失败记录为启用操作FAILED（保存lastStableState），不把共享应用整体变成所有项目不可用。ENABLED/DRAINING/PAUSED都阻塞应用卸载完成。shared↔dedicated一期仅按项目导出再导入，禁止在线迁移或改路由后丢历史。

### 平台→应用生命周期通道

System 在完成平台管理员、`platform:app:manage` 和操作台账校验后，为每次内部 HTTP 请求签发断言。System 从平台部署与项目登记取值。应用从受控部署配置读取本地 `appCode` 和 `deploymentId`。System 在 install 或 `enable --dedicated` 时用密码学安全随机源生成部署 ID，同一部署的副本使用同一 ID，共用实例与各独占实例各有自己的 ID。`appCode` 必须匹配 `[a-z][a-z0-9-]{1,63}`，与项目编码规则一致；`deploymentId` 必须匹配 `[a-z0-9][a-z0-9-]{7,63}`。签发端和验证端均校验格式，本地受控部署配置也必须满足这些约束，禁止用含点号等字符的身份拼接 `aud`。

第一期只使用同一宿主机上专用的 Docker 用户自定义网络，System 按 Compose 服务名通过 HTTP 访问应用，不经过宿主机端口或 Gateway，不另做 TLS。除 System 与目标应用服务外，平台其他容器不应加入此网络，具体由 A1 的 Compose 模板落实。**已接受风险：同一网络内的其他容器可以冒充应用的响应。** 现有缓解是卸载阻塞查询失败关闭，写操作以应用的持久操作台账为准。跨主机或 K8s 部署留待后续，届时必须启用 TLS 并校验服务端证书。

请求仅携带平台断言作为调用身份，浏览器不得转发此头。Gateway 对所有业务路由，在剥离路由前缀后判断实际转发目标，拒绝目标为 `/internal/apps/**` 的请求并直接返回 404；同时剥离入站 `X-Kaiwu-Lifecycle` 头。这两项均为 A1 验收项，不能只依赖应用验签。

#### 报文 v1

使用 JWS Compact Serialization，载荷为 UTF-8 JSON，三个段均使用无填充 base64url，签名算法固定为 RS256。受保护头包含 `typ=kaiwu-app-lifecycle+jwt`、`alg=RS256` 和 `kid`。只按本地受信公钥集中的 `kid` 选键。拒绝算法或类型不符、未知或已撤销的 `kid`、重复 JSON 键、额外 JOSE 头及非规范 base64url。部署证明使用同一公钥集，按 ADR 0046 的独立 `typ` 和声明验证。

| 声明 | 类型与校验 |
| --- | --- |
| `iss`、`sub` | 字符串，分别固定为 `kaiwu-system`、`system` |
| `aud` | 单个字符串，精确等于 `kaiwu-app-lifecycle.{appCode}.{deploymentId}`，两段取本地受控配置 |
| `appCode`、`deploymentId` | 字符串，分别匹配 `[a-z][a-z0-9-]{1,63}`、`[a-z0-9][a-z0-9-]{7,63}`，并与本地应用编码、部署 ID 精确相等 |
| `iat`、`exp` | UTC Unix 整秒整数。要求 `0 < exp - iat ≤ 30`、`iat ≤ now + 5`、`now < exp + 5`，其中 `now` 是验证端当前 UTC 整秒 |
| `jti` | 每次签发用密码学安全随机源生成 16 字节，编码为无填充 base64url（22 字符） |
| `scope` | 单个字符串，按端点精确匹配 `app:lifecycle:read` 或 `app:lifecycle:write` |
| `operationId` | 非空字符串，来自平台持久操作台账。同一操作的重试沿用此 ID |
| `projectId` | 项目级端点必填，使用权威项目 ID 的十进制字符串表示（正整数，无前导零）。应用级端点省略 |
| `htm` | 大写 HTTP 方法，与实际请求精确匹配 |
| `htu` | 规范路径及可选查询串，按下文与实际请求目标逐字节匹配 |
| `bsh` | 实际请求体原始字节的 SHA-256 摘要，编码为无填充 base64url（43 字符）。无正文时哈希零字节 |

每个请求只允许一个 `X-Kaiwu-Lifecycle` 头，值为完整 compact JWS，无前缀。应用只在下列方法和路径组合消费该头。其他端点忽略此头，按原业务认证处理。白名单处理器必须通过此断言验证。经框架归一化后才命中的非规范请求目标也必须拒绝。

| 方法 | 路径 | scope | 允许的查询参数 |
| --- | --- | --- | --- |
| GET | `/internal/apps/uninstall-blockers` | `app:lifecycle:read` | 仅 `cursor`、`limit`，规则见下文 |
| GET | `/internal/apps/projects/{projectCode}/enablement` | `app:lifecycle:read` | 无 |
| PUT、DELETE | `/internal/apps/projects/{projectCode}/enablement` | `app:lifecycle:write` | 无 |
| POST | `/internal/apps/projects/{projectCode}/freeze`、`/internal/apps/projects/{projectCode}/unfreeze` | `app:lifecycle:write` | 无 |

`htu` 使用 origin-form（以 `/` 开头，无 scheme、host 或 fragment）。按表中模板将 `{projectCode}` 替换为平台登记的项目编码，格式沿用 `[a-z][a-z0-9-]{1,63}`。路径中拒绝百分号编码、反斜杠、点段、重复斜杠、额外末尾斜杠和分号路径参数。只有卸载阻塞 GET 允许分页查询参数：`cursor` 是非空不透明字符串，解码后最长 256 个字符；`limit` 是 1 到 500 的十进制整数，无前导零。二者均可省略，首页可不带参数。查询以 `?` 引入，每项为 `name=value`，按编码后参数名的 ASCII 升序以 `&` 拼接（同时存在时 `cursor` 在 `limit` 前）。名称和值按 UTF-8 编码，RFC 3986 unreserved 字节直接保留，其余字节以大写 `%HH` 编码，空格编码为 `%20`。拒绝空查询串、重复或未知参数、非法 UTF-8 及非规范编码。无参数时省略 `?`。验证端在路由重写或 URL 解码前取得实际请求目标，验证其已符合上述形式，再与 `htu` 比较。内部转发必须保持该目标，无法获取原始目标时拒绝请求。

发送方先序列化正文，再对同一字节数组哈希并发送。所有白名单端点在哈希前限制原始正文最多 64 KiB（65536 字节），超限返回 413，不进入领域处理；不能仅信任 Content-Length，读取时同样执行上限。带任何 `Content-Encoding` 头的请求直接返回 415，包括 identity。接收方在 JSON 解析前对移除 HTTP 传输分帧后的原始正文哈希，禁止内容压缩或正文改写。应用使用验签后的 `operationId` 和 `projectId`，正文如重复携带这些字段必须完全一致。首次启用时，用已签名的路径项目编码、`projectId` 及写入的路由 audience 建立登记并校验一一对应。已有登记时必须核对路径编码与项目 ID，错配即拒绝。未登记时只允许首次登记、返回未登记的只读查询，或依据台账返回此前已提交的结果。

以下为应用级阻塞查询的解码示例。请求为 `GET /internal/apps/uninstall-blockers`，无正文。实际请求头携带 System 签名后的三个 JWS 段。

```json
{"typ":"kaiwu-app-lifecycle+jwt","alg":"RS256","kid":"lifecycle-v1"}
```

```json
{
  "iss": "kaiwu-system",
  "sub": "system",
  "aud": "kaiwu-app-lifecycle.sample-app.dep-a1b2c3d4",
  "iat": 1793754000,
  "exp": 1793754030,
  "jti": "AAECAwQFBgcICQoLDA0ODw",
  "scope": "app:lifecycle:read",
  "appCode": "sample-app",
  "deploymentId": "dep-a1b2c3d4",
  "operationId": "op-01",
  "htm": "GET",
  "htu": "/internal/apps/uninstall-blockers",
  "bsh": "47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU"
}
```

#### 验证、防重放与重试

Starter T1 提供 `LifecycleAssertionVerifier` 和 nonce 存储 SPI。A1 在 System 实现签发，T2 及后续应用复用 Starter 校验器并提供应用库的 SPI 实现。验签、时效、端点权限和请求绑定校验通过后，在调用领域处理前原子占用 `(iss, deploymentId, jti)`。应用库对此键设唯一约束，同一部署所有副本共用权威存储，单次插入即判定是否首次使用。占用先独立提交，领域事务失败或进程退出都不释放 nonce。至少保留到所有验证副本均已越过 `exp + 5`。按清理时钟计算时，须计入验证副本可能落后的最大时差。重复 nonce、无效凭据或目标错配返回 401，存储不可用或无法确定占用结果返回 503，均不得进入领域处理。

请求超时或结果未知时，System 先对账。需要重发时签发新 `jti`，保持同一 `operationId` 和操作输入。应用按持久操作台账、目标和步骤检查幂等及 revision，已提交步骤返回已有结果，同一步骤输入冲突时拒绝。nonce 防止重放同一断言，操作台账防止重签后重复产生副作用。read 断言不具备写权限，write 断言的可调用范围限于表中写端点。日志只记录操作 ID、部署、`kid`、结果及脱敏拒绝原因。

T1 的互通验收须覆盖签名样例、时间边界、应用/部署身份格式和本地绑定错配、项目错配、方法或 scope 错配、路径或正文被改写、非规范及重复分页参数、正文大小边界、Content-Encoding 拒绝、跨副本重放和 nonce 存储失败。A1 验收须证明所有业务路由在剥离前缀后均拒绝内部生命周期路径并返回 404，同时剥离入站生命周期头；同宿主机网络、Compose 服务名寻址及网络成员范围也须核对。T2 验证同一操作重签重试时的领域幂等。

#### 密钥分发与轮换

每套平台环境使用独立的应用生命周期 RSA 密钥对（至少 2048 位）。私钥只在 System 受保护的签名配置中可用。生命周期断言和 ADR 0046 部署证明共用此密钥体系，Gateway Context、D03 与 D06 各自保有独立凭据。每个 `kid` 永久对应一把公钥，轮换时分配新 ID。

install 和 `enable --dedicated` 时，CLI 通过分发 Context 公钥的同一受控宿主机部署渠道，从可信 System 部署取得生命周期公钥集。CLI 将它与部署身份一同原子写入受管配置，使用独立的生命周期信任配置项。公钥集必须有 1 到 2 个条目，每条含非空且不重复的 `kid` 和 PEM 编码的 SubjectPublicKeyInfo。Starter 从只读部署配置离线加载，启动时校验条目数、kid 以及每条公钥均能解析为至少 2048 位的 RSA 公钥；任一不满足即拒绝启动，并纳入 T1 验收。禁止根据断言提供的地址或密钥建立信任。CLI 核验各副本实际加载的配置版本、公钥 SHA-256 指纹及部署证明签名键，台账记录这些回执。

1. **预分发。** System 生成新键但继续用旧键签发。CLI 先向所有部署副本安装旧、新两把公钥，逐副本核验。更新过程中启动或扩容的副本必须加载当前受控配置。缺回执时保持原签发键。
2. **切换。** 全部目标副本确认双键后，System 将所有签发副本切到新 `kid` 并核对回执。CLI 为仍需启动的部署安装新键重签的部署证明，保持原部署身份和对应发行摘要，并验证所有副本，包括停用后可能恢复的部署配置。短期断言可继续验旧键，等待最后一份旧键断言的 `exp + 5` 在所有验证端过去。若只掌握最后签发时的 System 时钟，按 30 秒寿命、5 秒过期容差和最多 5 秒验证端落后，至少等 40 秒。
3. **撤旧。** 短期断言窗口结束且所有可启动配置均已换证明后，CLI 移除旧公钥，核验各副本加载新配置且拒绝旧 `kid`。System 退出旧签名材料，保留轮换审计。故障恢复从已确认步骤继续。正常轮换仅在旧键仍可信且目标仍接受旧键时允许回切，恢复旧签发后重新计算等待窗口。

怀疑私钥泄露时，立即停用旧键签发，通过同一渠道将旧 `kid` 从受信配置移除，并隔离无法确认更新的副本，直至拒旧得到验证。撤销不等正常重叠窗口。使用新键重签合法部署的证明，证明与新公钥一同落地后恢复服务。离线或停用部署恢复前必须更新配置与证明。部署自身被吊销时，仍按 ADR 0046 将其 Registry 准入收敛为 `DENY`。

应用卸载两阶段：`uninstall --prepare`冻结所有启用项目进入DRAINING并阻止新启用，持续复查；有阻塞只报告并保留prepare，不能停容器。`--complete`仅所有登记DISABLED、绑定/在途均零、冻结仍有效时摘入口、停组件，进入UNINSTALLED_RETAINED；plain uninstall顺序尝试这两阶段，有阻塞停在prepare并给同命令建议。`--abort`通过write解冻并恢复原状态/路由/worker，记录逐项回执；不能把完成后已卸载当成可abort。平台所有启用入口与应用所有新发起/绑定必须共同受冻结revision约束，不能仅靠一次GET零值防竞态。

### 每项目凭据及配置交付

| 凭据 | 归属、存放与用途 |
| --- | --- |
| 平台服务凭据D03 | 绑定应用+业务项目+service+scope（成员查询/受管待办），System只保存hash/签发审计，应用按项目加密保存引用/值；不能查另一项目 |
| D06 S2S入站密钥 | 按项目/调用服务/业务类型白名单，应用加密保存，业务服务通过受保护交付文件取得；仅用于原D06签名发起 |
| 回调密钥/白名单 | 与入站独立，按项目+业务类型定位目标；应用加密保存，接收业务服务保存对应Secret；不能回退默认项目/目标 |
| 应用加密主密钥 | 来自部署Secret，只应用进程可读，不存平台签发记录/响应；轮换须逐项重加密并核验，不能丢旧解密能力 |

应用每项目密钥在应用库加密，主密钥外置；独占模式使用该独占实例的主密钥/库。日志/接口回执不回显明文；CLI经受保护一次性交付通道将配置存本地0600文件，只打印路径与摘要；业务方手动导入Secret，平台不改源码。交付片段固定formatVersion/appCode/projectCode/mode/serviceBaseUrl/入站kid+secretRef/回调kid+secretRef/platformCredentialRef，不含用户Context；secretRef解析到另行受保护的密钥载体，不能将引用当实际已配置证明。

轮换按项目和方向分别执行：生成新kid/凭据、双端安装验证、切新签名/调用、停旧并验证拒绝、保留审计。平台D03凭据按其受控轮换语义执行，不改变旧default凭据；禁用完成后吊销项目凭据，DRAINING阶段保留有效，PAUSED不丢恢复引用。响应丢失先查密钥版本摘要/启用状态，不重新生成覆盖；无法证明交付成功停在失败步骤。

配置片段示例（引用不是密钥）：

```yaml
formatVersion: 1
appCode: sample-app
projectCode: sample-business
mode: shared
serviceBaseUrl: /sample-business-svc/capability/
inbound: { kid: inbound-v1, secretRef: local-secret:sample-business-inbound }
callback: { kid: callback-v1, secretRef: local-secret:sample-business-callback }
platformCredentialRef: app-encrypted:sample-business-platform
```

共享库purge必须按项目分区导出后清除，只作用目标projectId的业务表/引擎tenantId/对象键前缀，验证其他项目计数不变；绝不DROP共享schema或删除整个共享volume。应用整体purge只有所有项目排空且备份完整才可删除应用独占schema/volume；保留审计/备份。文档采用应用自己的存储绑定，键带项目前缀，下载仍验归属。

## 5. 应用项目与清单合并

采用独立 app_code 语义标记（最终 DDL 在 A1 另交审，不在 A0 建列），`built_in=false`；built_in=true 仍只遵守 ADR 0004 的不可停用/归档/删除约束。应用记录与项目 ID 一对一，应用状态不直接塞进普通项目 status。普通项目入口和 API 均拒绝单独停用、归档、删除或改应用归属；所有生命周期变更必须经过应用操作。项目内成员、菜单与角色按原权限正常维护，不能通过成员/角色修改规避生命周期保护。

卸载为隐藏/停用投影而非物理删除全部平台资源。重装复用原 projectId、稳定业务键与人工维护内容；升级复用 ADR 0036/0042 planHash/CAS 与权限检查。字典/配置/菜单默认只增/更新，保留运营当前配置值、人工译文及目标独有条目，不自动删条目或撤销授权。i18n.yml 的显式资源变更按 ADR 0042 计划展示，不冒称一律保留人工文案。

roles.yml 必须展示ACCESS差异并由有权管理员批准计划，追加授权而不移除原授权；不得把角色分配给成员，安装人的project-admin为唯一初始化例外。应用生命周期同步可按批准清单创建角色与其权限，普通project sync仍必须显式 --with-access。生命周期计划展示角色/权限差异，经platform:app:manage批准后仅作用本应用项目；不自动把角色分给其他成员。新菜单授予内置 project-admin 沿用既有规则；data-scopes 的角色范围同样属于授权。DELETE 默认空，升级与重装绝不自动 prune。旧 API 与 project sync 的项目管理员/计划哈希/ACCESS guard全部保持。新增专用生命周期授权路径仅接受内置目录，限本应用项目并逐步审计；首次安装人成为project-admin，持platform:app:manage的其他平台管理员可恢复/重装，无需冒充原项目管理员。这是对0036/0042执行入口的补充，不扩大它们原接口权限。

## 6. 卸载阻塞与数据

拟新增只读 `GET /internal/apps/uninstall-blockers`，仅平台调用身份可用、不发布浏览器路由。响应使用既有 Result 包装，data 包含 appCode、installedVersion、observedAt、snapshotRevision、complete、nextCursor、bindingCount、inFlightCount、items（type 为 BOUND_PROJECT/IN_FLIGHT_INSTANCE，字符串 resourceId、projectCode、最小安全说明）。分页参数只允许 §4a 的 cursor、limit，首页可不带参数。返回计数须完整，有后续页时用 nextCursor 返回不透明游标并令 complete=false；末页省略 nextCursor 或置 null，complete=true 表示已取全。平台必须沿游标取全且确认完整后才能放行；限流、超时、未知版本、鉴权失败、不完整响应均失败关闭。业务项目绑定和在途事实由应用自己判定，平台不读应用数据库，也不把平台待办数代替在途数。

调用身份与请求格式见 §4a。只读查询不承担冻结副作用，冻结和完成条件由 prepare/complete/abort 控制。存在阻塞时列出安全 ID 与原因退出，不能强制终止实例。DISABLED 应用也须能接受受限阻塞查询；不得因无 PUBLIC/PROJECT 路由就视为无阻塞。

默认卸载只停止运行，Docker volume、数据库 schema、对象存储及历史审计全部保留，重装恢复。`uninstall --purge` 仍先完成阻塞检查；关闭入口/写入后先由 CLI 本地导出独立 schema dump、所有应用自有 volume 打包及对象数据恢复引用/清单，校验退出码、文件非空和 SHA256，记录本地绝对路径、备份版本和数据清单。备份失败不得继续。只对平台登记为该应用独占的资源可 purge，绝不能删共享平台库/共享桶/其他应用 volume。

打印脱敏删除清单及备份路径后，**第二次确认**要求输入应用编码与 purge（初始 --purge 标志不是二次确认）；非交互模式不删除。确认绑定 operationId、备份摘要与资源清单，任一变化重新确认。先删除应用自有资源再记 purgeComplete，失败保留逐项记录、同命令续跑前再次验证备份及确认，已删项不重复猜测。不得删除备份或生命周期/审计台账。状态仍为 UNINSTALLED_RETAINED，并以 retainedData=false、purgeComplete=true 标明已清理业务数据；再次安装是空数据初始化，不能声称恢复。更改状态名需评审，避免把历史登记物理清除。

## 7. ADR 与源码逐条关系

下表为核对关系，不替代历史 ADR 的效力。System 基线 `8c4e53a`。


| ADR | 本 ADR 的关系与保留约束 |
| --- | --- |
| 0002 | 补充发行聚合；双仓独立版本/CI/回滚不变，不建 monorepo |
| 0003 | 补充管理操作边界；Gateway Context、最终授权、Starter 不回调鉴权不变；新平台→应用身份限下文生命周期通道；多项目验证由0046定稿 |
| 0004 | 补充 app_code；不取代 built_in 不可停用/删除规则 |
| 0022 | 补充应用登记；service_url 与 backend_url 分离、显式 PROJECT 身份不变 |
| 0023 | 不影响 K8s chart/环境仓、不可变镜像及 Secret 边界；本期不写部署仓 |
| 0025 | 补充宿主机 CLI 应用安装；复用 compose/受管路由/reload/边缘同源入口；平台进程仍不部署 |
| 0027 | 补充内置发行目录；薄入口继续委托 System，目录不能复制产品实现 |
| 0028 | 不影响模板唯一事实源与无私有前端 SDK；上架规范复用模板外壳和 check-dict/perm/log |
| 0032 | 不影响 api/domain/boot 与分类分层；新稳定 DTO 不包含实体、密钥或调用上下文 |
| 0034 | 不影响待办由业务事实驱动；requires 只声明依赖，不把待办当流程状态 |
| 0036、0042 | 补充应用发行 plan/apply，保留角色不自动分配成员/只增不删/运营值；新增专用生命周期授权路径，原API权限门不变，不发明第二同步器 |
| 0044（项目数据范围） | 不影响既有范围与角色授权；不复用其编号。工作区旧可选服务草案同占0044，见 DQ-01 |

源码核对锚点：`scripts/kaiwu.sh` 的 project-up 先 --build 后路由再前端、project-down 默认无 -v、4/6GiB 与 override；新安装需重排发布时机且仅 pull，不能原封调用。`ProjectServiceImpl` 创建项目/管理员/种菜单，已有 built_in guard 不能代表已有 app guard。`factory/service/impl/ProjectManifestServiceImpl` 的 plan/apply 要求目标项目管理员与计划哈希、ACCESS/DELETE 选择，不能绕过。`ProjectServiceCredentials` 是服务访问 System 的认证入口。


## 8. 扩展位与不做

部署后端扩展位仅在宿主执行适配层，未来 K8s 适配需独立 ADR/任务；manifest formatVersion/来源、平台状态与幂等回执、独立数据、显式路由、权限审计、默认保留和阻塞检查约定不可破坏。本期 deployment 只允许 docker，不能提交虚构 K8s 字段或调用实现。既有 test 集群继续手工 GitOps，不在本卡迁移。

第一期不做远程市场/第三方/付费授权、应用依赖解析、自动改业务项目代码配置、应用中心页、K8s/Argo、平台进程操作容器、未审查的共享引擎实现、全新权限模型或迁移实现。A0 无 DDL、无共享库连接、无运行代码；A1 的表/字段和 MySQL/DM/Helm/schema 副本须单独列 DDL 供 Claude 确认。A1/A3 的真实 Docker、MySQL、恢复和权限验收必须后续实际执行，本文结构校验不证明安装已可运行。

## 9. 与0046、D09及实施门的关系

0045定义平台应用分类、安装/项目启用编排与生命周期授权。0046由共用T0另卡定义能力应用专用TrustedProjectRegistry、多项目Context验证及≤30秒缓存失效，普通服务仍默认单项目；0045不放宽现Starter。D09由另一T0卡部分取代D01第1/5条，明确shared/dedicated、projectId/tenantId隔离、worker、公平调度、配额、加密密钥、存储及T1–T9威胁验收。此两份未定稿前不得实现A1/A3，A0不代起T0。

同日新提示词顶部修订优先于下方遗留“每项目一实例、不得共享”段；安装默认起共用实例、shared启用只登记、dedicated才启动独占是明确裁决，不再作为未决选项。生命周期断言和密钥分发由本 ADR 的 §4a 定义。0046 引用该密钥体系验证部署证明，D09 定义工作流消费方约束。生命周期校验器在 0045 定稿后纳入 T1。Docker 峰值预算由 A1 实测。
