# Kaiwu 项目工厂设计

> 状态：Accepted  
> 产品主入口：AI 生成第一版项目  
> 架构依据：ADR 0002、ADR 0003、ADR 0004、ADR 0006

## 1. 用户看到的流程

1. 在“项目管理”登记业务项目并配置成员、角色和菜单。
2. 项目管理员进入“项目工厂”，选择尚未生成的项目。
3. 默认选择“AI 生成项目”，填写业务描述：
   - 新项目可以只写描述；
   - 已有表结构可以粘贴 DDL；
   - 也可以临时连接 MySQL 获取结构，再确认导入的 DDL。
4. System 异步生成后端仓库 ZIP 和前端仓库 ZIP。
5. 用户在项目工厂统一查看生成与交付状态，可永久下载两个 ZIP；配置 GitLab 后，也可向项目登记的
   `defaultBranch` 显式执行一次初始推送。新项目默认 `main`，业务团队可在推送前修改。
6. 双仓推送完成后，“开始本地 AI Coding”提供 SSH/HTTPS 工作区初始化命令；开发者在同一父目录
   clone 两个独立仓库，再使用各仓的 `scripts/dev.sh` 完成本地环境检查和启动。
7. 推送或下载后，项目代码由业务仓库接管；Kaiwu 不再提供重新生成或覆盖入口。
8. 后续 CI 由 GitLab CI 负责，CD 由 Argo CD 依据 GitOps 仓库执行，Kaiwu 不建设重复的发布中心。

## 2. 领域模型

```text
sys_project 1 ── 0..1 sys_project_generation
                         ├── backend_artifact_name
                         ├── frontend_artifact_name
                         ├── generation_status
                         ├── blueprint_json
                         └── owner_user_id

sys_project 1 ── 0..2 sys_project_repository
                         ├── repository_type: BACKEND | FRONTEND
                         ├── gitlab_project_id
                         ├── web_url
                         ├── default_branch
                         └── push_status

sys_gitlab_config 0..1
```

关键约束：

- `sys_project_generation.project_id` 唯一。
- `sys_project_repository(project_id, repository_type)` 唯一。
- `system` 项目不能创建 generation。
- generation 成功后不可重置、删除或新建第二条。
- repository 的 `PUSHED` 状态不可回退。

## 3. API

### 3.1 GitLab

```text
GET  /api/gitlab/config
PUT  /api/gitlab/config
POST /api/gitlab/config/test
```

权限：

```text
system:git:list
system:git:save
system:git:test
```

### 3.2 数据库结构导入

```text
POST /api/project-generations/schema/mysql
```

请求只包含本次连接所需字段：

```json
{
  "projectId": "9000000000000001001",
  "host": "mysql.internal",
  "port": 3306,
  "database": "biz_order",
  "username": "schema_reader",
  "password": "仅在本次请求内使用"
}
```

响应返回表数、字段数和可编辑 DDL。服务端只查询指定 schema 的
`information_schema.tables/columns/statistics/table_constraints`；不读取业务行。

### 3.3 项目生成

```text
POST /api/project-generations
GET  /api/project-generations?projectId={id}
GET  /api/project-generations/{taskNo}
POST /api/project-generations/{taskNo}/retry
GET  /api/project-generations/{taskNo}/download/BACKEND
GET  /api/project-generations/{taskNo}/download/FRONTEND
POST /api/project-generations/{taskNo}/push
```

权限：

```text
system:project-factory:list
system:project-factory:generate
system:project-factory:download
system:project-factory:push
```

以上平台权限之外，服务端还要求操作者是目标项目 ACTIVE 成员并持有
`project-admin` 项目角色。

## 4. ProjectBlueprint

AI 不能直接提交文件。内部蓝图最小结构为：

```json
{
  "contractVersion": "1",
  "projectCode": "order-center",
  "designSummary": "订单、客户和支付记录的第一版后台",
  "ddl": "CREATE TABLE ...",
  "modules": [
    {
      "table": "biz_order",
      "moduleCode": "order",
      "moduleName": "订单管理",
      "accessScope": "PROJECT_WIDE",
      "ownerColumn": null
    }
  ]
}
```

校验规则：

