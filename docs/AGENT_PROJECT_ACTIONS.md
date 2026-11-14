# Agent 项目创建（B1）

本批仅开放 `system.project.create`。聊天可生成创建项目预览；用户核对后点击“确认创建项目”，才会调用已有 `ProjectService.create`。项目编辑、成员/角色、生成、调度和远程业务 Handler 仍未接入。

## 用户流程

1. 有 `system:agent:ask` 和 `system:project:create` 权限的用户输入“创建订单管理项目，编码 orders”。缺少名称/编码时模型应请求补充；服务端不接受不完整参数。
2. 卡片展示冻结的名称、编码、描述和基础包名，说明创建人将成为项目管理员。包名缺省按既有规则推导。单次只允许一个写操作，不能和查询混合。
3. 5 分钟内点击确认或取消。在聊天里回复“确认”不会执行操作。模型不能提交确认凭证。
4. 成功后显示项目卡片，点击“前往项目管理”关闭对话并打开 `/projects`，继续配置服务入口；创建项目不等于生成代码、部署服务或初始化 GitLab。
5. 响应丢失时显示“结果待核验”，仅 GET 查询状态或前往项目管理核验。浏览器不自动重放确认 POST；查询不会重新签发确认凭证。无凭证的未执行预览只能取消后重新生成。

## 服务端契约

- `POST /api/agent/ask` 的 `pendingAction` 为可选字段，原查询响应兼容。
- `POST /api/agent/actions/{uuid}/confirm` 请求仅需 `{ "confirmationToken": "..." }`，不接受客户端重定义操作参数。
- `POST /api/agent/actions/{uuid}/cancel` 取消未执行操作。
- `GET /api/agent/actions/{uuid}` 查询原会话的状态。确认、取消、状态均要求 Agent 权限并实时检查创建权限、用户与会话有效性；无效身份/令牌不披露其他人的操作。
- 响应带 `Cache-Control: no-store`。token 是 32 字节密码学随机数的 Base64URL，仅首次预览交付；Redis 仅存 SHA-256 摘要，DTO `toString` 不输出参数或凭证。token 不进入模型、URL、浏览器存储和审计内容。
- 冻结 user/session、能力码/版本、规范化请求及 SHA-256 计划摘要；参数使用 ProjectCreateRequest 的校验规则。执行前重新读取当前会话/权限及能力版本，原子占用后再次复核权限和有效期。能力契约变更必须递增版本。
- 复用领域事务创建项目、project-admin 角色和创建人成员关系；复用项目编码唯一约束及领域审计。没有新增绕过领域规则的 CRUD 通道。

## 状态、故障与幂等边界

Redis 单键 `agent:action:{uuid}` 保留 1 小时；创建用 SET NX，确认/取消用比较完整旧记录的 Lua CAS，并保留原 TTL。状态包括 PENDING、EXECUTING、SUCCEEDED、FAILED、CANCELLED、EXPIRED、REJECTED、UNKNOWN。PENDING 的确认窗口为 5 分钟，EXECUTING 超过 60 秒时查询显示 UNKNOWN；正在完成的原请求仍可写回最终结果。

这是**保留记录内单次认领、禁止自动重放**，不是跨 Redis 灾难恢复的 exactly-once。该本地领域方法不接收 actionId 幂等键；项目编码唯一约束是额外守卫，不能扩展成通用写能力保证。Redis 丢失记录、TTL 到期或回滚旧快照时必须人工通过项目编码/审计核验；不从客户端重建动作，不承诺历史状态永远可查询。后续远程写能力必须有领域持久化幂等键，再按 ADR 单独接入。

预览/确认/取消/结果通过现有 AuditPort 记录 actionId 和能力码，不记录参数与token；成功项目创建另有领域审计。确认前审计失败会阻止创建；执行后状态/审计写入失败只返回 UNKNOWN 或告警，不重试业务调用。已认领后出现 4xx 领域拒绝为 FAILED；提交或网络结果无法判断时为 UNKNOWN。

前端仅在内存保留凭证；退出、换用户或 Agent 权限消失时清空对话。刷新页面也会丢失卡片，用户应先在项目管理核验是否已经创建。服务端状态查询只供仍持有 actionId 的原会话使用，不提供跨会话历史恢复。

## 迁移与验证

V49 仅增加中英文文案、`agent.action.status` 字典并推进语言目录版本，无新增业务表。必须先部署 System V49，再部署 Web。累计 schema 与 Helm 迁移副本同步。移除创建能力的服务端目录项可阻止新预览及尚未认领的确认；已认领请求仍需按结果对账。

验证使用一次性 Redis/MySQL Testcontainers：并发确认、确认/取消竞争、过期、会话与权限撤销、缺失记录、结果落库失败、事务提交/回滚，以及 V48→V49 升级。Web Playwright 使用本地模拟 API 验证确认、取消、响应丢失恢复、权限拒绝、过期、登出和凭证不落存储/历史。不能将这些测试表述为共享 test 环境已实际创建项目；共享环境仅做发布与健康核验。
