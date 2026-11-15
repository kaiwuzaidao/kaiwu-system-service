# Kaiwu System Service

这是 Kaiwu 平台控制面后端，也是统一启动逻辑的事实源。第一次接触开源项目，推荐先从同一
组织下的 `kaiwu` 主页仓库执行 `./kaiwu up`；直接克隆本仓仍可使用下面的开发者入口。

## 直接从本仓启动

准备 Git、Docker Compose v2、OpenSSL 和 curl。在当前 GitHub 页面点击 **Code**，复制本仓库地址：

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
export KAIWU_REPOSITORY_REF='v0.2.0'       # 可选；Release 默认会自动选择同名 tag
./scripts/kaiwu.sh repositories            # 先确认将要访问的地址
./scripts/kaiwu.sh up
```

工作区实际 commit 会记录到相邻 `.kaiwu/workspace.lock`，方便反馈问题时确认已获取仓库的版本；该运行文件
不进入任何 Git 仓库。

## 用 AI Coding 工具继续开发

也可以用 Codex 或 Claude Code 打开本仓库，直接提出
“初始化并启动 Kaiwu”。项目内置的 [Kaiwu Development Skill](docs/AGENT_DEVELOPMENT.md)
会完成环境检查、四仓初始化、启动、任务路由和按改动验证。

```text
kaiwu-system-boot -> kaiwu-system-domain -> kaiwu-system-api
```

本仓库不承载生成业务项目的业务模块或业务表。

平台提供以下能力：

- 用户名密码登录、Access JWT、Refresh Token、登出撤销。
- Redis 在线会话与 MySQL 会话审计事实。
- 从 v0.1.0 升级见 [升级说明](docs/UPGRADING.md)。
- 依赖 `com.kaiwuzaidao:kaiwu-system-starter`，依赖版本见根 pom 的 `kaiwu-system-starter.version`。
- `/api/platform/probe` 使用 `@RequirePermission("system:platform:read")`。
- 用户分页、创建、编辑、启停和管理员重置密码；支持 Excel 导入导出、批量启停和多部门归属。
  组织页通过受权限保护的 `GET /api/org/user-departments?userIds=...` 批量读取最多 100 位
  用户的主部门与兼任部门，避免逐用户请求。
- `system` 是不可停用、不可归档的内置项目；Kaiwu 自身成员、系统角色、平台菜单与
  登录权限全部在该项目的权限中心管理。
- system 成员、角色授权或平台菜单发生变化时，撤销受影响用户的 MySQL/Redis 在线会话。
- 内置 `project-admin` 始终拥有 system 项目全部节点且不可编辑、停用或重授权，
  避免切断平台管理入口。
- 项目登记、编辑、启停和归档；项目创建人自动成为内置项目管理员。
- 每个项目有自己的编码、基础包名、成员角色和业务后台入口，生成前后端双制品后由业务团队维护。
- 项目成员支持多项目角色；system 项目角色控制平台，其余项目角色只控制所属业务项目。
- 项目菜单支持树维护和按项目角色授权；当前用户接口只返回本人可访问的项目、菜单和权限。
- 所有运行态菜单与角色授权都进入 `sys_project_*`：system 项目承载 Kaiwu 平台菜单，
  业务项目承载各自菜单，全部以 `project_id` 为边界。legacy `sys_role/sys_menu`
  仅保留为兼容种子，不再是登录鉴权事实源。
- 项目管理接口属于平台控制面；业务请求经显式 PROJECT Route 校验项目成员身份，再由业务服务执行权限与资源归属检查。
- 全局/项目级应用配置，项目值覆盖全局值；敏感配置 AES-GCM 加密，管理端只返回掩码，
  业务有效配置接口永不返回敏感项。
- 全局/项目级字典类型和字典项，支持项目继承全局并按字典值覆盖，未知值由前端原样显示。
- 根据项目编码、名称和基础包名等配置，用确定性模板生成前后端基础脚手架；产物包含
  工程配置、平台清单、`AGENTS.md` 和 `CLAUDE.md`，可下载 ZIP 后在独立业务仓继续开发。
- 代码生成会把三端同码权限幂等登记到所选项目的菜单树，并只自动授予该项目内置
  `project-admin`。项目成功生成一次后，后续权限通过清单同步维护。
- 生成任务的查看、重试和下载按创建人隔离；通过 ZIP 或 CLI 取回业务源码。
- 登录成功/失败/登出日志与用户写操作审计；被动下线（管理员强制、改密码踢其它会话）
  只记操作审计，不写登录日志。
- 安全运营中心提供登录/操作日志、在线会话和强制下线；顶栏搜索按权限过滤项目、交付和用户。
- 项目开通向导串联项目、成员角色与一次性生成；项目工厂汇总生成状态和前后端制品。

Starter、Data Scope 和 Excel 的 0.2.0 制品已发布到 Maven Central。直接构建本仓时，准备 JDK 21、Maven 和可用的 Docker（数据库契约测试使用 Testcontainers），再运行：

```bash
./scripts/verify.sh
```

本地 Compose：

```bash
./scripts/kaiwu.sh up
./scripts/kaiwu.sh status
./scripts/kaiwu.sh logs
./scripts/kaiwu.sh down
```

在 IDE 中调试平台源码时，使用混合开发模式。MySQL 和 Redis 在 Docker 中运行，System、Gateway 和 Web 在本机运行：

```bash
./scripts/kaiwu.sh down
./scripts/kaiwu.sh dev
```

本机需要 JDK 21、Maven、Node.js 和 pnpm。已由部署方托管 MySQL、Redis 和 Nacos 的环境可以使用
`local-up`，配置步骤见 [Nacos 本机直启](docs/NACOS.md#无-docker-的本机直启)。

验收脚本：

```bash
./scripts/verify-auth.sh
./scripts/verify-change-password.sh
./scripts/verify-users.sh
./scripts/verify-projects.sh
./scripts/verify-metadata.sh
./scripts/verify-project-factory.sh
```

Compose 使用仓库 Maven settings 配置的 Central 镜像及 npm 公共仓库下载依赖。受限网络可通过 Maven settings
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
