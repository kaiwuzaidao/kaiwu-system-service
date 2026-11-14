# 子项目聊天写任务协议（Phase D，分批实施中）

本文承接 ADR 0030 与已实现的 [远程查询协议](AGENT_REMOTE_EXECUTION.md)，是远程写链路的实现约束与验收清单，**不是已上线能力**。D1 事务账本、D2 的 SDK 固定入口/System 编排/Gateway 写委托及 D3 Web 通用卡片已实现；首个业务项目写 Handler 已提供，但业务库迁移、注册审批、受控详情页导航与端到端验收仍未完成，独立写开关保持关闭。实际合并与发布状态见 [交接](HANDOFF.md)。

目标：业务项目增加一个版本化领域 Handler 后，平台完成审核和授权即可通过聊天发起任务；无需逐项修改 System 编排器或聊天页面。第一批远程写操作只接纳同一业务数据库事务能完成的短任务。支付、邮件、外部 HTTP 副作用和长作业需要各自领域的可靠投递/幂等协议，不能用通用 Handler 的事务保证替代。

## 用户流程

1. 用户说出业务目标，例如“将订单 A 的备注改成明天送达”。模型选择有权限的能力并补齐必要参数。
2. System 调用业务 Handler 的只读预览。界面显示项目、操作名称、目标对象、变更前后值、影响数量、有效期以及确认/取消按钮。参数与当前资源版本同时冻结。
3. 用户确认后，System 重新检查会话、项目、成员、权限、能力版本和审核状态，原子认领操作记录，再委托 Gateway 执行。
4. Handler 在事务内重新验证资源归属和预览时的版本，将业务变更与执行结果一起提交。成功后显示结果卡片和受控页面入口。
5. 网络超时显示“执行结果待核实”，只查询执行账本。查询不到结果不能转为成功、失败或自动重新执行。

一次确认只能包含一个写调用。批量操作必须是业务方单独定义的能力，预览明确具体范围和数量上限，不允许模型拼出多个写调用后共用一次确认。高风险能力使用 STRONG：前端显示并要求用户手工输入绑定本次操作摘要的确认短语。聊天中的“确认”不能替代点击确认接口，也不能由模型填入短语或 token。

## 三层职责

| 所有者 | 持有的信息 | 必须保证 |
|---|---|---|
| System | 待确认动作、冻结参数/预览、确认凭证摘要、状态、审计 | 只有原用户与会话能确认；确认后不可替换参数；模型不能调用执行入口 |
| Gateway | 短期用途凭证、实时授权、显式 PROJECT Route | 来源、目标、操作类型和所有摘要一致；不接受请求指定 URL；不自动重试 |
| 子项目 Starter + 领域 Service | 固定 Handler、资源版本、事务执行账本 | 领域授权、资源并发控制、同一 actionId 的幂等结果；不依赖 System 数据库 |

注册凭据只能注册/心跳。浏览器 JWT 只能到 System 用户接口。System 服务断言不能直接访问业务接口。Gateway 的 Agent Context 只能在对应的固定 Handler 入口使用。现有 Phase C 查询协议继续拒绝写操作。

## 能力与 Handler

新增独立 `AgentWriteCapabilityHandler`，不扩展 `AgentReadCapabilityHandler.query()` 的用途。拟定三个领域扩展点：

- `preview(parameters, actor)`：只读，返回显示字段、影响范围与不透明的前置条件；不分配业务资源、不发外部请求产生副作用。
- `execute(parameters, preconditions, actor)`：只由确认后路径在执行账本事务内调用。重新校验数据归属、状态及乐观锁版本，返回受审核输出字段约束的结果。
- 结果查询由 SDK 的账本适配器完成，不再次调用 `execute()`。Handler 不以“查询状态”为名补做操作。

所有类型都是 SDK 自包含 DTO/SPI，不依赖 System API/Domain。首次写版本需 `readOnly=false`、`idempotent=true`、`confirmation=REQUIRED|STRONG`，并具备领域审计。manifest 声明只是准入信息，不能证明实现满足事务和幂等；审核必须核验实现及测试证据。修改参数、权限、输出字段、确认等级或 Handler 语义都必须递增版本并重新审核。

