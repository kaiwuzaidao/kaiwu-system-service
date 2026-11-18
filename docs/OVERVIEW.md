# 10 分钟看懂 Kaiwu

Kaiwu 是一个面向多项目治理与 AI 时代协同开发的后台控制面。它把用户组织、项目成员、角色与行级数据范围、
菜单与三端同码权限、受管字典、项目级引用式多语言、配置移交、对象存储 STS 凭据、统一待办、租约调度与
项目工厂/前端纳管集中在同一控制面中，而将业务源码和业务库彻底交给各项目独立交付。

## 两条最短体验路径

1. **产品先做前端演示（无需启动平台）**：克隆 [`kaiwu-web-starter`](https://github.com/kaiwuzaidao/kaiwu-web-starter)，用 `node scripts/kaiwu-init.mjs` 起一个带 `/__mock/` 多角色切换和规则验收门禁的独立 React 前端；验收后运行 `./kaiwu project adopt <前端仓> --apply` 一键纳管生成配套后端（[ADR 0048](adr/0048-adopt-existing-frontend.md)）。
2. **启动完整平台并创建双仓**：只需 Git、Docker（含 Compose v2）、OpenSSL 与 curl，从入口仓执行（或在本仓运行 `./scripts/kaiwu.sh up`）：

```bash
git clone https://github.com/kaiwuzaidao/kaiwu.git
cd kaiwu
./kaiwu doctor
KAIWU_DB_TYPE=mysql ./kaiwu up
```

首次安装也原生支持选择国产**达梦 DM8**（`KAIWU_DB_TYPE=dm`，详见 [数据库配置](DATABASES.md)）。启动后打开 `http://127.0.0.1:8000`，使用终端打印的 admin 初始密码登录。完整步骤和故障处理见 [从零开始快速使用](QUICKSTART.md)。

需要在 IDE 内直接调试、且已在 Nacos 配好 MySQL/Redis/路由运行配置时，可使用不依赖 Docker 的入口：`./scripts/kaiwu.sh local-up`（[Nacos 可选配置](NACOS.md)）。

## 请求如何流动

```text
浏览器
  │
  ▼
System Web :8000 / 业务 Web
  │ /api 或 /{code}-api
  ▼
Gateway :8088 ── 鉴权、会话校验、项目入口与 ds 声明签发
  │
  ▼
System Service :8080 / 业务 Service ── Starter 本地验签、@RequirePermission、SQL 行级数据范围
  ├── MySQL / 达梦 DM8：平台事实与 Flyway 版本（业务项目使用独立业务库）
  ├── Redis：在线会话与短期状态
  └── Artifact Volume：项目工厂生成制品
```

浏览器只访问前端同源入口，由 Gateway 验证身份并签发 60 秒 audience-bound 内部 Context 转发给 System 或业务 Service。MySQL、Redis 和内部服务默认不暴露到宿主机或公网。

## 核心仓库

| 仓库 | 定位 |
| --- | --- |
| `kaiwu` | 统一开源入口与 CLI 编排（含设备授权 `./kaiwu login`、项目同步与纳管命令） |
| `kaiwu-web-starter` | 零平台依赖的产品前端起步仓（内置 `/__mock/`、规则场景门禁与 `@/kaiwu` 接入层） |
| `kaiwu-system-web` | 平台管理前端（工作台、权限中心、配置移交、字典、国际化、项目工厂、AI 助手） |
| `kaiwu-gateway-service` | 统一外部入口（JWT、Redis 会话、项目入口与显式路由） |
| `kaiwu-system-service` | 平台控制面后端（组织权限、项目工厂/纳管、STS 存储、待办、调度、数据库迁移与 Helm Chart） |
| `kaiwu-system-starter` | 业务服务 SDK（含 `kaiwu-system-starter`、`kaiwu-data-scope` 与 `kaiwu-excel`） |

## 平台内置的企业级核心优势

除基础登录与项目管理外，Kaiwu 在控制面与 SDK 中内建了多团队与多环境上线的关键能力（均可按需启用）：

- **跨环境配置移交（[ADR 0042](adr/0042-project-config-handover.md)）**：从测试到生产导出 6 类 YAML 全量快照（字典、参数、菜单、含 `dataScopes` 的角色、定时任务、项目级多语言），按业务键对齐不耦合 DB ID；导入时基于上次基线做三方 diff 预览与 409 并发守卫，角色授权按组确认、删除逐项勾选，新建定时任务默认停用，导出的 YAML 也可直接写回代码仓。
- **清单声明式同步（[ADR 0036](adr/0036-platform-manifest-sync.md)）与 CLI 设备授权（[ADR 0035](adr/0035-cli-device-authorization.md)）**：AI 编码工具通过免接触密码的 `./kaiwu login` 授权并执行 `./kaiwu project sync` 预览同步 `kaiwu/*.yml`，不覆盖运营在线调整的当前值与人工译文。
- **行级数据范围（[DATA_SCOPE.md](DATA_SCOPE.md)）**：支持 `ALL`、`DEPT_AND_CHILD`、`DEPT`、`SELF`、`CUSTOM_DEPT`，经 Gateway 签名 Context 透传，业务端引入 `kaiwu-data-scope` 在 SQL 层自动过滤并配合构建门禁，防止 AI 编写接口时遗漏数据隔离。
- **对象存储 STS 凭证中心（[ADR 0039](adr/0039-project-object-storage-via-sts.md)）与安全 Excel**：长期 AK/SK 加密留在 System，业务服务仅领取前缀限定的临时凭证并只存 `storage_ref + object_key`（保留原绑定即可读取历史文件）；`kaiwu-excel` 提供防公式注入、防 ZIP 炸弹的单表格读写。
- **统一待办（[UNIFIED_TODO.md](UNIFIED_TODO.md)）与租约调度**：`TodoClient` 按业务键表达或签/会签/撤回/逾期置顶，业务状态真源留在业务库；租约调度内置协作式 `fencingToken` 防多副本重入。
- **项目级引用式多语言（[ADR 0037](adr/0037-project-scoped-i18n-resources.md)）**：按 `scope_id` 隔离各项目译文，消除内联 JSON“双真相源”漂移且项目间词条互不泄露。
- **受控项目 AI 助手（[ADR 0030](adr/0030-agent-cross-project-capabilities.md)、[ADR 0043](adr/0043-agent-multi-model-routing.md)）**：分离 `PLAN` 与 `ANSWER` 模型路由，按成员权限与行级数据范围执行已审核能力，写操作先预览冻结版本再确认入账。

## 从本地到 Kubernetes

本地和 Kubernetes 使用相同的应用镜像，没有第二套应用实现：

| 本地 Compose | Kubernetes |
| --- | --- |
| `.kaiwu/dev.env` | 已存在的 Kubernetes Secret |
| Compose MySQL / 外部达梦 DM8 | 演示 StatefulSet 或生产受管数据库 |
| `db-migrate` / `kaiwu-dm-migrator` | Flyway `initContainer` / 迁移 Job |
| Docker volume | PVC |
| `127.0.0.1:8000` | Ingress / TLS 入口 |

准备部署时先构建并推送或固定发行版 System、Gateway、Web 镜像，然后使用 [Kubernetes 部署与升级](KUBERNETES.md) 中的 Helm 命令。

## 文档入口

- [架构图谱：用 7 张图看懂 Kaiwu 的项目交付、运行鉴权与部署方式](ARCHITECTURE-GUIDE.md)
- [从下载到第一个业务项目](QUICKSTART.md)
- [项目工厂与前端纳管](PROJECT_FACTORY.md) · [数据范围契约](DATA_SCOPE.md) · [统一待办](UNIFIED_TODO.md)
- [传统服务器部署](SERVER-DEPLOYMENT.md) · [Kubernetes 部署、升级与回滚](KUBERNETES.md) · [数据库选择](DATABASES.md)
- [系统架构](ARCHITECTURE.md) · [Nacos 可选配置](NACOS.md) · [AI 协作开发](AGENT_DEVELOPMENT.md)
- [安全策略](../SECURITY.md) · [贡献指南](../CONTRIBUTING.md)
