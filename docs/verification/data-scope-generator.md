# Data Scope：项目工厂缺口修复

来源：D6 端到端联调（`data-scope-d6.md` 的问题 3、4、5）。分支 `feat/data-scope-d5`。

## 约定

**表同时含 `owner_user_id` 与 `owner_dept_id`** → 项目工厂按行级数据范围生成（`TableMeta.accessScope() = DATA_SCOPED`）。
这是显式约定而非猜测：数据范围需要这两列，缺一个就退回原有的 `OWNER_ONLY`（只含 `owner_user_id`/`global_user_id`）或
`PROJECT_WIDE`。两套机制从此在生成物里互斥，不会再同时出现手写过滤与拦截器。

## 变化（仅对 `DATA_SCOPED` 表；其它表的生成物不变，由原有测试保证）

| 位置 | 之前 | 现在 |
|---|---|---|
| Service | `eq(ownerUserId, currentOwnerId())` 手写过滤、`setOwnerUserId`、`currentOwnerId()` | 全部不生成；`get` 查不到统一 404（`requireVisible(mapper.selectById(id))`） |
| `SaveRequest` | 含 `ownerDeptId`（还是 `@NotNull`） | 不含任何归属字段（`editableColumns` 排除两列） |
| 实体 | 归属字段是普通字段 | 两个归属字段带 `@TableField(fill = INSERT, updateStrategy = NEVER)` |
| V1 迁移与 `sql/schema.sql` | 用户 DDL 原样 | 缺单列索引则补 `CREATE INDEX idx_<表>_owner_user/_owner_dept`；DDL 没有结尾分号时先补分号 |
| `kaiwu/data-scopes.yml` | 空清单 | 为每张受控表声明资源（`code` = 权限前缀，五种范围） |
| domain `pom.xml` | 无 | 依赖 `kaiwu-data-scope`；`kaiwu-system-starter.version` 改为 `0.1.1-SNAPSHOT`（该版本需已发布到项目的 Maven 仓库） |
| `application.yml` | 无 | `kaiwu.data-scope.members.{system-address,credential}` 占位（空串视同未配置，`reassign` 失败关闭） |
| Service 测试 | — | 增加 `hidesRecordsFilteredByTheDataScope` |
| 蓝图 JSON / 约束 / AGENTS | `PROJECT_WIDE`/`OWNER_ONLY` | 增加 `DATA_SCOPED`，说明不要手写归属条件 |

## 顺手修的两个既有缺口（对所有生成项目生效）

- **`created_at`/`updated_at` 为 NOT NULL 又没有默认值时，生成的创建接口 500**：Service 现在在 `create` 里给所有自动时间列赋
  `LocalDateTime.now()`，`update` 里刷新名字含 `update` 的时间列。
- **`application.yml` 没有排除 `/api/internal/agent/**`**，开启 Agent 执行后该入口被普通 Context 拦截器挡成 401：已加入
  `exclude-paths`（Agent 开关默认仍关闭，这条在关闭时无作用）。

## 验证

- `ProjectScaffoldGeneratorTest` 新增 `generatesDataScopedResourcesWithoutHandWrittenOwnerFilters`：逐项断言上表，
  并断言只含 `owner_user_id` 的表保持原样、不引入数据范围依赖。
- **真实构建**：把该用例生成的 `demo-crm` 放到 `target/project-scaffold-data-scope-sample/backend`，执行完整 `mvn verify`
  通过——包括 `DataScopeConventionTest`（四条失败规则全绿）、各服务/控制器测试，以及 `ApiSmokeTest`（Testcontainers MySQL
  上真实启动 Spring 应用，`kaiwu-data-scope` 的启动自检随之通过：拦截器已注册且早于分页、表列存在、实体注解与填充齐全）。
- 全量 `./scripts/verify.sh`：见提交说明。
- Starter 侧配套：`kaiwu-data-scope` 把成员查询的空串视同未配置（`f1162bb`），否则占位配置会让应用起不来；模块 44 项通过。

## 仍然没做

- 已有项目（非工厂生成）不会自动迁移；Skill 仍描述手工接入步骤。
- 批量转移接口（`reassign`）仍需业务自己写，生成器不生成；这是有意的——转移的权限和审计口径要业务确认。
- MyBatis 二级缓存冲突：启动自检仍不检查（`data-scope-d6.md` 问题 7）。
- 前端模板未改动：`DATA_SCOPED` 表的前端页面仍按现有 CRUD 生成，归属列只作展示。
