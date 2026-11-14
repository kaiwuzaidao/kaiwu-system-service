# Data Scope D6 验证记录（端到端）

时间：2026-11-03，本机。**只在本地跑，没有部署 test，没有推送任何分支。**

## 被验证的组合

| 组件 | 分支（本地） | 说明 |
|---|---|---|
| System | 临时集成分支 = `feat/data-scope-d1`（含 D0）+ `feat/data-scope-d5` + `feat/data-scope-members`（基于 C3） | 集成分支只用于联调，已丢弃，不推送；合并仅在 `sql/schema.sql` 追加段有文本冲突，保留了两边 |
| Gateway | `feat/data-scope-d2` | 真实进程 |
| Starter + `kaiwu-data-scope` | `feat/data-scope-d3`（含本次修复） | 示例服务依赖 `0.1.1-SNAPSHOT` |
| 示例服务 | 用集成分支的项目工厂模板生成 `demo-crm`，按 Skill 接入 `crmcustomer:crmcustomer` | 不提交到任何仓库 |

## 与提示词的差异：没有用 Compose 全栈

本机 colima 只有 **1.9 GiB**，且与 Vaultwarden 共用；仓库自带的 `project-up` 在低于 4 GiB 时直接拒绝，记录里也写过
2 GiB 下平台 MySQL 会被 OOM 杀掉。所以**没有重启或调大 colima**，改用更轻的拓扑：

- 容器只有两个：MySQL 8.4（`--memory=700m`，buffer pool 96M，performance_schema 关）与 Redis（`--memory=64m`），
  合计常驻约 140 MiB；
- System、Gateway、示例服务是宿主机上的三个 Java 进程（Nacos 关闭，用 `application-local.yml`）；
- 数据库迁移用 Flyway Java API 对同一份 `sql/increment` 跑到 V118（含 C3 的 V118–V120）。

这条链路里的 Gateway、System、Starter、数据范围模块、示例服务都是真实代码、真实 HTTP；缺的只是容器化与网络隔离。
联调结束后两个容器已删除。

## 环境

部门树：总部 → 销售一部 → 销售一部-华东组；总部 → 销售二部。用户（项目内角色 / 范围 / 所属部门）：

| 用户 | 角色 | 范围 | 部门 |
|---|---|---|---|
| alice | sales-self | SELF（未配置） | 华东组 |
| bob | sales-manager | DEPT_AND_CHILD | 销售一部 |
| carol | sales-director | ALL | 总部 |
| dave | sales-self | SELF | 销售二部 |

角色、菜单、受控资源与角色范围全部来自 `kaiwu/roles.yml`、`menus.yml`、`data-scopes.yml`，经
`/api/projects/{id}/manifest/plan` + `apply`（`applyAccess=true`）一次写入——这同时验证了 D1 的清单同步与 ADR 0042 移交。

## 行数对照表（场景 1）

数据：alice A1 A2；bob B1 B2；carol C1；dave D1 D2（均由本人经 API 创建，归属由 Context 写入）。

| 用户 | 列表 | 列表 total | count | 导出 | Agent 读 | 预期 |
|---|---|---|---|---|---|---|
| alice (SELF) | A1 A2 | 2 | 2 | A1 A2 | A1 | 仅本人 |
| bob (DEPT_AND_CHILD) | A1 A2 B1 B2 | 4 | 4 | A1 A2 B1 B2 | A1 B1 B2 | 本人 + 销售一部及下级（含华东组 alice 的） |
| carol (ALL) | 全部 7 行 | 7 | 7 | 7 行 | 6 行 | 全部 |
| dave (SELF) | D1 D2 | 2 | 2 | D1 D2 | D1 D2 | 仅本人 |

列表、总数、count、导出四者对每个用户完全一致。Agent 一列取自 alice 删除 A2 之后的快照，所以比列表少对应的行，
与同一时刻的 HTTP 导出逐用户一致（脚本输出 `same`），见下文「Agent」。

### 详情 / 修改 / 删除（HTTP 状态码）

| 操作者 → 目标 | 详情 | 修改 | 删除 |
|---|---|---|---|
| alice → A1（自己的） | 200 | 200 | — |
| alice → B1（bob 的） | **404** | **404** | **404** |
| alice → D1（dave 的） | **404** | **404** | — |
| alice → A2（自己的，删除） | — | — | 200 |
| bob → A1（华东组，子部门） | 200 | 200 | 200（场景 2 中删除，carol 随后看不到） |
| bob → B1（自己的） | 200 | 200 | — |
| bob → D1（销售二部，范围外） | **404** | **404** | **404** |
| carol → A1 / D1 | 200 | 200 | — |

越权一律 404，不泄露「数据存在」。

## Agent 读能力与 HTTP 一致

示例服务注册一个只读能力 `demo-crm.customer.list`（`ROLE_SCOPED`），**复用同一个 Service**，Handler 里没有任何范围代码。
Agent Context 由 **Gateway 的真实签发代码** `GatewayContextIssuer.issueForAgent` 生成（输入是 System 真实返回的
`project-access` 快照），再 POST 到示例服务的 `/api/internal/agent/capabilities/{code}/invoke`。
场景 1 之后与场景 3 之后各比一次，四个用户的 Agent 结果与同一时刻 HTTP 导出的集合完全相同。

局限：Agent Context 是脚本调用 Gateway 的签发类生成的，**没有走 Gateway 的 `/api/internal/agent/delegate` 与 System 的
`agent-access` 审批**（那需要注册并审核能力、会话和 AI 模型）。D2 的单元测试已覆盖 delegate 对 `ds` 的透传。

