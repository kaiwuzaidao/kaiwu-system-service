# Data Scope D0 验证记录

- 日期：2026-11-03
- 分支：`feat/data-scope-d0`（基于 `origin/dev` 571e4a6），仅本地提交，未 push
- 范围：只改文档，无代码、无迁移

## 做了什么

1. 确认 ADR 编号 0044 在 `origin/dev` 与全部远端分支均未被占用。
2. 新增 `docs/adr/0044-project-data-scope.md`（Proposed）与 `docs/DATA_SCOPE.md`。
3. 对 ADR 0003 §5、`ARCHITECTURE.md` §8.4、ADR 0030 只加注，不删原文。

## 对照 origin/dev 核实的事实

| 事实 | 位置 | 对契约的影响 |
|---|---|---|
| 内部接口是 `GET /api/internal/gateway/project-access`，返回 `Result<ProjectAccessView>`，非成员 403 | `GatewayProjectAccessController` | 契约沿用该接口，超限错误复用 403，Gateway 不需要新增分支 |
| `ProjectAccessView` 只有 projectId/projectCode/permissions/projectRoleCodes | `kaiwu-system-api/.../ProjectAccessView.java` | 在其上新增可选 `dataScope` |
| `authzVersion` 是会话级平台权限摘要，项目快照里没有 | `RedisSessionSnapshotAdapter.java:34` | 不改它；用 `fp` 表示范围内容变化，收敛靠 Gateway 30 秒缓存 |
| `roles.yml` 角色字段为 roleCode/name/description/permissions/routes/directories，并拒绝 `project-admin` | `ProjectManifestParser.role()` | `dataScopes` 按此风格扩展，不含 project-admin |
| Starter 的 `GatewayContextVerifier` 按名称读取声明 | `GatewayContextVerifier.java` | 旧版 Starter 会忽略 `ds` |
| 工程约束 `auth.resource-ownership` 已要求显式 PROJECT_WIDE / OWNER_ONLY | `docs/kaiwu-constraints.json` | ADR 背景写明本方案是它的扩展，不取代 |
| 部门 ID 由自增 `nextId()` 生成 | `OrgServiceImpl.java:339` | 契约要求迁移时保留部门 ID |

## 校验

- 文档内相对链接全部有效。
- 文档中的 3 个 JSON 块均可解析；§4.1 示例已改为规范化形式，并给出共用测试向量
  （规范化字节的 SHA-256 前 16 位 `d361b479f54b4be2`）。
- **未跑** `./scripts/verify.sh`（Maven 全量）：本批次只改 Markdown，没有 Java、SQL、模板变化。
- **未用** JSON Schema 校验器实际校验示例（本机未装 `jsonschema`），仅人工对照。

## 没覆盖到

- 与 D1 之后实现的一致性要靠 D1/D3 对共用测试向量的断言来保证。
- 6144 字节上限与「256 个部门」口径尚未实测，留给 D2。
- `kaiwu-constraints.json` 暂未新增约束条目，留给 D5 随门禁一起评估。
