# Kaiwu System Service Agent Contract

> **工具级流程看这里**：初始化、启动、四仓路由、按改动验证的完整步骤在
> `.agents/skills/kaiwu-development/SKILL.md`。本文件是本仓的**约束**，那份是**流程**。
>
> 本文件即跨工具兜底入口——任何会读 `AGENTS.md` 的工具无需任何额外适配文件就能顺着
> 这条指引拿到全部流程。只认自己私有规则路径的工具（Cursor、Trae 等）才需要一层薄转发，
> 用 `.agents/skills/kaiwu-development/scripts/kaiwu-agent.sh adapters add <tool>` 按需生成，
> 不再预先铺在仓库里。

- 禁止直接在 `main` 等受保护分支实现；保留调用者当前分支，必要时创建描述性 feature/fix 分支。
- 先读本仓 `CLAUDE.md`、`docs/ARCHITECTURE.md` 与相关 ADR。
- 修改 Nacos、local 或 Compose 配置前，先读 `docs/NACOS.md`；发布脚本必须读回校验 Data ID。
- 环境选择只由启动时传入的 Nacos URL、Client 地址、namespace、账号和密码决定；禁止回填任一
  环境默认值。MySQL/Redis 等运行值由该 namespace 的受管 Nacos Data ID 提供。
- 不引入 Workflow、Integration、AI Harness、发布中心或 SHARED 模式。
- API 只放稳定 DTO/VO；Domain 放业务实现；Boot 只装配启动。
- 权限码必须与前端 AuthButton、menu.sql BUTTON 三端同码。
- 数据层只用 MyBatis-Plus（ADR 0017、ADR 0020），`ArchitectureConventionTest` 会拦住 JdbcTemplate
  与第二套 ORM。单表 CRUD 走 `BaseMapper`；多表 JOIN、动态条件、报表等复杂查询优先使用
  Mapper XML。现有授权、状态机守卫、MySQL 专有函数与乐观锁注解 SQL 不做机械迁移。
- **可清空字段的编辑必须用 `LambdaUpdateWrapper` 显式 `set()`**。MyBatis-Plus 的
  `updateById` 和 `update(entity, wrapper)` 都只把非 null 字段写进 SET，用实体更新会让
  「清空邮箱 / 清空路由 / 清空描述」静默失效——界面显示保存成功，值还是旧的。
- **一张表只有一份实体**（由 `ArchitectureConventionTest` 按 `@TableName` 判重）。跨模块只需
  读写某表少数几列时，用注解 SQL，不新建第二份实体；复合主键关联表不继承 `BaseMapper`
  （否则得在实体里标一个假主键）。
- **Controller 不得直接依赖 Mapper，也不得返回数据库实体**：实体贴表结构，直接外发会让表的
  每次演进变成前端破坏性变更，也容易顺手带出不该外发的列。
- 授权链路、状态机守卫（`WHERE ... AND status = 'RUNNING'`）、MySQL 专有函数与乐观锁
  条件一律保持原样 SQL，不要改写成条件构造器（ADR 0017 第 4 节）。
- 公共 API、SPI、Port、安全边界和难以从签名理解的行为写 Javadoc；普通 public 方法不以
  注释数量阻断构建。写“为什么”和边界，不写 `/** 保存配置 */` 这类重复签名的填充物。
- 每次交付记录真实测试证据，不把文档决策描述成已运行能力。
- Mockito 单元测试证明不了 SQL 与字段映射正确；`MySqlDataLayerContractTest` 会用
  Testcontainers 的一次性 MySQL 执行完整 Flyway 迁移并校验高风险 Mapper。它需要可用 Docker，
  缺失 Docker 必须失败而不是跳过；绝不连接开发库或共享库。

## 构建与验证

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export MAVEN_SKIP_RC=1
# Testcontainers 要能找到 Docker。本机是 Colima，socket 不在默认的 /var/run/docker.sock，
# 不设这两个变量 MySqlDataLayerContractTest 会直接报「Could not find a valid Docker environment」。
# Docker Desktop 用户通常无需设置；用 `docker context inspect` 确认自己的 socket 路径。
export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock

mvn -s .mvn/settings.xml verify
```

## 门禁清单

改动落地前这些必须全绿；每一道都对应一类「运行期才会暴露、且不容易被发现」的失败。

| 门禁 | 在哪跑 | 挡住什么 |
|---|---|---|
| `ArchitectureConventionTest` | `mvn verify` | 架构漂移：数据层回退 JdbcTemplate/第二套 ORM、Controller 直连 Mapper、Controller 返回实体、一张表两份实体（ADR 0017） |
| ErrorProne | `mvn compile` | 编译期真实缺陷：分支重复、断言结果被丢弃、格式化串参数不匹配等 |
| `MySqlDataLayerContractTest` | `mvn verify`（需 Docker） | 字段映射、`IdType`、时区与类型转换错误——Mockito 测试碰不到这些 |
| `MigrationConventionTest` | `mvn verify` | Flyway 版本号撞号、文件名不可解析、新 seed ID 落进运行期动态段（V27 事故） |
| `check-test-baseline.sh` | **仅生成项目** CI | 默认警告 Controller/Service 缺同名测试；模板自验用 `--strict` 防止首版骨架丢失 |
| `pnpm check:perm` | `kaiwu-system-web` | 权限码三端不同码、菜单 seed 缺失 |
| `pnpm check:dict` | `kaiwu-system-web` | 新增字典缺前端 fallback |
| `pnpm check:dict-usage` | `kaiwu-system-web` | 页面写 `valueEnum`、或用 `<Tag>` 手工映射状态颜色而不走 `DictTag` |
| `pnpm check:i18n` | `kaiwu-system-web` | 缺译文、缺菜单翻译来源、后端错误码缺资源、UI 硬编码文案 |
| `pnpm check:architecture` | `kaiwu-system-web` | 前端分层反向依赖、跨页 import、绕过 `services/` 直接发请求、硬编码后端地址、页面 index 兼做组件库 |
| `scripts/check-flyway-compatibility.sh` | **起栈时**（Compose 的 `schema-compat-check`，需数据库连接） | 数据库当前版本高于代码迁移线时拒绝启动；**它不查版本号撞号** |
| `scripts/verify-*.sh` | 起栈后手工 | 真实链路上的行为回归——单元测试证明不了 SQL 是对的 |