- `projectCode` 必须等于目标项目；
- 只接受 `CREATE TABLE`，拒绝 DML、`DROP`、`ALTER`、账号和权限语句；
- 表、字段、模块编码必须满足固定正则和数量/长度上限；
- 有用户 DDL 时，AI 不得新增、删除或改写表字段；
- 权限码只由 `moduleCode + resource + action` 派生，不读取模型提供的权限；
- 表包含 `owner_user_id` 或 `global_user_id` 时确定性生成 `OWNER_ONLY`，其它表生成
  `PROJECT_WIDE`；模型不能提供任意授权表达式；
- 主键、归属列、逻辑删除和自动审计列不进入保存请求，更新主键只来自路径；
- 输出中的 URL、Secret、Shell 和额外文件节点全部忽略。

## 5. 生成产物

后端仓库：

```text
kaiwu-{code}-service/
├── pom.xml
├── src/main/java/
├── src/main/resources/
│   └── db/migration/V1__init_business_schema.sql
├── sql/schema.sql
├── sql/menu.sql
├── Dockerfile
├── .gitlab-ci.yml
├── AGENTS.md
├── CLAUDE.md
├── compose.local.yml
├── scripts/dev-check.sh
├── scripts/dev.sh
├── docs/gateway-route-local.yml
├── docs/kaiwu-constraints.json
├── docs/kaiwu-constraint-waivers.json
└── README.md
```

生成的后端 `application.yml` 同时预置项目级 scheduler starter 配置。凭据不进入 ZIP：
项目管理员需在 System“定时任务”页面生成一次性凭据，再以
`KAIWU_SCHEDULER_CREDENTIAL` 环境变量注入部署。业务代码只注册固定
`ProjectScheduledTaskHandler`，System 不会下发类名、Shell 或任意 URL。

前端仓库：

```text
kaiwu-{code}-web/
├── config/config.ts
├── src/shell/
├── src/pages/
├── package.json
├── Dockerfile
├── nginx.conf
├── .gitlab-ci.yml
├── AGENTS.md
├── CLAUDE.md
├── scripts/dev.sh
├── docs/kaiwu-constraints.json
├── docs/kaiwu-constraint-waivers.json
└── README.md
```

两个 ZIP 都使用排序后的文件条目和固定时间戳，且排除 `.git`、构建缓存、环境文件和
符号链接。

生成项目的长期约束按 ADR 0020 分为 MUST/WARN/DEFAULT。CI 校验约束目录、waiver、Secret、
依赖漏洞与 SBOM；Java/TypeScript 提供确定性自动格式化入口。只对 manifest 声明的
`supportedLocales` 要求资源完整，默认只启用 `zh-CN`。

## 6. 失败与恢复

| 场景 | 行为 |
|---|---|
| AI 未配置/超时/蓝图非法 | generation=`FAILED`，保留错误摘要，允许 owner 重试 |
| ZIP 生成中断 | 删除本轮不完整制品，generation=`FAILED` |
| 任务进程重启 | 启动时将遗留 `PENDING/RUNNING` 重新入队 |
| 生成执行器拒绝 | 把仍为 `PENDING` 的任务补偿为 `FAILED`，返回 503，owner 可重试 |
| GitLab 未配置 | 不影响 SUCCESS 和下载；push 返回明确前置缺失 |
| 绑定仓库非空 | 两边都不写，push 失败关闭 |
| 后端已推、前端失败 | 后端永久保持 PUSHED；重试只检查并推前端 |
| 推送执行器拒绝 | 把本次已抢占的 `PUSHING` 仓库补偿为 `FAILED`，不等待重启 |
| 用户已向远端提交 | 远端非空，Kaiwu 拒绝写入 |

GitLab Repository Commits API 使用一次请求创建同仓库全部文件，使单个仓库的初始化保持
原子；超过 GitLab 实例请求大小限制时任务失败且仓库仍为空，不改为多批半成品提交。

## 7. 生成之后：让项目对外可访问

生成产物跑起来之后还要登记服务地址与显式路由，Gateway 才会转发。
完整步骤、四种部署形态的填法、本地开发路径和错误码对照见
[`PROJECT_ACCESS.md`](PROJECT_ACCESS.md)。

## 8. 明确不做

- 对成功项目再次生成或同步模板升级。
- 对业务仓库创建后续 MR。
- 读取或迁移业务数据。
- 保存数据库连接密码。
- 执行 AI 返回的源码、SQL、Shell 或构建命令。
- Workflow、Integration、AI Harness、Agent/Runner、发布中心。
