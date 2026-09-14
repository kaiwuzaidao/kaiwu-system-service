# ADR 0006：AI 优先的一次性项目工厂

- 状态：Accepted
- 日期：2026-07-23
- 决策范围：`kaiwu-system-service`、`kaiwu-system-web`
- 取代：ADR 0005 中“AI 只能增强字段元数据”的产品边界
- 保留：ADR 0002 的“一个业务项目对应独立后端仓库和独立前端仓库”

> 2026-08-12 补充：固定的个人初始分支约定由 ADR 0020 取代；一次生成、空仓库一次推送与平台退出写权限继续有效。

## 背景

Kaiwu 的特色不是对已有仓库反复执行 CRUD codegen，而是按一套可理解、可验证的脚手架
规范生成业务项目第一版。用户可以只描述业务，也可以提供已有表结构；生成后由开发者接管，
平台不得再次向仓库写代码，避免覆盖人工修改。

旧 `sys_codegen_task` 支持同一项目重复生成模块并创建 MR，不满足“一项目只初始化一次”
和“生成后平台退出写入权”的新需求。ADR 0005 只允许 AI 增强字段标签，也不足以支撑
“根据描述生成第一版项目”。

## 决策

### 1. 生成对象与仓库边界

1. 生成聚合根是已登记的 `sys_project`，不是任意 DDL 任务。
2. 每个非内置项目最多存在一条 `sys_project_generation`；数据库以
   `UNIQUE(project_id)` 强制约束。
3. 一次生成同时产出：
   - `kaiwu-{projectCode}-service.zip`
   - `kaiwu-{projectCode}-web.zip`
4. 两个制品分别对应 BACKEND、FRONTEND 两个独立 GitLab 仓库，继续遵守 ADR 0002。
5. 内置 `system` 项目已经存在真实源码，禁止通过项目工厂生成。

### 2. 输入模式

- `AI_PROJECT`：默认入口。业务描述必填；DDL 可选。无 DDL 时，AI 生成受约束的 MySQL
  schema 蓝图；有 DDL 时，以解析后的真实表字段为硬边界，AI 只补充模块、字段展示和设计说明。
- `BASIC_SCAFFOLD`：明确兜底。不调用 AI，只生成可启动的空后端和空管理前端。

已有数据库有两种结构输入方式：

- 粘贴 `CREATE TABLE` DDL；
- 提交一次性的 MySQL host、port、database、username、password，由 System 只读查询
  `information_schema` 并返回 DDL。密码不落库、不写日志、不进入异步任务。

数据库导入与项目生成分成两个请求：先导入并拿到 DDL，再发起异步生成。这样异步任务永远
不持有数据库凭据。

### 3. AI 与确定性边界

产品上称为“AI 生成项目”，工程上采用受约束混合模式：

1. AI 只返回结构化 `ProjectBlueprint`，包含 schema、模块说明、字段展示元数据和设计摘要。
2. 服务端校验 JSON、标识符、DDL 语句类型、表字段集合和数量/长度上限。
3. Java、TypeScript、SQL、权限码、Docker、CI、`CLAUDE.md`、`AGENTS.md` 全部由
   Kaiwu 版本化模板确定性渲染。
4. 不执行模型返回的源码、Shell、SQL 或网络指令；不在 System JVM 中运行生成项目。
5. `AI_PROJECT` 的 Provider 未启用、超时或蓝图非法时任务进入 `FAILED`，由 owner 在同一条
   任务上重试；不得静默伪装为 AI 成功。
6. `BASIC_SCAFFOLD` 不依赖 Provider。

该边界允许 AI 决定第一版业务数据模型与后台模块，同时把可执行源码控制在用户能审阅的
固定脚手架内；不引入 AI Harness、Agent、Workflow 或 Runner。

### 4. 状态机与一次性语义

```text
NOT_CREATED
    │ POST /api/project-generations
    ▼
PENDING ── worker ──> RUNNING ──> SUCCESS
                         │
                         └──────> FAILED ── retry ──> PENDING
```

- `SUCCESS` 后永久禁止重新生成。
- `FAILED` 只允许 owner 重试同一记录，不能新建第二条记录。
- `PENDING/RUNNING` 拒绝重复提交和重复重试。
- ZIP 在 `SUCCESS` 后持久化，下载不改变状态。
- 任务详情、重试、下载和推送都校验 owner；任务号不是授权。

### 5. GitLab 配置与一次安全推送

System 管理一条受管 GitLab 配置：

- GitLab Base URL；
- 默认 Group ID；
- API Token（AES-256-GCM 加密）；
- enabled、连接测试结果。

浏览器只得到 `tokenConfigured`，永远得不到明文或密文。Token 只发往配置中相同
scheme/host/port/base-path 的 GitLab API。

生成成功后可选择：

- 为 BACKEND/FRONTEND 在默认 Group 创建两个 private 空仓库；或
- 分别绑定同一 GitLab 实例的两个已有空仓库。

推送前必须先验证两个目标仓库均为空。每个仓库只允许一次初始提交到项目登记的
`defaultBranch`（新项目默认 `main`）：

- 禁止 force push；
- 禁止覆盖目标分支已有内容；
- 禁止创建后续 codegen 分支或 MR；
- 远端非空立即失败关闭；
- 某一仓库已经成功推送后永不重写；另一仓库失败时只允许补推尚未成功的一侧。

因此开发者首次提交后，Kaiwu 没有任何覆盖路径。后续修改、分支、MR 和发布完全归业务
仓库自身。

## 后果

### 正向

- AI 成为项目创建主入口，而不是装饰性的字段标签功能。
- 一项目一次生成和一次推送消除了模板覆盖人工代码的路径。
- 不配置 GitLab也能完整下载两个 ZIP。
- 数据库密码只在一次 HTTP 请求的内存和 JDBC 连接生命周期内存在。
- AI 失败、GitLab 失败和本地制品成功状态可以准确区分并重试。

### 成本与限制

- 两个 GitLab 仓库无法事务性同时提交；必须记录分仓推送状态并支持只补偿失败一侧。
- 项目需求变化不通过项目工厂“再生成”，由开发者在独立仓库继续开发。
- 第一阶段只支持 MySQL 8 结构导入，不接 PostgreSQL、Oracle 或业务数据迁移。
- 不接受完整 JDBC URL，避免用户注入驱动参数或凭据。

## 被否决方案

- 对同一项目反复生成 MR：仍可能覆盖或冲突人工代码。
- AI 直接返回任意文件树：难以审阅路径、权限和可执行代码边界。
- 在异步任务表保存数据库密码：扩大 Secret 暴露面。
- 后端和前端塞进一个仓库：违反 ADR 0002 的独立交付边界。
- 生成成功后自动推 Git：外部写入必须由用户显式触发。
