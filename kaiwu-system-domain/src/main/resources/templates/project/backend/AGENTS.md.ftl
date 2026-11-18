# ${projectName} 后端 Agent Contract

- 本仓库只属于 `${projectCode}`，使用 JDK 21、Spring Boot 4 和
  `boot -> domain -> api` 三模块结构，由 Boot 产出单一可部署制品。
- 所有手写 Java 类型、构造器和方法都使用中文 Javadoc，具体格式、命名和说明边界遵守
  [docs/JAVA_STYLE.md](docs/JAVA_STYLE.md)；不得用复述签名的模板句代替业务语义。
- 聊天能力须按 `docs/AGENT_CAPABILITIES.md` 显式实现版本化 Handler，复用现有领域服务、
  BUTTON 权限和资源归属校验；不得扫描 Controller/OpenAPI 自动开放。只读响应限制字段与行数；
  写任务须经预览、确认及业务变更同事务的幂等账本。生成时所有 Agent 开关保持关闭。
- 清单归属：存在 `kaiwu/frontend-manifests` 时，下面提到的菜单、字典、参数清单均维护在该文件指向的同级前端仓，project sync 的目标也为该前端仓。其他项目在后端维护清单。
- 权限码必须在 `@RequirePermission`、前端 `PermissionButton`、`kaiwu/menus.yml` 三处同码，
  由 `bash scripts/check-permission-seed.sh` 校验（CI 门禁，**加接口后必须跑**）。
  新增受权限保护的接口时，`kaiwu/menus.yml` 必须同批补 BUTTON 节点，再用
  `./kaiwu project sync <清单所属仓路径>` 查看计划、加 `--apply` 写入平台——
  只在运行库里手工建菜单不算数，全新安装时管理员无法把该权限授予任何角色。
- 受管字典与参数配置写在 `kaiwu/dicts.yml`、`kaiwu/configs.yml`，同样用 `project sync` 同步（只新增、不删除，
  运行值由运维维护）。
- 每次改动后、提交前运行 `bash scripts/verify.sh`（只想快速检查用 `--static`）；全部通过才算完成。
  新增**模块**还要把 `permissionPrefix` 登记进 `docs/kaiwu-project-blueprint.json`，
  它是与前端仓库共享的模块契约。
- 用户可见且需要翻译或运营配置的状态/枚举使用受管字典；内部状态机、协议码和只参与分支
  判断的值保留类型安全的代码常量。未知值原样显示。字典在 Kaiwu「字典管理」维护，前端用
  `useManagedDictionary` 渲染；**后端只存稳定的机器值**（如 `ENABLED`、`PAID`），
  不存中文标签、不按标签查询、不因语言变化而改变入库值。
- 运行期可变、需要运营调整的参数默认走 Kaiwu「参数配置」；领域不变量可以留在版本化代码或
  业务库，不要为了形式统一全部外置。密钥类仍走环境变量，不进配置中心。
  密钥类仍走环境变量，不进配置中心。按用途决定在哪读，不能一律交给前端：

  | 参数用途 | 在哪读 |
  |---|---|
  | 纯展示（公告文案、默认分页大小） | 前端 `useProjectConfig` |
  | **限额、阈值、开关等参与校验的值** | **必须后端读**——前端读了再传回来等于没有校验，客户端可篡改 |
  | 定时任务批次大小、扫描窗口等后端专用值 | 后端读，前端不在场 |

  后端读取用 Starter 注入的 `ProjectConfigClient`，**每次读取必须给 fallback**：

  ```java
  int batchSize = projectConfigClient.getInt("order.settle.batchSize", 200);
  boolean autoSettle = projectConfigClient.getBoolean("order.autoSettle.enabled", false);
  ```

  它读的是内存快照，请求路径上不发网络请求，后台按 `kaiwu.starter.config.refresh-seconds`
  （默认 300 秒）刷新，因此配置变更最长延迟一个刷新周期；需要秒级生效的开关不要依赖它。
  平台不可达时返回 fallback，绝不抛异常。凭据与定时任务共用同一个项目服务凭据，
  未单独配置时自动复用 `kaiwu.starter.scheduler.credential`。
- 需要平台统一 Cron 管理、审计和多副本抢占的任务，默认使用 Starter 调度能力。项目也可以选择
  `@Scheduled` 或其它本地方案，但必须在项目 ADR 中说明多副本协调、幂等、运维入口和回滚责任。
  使用 Starter 时注册 Bean：

  ```java
  @Component
  public class DailyReportTask implements ProjectScheduledTaskHandler {
      @Override
      public String taskType() { return "daily-report"; }

      @Override
      public void execute(ProjectScheduledTaskContext context) {
          // context.payload() 是平台侧配置的受管 JSON 字符串，自行反序列化
      }
  }
  ```

  Cron、时区、启停与执行记录由平台保存，平台只能选择已上报的 `taskType`，不能远程指定
  Java 类、Shell 或 URL。调度语义是 at-least-once：必须用 `context.executionId()`，或
  `context.jobId() + context.scheduledAt()` 建立幂等键。需要 `KAIWU_SCHEDULER_ENABLED=true`
  与平台签发的一次性凭据才启用，默认关闭。