## 改角色范围的生效时间（场景 2）

管理员把 `sales-self` 的范围改成 `CUSTOM_DEPT(销售二部)`，轮询 alice 的行数（1 → 3）：

| 变更 | 观察到生效耗时 |
|---|---|
| 首次测量（缓存已有一段时间） | 9.4 s |
| 重新测量 | 24.8 s |
| 还原为仅本人（缓存刚刷新） | 31.0 s |

最坏情况 = Gateway 30 秒本地缓存 + 轮询粒度 1 秒 + 调用耗时，与契约一致。**「30 秒内」是上限而不是保证值**，会略超过 30 秒。

## 调岗交接（场景 3）

1. alice 从华东组调到销售二部；立即与等过缓存期（32 秒）后她都**仍能看到 A3**（可见性跟归属人走，符合预期）。
2. 反例：
   - alice 调用批量转移 → **403**（没有 `transfer` 权限）；
   - bob 转给非成员 erin → **400**；
   - bob 转给 carol 但部门写销售二部（不是 carol 的所属部门）→ **400**；
   - bob 转移 dave 名下的行（不在 bob 范围内）→ **200，转移 0 行**。
3. bob 把 alice 名下转给 dave（销售二部）→ 200，转移 **1 行**。
4. 转移后：alice 看不到任何行；dave 看到 A3 D1 D2；bob 的范围不再含 A3（它现在属于销售二部）；carol 仍全部可见。
   库里 A3 的归属人为 dave、部门为销售二部。

成员校验走的是真实链路：示例服务 → `SystemMemberDirectory` → System 的 `placement`（带 `member:read` 项目服务凭据）。

## Context 字节数

| 用户 | Gateway Context（JWT 字符数） | 其中 `ds`（紧凑 JSON 字节） | Agent 单次 Context（字符数） |
|---|---|---|---|
| alice (SELF) | 1182 | 127 | 1498 |
| bob (DEPT_AND_CHILD，2 个部门) | 1294 | 173 | 1610 |
| carol (ALL) | 1237 | 129 | 1552 |
| dave (SELF) | 1182 | 127 | 1498 |

远低于 16 KiB 上限。`ds` 的体积随可见部门数线性增长，与 D2 的体积实测（128 个部门约 5.9 KB）一致。

## 联调发现的问题（按严重程度）

1. **【严重，已修复】`selectOne(wrapper)`、游标、`ResultHandler` 查询整条绕过数据范围，且没有任何报错。**
   示例服务的详情接口让 alice 读到了 bob 的客户（HTTP 200）。根因：MyBatis-Plus 3.5.17 的这些路径不经过
   `Executor.query`，而 D3 把 SELECT 改写放在 `beforeQuery`。D3 的 40 项测试都没覆盖。
   修复（Starter `8e01268`）：所有语句统一在 `StatementHandler.prepare` 改写；新增 `selectOne`、游标回归用例。
   **这也是生成的 CRUD 模板默认就会用到的路径**（生成的 `get(id)` 就是 `selectOne`）。
2. **【已修复】`reassign` 的新归属不合法返回 500。** 新增 `DataScopeReassignRejectedException`（Starter `6ac9e2c`），
   Service 翻译成 400；其它数据范围异常保持 5xx。Skill 已补充。
3. **【已修复，见 `data-scope-generator.md`】生成器对带 `owner_user_id` 的表会自带「只看自己」的手写逻辑**：Service 里 `eq(ownerUserId, currentOwnerId())`、
   `SaveRequest` 里带 `ownerDeptId`、创建时 `setOwnerUserId`。这与数据范围是两套机制，接入时必须按 Skill 手工删除，
   否则手写条件会盖住角色配置。门禁第 4 条会抓到 `SaveRequest` 里的归属字段，但抓不到 Service 里的手写过滤。
   建议后续让生成器在表声明为受控资源时不再生成这些逻辑，并把它登记为一条门禁。
4. **【已修复】生成项目的 `application.yml` 没有排除 `/api/internal/agent/**`**，开启 Agent 执行后该入口会被普通 Context
   拦截器挡成 401；示例服务里手工加了排除。
5. **【已修复】生成的 Service 不设置 `created_at`**，而 DDL 是 `NOT NULL` 无默认值，创建接口直接 500；示例服务里手工补了。
6. **【约束】`kaiwu.service-credentials.multi-enabled` 默认关闭**，不打开就签发不出 `placement` 需要的 `member:read` 凭据；
   本地联调时通过环境变量打开。线上启用前需要单独评估（它属于 C5）。
7. **【限制】MyBatis 二级缓存**的缓存键不含数据范围，对受控 Mapper 不能启用（已写进 `data-scope/README.md`）；
   启动自检目前不会检查这一点。

## 测试覆盖与没有覆盖

- 覆盖：D1 清单同步与角色移交、D1 管理接口、D2 `ds` 透传、D3 全部改写规则、D3 成员查询、D5 模板与门禁（在生成项目上
  以正例与反例逐条验证）、Agent 读路径、30 秒生效、调岗交接。
- 没覆盖：
  - 达梦；
  - 真实的 Compose / Kubernetes 部署与网络隔离；
  - 多副本 Gateway（缓存各自独立，生效时间上限不变）；
  - Web 角色页（D4 未做）；
  - Agent 的写路径与完整 delegate 审批；
  - 并发压力与性能。
- 联调用的脚本与示例项目在会话临时目录，没有入库。
