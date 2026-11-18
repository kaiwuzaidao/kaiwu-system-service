# Kaiwu System Service

这是 Kaiwu 平台控制面后端，也是统一启动逻辑的事实源。第一次接触开源项目，推荐先从同一
组织下的 `kaiwu` 主页仓库执行 `./kaiwu up`；直接克隆本仓仍可使用下面的开发者入口。

## 直接从本仓启动

准备 Git、Docker Compose v2 和 OpenSSL。在当前 GitHub 页面点击 **Code**，复制本仓库地址：

```bash
git clone <刚复制的仓库地址>
cd kaiwu-system-service
./scripts/kaiwu.sh doctor
./scripts/kaiwu.sh up
```

启动器会从本仓库所在的同一个 Git 组织获取另外三个运行仓库。若当前 System 位于 Release tag，
其他仓库会自动使用同名 tag；开发态使用各仓默认分支。随后它会生成仅保存在工作区外的本地
密钥、执行 Flyway，并启动完整平台。

看到三个 `✓` 后打开 [http://127.0.0.1:8000](http://127.0.0.1:8000)。账号和随机初始密码会
直接显示在终端，也可随时执行 `./scripts/kaiwu.sh credentials` 查看。

| 你现在想做什么 | 继续阅读 |
| --- | --- |
| 第一次体验并创建项目 | [从零开始快速使用](docs/QUICKSTART.md) |
| 先看懂项目定位和架构 | [10 分钟看懂 Kaiwu](docs/OVERVIEW.md) |
| 部署到一台服务器 | [传统服务器部署](docs/SERVER-DEPLOYMENT.md) |
| 部署到 Kubernetes | 先执行 `./scripts/kaiwu.sh deploy-init`，再看 [Kubernetes 部署](docs/KUBERNETES.md) |

`kaiwu-deploy` 只服务 Kubernetes/GitOps，不属于首次体验依赖。使用 Fork、镜像组织或自建 Git
服务时，可以显式指定仓库来源和版本：

```bash
export KAIWU_REPOSITORY_BASE_URL='https://github.com/kaiwuzaidao'
export KAIWU_REPOSITORY_REF='v0.3.0'       # 可选；Release 默认会自动选择同名 tag
./scripts/kaiwu.sh repositories            # 先确认将要访问的地址
./scripts/kaiwu.sh up
```

工作区实际 commit 会记录到相邻 `.kaiwu/workspace.lock`，方便反馈问题时确认五仓版本；该运行文件
不进入任何 Git 仓库。

## 用 AI Coding 工具继续开发

也可以用 Codex 或 Claude Code 打开本仓库，直接提出
“初始化并启动 Kaiwu”。项目内置的 [Kaiwu Development Skill](docs/AGENT_DEVELOPMENT.md)
会完成环境检查、四仓初始化、启动、任务路由和按改动验证。

```text
kaiwu-system-boot -> kaiwu-system-domain -> kaiwu-system-api
```

本仓库不承载生成业务项目的业务模块或业务表，只提供统一的平台控制面与确定性交付底座。

## 核心能力（v0.3.0）

| 能力域 | 说明与关键特性 | 相关文档 |
| --- | --- | --- |
| **统一身份与项目级 RBAC** | 用户名密码登录、RS256 Access JWT + HttpOnly Refresh 轮换、Redis 在线会话与安全运营强制下线；内置不可停用的 `system` 项目遵循同一套 `sys_project_*` 权限事实源，业务项目支持项目内自助成员与角色授权（`access-admin`） | [架构设计](docs/ARCHITECTURE.md) · [项目接入](docs/PROJECT_ACCESS.md) |
| **按角色 × 部门的行级数据范围** | 支持 `ALL`、`DEPT_AND_CHILD`、`DEPT`、`SELF`、`CUSTOM_DEPT` 与多角色并集归约；System 计算快照经 Gateway 写入签名 Context 的 `ds` 字段，由业务端 `kaiwu-data-scope` 在 SQL 层自动过滤，请求链路零回调 | [数据范围契约](docs/DATA_SCOPE.md) · [ADR 0044](docs/adr/0044-project-data-scope.md) |
| **产品前端纳管与确定性项目工厂** | 支持**产品先出前端**（`project adopt` 纳管 `kaiwu-web-starter` 前端、导入清单与初始角色并生成配套后端，`ADOPT_FRONTEND`）与**基础双仓脚手架**（`BASIC_SCAFFOLD`）两种一次性交付，产出自带 `AGENTS.md` 与校验门禁，之后平台永久退出写入权 | [项目工厂](docs/PROJECT_FACTORY.md) · [ADR 0048](docs/adr/0048-adopt-existing-frontend.md) |
| **声明式清单同步与跨环境配置移交** | 业务仓维护 `kaiwu/*.yml` 并经 `./kaiwu project sync` 预览差异后幂等同步；支持从测试到生产导出 6 类 YAML 全量快照（字典、参数、菜单、含 `dataScopes` 的角色、定时任务、项目多语言），按业务键对齐、三方基线比对 + 409 并发守卫，**角色授权按组确认、删除逐项勾选、新建定时任务默认停用** | [ADR 0036 清单同步](docs/adr/0036-platform-manifest-sync.md) · [ADR 0042 配置移交](docs/adr/0042-project-config-handover.md) |
| **受管字典、参数与项目级国际化** | 全局作底、项目覆盖；敏感参数 AES-256-GCM 加密且不下发给业务接口；全面采用引用式多语言并按 `scope_id` 隔离项目与平台译文，消除内联 JSON“双真相源”漂移且项目间互不泄露 | [ADR 0015](docs/adr/0015-referenced-i18n-is-the-only-multilingual-path.md) · [ADR 0037](docs/adr/0037-project-scoped-i18n-resources.md) |
| **对象存储 (STS) 与统一待办/调度** | 长期 AK/SK 加密留平台，按项目 `{bucket}/{projectCode}/*` 前缀签发 STS 临时凭证；`TodoClient` 按 `bizKey` 幂等表达或签/会签/逾期置顶；租约抢占式分布式调度（含多副本 `fencingToken` 协作栅栏） | [ADR 0039 对象存储](docs/adr/0039-project-object-storage-via-sts.md) · [统一待办](docs/UNIFIED_TODO.md) |
| **受控跨项目 AI 助手** | `PLAN`（任务识别）与 `ANSWER`（回答）多模型路由、按个人隔离的历史会话与显式记忆；业务项目显式注册版本化读写能力，写操作先只读预览冻结版本、用户确认后通过事务账本幂等执行 | [ADR 0043](docs/adr/0043-agent-multi-model-routing.md) · [ADR 0030](docs/adr/0030-agent-cross-project-capabilities.md) |
| **MySQL 与国产达梦 DM8 双库基线** | 控制面首次安装可选 MySQL 8 或达梦 DM8，配备独立 `kaiwu-dm-migrator` 容器与迁移前实例参数校验 | [数据库配置](docs/DATABASES.md) · [ADR 0048](docs/adr/0048-platform-mysql-and-dameng.md) |
| **CLI 设备授权与安全运营** | `./kaiwu login` 免接触用户密码（支持 `/device` 网页确认与受限 `CliSessionScope`）、登录/操作审计、在线会话强踢、顶栏跨模块授权搜索 | [ADR 0035](docs/adr/0035-cli-device-authorization.md) |

## 本地开发与源码构建

`com.kaiwuzaidao:kaiwu-system-starter`、`kaiwu-data-scope` 与 `kaiwu-excel` 的 `0.2.0` 正式制品已发布至 Maven Central。只有在本机修改了 Starter 源码并希望离线联调时，才需要先将本地 Starter 安装到本地 Maven 仓库：

```bash
./scripts/kaiwu.sh init
mvn -f ../kaiwu-system-starter/pom.xml -DskipTests install
mvn -s .mvn/settings.xml verify
```

本地 Compose：

```bash
./scripts/kaiwu.sh up
./scripts/kaiwu.sh status
./scripts/kaiwu.sh logs
./scripts/kaiwu.sh down
```

不使用 Docker、希望直接调试 Java/前端源码时，可改用 Nacos 本机进程模式：

```bash
# 在当前终端提供 Nacos Bootstrap 参数；MySQL、Redis 地址与凭据只在 Nacos Data ID 中配置。
export KAIWU_NACOS_SERVER_ADDR='nacos.example.internal:8848'
export KAIWU_NACOS_NAMESPACE='your-namespace-id'
export KAIWU_NACOS_USERNAME='your-account'
export KAIWU_NACOS_PASSWORD='...'
./scripts/kaiwu.sh local-up
```

该模式要求本机已有 JDK 21、Maven、Node.js + pnpm；脚本只启动 System、Gateway、Web，
三个应用以 `dev` profile 从 Nacos 分别读取 `kaiwu-system-service-dev.yml` 和
`kaiwu-gateway-service-dev.yml`。MySQL、Redis、Nacos 和 Flyway 历史均不由脚本管理。停止与查看：

```bash
./scripts/kaiwu.sh local-status
./scripts/kaiwu.sh local-logs
./scripts/kaiwu.sh local-down
```

本机模式只停止自身启动的应用进程，System/Gateway 均仅绑定 `127.0.0.1`；Nacos、MySQL、
Redis 和数据均不被修改。

首次执行会自动克隆缺少的相邻仓库、生成本地开发密钥并后台启动完整环境。详细说明见
[从零开始快速使用](docs/QUICKSTART.md)。底层手工启动仍可使用：

```bash
export KAIWU_MYSQL_ROOT_PASSWORD
export KAIWU_MYSQL_PASSWORD
export KAIWU_REDIS_PASSWORD
export KAIWU_BOOTSTRAP_ADMIN_PASSWORD
export KAIWU_CONFIG_ENCRYPTION_KEY
./scripts/dev-run.sh
```

验收脚本：

```bash
./scripts/verify-auth.sh
./scripts/verify-change-password.sh
./scripts/verify-users.sh
./scripts/verify-projects.sh
./scripts/verify-metadata.sh
./scripts/verify-project-factory.sh
```

Compose 默认使用 Maven Central 和 npm 公共仓库下载依赖。受限网络可通过 Maven settings
以及 `KAIWU_NPM_REGISTRY`、`KAIWU_NPM_STRICT_SSL` 覆盖镜像源。

`dev-run.sh` 在内存中生成两套开发态 RSA 密钥并通过环境变量注入容器。管理员只在空库
首次启动时创建；以后修改 `KAIWU_BOOTSTRAP_ADMIN_PASSWORD` 不会自动重置已有密码。

### Nacos dev 启动

`local` 保持不依赖 Nacos 的 Compose 黄金路径。需要验证部署同构的 Nacos 配置与服务注册时，
在同一终端注入目标环境的 Nacos bootstrap 参数后执行：

```bash
export KAIWU_NACOS_SERVER_URL='https://nacos-console.example.internal'
export KAIWU_NACOS_SERVER_ADDR='nacos-client.example.internal:8848'
export KAIWU_NACOS_NAMESPACE='target-namespace-id'
export KAIWU_NACOS_USERNAME='target-account'
export KAIWU_NACOS_PASSWORD='...'
```

```bash
./scripts/dev-nacos-run.sh
```

它会从受管 dev Data ID 获取本地运行值，再以 `dev` profile 启动同一套 Compose。RSA 私钥只在
脚本内存中生成。详细契约见
[docs/NACOS.md](docs/NACOS.md)。

首次安装请准备空库，Compose 会通过 Flyway 建表、写入内置数据并记录迁移历史。
[数据库初始化](sql/README.md) 提供 MySQL 和达梦各自的 DDL、DML 下载及执行顺序。
已有数据库请参阅[升级说明](docs/UPGRADING.md#数据库)。

## 文档

- [10 分钟看懂 Kaiwu](docs/OVERVIEW.md)
- [架构图谱：7 张图看懂项目生成、运行鉴权与部署方式](docs/ARCHITECTURE-GUIDE.md)
- [从零开始快速使用](docs/QUICKSTART.md)
- [传统服务器部署](docs/SERVER-DEPLOYMENT.md)
- [Kubernetes 部署、升级与回滚](docs/KUBERNETES.md)
- [使用 Codex 和 Claude Code 开发](docs/AGENT_DEVELOPMENT.md)
- [架构说明](docs/ARCHITECTURE.md)
- [Nacos 配置](docs/NACOS.md)

## License

本项目基于 [Apache License 2.0](LICENSE) 开源。

> 说明：仓库内亦包含用于后续多服务登记、受管待办协议与候选成员查询的实验性内部接口与开关（默认全部 `false` 关闭），未正式启用前不影响上述主链路；详细契约与验收约束见 `docs/verification/` 下的专题记录。
