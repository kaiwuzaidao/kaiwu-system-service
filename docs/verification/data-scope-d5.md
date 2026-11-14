# Data Scope D5 验证记录（项目模板 + Skill + 门禁）

依据：设计稿 §8.1、§8.6、§9，System 仓 `docs/DATA_SCOPE.md`。本仓分支 `feat/data-scope-d5`（基于 `origin/dev`）；
Skill 源文件在 Starter 仓同名分支 `data-scope/skill/SKILL.md`（基于 `feat/data-scope-d3`，因为 `data-scope/` 目录只存在于那里）。

## 改动（生成项目 = 模板产出）

- `MybatisPlusConfig`：`@Qualifier("dataScopeInnerInterceptor") ObjectProvider<InnerInterceptor>`，`ifAvailable` 注册，
  排在分页之前。按 Bean 名而不是引用 `DataScopeInnerInterceptor` 类，是因为默认**不引入** `kaiwu-data-scope`，
  引用具体类会让没有该依赖的项目编译失败。
- `boot/pom.xml`：把仓库根的 `kaiwu/data-scopes.yml` 打进 `META-INF/kaiwu/`（运行时清单与平台同步用的是同一份）。
- 生成 `kaiwu/data-scopes.yml`：注释 + `resources: []` + `exempt: []`。
- 生成 `DataScopeConventionTest`（domain 测试，不连库不起容器），五条规则：
  1. 清单里每个资源：实体存在（`@TableName`）、归属字段存在并声明 `fill = INSERT` 与 `updateStrategy = NEVER`、
     建表 SQL（`db/migration`、`sql/`）里两个归属列各有**单列**索引（复合索引不算）；
  2. 使用 `JdbcTemplate`/`JdbcClient` 的源码里不得出现受控表名；
  3. `DataScopes.unrestricted/reassign` 的第一个参数必须是非空白字符串字面量；
  4. `*SaveRequest`/`*UpdateRequest` 不得含归属字段；
  5. （只提示）被 `@RequirePermission` 保护的 list/page/export 接口，资源既非受控也不在 `exempt`，打印提示，
     并明确输出「没有提示不代表安全」。
- 生成 `.agents/skills/kaiwu-data-scope/SKILL.md`（正文）与 `.claude/skills/kaiwu-data-scope/SKILL.md`（转发指针），
  `AGENTS.md` 增加一条「何时必须先读这个 Skill」。
- 默认不加 `kaiwu-data-scope` 依赖（生成器测试断言四个 pom 都没有该 artifact）。

## 结果

- 全量 `./scripts/verify.sh`：675 个测试，0 失败；生成项目的后端三模块真实构建（含 Testcontainers 启动冒烟）与前端权限/字典
  门禁通过。
- `ProjectScaffoldGeneratorTest`：新增文件清单与 `generatesOptionalDataScopeWiringWithoutAddingTheDependency`
  （拦截器在分页之前、不含具体类引用、清单为空、Skill 与指针齐全、AGENTS 引用、四个 pom 无依赖）。

## 模板自验

用生成的订单示例项目（`target/project-scaffold-sample/backend`）：

| 场景 | 预期 | 实际 |
|---|---|---|
| 空清单，不加依赖，完整 `mvn verify` | 全绿，行为与改动前一致 | ✅ exit 0 |
| 空清单，加 `kaiwu-data-scope` 依赖，完整 `mvn verify`（启动冒烟） | 启动自检通过，说明拦截器已按名字注册、清单已打进 classpath | ✅ exit 0 |
| 正例：声明 `crm_customer`，实体/索引齐全 | 门禁通过 | ✅ |
| 实体归属字段缺 `updateStrategy = NEVER`（规则 1） | 失败 | ✅ 红，指出该资源 |
| 缺 `owner_dept_id` 单列索引（规则 1） | 失败 | ✅ 红 |
| 只有复合索引 `(owner_user_id, owner_dept_id)`（规则 1） | 失败 | ✅ 红，两列都报缺单列索引 |
| `JdbcTemplate` 查询受控表（规则 2） | 失败 | ✅ 红 |
| `unrestricted(变量, …)`（规则 3） | 失败 | ✅ 红 |
| `reassign("  ", …)`（规则 3） | 失败 | ✅ 红 |
| `unrestricted("每日客户公海回收任务", …)`（规则 3 正例） | 通过 | ✅ |
| `CustomerSaveRequest` 含 `ownerUserId`（规则 4） | 失败 | ✅ 红 |
| 示例的 `order:order:list` 未表态（规则 5） | 打印提示、不失败 | ✅ 提示打印，构建绿 |

反例场景脚本在会话临时目录（`ds-gate.sh`，未入库）；规则 3 的反例用了一个 `DataScopes` 空桩让其可编译。

## 与提示词/设计稿的差异

- **实体与 DDL 的索引**：生成器的 DDL 来自用户粘贴的 `CREATE TABLE`，不会自己"创建受控表"，所以没有往生成器里加
  标志位；改成**门禁**（规则 1）强制两个单列索引，并在 Skill 中写明。
- **没有新增约束登记**：未改 `docs/kaiwu-constraints.json`/`constraints.json.ftl`。数据范围目前是"按需引入"的能力，
  登记为 MUST 会让所有不用它的项目被约束；待 D6 之后再决定。
- **Skill 双份**：System 模板里的 `skill-kaiwu-data-scope.md.ftl` 是 Starter 源文件的拷贝，跨仓库无法自动同步，
  README 里写了同步约定；风险是两边漂移。
- **门禁是文本启发式**：清单用正则解析（兼容块状/行内写法），实体检查按注解文本计数，不做完整语法分析。

## 没有覆盖

- 未对着"声明了受控资源且引入依赖"的项目跑完整启动（那是 D6 端到端示例）；本次只验证到依赖在场、清单为空时启动自检通过。
- 前端模板未改动（Web 角色页是 D4）。
- 本地验证时把 `docker.m.daocloud.io/library/mysql:8.4` 打了本机标签 `mysql:8.4`，因为生成项目的 `ApiSmokeTest` 写死了该镜像名。