- 生成时为 Controller 和 Service 提供同名测试骨架；`bash scripts/check-test-baseline.sh` 默认只
  报告缺失，模板自验才使用 `--strict`。新增需求优先覆盖领域行为、权限反例和接口契约：
  Service 用 Mockito 打桩 Mapper，Controller 用 standalone MockMvc，
  **都不连数据库、不起 Spring 容器**，新增用例时保持这个约束，否则 CI 跑不动。
  新增接口在既有测试类里补用例；`mvn verify` 只运行存在的测试，删测试不会让构建变红，
  所以这条靠门禁而不是靠自觉。
- `docs/api-contract.txt` 是对外接口最低兼容基线，由 `ApiContractTest` 校验。新增接口/字段允许通过；
  删除接口/字段、改字段类型或改已有路径会变红。确属有意的不兼容发布时运行
  `mvn test -Dkaiwu.api-contract.update=true` 刷新快照，并把 diff 一起提交评审。
  新增模块要把 Controller 与 DTO/VO 登记进 `ApiContractTest` 的 `CONTROLLERS`/`PAYLOADS`。
- 新增或修改业务表、列表/详情/导出/统计接口、Agent 读写能力、定时任务、数据导入时，**先读**
  `.agents/skills/kaiwu-data-scope/SKILL.md`：菜单权限只决定能不能进功能，不决定能看到哪些行。
  要先回答「同一菜单下不同用户应该看到不同的行吗」，是则在 `kaiwu/data-scopes.yml` 声明受控资源，
  否则写进 `exempt` 并附理由；`DataScopeConventionTest` 随 `scripts/verify.sh` 运行。
- 只从 `StarterContext` 读取已验证用户和项目，禁止信任外部 Access JWT 或任意身份头。
- 平台地址 `KAIWU_SYSTEM_SERVICE_URI` 的 scheme 决定由谁解析（ADR 0024），本服务没有部署模式开关：
  `http(s)://` 交给底层网络（本地固定地址、Kubernetes Service DNS 都属此类），
  `lb://` 交给 Spring Cloud LoadBalancer（背后是 Nacos、Consul 还是别的由你的依赖决定）。
  **不要为此写 if/else 或新增 `discovery.mode` 类配置**——切换部署形态只改这个环境变量的值。
  用 `lb://` 需自行添加 `spring-cloud-starter-loadbalancer` 与一个注册中心 starter，
  缺依赖时服务启动即失败并打印所需依赖名。
- 站内信用 Starter 注入的 `NotificationClient`，在明确业务事件后显式调用：
  `notificationClient.send(userId, "标题", "正文", "/相对路径")`。收件人必须是本项目
  成员。它是尽力而为的通知，失败只记日志不抛异常，**业务流程不得依赖它做状态流转**；
  禁止挂在拦截器上或随每个请求触发。
- 流程类需求（审批、工单、核对等「谁现在要处理什么，办完自动消失」）用 Starter 注入的 `TodoClient`
  投递统一待办，**不要自建待办表**，也不要用站内信代替：站内信是不可变事实，待办的状态由本服务维护。
  事项发生时 `open(处理人, 业务键, 标题)`，办完时 `close(业务键)`（或签，关闭所有人）或
  `close(业务键, 处理人)`（会签，只关一人），事项取消用 `cancel(...)`。业务键是事项唯一键
  （如 `approval:2026-0001`），同一事项的多位处理人共用；打开时处理人必须是本项目成员。
  与站内信一样是尽力而为：失败只记日志不抛异常，**业务流程不得依赖它推进状态**，禁止挂在拦截器上。
  依赖的 `kaiwu-system-starter.version` 需包含 `com.kaiwu.starter.todo.client.TodoClient`，没有就先升级版本再写调用。
  用法与限制见 CLAUDE.md「统一待办」。
- 数据库迁移只走内嵌 Flyway：新增
  `kaiwu-${projectCode}-boot/src/main/resources/db/migration/V{n}__desc.sql`
  （版本号唯一、递增），应用启动时 Spring Boot 自动执行，历史记录在 `flyway_schema_history`。
  增量必须确定、前向并在全新 MySQL 与升级样本上验证；不要普遍使用 `IF NOT EXISTS` 掩盖
  结构漂移。只有明确需要重试的 seed/补偿步骤才要求幂等并写明原因；
  已发布的 V 脚本一律不可修改，修错只能追加新版本纠正。`sql/schema.sql` 仅作累积快照，运行时
  不执行，每次新增迁移需同步维护。V1 只初始化全新空库，不接管已有 schema。
