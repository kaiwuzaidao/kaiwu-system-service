# Agent 能力注册接入（A2）

System 提供注册服务端和管理 API，Starter 提供自动注册和固定 Handler 入口。`APPROVED` 只表示该版清单经过管理审批；只读和写执行分别受独立部署开关、在线状态、用户权限及业务 Handler 约束。审批不会自动生成 `verifiedReadOnly`，也不会启用远程写入口。

## 身份和接口

管理接口通过现有 Gateway / Starter 用户 Context 认证。除表中平台权限外，每次操作还查询目标项目有效成员关系与有效 `project-admin` 角色，不接受其他项目的管理员身份；内置 System 项目不能注册。所有 ID 按字符串传输。

| 方法与 System 路径 | 平台权限 | 行为 |
|---|---|---|
| POST `/api/projects/{projectId}/agent/credential` | `system:project:update` | 首次签发或轮换凭据，仅本次响应返回明文，`Cache-Control: no-store` |
| DELETE `/api/projects/{projectId}/agent/credential` | `system:project:update` | 撤销凭据和能力；项目停用后仍可撤销 |
| GET `/api/projects/{projectId}/agent/capabilities` | `system:project:list` | 至多 100 条注册摘要及在线状态，不返回凭据 |
| GET `/api/projects/{projectId}/agent/capabilities/{code}` | `system:project:list` | 取得注册摘要及完整规范化 manifest，供逐版审批 |
| POST `/api/projects/{projectId}/agent/capabilities/review` | `system:project:update` | 按能力码、版本、摘要审批或撤销 |

机器端调用 System 的内部地址，不经过浏览器外部路由：

| 方法与路径 | 请求 |
|---|---|
| POST `/api/internal/agent/capabilities/register` | 单条 manifest JSON |
| POST `/api/internal/agent/capabilities/heartbeat` | `capabilityCode`、`version`、`manifestHash` |

两者均使用 `Authorization: Bearer <Agent注册令牌>`。Gateway 现有内部路径阻断保持有效。令牌专用于注册，格式前缀 `kagent_`，绑定项目 ID，含 256 位随机秘密；数据库仅保存 SHA-256 摘要。调度凭据、浏览器 JWT、伪造 Context 不能替代。部署时放入业务服务的秘密配置，不写源码、日志或浏览器持久存储。

## 接入顺序

1. 先登记项目有效 BUTTON 权限，例如 `record:record:list`，再由同时具备平台编辑权限与目标项目管理员角色的用户签发凭据。
2. 业务服务提交自己的 manifest。认证后的项目码及有效权限来自 System 数据库，不能由请求自行提供权限事实。示例：

```json
{
  "projectCode": "crm",
  "code": "crm.record.list",
  "version": "1",
  "description": "查询当前用户可见的客户记录",
  "permission": "record:record:list",
  "dataScope": "SELF",
  "params": {},
  "outboundFields": ["id", "title"],
  "redact": {},
  "readOnly": true,
  "idempotent": true,
  "confirmation": "NONE",
  "timeoutMs": 5000
}
```

3. 响应 `Result.data` 为注册摘要，包含 `capabilityCode`、`version`、`manifestHash`、`status`、`online`。客户端保存服务返回的摘要，不自行猜测 JSON 哈希。未知字段（包括 `verifiedReadOnly`）、重复字段、字符串转布尔等隐式类型转换、多个根 JSON 均拒绝。
4. 建议每 60 秒发送一次心跳，携带这三个版本标识。服务端在线窗口为最近 180 秒，边界不包含第 180 秒；未来时间不视为有效。时钟以服务端为准，时间写入精度为毫秒。
5. 管理员先读详情核对完整清单，再提交审批：

```json
{
  "revision": {
    "capabilityCode": "crm.record.list",
    "version": "1",
    "manifestHash": "替换为详情返回的64位小写十六进制摘要"
  },
  "status": "APPROVED"
}
```

审核仅接受仍在线、有效凭据及有效项目下的 `PENDING` 清单，并再次核对权限。写能力还必须声明幂等、`REQUIRED` 或 `STRONG` 确认，且业务实现需要单独核验领域授权、只读预览和同事务账本。审核摘要不匹配返回 409，必须重新展示内容后再审批。

## 状态、限额与重试