预览与执行沿用 Phase C 的参数类型/数量/长度上限。前置条件限制 16 KiB、结构深度 12；不得包含凭据。预览最多 32 个有名称的显示字段、总计 32 KiB；可选 `displayLabels` 为字段提供中文等可读标签，键必须对应显示字段，值同样限制为安全纯文本。只能显示按字段策略脱敏的文本。业务服务不能返回 HTML、任意 URL、脚本、确认 token 或前端组件代码。

列表与详情入口使用平台受控导航描述：项目 ID、已登记页面键、字符串资源 ID。前端按注册的页面规则构造路径，找不到规则时只显示结果，不退化为任意 URL 跳转。平台卡片负责名称、状态、时间和操作按钮的一致样式，业务项目负责字段含义。

## 固定协议与摘要

拟新增写协议入口，与 Phase C 的 `/invoke` 分离：

```text
POST /api/internal/agent/capabilities/{code}/preview
POST /api/internal/agent/capabilities/{code}/execute
POST /api/internal/agent/capabilities/{code}/result
```

这些入口不加入外部路由。调用必须经过 Gateway，并使用与方法一致的 `operation=PREVIEW|EXECUTE|RESULT` Context。预览不能执行，执行凭证不能调用普通 API，结果查询凭证不能调用执行入口。

System 生成随机 actionId 和 correlationId。执行绑定至少包括：用户、session、项目、audience、能力码/版本/manifestHash、actionId、operation、paramsHash、preconditionsHash、previewHash、actionExpiresAt、jti。参数与前置条件保留原始 UTF-8 JSON 字符串并计算 SHA-256，跨服务不重新序列化后比较。展示的预览内容也在服务端摘要内，确认请求没有参数或摘要覆盖字段。

沿用 Phase C 的不同 typ、固定 issuer/subject/audience、短期 RSA 服务断言、原始请求 bodyHash、共享 Redis jti 原子消费及固定目标限制。写 Context 继续使用至多 60 秒有效期，并且不得晚于 actionExpiresAt。每次 RESULT 查询签发新的只读用途凭证；查询已提交结果可晚于预览有效期，但仍须当前会话、成员及查询权限有效。

Gateway 每次向 System 权威授权端点检查 operation。EXECUTE 不只检查当前能力权限，还必须读取动作记录，要求其已由确认接口认领为 EXECUTING，且用户/session、能力版本、全部摘要、有效期均一致。不能因为调用方有服务签名密钥就相信 `confirmed=true`。PREVIEW 不签发可写 Context；RESULT 只查询本人动作。

## System 持久化动作状态

远程动作新增独立 MySQL 表，通过 MyBatis-Plus Repository 管理，沿用迁移/累计 schema/Helm 副本约束。迁移号在实现时按最新 dev 分配。现有 B1 Redis 状态不机械迁移，也不以其 1 小时保留期承担远程幂等保证。

拟存储字段：actionId、userId、sessionId、projectId、能力码/版本/manifestHash、参数/前置条件/预览摘要、加密冻结载荷、tokenHash、confirmationMode、status、expiresAt、startedAt、finishedAt、结果引用/摘要、脱敏原因码、revision。确认 token 使用至少 256 位随机数，只存摘要，只首次返回浏览器内存，不进入模型、URL、日志或浏览器持久存储。敏感冻结载荷复用平台加密能力，密文内也包含 actionId 与绑定信息，解密后复核，避免跨记录替换。

```text
PENDING --确认 + SQL CAS--> EXECUTING --确定已提交--> SUCCEEDED
   |                           |--确定未执行/已回滚--> REJECTED / FAILED
   |                           |--超时/结果无法判定--> UNKNOWN
   |--取消--> CANCELLED                              |
   |--过期--> EXPIRED                     只读账本查询 --+--> SUCCEEDED / FAILED
   |--版本/权限变化--> REJECTED
```

确认、取消、过期使用带原状态/revision 条件的 SQL CAS。只允许 PENDING→EXECUTING；没有 UNKNOWN→EXECUTING。确认成功后网络层仍只发送一次。进程在认领后崩溃，恢复逻辑只能查账本；不得抢占执行记录后重发。

