# Data Scope 端到端联调（可重跑）

一条命令，对着**真实** System + Gateway + 示例业务服务 + MySQL + Redis，验证行级数据范围从「角色配置」到「SQL 过滤」整条链路。
它是 D6 联调的可重跑版本：以后改 Starter、`kaiwu-data-scope`、Gateway 或 System 任何一处，都可以重跑它。

```bash
scripts/e2e/data-scope/run.sh            # 构建 + 启动 + 验证 + 清理，约 4 分钟
scripts/e2e/data-scope/run.sh --skip-build   # 复用已构建的 jar
scripts/e2e/data-scope/run.sh --keep         # 结束后保留整套环境便于排查（日志在 $E2E_WORK/logs）
```

退出码：`0` 全部通过；`1` 有场景失败（报告里逐条列出预期与实际）；`2` 环境问题。报告在 `$E2E_WORK/report.md`。

## 它依赖什么

| 变量 | 含义 | 默认 |
|---|---|---|
| `E2E_SYSTEM_DIR` | System 集成副本：必须含 D1（`feat/data-scope-d1`）+ D5 模板 + 成员查询（`feat/data-scope-members`，基于 C3） | 自动合成到 `$E2E_WORK/system`（`prepare-integration.sh`） |
| `E2E_GATEWAY_DIR` | Gateway，须含 D2（`feat/data-scope-d2`） | `../kaiwu-gateway-ds-d2` |
| `E2E_STARTER_DIR` | Starter 与 `data-scope` 模块，须含 D3 的修复（`feat/data-scope-d5`） | `../kaiwu-starter-ds-d5` |
| `E2E_WORK` | 工作目录（日志、临时密钥、状态） | `$TMPDIR/kaiwu-ds-e2e` |

本机需要：JDK 21、Maven、Docker（colima 即可，**约 1.5 GiB 内存够用**）、openssl、python3，以及本地镜像 `mysql:8.4`、`redis:7.4-alpine`。
端口 8080 / 8088 / 8316 / 23306 / 26379 必须空闲。

## 拓扑

```text
容器          MySQL 8.4（700 MiB 上限）  Redis（64 MiB）           ← 本次专用，结束即删
宿主机进程    System :8080   Gateway :8088   demo-crm :8316          ← 都是真实代码、真实 HTTP
```

没有用 Compose 全栈：本机 colima 内存太小（`project-up` 低于 4 GiB 直接拒绝）。缺的只是容器化和网络隔离，Nacos 关闭、走 `application-local.yml`。

## 做了什么

1. `Migrate.java`：用 Flyway 对同一份 `sql/increment` 跑到最新（含 V118、V119），**顺带验证整条迁移链在真实 MySQL 上可执行**；
2. `seed.py`：经平台 API 造部门树、用户、项目，用 `manifest/plan + apply` 写入菜单、角色、受控资源与**角色范围**（同时验证 D1 清单同步与 ADR 0042 移交），分配成员，签发 `member:read` 服务凭据；
3. `demo-crm/`：示例业务服务（**夹具，不是产品代码**）。里面没有任何范围代码，详情走 `selectOne`、列表走分页、Agent 读复用同一个 Mapper；
4. `scenarios.py`：逐条断言，写报告。

### 场景

| # | 内容 |
|---|---|
| 1 | 4 个用户的列表 / total / count / 导出 / Agent 读完全一致，且符合 SELF、DEPT_AND_CHILD、ALL 的预期 |
| 1b | 详情 / 修改 / 删除：范围内 200，越权一律 404，越权删除没有真的删掉 |
| 2 | 管理员改角色范围后的生效时间（上限约 30 秒 Gateway 缓存） |
| 3 | 调岗后可见性跟归属人走；批量交接的 403 / 400 / 0 行 / 1 行；交接后各人的可见集合 |
| 4 | 管理端契约：角色范围读写与校验、内置角色只读、`project.data_scope.type` 字典、V119 文案进入目录 |
| 5 | 非成员 403；`ds` 与 Agent Context 的字节数 |

## 它自己的局限（请读）

- **编号撞车（暂时）**：Data Scope 先于 Workflow 合入 dev，迁移是 V118、V119；成员查询分支 `feat/data-scope-members` 基于 Workflow C3，带着 V118–V120。
  在 Workflow 链顺延编号之前，把两者合成集成副本会出现重复版本号，Flyway 会拒绝，脚本跑不起来。Workflow 顺延并重新 rebase `members` 之后恢复。

- **Agent Context 是脚本用 Gateway 的 Context 私钥签的**，声明集合照 `GatewayContextIssuer.issueForAgent`，`ds` 取自 System 真实返回的项目快照；
  **没有走** Gateway 的 `/api/internal/agent/delegate` 与 System 的 `agent-access` 审批（那需要注册并审核能力、会话和 AI 模型）。D2 的单元测试覆盖了 delegate 对 `ds` 的透传。
- 示例服务是手写夹具，不是项目工厂生成的；模板与门禁由 D5 的生成器测试覆盖（在 System 的 `./scripts/verify.sh` 里）。
- 只在 MySQL 上跑；不含达梦、多副本 Gateway、Agent 写路径、压测、浏览器 UI（Web 角色页由 `kaiwu-system-web` 的 Playwright 覆盖，那边接口是 mock）。
- 生效时间的断言上限放宽到 40 秒：理论上界是 30 秒缓存 + 轮询粒度，机器很卡时可能略超。

## 它能抓到什么：反例验证

2026-11-03 做过一次反例：把 `kaiwu-data-scope` 换回 D3 的旧拦截器（SELECT 改写放在 `beforeQuery`，`selectOne`/游标整条绕过范围），
本脚本 **42 项里 3 项失败、退出码 1**——alice 经详情接口读到 bob 与 dave 的客户（预期 404，实际 200）。换回修复后 42/42 通过。

这次反例还暴露了脚本自己的一个坑：示例服务若不 `clean package`，Maven 会拿旧 jar 冒充新依赖，反例就会「通过」。`run.sh` 已固定用 `clean package`。

## 排查

- 日志：`$E2E_WORK/logs/{system,gateway,demo,seed,migrate}.log`；
- `--keep` 保留环境后，清理：`docker rm -f ds-e2e-mysql ds-e2e-redis`，并 kill 打印出来的三个进程；
- 集成副本是 `git worktree`，不用了：`git worktree remove --force $E2E_WORK/system`；
- 脚本会把 Starter 与 `kaiwu-data-scope` 的 `0.1.1-SNAPSHOT` **安装到你本机的 `~/.m2`**（覆盖同名快照）。