- 首次注册为 `PENDING`。同版同内容注册幂等并刷新心跳；字段顺序及集合顺序不影响摘要。同版改内容返回 409。
- 换版必须按数字分段严格递增，如 `1.2` → `1.3`；`1` 与 `1.0` 视为相等，拒绝降版或等价版本换名。换版恢复 `PENDING`，旧版本心跳/审批返回 409。
- 单项目至多 100 个能力码（含撤销记录）；请求体最多 65,536 字节，JSON 深度最多 12，另有 A1 字段与集合上限。内部注册读取最多上限加一个字节，分块传输也受限。
- 撤销能力使用 `status: REVOKED`，清除心跳。注册、升版或凭据轮换都不能自动恢复撤销能力。管理员明确改为 `PENDING`，再由客户端注册或心跳、重新审批。
- 凭据轮换立即使旧令牌失效，并把未撤销能力重置为 `PENDING`、清除心跳。凭据撤销使全部未撤销能力变为 `REVOKED`。项目停用后拒绝机器请求。
- `online` 仅描述项目、凭据与心跳有效性，不代表获准执行。权限删除后下一次心跳或审批会拒绝；未来执行入口仍必须重新鉴权，不能仅信任目录缓存。
- 400 表示参数错误，401 表示注册凭据无效，403 表示无管理权限，409 表示状态/版本冲突或配额已满，413 表示注册请求体超限。不得对 401/403/409 无限制自动重试；重读状态或修正配置后再操作。

## 存储、审计与运维

V47 新增 `sys_agent_credential`、`sys_agent_capability`、`sys_agent_registry_event`。每项目/能力保留最新一版 manifest，事件保存变更摘要、操作者或凭据 ID，不保存令牌、业务参数或结果。管理员变更同时写现有操作审计；幂等注册和成功心跳不逐次落事件。完整历史清单快照及事件保留清理策略尚未实现。

项目行锁串行化注册、轮换、撤销与审核；数据库唯一约束为最终守卫，状态与审计在同一事务。V47 为增量迁移，Helm 副本和累计 schema 同步。关闭接入时撤销凭据并停止客户端；保留表与审计，不执行 down migration。旧版本代码结构上兼容新表，但部署回滚仍必须遵守仓库现有 Flyway 版本兼容门禁，不能绕过检查降版启动。

验证由 `AgentRegistryServiceTest`、`AgentManifestCodecTest`、`InternalAgentRegistryControllerTest`、`AgentRegistryMySqlTest` 覆盖。MySQL 测试使用一次性容器验证 V46→V47、重复 migrate 无操作、真实 Mapper/JSON/NULL 更新、约束及并发行锁；不操作共享环境凭据。

## Starter 与管理页面

业务服务采用 `com.kaiwuzaidao:kaiwu-system-starter:0.1.1-SNAPSHOT`，开启 `kaiwu.starter.agent.enabled`、配置独立凭据和 System 内部根地址，并声明独立 `CapabilityManifest` Bean。完整配置、生命周期、滚动升级与故障处置见 Starter 仓 `docs/AGENT_REGISTRATION.md`。DTO 不依赖 System API/Domain，两仓使用同一协议夹具测试兼容性。初始连接失败不会阻塞业务 HTTP 启动；401/403 停止注册，409 停止该版能力，修复后显式重启。

项目管理列表的 **Agent 能力** 入口提供凭据签发/轮换/撤销、能力状态、完整清单及逐版审核。UI 复用平台查看/编辑权限；目标项目管理员要求仍由后端逐次校验。令牌仅本次弹窗存在于内存，默认遮蔽、显式复制，关闭即清除。旋转结果不明时不自动重试，应核验后重新签发；浏览器不保存到 local/sessionStorage。

审批先展示完整清单、版本和摘要，用户再次确认后提交同一份 revision。写能力显示单独的风险提示与确认文案。409 关闭旧清单并刷新，不自动重放；离线清单不能批准。`APPROVED` 不代表可以聊天执行，管理页不会自动扫描子项目 Controller。

V48 增加管理页双语文案和全局状态字典；V52 更新过时的只读审批提示并增加写能力审核文案，均不改变权限码或业务表结构。应用回滚仍保留已执行迁移并遵守 Flyway 兼容门禁。真实子项目的迁移、注册、审批和聊天写任务仍需逐项目验收，不能用本地回环服务器测试替代这一结论。
