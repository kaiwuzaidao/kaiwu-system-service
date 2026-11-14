# Data Scope D6 可重跑脚本验证记录

2026-11-03。把 D6 联调写成入库的脚本 `scripts/e2e/data-scope/`（用法与局限见该目录 README）。本机、本地，**没有部署 test，没有推送**。
分支 `feat/data-scope-d6`，基于 `feat/data-scope-d5`。

## 被验证的组合

| 组件 | 分支 |
|---|---|
| System（集成副本，自动合成） | `feat/data-scope-d6` = D5 模板 + `feat/data-scope-d1`（含 D0、V118、V119）+ `feat/data-scope-members`（基于 C3） |
| Gateway | `feat/data-scope-d2` |
| Starter + `kaiwu-data-scope` | `feat/data-scope-d5`（含 D3 与对它的修复） |
| 示例服务 | `scripts/e2e/data-scope/demo-crm/`（夹具，入库） |

## 结果

| 运行 | 结果 |
|---|---|
| 从零完整运行（合成副本、构建、迁移、种子、场景） | **42 / 42 通过**，退出码 0，约 4 分钟；结束后容器与进程均已清理 |
| 同一工作目录 `--skip-build` 再跑 | 42 / 42 通过（证明可重复运行，不依赖上一次残留） |
| 最终复核（修好 `clean package` 后从零再跑） | 42 / 42 通过 |
| **rebase 到 d5 最新（`f116729`，含带归属列的表的自动生成）后从零再跑** | **42 / 42 通过**，退出码 0；生效耗时扩大 29.0 s、收窄 30.0 s |
| **反例**：把 `kaiwu-data-scope` 换回 D3 旧拦截器 | **39 / 42，退出码 1**：alice 读 bob、dave 的客户详情得到 200（预期 404）；换回修复后 42/42 |

反例证明脚本抓得到当初的那个严重绕过（`selectOne` 不经 `Executor.query`），并非空跑。

## 相对第一版 D6 记录新增覆盖

- **整条迁移链在真实 MySQL 上执行到 V119**（121 个脚本，含 C3 的 V118–V120、D1 的 V118 与 D4 配套的 V119）；
- **V119 的字典 `project.data_scope.type` 与 27 条界面文案**由运行中的 System 对外提供（场景 4）；
- 管理端契约：角色范围读写、内置角色只读、非法类型 400 且错误键为 `api.project.dataScopeInvalid`、内置角色保存 400；
- 非成员经 Gateway 访问 403；
- 详情接口显式用 `selectOne(wrapper)`，列表用分页，Agent 读复用同一个 Mapper。

## 联调中发现的新问题（按严重程度）

1. **【脚本自己的缺陷，已修】示例服务不 `clean package` 会用旧 jar**：Maven 不会因为依赖（Starter / data-scope）变了就重打包。
   第一次反例因此「通过」了 42 项——幸好做了反例才发现。`run.sh` 现固定 `clean package`。
2. **【文档错误，已修】契约里的部门编码示例是大写（`SALES-EAST`）**，而平台部门编码格式是 `[a-z][a-z0-9-]{1,63}`，
   大写编码在真实环境里永远解析不到（`roles.yml` 导入会 400）。已改为小写（D1 分支 `0582b29`）；单元测试里仍有大写的 mock 值，不影响结论。
3. **【既有行为，未改】`GET /api/public/i18n/catalog` 只有登录页用的一小部分文案**（37 条），完整目录在登录后的 `/api/i18n/catalog`。

## 与第一版 D6 记录的差异

- 第一版的 Agent 对照取自「alice 删除 A2 之后」的快照；这次直接在同一时刻对比列表、count、导出、Agent，四者一致。
- 第一版用 `demo-crm` 由项目工厂模板生成；这次用入库夹具，模板由 System 的 `./scripts/verify.sh`（D5 生成器测试，含正反例门禁）覆盖。
  所以**「生成的 CRUD 默认路径」不再被联调覆盖**，只靠夹具里的 `selectOne` 近似。
- 生效耗时：扩大 / 收窄分别约 29～30 秒，与第一版的 9～31 秒一致，上限仍是 Gateway 的 30 秒缓存。

## 没有覆盖

- 达梦；多副本 Gateway；Agent 写路径与完整 delegate 审批（Agent Context 由脚本照声明集合签发，`ds` 取自真实快照）；压测。
- 浏览器 UI：D4 的 Web 页由 `kaiwu-system-web` 的 Playwright 覆盖，那边接口是 mock；本脚本只覆盖其依赖的后端契约。
- 本脚本需要 `mysql:8.4` 与 `redis:7.4-alpine` 本地镜像，内网首次需要手工 pull + tag。
- 脚本会覆盖本机 `~/.m2` 里 `0.1.1-SNAPSHOT` 的 Starter 与 `kaiwu-data-scope`。
