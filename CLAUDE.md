# Kaiwu System Service 开发约定

先读 `docs/ARCHITECTURE.md`、`docs/REQUIREMENTS.md`、`docs/adr/0003-gateway-centric-authentication.md`
与 `docs/NACOS.md`。

- 模块依赖固定为 `boot -> domain -> api`。
- System 是平台身份和权限唯一事实源，不承载业务项目代码。
- 正常业务请求不得由 Starter 回调 System。
- Gateway 的项目入口授权走 `/api/internal/gateway/project-access`（ADR 0022），
  凭 `KAIWU_GATEWAY_INTERNAL_TOKEN` 校验；Gateway 必须缓存结果，不得每请求同步调用。
- 数据库迁移只走 Flyway：新增 `sql/increment/V{n}__desc.sql`（版本号唯一、递增），由
  `docker-compose.yml` 的 `db-migrate` 服务用 `flyway/flyway` 镜像执行，历史落在
  `flyway_schema_history`。`V1__kaiwu_baseline.sql` 只初始化全新空库，后续变化从 V2
  开始追加。已发布的 V 脚本一律不可修改，修错只能追加新版本纠正。
  `sql/schema.sql` 是完整累积快照，运行时不执行，每次新增迁移需同步维护结构和 seed。
- Secret 不得写入仓库；Nacos bootstrap 凭据由环境变量注入，环境运行值由受保护的 Nacos
  Data ID 管理。
- `application.yml` 只做 Nacos bootstrap；`local` 运行配置放 `application-local.yml`，`dev`
  运行配置由 Nacos Data ID 管理。禁止把 Secret 放入 Nacos。
- 启动任何非 local 环境时，必须显式传入 `KAIWU_NACOS_SERVER_URL`、
  `KAIWU_NACOS_SERVER_ADDR`、`KAIWU_NACOS_NAMESPACE`、`KAIWU_NACOS_USERNAME`、
  `KAIWU_NACOS_PASSWORD`；不得在代码、Compose 或脚本中固化某环境地址、namespace 或账号。
  数据库、Redis、管理员首启密码和配置加密密钥从该环境 Nacos 的受管 Data ID 读取，日常启动
  不得要求调用者重复传入这些变量。
- 改动后执行 `./scripts/verify.sh`；脚本会先拒绝非 JDK 21 环境，再验证平台和当前生成模板。
  该脚本跑 `mvn verify`，spotless 绑在 `validate` 阶段：排版不合规会在编译前就失败，
  连编译都到不了。修复只有一条命令 `mvn spotless:apply`（palantirJavaFormat），
  不要手工对齐——手工对齐的结果和 palantir 的输出几乎不会一致。
- 提交前的固定动作：`mvn spotless:apply && ./scripts/verify.sh`。依据 ADR 0029。