- 任何接受外部分页参数的查询必须调用 `PageBounds.require`（约束 `query.bounded-result`，MUST）：
  上限 `PageBounds.MAX_SIZE`，越界返回 400 而不是静默截断。拼出 `LIMIT` 的地方自己就要校验，
  不依赖上游；`BoundedQueryConventionTest` 按文件断言，漏写会让构建变红。
- 每张业务表必须保持蓝图声明的资源范围（约束 `auth.resource-ownership`，MUST）：
  `PROJECT_WIDE` 表由项目权限控制；`OWNER_ONLY` 表的列表、详情、更新和删除还必须绑定
  `StarterContext.userId()`；`DATA_SCOPED` 表（同时含 `owner_user_id` 与 `owner_dept_id`）由 `kaiwu-data-scope`
  拦截器按角色范围自动过滤，Service 里**不要**再手写归属条件，归属变更只走 `DataScopes.reassign`。主键、归属、逻辑删除和审计字段不得从保存请求体写入；修改范围前先补
  越权反例测试，禁止只靠前端隐藏。
- ORM 查询必须写出结果列，禁止 `SELECT *` / `alias.*`（约束 `query.explicit-projection`，MUST）：
  加一列就会自动多带一列出去，覆盖索引失效、映射漂移、敏感列外泄同时发生且没有报错。
  由 `SqlProjectionConventionTest` 把关，Mapper XML 一并扫描。
- 生产线程必须由显式 `ThreadPoolExecutor` 管理（约束 `runtime.managed-threads`，MUST）：
  不用 `Executors` 工厂方法，不起裸 `new Thread(...)`；线程名、容量、拒绝策略和关闭路径都要写出来。
  分布式定时任务优先用 Kaiwu Scheduler Starter。由 `ManagedThreadConventionTest` 把关。
- 运行时日志不得写出凭据与敏感个人信息（约束 `logging.no-sensitive-data`，MUST）：
  只记录标识、长度或掩码值。诊断需要的是「哪个 key 出问题」，不是它的值；
  由 `SensitiveLoggingConventionTest` 把关。
- Excel 导入导出按需使用 Maven Central 依赖 `com.kaiwuzaidao:kaiwu-excel:${starterVersion}`。读取/模板/写出使用 `ExcelTable`，业务接口、权限、校验与事务由本项目实现；先下载模板，导入返回行号和业务错误，明确定义重复数据策略。列表导出必须遵守：查询自带 `LIMIT` 并设行数上限
  （结果集整体进内存，无上限的全表查询会 OOM）；超限直接报错，禁止静默截断；敏感列留空或
  掩码；复用列表权限码 `{module}:{resource}:list`，不新增导出专用权限码。
- 抛业务异常时**必须带 messageKey**，否则前端无法把错误翻译成用户界面语言：

  ```java
  throw new ApiException(HttpStatus.NOT_FOUND, "订单不存在",
          "error.order.notFound", Map.of("orderNo", orderNo));
  ```

  `message` 保持服务端语言不变（供日志与排查），只有 key 参与界面翻译；`messageArgs`
  只放可安全展示的值，禁止放 token、密码、连接串或堆栈。新增 key 要同时补进前端仓库的
  当前项目 `supportedLocales` 声明的语言资源；默认只启用 `zh-CN`，新增语言后才要求同步补齐。
- Secret 只通过环境变量注入，不得写入代码、日志、文档或提交。
- 禁止 force push 或直接在受保护分支实现；具体分支策略由业务团队维护。
- 约束强度以 `docs/kaiwu-constraints.json` 为准；只有 WARN/DEFAULT 可通过
  `docs/kaiwu-constraint-waivers.json` 有期限偏离，MUST 不可豁免。
- 本仓库是一次性生成产物；后续需求在本仓库正常开发，不回到 Kaiwu 重新生成。

## 包结构与契约

遵守 [docs/PACKAGE_STRUCTURE.md](docs/PACKAGE_STRUCTURE.md) 和版本化 `docs/package-layout.json`。
业务采用 `module/分类/controller|service|repository|mapper|entity|agent`，不插入功能目录。
Service 接口与 `service/impl` 分离；新增写 DTO 位于 API 的 `dto/request`，查询 DTO 位于 `dto/query`。
布局门禁随 Maven verify 执行。新分类须更新契约；权限、数据范围与能力审批继续独立验证。

## 产品前端交接

有 `kaiwu/frontend-manifests` 时，平台清单由配套前端仓维护。校验新增业务权限时并排检出两个仓，或设置 `KAIWU_FRONTEND_DIR`。按前端的编号规则和验收场景实现业务 API，覆盖直接请求的权限反例。字段、错误提示、加载和空态可随联调调整；布局和已验收交互变动由产品复验。契约变化同步改前端 service、Mock 与验收场景。
