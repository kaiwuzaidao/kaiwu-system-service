# ADR 0019：使用 HttpOnly Refresh Cookie 恢复浏览器会话

- 状态：Accepted
- 日期：2026-08-10
- 取代：ADR 0003 第 4 节中“Refresh Token 只驻留前端内存、页面刷新后重新登录”的部分

## 背景

平台用户明确要求切换语言后刷新页面仍保持登录。现有实现把 Access Token 与 Refresh Token
都只保存在 JavaScript 内存，刷新页面必然丢失两者；服务端虽然保留 7 天在线会话和刷新令牌摘要，
浏览器却无法在新页面进程中使用它们。把令牌写入 Local Storage 或 Session Storage 会扩大 XSS
后的凭据窃取面，不接受作为修复方案。

## 决策

1. Access Token 继续只驻留 JavaScript 内存，有效期仍为 15 分钟。
2. Refresh Token 改由 System 通过同源 Cookie 下发：`HttpOnly`、`SameSite=Strict`、
   `Path=/api/auth`；部署环境必须启用 `Secure`，仅本地 HTTP profile 可显式关闭。
3. 登录和刷新响应 JSON 不再返回 Refresh Token。`POST /api/auth/refresh` 不接收请求体，
   只读取 Cookie；Gateway 继续以精确 PUBLIC POST 路由转发该端点。
4. 每次成功刷新生成新的不可预测 Refresh Token，并用条件更新替换服务端摘要；旧 Token
   立即失效，并发刷新只有一个可以成功。在线会话绝对到期时间仍为首次登录后的 7 天，轮换不续期。
5. Web 启动时先调用刷新端点恢复内存 Access Token、用户与语言 catalog，再渲染受保护页面；
   Cookie 缺失、过期、已撤销或轮换冲突时进入登录页。
6. 主动注销仍走受保护端点撤销 System/Redis 会话，并清除 Refresh Cookie。刷新失败也清除
   无效 Cookie，避免浏览器反复携带坏凭据。
7. Web Storage、普通 JavaScript Cookie、URL 参数和组件级 Token 副本仍禁止使用。

## 安全边界

- `HttpOnly` 阻止前端脚本读取 Refresh Token；Access Token 的暴露窗口仍受 15 分钟寿命限制。
- `SameSite=Strict`、同源 `/api` 与精确 POST 路由共同限制跨站刷新请求；刷新端点只签发同一
  已存在会话的短期 Access Token，不执行其它业务变更。
- Gateway 仍逐请求校验 Access JWT 与 Redis 在线会话；注销、禁用、重置密码和强制下线后，
  Cookie 不能恢复已撤销会话。
- 生产环境若未通过 HTTPS 提供同源 Web/API，不得关闭 `Secure` 迁就部署。

## 迁移与回滚

- System 与 Web 必须协调发布：新 Web 不再持有 Refresh Token，新 System 不再在 JSON 中返回它。
- CLI/E2E 调用方改用标准 Cookie jar，不从响应 JSON 提取 Refresh Token。
- 回滚应同时回滚 System 与 Web。已下发 Cookie 可由新版本注销或过期清除；不得以把 Refresh
  Token 重新写入 Web Storage 作为临时回滚。

## 后果

- 页面刷新可以在 7 天绝对会话期内无感恢复登录与用户语言。
- 前端首次渲染增加一次 PUBLIC refresh 请求；无有效 Cookie 时快速失败并进入登录页。
- System 需要维护 Cookie 属性和原子 Refresh Token 轮换测试，但 Gateway/Starter 信任边界不变。