没有账本记录不构成失败证明：旧执行请求可能仍在途，或数据库事务未提交。超时任务保持 UNKNOWN 并要求领域对账；不能生成新 actionId 自动代替重试。用户重新提出同一目标时仍可能造成语义重复，应展示未决任务并引导核实，不能宣称跨不同 actionId 也具备 exactly-once。

确认时先复核权限，CAS 后再复核。撤权、项目停用、能力下线/换版或 feature flag 关闭都阻止新的执行。已认领或已提交动作不能通过“取消”回滚，返回实际状态。关闭入口后仍保留受权限保护的结果核实与审计。

## 业务数据库执行账本

SDK 定义持久化幂等 SPI；业务方的账本适配器必须使用与领域写入相同的数据源、相同事务管理器与同一事务。提供 MySQL 接入参考及迁移，不在 SDK 启动时自动建表，也不访问 System 库。

1. 唯一键覆盖项目与 actionId，记录 owner、session、能力版本和完整绑定摘要；先插入执行占位并持有事务锁，再调用领域写入。
2. 同一事务内存储受控结果并提交。若领域授权、并发版本或业务校验失败，业务写入与占位一起回滚；确定失败记录的持久化必须有清晰的独立处理，不能留下看似成功的账本。
3. 相同 actionId/绑定的并发请求等待已提交结果并返回它，不重复执行；绑定不同一律拒绝。事务锁等待有上限，超时不推测另一事务失败。
4. 断电、连接中断或提交结果未知时，由后续 RESULT 查询读取账本。账本可用并不意味着缺失记录可安全重试。
5. 结果写入失败必须使业务事务回滚；Handler 不能用 REQUIRES_NEW、独立连接或捕获异常后提交业务变更来绕过账本事务。不可事务化的外部副作用不进入第一批。

jti 重放存储只挡凭证重用，actionId 账本保证已提交业务动作去重，两者不互相替代。账本和结果保留期在首个项目接入时与业务审计策略一并配置；第一版不自动清理去重键。System 删除显示载荷不得复活已消费的 actionId。清理策略必须保留足以拒绝旧执行的 tombstone 与审计依据。

## 分批实施与发布门禁

| 批次 | 修改位置 | 合入验收 |
|---|---|---|
| D1 | Starter 写 Handler/预览 DTO、事务账本 SPI 与业务 MySQL 示例 | 真实一次性 MySQL：16 路竞争只变更一次、绑定冲突、领域/结果失败一起回滚、提交后断响应可查询；不装配远程写入口 |
| D2 | System 持久化动作表/Repository/服务、Gateway 写用途授权、Starter 固定入口 | 用户/会话/项目/版本/摘要/操作用途负向测试；确认与取消竞争；权限撤销；崩溃/断网禁止重发；普通 API 拒绝写 Context |
| D3 | Web 通用确认卡、STRONG 输入、结果查询与导航；中英文资源/字典迁移 | Playwright：冻结预览、双击不重复、参数无法替换、过期/撤权、UNKNOWN 只查询、退出清理、受控跳转；列表样式和中文实测 |
| D4 | 一项真实业务能力及接入验收 | 先用隔离业务库完成 LLM→预览→确认→事务→卡片全链路，再逐项目开放，不能仅以模拟 API 当成业务接入完成 |

独立写开关默认关闭；未完整通过 D1–D4 的项目不能批准写 manifest 进入执行目录。先发布向后兼容 SDK，再发布 Gateway/System，最后 Web 与业务 Handler。每次记录准确镜像、SDK 发布版本、迁移版本、CI 与实际部署证据。

## 设计复核结论

目录、短期委托、固定读写 Handler、远程动作状态与通用确认卡片已经实现；不能仅把 `readOnly` 改为 false 就认为某个子项目的写能力可用。D4 仍需完成业务库迁移、项目凭据和 Redis、在线逐版审核，以及真实事务、故障注入和聊天回环验收。文档评审和平台代码部署都不替代单项目上线验收。
