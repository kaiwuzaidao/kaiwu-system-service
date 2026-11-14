# ADR 0040：对象存储的 CLI 命令

- 状态：Accepted
- 日期：2026-10-29
- 决策范围：`kaiwu-system-service`（`scripts/kaiwu.sh`）
- 补充：ADR 0035（CLI 设备授权）、ADR 0039（对象存储 STS）

## 背景
ADR 0039 的管理接口 `/api/storage/*` 目前只有网页入口。AI 编码工具生成项目后，
"给项目开通存储"这一步只能回到浏览器。ADR 0035 的 CLI 会话是普通会话、权限与本人一致，
`/api/storage/*` 本来就走 Gateway，无需新授权机制。

## 决策

### 1. 命令（`scripts/kaiwu.sh`，入口仓只转发）
| 命令 | 对应接口 | 权限 |
|---|---|---|
| `kaiwu storage accounts` | `GET /api/storage/accounts` | `system:storage:list` |
| `kaiwu storage test <accountCode>` | `POST /api/storage/accounts/{id}/test` | `system:storage:test` |
| `kaiwu storage bindings [<projectCode>]` | `GET /api/storage/bindings` | `system:storage:list` |
| `kaiwu storage bind <projectCode> --account <accountCode> [--name <storageName>] [--max-mb <n>] [--types a/b,c/d]` | `POST /api/storage/bindings` | `system:storage:save` |
| `kaiwu storage bind-status <bindingId> --status <ACTIVE\|READ_ONLY\|DISABLED>` | `PUT /api/storage/bindings/{id}/status` | `system:storage:save` |

- 命令按**编码**取参，CLI 内部先查列表换成 ID（与 `cli_lookup_project_id` 同模式）。
- 输出只含 `StorageAccountView` / `ProjectStorageBindingView` 里已有的脱敏字段。
- 第一期**不提供**账号的新增/修改命令。

### 2. 密钥边界
- AccessKey Secret 不经命令行参数、环境变量或 shell 历史；CLI 不接触任何长期密钥。
- 账号创建/改密仍在网页完成（`/api/storage/accounts` 的 POST/PUT 不做 CLI 封装）。
  如后续确需，只允许 `--secret-stdin`，且单独走一次 ADR 评审。
- `/api/internal/storage/credentials` 是项目服务凭据专用，不进 CLI。
- CLI 不下载、不上传对象（ADR 0039：文件字节不经 System）。

### 3. 权限与审计
- 不新增权限点，沿用 `system:storage:list|save|test`。该权限当前只在平台管理员手里，
  所以与 `access` 命令一样：项目管理员用不了 CLI 绑定，仍在网页处理（与 ADR 0035 的既有取舍一致）。
- CLI 会话的权限快照是固定范围与用户权限的交集（ADR 0035 补充），因此必须把这三个权限码加进 `CliSessionScope`。
- 加入范围后 `system:storage:save` 也会让 CLI 令牌能直接调用账号创建/修改接口，绕过「CLI 不处理密钥」的边界
  （例如把已有账号的地址改走）。`StorageController` 因此对带 `cli:session` 标记的会话拒绝
  `POST /api/storage/accounts` 与 `PUT /api/storage/accounts/{id}`（403），账号写入只允许网页会话。
- 审计沿用现有 `BIND_PROJECT` / `TEST_ACCOUNT` 记录，会话来源字段已能区分 CLI。

### 4. 实现范围
- 后端：`GET /api/storage/bindings` 新增可选参数 `projectCode`，省掉 CLI 端二次查询。
- `scripts/kaiwu.sh` 新增 `cli_storage*` 函数与 `usage` 条目；`scripts/tests` 补桩测试。
- 文档：`QUICKSTART`/CLI 命令表追加一节；ADR 0035 命令表加交叉引用。
- 不需要 i18n 迁移。

## 被否决
- 在 CLI 里创建账号并传 Secret：Secret 会落入命令历史、AI 工具上下文和日志。
- 新增"项目管理员可绑定存储"的权限：属于授权模型变更，另行评审。

## 验证
- 脚本桩测试覆盖：未登录、无权限（403）、编码不存在、绑定成功/重复绑定转只读。
- 在 test 环境用平台管理员 CLI 会话跑一遍 accounts → test → bind → bindings。

## 已确认的取舍
1. 第一期不含账号创建/修改命令。
2. 仅平台管理员可用，项目管理员仍在网页里处理。
3. 后端顺带支持绑定列表按项目编码过滤（`GET /api/storage/bindings?projectCode=`）。
