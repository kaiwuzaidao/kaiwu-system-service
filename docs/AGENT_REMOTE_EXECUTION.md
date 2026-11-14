# 子项目聊天能力接入与执行（Phase C）

目标是让子项目通过 Starter 提供固定 Handler 和版本化 manifest，经平台审核后自动进入当前用户的聊天能力目录。新增业务能力无需修改 Agent 编排器；模型不能提供 URL、用户身份、SQL 或类名。

## 本批协议

1. 子项目的 `AgentReadCapabilityHandler` 同时提供 manifest 与领域查询实现。注册和执行使用同一份 manifest；只接受审核通过、在线、版本与摘要均一致的只读能力。
2. System 从当前会话裁剪能力；执行前重查用户、会话、项目状态、成员和项目权限。System 使用独立用途的短期服务断言调用 Gateway 内部委托入口。
3. Gateway 再查在线会话及 System 权威授权，不沿用 PROJECT 权限缓存。目标只能来自显式 PROJECT Route 的服务 URI 与 audience；请求不得指定目标地址。
4. Gateway 以 `kaiwu-agent-action-context+jwt` 签发最多 60 秒 Context，绑定用户、会话、项目、能力、版本、manifest 摘要、原始 paramsJson 的 SHA-256、correlationId 和单次 jti。
5. Starter 仅在固定 Agent Handler 入口接受该 Context。普通 API 仍只接受原有 Context；Agent 入口拒绝浏览器 JWT、普通 Context、错项目、错版本、参数改写和重放。
6. Starter 的跨实例重放存储必须由业务服务显式提供原子 claim，缺失则不能启动执行入口。业务 Handler 继续检查数据归属，不能把平台审核理解成领域授权。
7. 输出有行数、字段和字节上限，System 再按审核的 outboundFields/redact 过滤后送给模型。超时不自动重试。

## 交付顺序

先完成 SDK 固定 Handler、安全验证和负向测试，再接通 System 动态目录与 Gateway 委托。只有完整链路验证后才在部署环境开启。注册元数据不等于可执行能力。

远程写能力仍需下一层统一预览/确认、领域持久化幂等键和结果恢复；本批不得把远程写 manifest 作为查询放行。既有 System 项目创建确认流程保持独立有效。

## 配置与信任链

System：`kaiwu.agent.remote.enabled=true`、`kaiwu.agent.remote.gateway-base-url`（固定内部 Gateway base URI，支持 http/https/lb）。Gateway：`kaiwu.gateway.agent.enabled=true`，并保留现有 `kaiwu.gateway.project-access.system-base-url` / `internal-token`。均默认关闭；没有业务 Handler 和共享重放存储的项目不应开启接入。

System→Gateway 是独立**用途**断言，使用 System 已有 RSA 签名密钥，不新增共享秘密：`typ=kaiwu-agent-delegation+jwt`、固定 iss/sub `kaiwu-system-service`、唯一 aud `kaiwu-gateway-agent`、最多 30 秒、请求原始 UTF-8 bodyHash 与单次 jti。Gateway 使用现有 System 公钥验证，Redis 原子保留 jti；不能复用用户 Access JWT。

Gateway→System `/api/internal/gateway/agent-access` 沿用 ADR 0022 已有 Gateway 内部凭据，返回实时项目授权及审核版本，不使用 ProjectAccessResolver 缓存。用户从 sessionId 对应的有效会话解析，并与 Gateway Redis 会话的 userId 比较。Gateway→业务服务使用独立 typ 的 Action Context。Gateway 只使用显式 PROJECT Route 中唯一的目标；多个不同目标、无 audience、URI 含路径/凭据/query/fragment 时拒绝。

参数通过 `paramsJson` 原文和 SHA-256 绑定，避免多次序列化引起数值差异；模型不得提供该摘要。SDK 与 System 用同一固定 manifest fixture 验证规范化摘要。响应最多 100 行 / 256 KiB；System 的模型与浏览器投影都执行审核字段及脱敏，浏览器仅另加服务端来源项目 ID。

## 接入与后续写任务

完整 Handler、注册配置和 Redis 接入示例见 Starter 的 `docs/AGENT_CAPABILITIES.md`。写 Handler 必须使用独立的 Phase D 固定入口、持久化幂等账本和确认协议，不能把创建/修改/删除包装成 `AgentReadCapabilityHandler`。本地项目创建 B1 已上线，不能作为远程业务写操作已上线的证据。

远程写状态机、执行账本、确认界面及各项目的发布门禁见 [远程写任务协议](AGENT_REMOTE_ACTIONS.md)；平台通用代码已实现，业务项目仍须逐项迁移、接入和验收。


Helm 使用一个协调开关 `agent.remoteReadEnabled`（默认 false），同时向 System 与 Gateway 注入上述启用配置，System 委托地址由当前 release 的 Gateway Service DNS 生成。升级两侧代码后再开启，不能只开启其中一侧。
远程写另有 `agent.remoteWriteEnabled`（默认 false），同步注入 System 与 Gateway；
Chart 拒绝写开启而只读关闭的组合。业务服务仍有自己的写开关，
三处开关都不能替代在线 manifest 的逐版批准和隔离测试记录上的正反向回环。
