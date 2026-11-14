# ${projectName} 聊天能力接入

项目 `${projectCode}`（项目 ID `${projectId}`）生成时**没有可执行的聊天能力**。项目工厂只
提供默认关闭的配置和接入约定；不会从 Controller、OpenAPI、数据表或页面自动暴露操作。
每一项能力都由本项目维护领域实现，平台只负责发现、授权、编排和展示。

## 接入一项只读任务

1. 确认 `com.kaiwuzaidao:kaiwu-system-starter` 不低于 `0.2.0`（脚手架固定为
   `${starterVersion}`，已包含 `AgentReadCapabilityHandler`），并在本仓库运行 `mvn verify`。
   只使用 Maven Central 上的正式版本，不要依赖本地安装或开发快照。
2. 为具体领域任务（例如 `${projectCode}.order.list`）定义稳定能力码、递增版本、参数
   类型和上限、允许返回的字段、数据范围与有效的 BUTTON 权限码。把 BUTTON 写入
   `kaiwu/menus.yml` 并用 `./kaiwu project sync` 同步到 Kaiwu System，再给目标项目成员授权。不要用平台管理员身份
   代替项目权限，也不要给模型任意 SQL、URL、类名或方法名。
3. 实现一个 `AgentReadCapabilityHandler` Bean。它的 `manifest()` 和 `query()` 必须描述
   同一项能力；不要再注册第二份同码的 `CapabilityManifest` Bean。查询复用领域 Service，
   从已验签的 actor 取得用户身份，在数据库查询中检查资源归属和状态。`pageSize`、过滤
   参数和超时必须有界；只返回清单列出的安全字段，敏感值在领域层脱敏。
4. 配置所有实例共用的原子重放存储（通常是 `StringRedisTemplate` 加 SDK 的
   `RedisAgentReplayStore`），确认 Redis 故障时拒绝调用、readiness 行为及必要的 `INFO`
   权限。不能用单进程内存存储代替。将独立 Agent 注册凭据通过 Secret 注入
   `KAIWU_AGENT_REGISTRY_CREDENTIAL`；不可复用调度凭据、用户令牌或 Gateway Context。
5. 为项目配置显式的 Gateway PROJECT Route，核对 projectCode、audience 和目标服务；
   内部 Agent 固定入口不能成为浏览器可直达的普通业务路由。核验 System、Gateway 与业务
   服务的各自开关、注册心跳、清单版本和摘要。目标项目管理员**逐版审核**后，分别测试
   授权用户、无权限用户、越权资源、错项目、超限参数、断线和重放。注册成功或审核通过
   本身都不代表端到端可用。

`application.yml` 中 `KAIWU_AGENT_ENABLED` 控制注册，`KAIWU_AGENT_READ_ENABLED` 控制
只读执行；两者默认 `false`，且要在 Handler、凭据、重放存储、平台服务和路由都部署完成
并通过隔离环境验收后才开启。变更字段、权限、参数或描述时递增 manifest 版本并重新审核。

## 接入一项写任务

写操作必须使用独立的 `AgentWriteCapabilityHandler`，不能放在只读 `query()` 内，不能把
现有 REST 写接口直接开放给模型。选择可在**同一个业务数据库事务**完成的短操作，清单
声明 `readOnly=false`、幂等与确认级别；预览只读，显示目标、变更及资源版本。用户确认后，
执行时重新检查 actor 权限、归属、状态和预览版本。业务变更与动作账本、结果持久化使用
同一数据源和事务；相同 actionId 只能提交一次，超时只能查询原动作结果，不自动重放。
外部支付、邮件、HTTP 或长任务不能套用这套同事务保证。`KAIWU_AGENT_WRITE_ENABLED` 默认
`false`，只有迁移、并发/回滚/结果查询测试及 System/Gateway/项目三级写开关全部验收后
才能开启。SDK 的固定写入口、账本接口和参考 SQL 以所升级 Starter 的
`docs/AGENT_WRITE_LEDGER.md` 为准。

普通业务 API 仍须遵守本仓库 `AGENTS.md` 的权限、分页、投影和审计约束。聊天能力是显式
接入的另一条受控调用链，不绕过原有领域规则。
