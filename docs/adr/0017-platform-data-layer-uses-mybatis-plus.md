# ADR 0017：平台控制面数据层统一为 MyBatis-Plus，退役 JdbcTemplate

- 状态：Accepted
- 日期：2026-08-07
- 决策范围：`kaiwu-system-service`
- 兑现：CLAUDE.md「不可变架构 · 平台后端：…MyBatis-Plus…」——该约束此前未被代码遵守

## 背景

CLAUDE.md 把 MyBatis-Plus 列为平台后端的**不可变架构**，但实际实现是
`spring-boot-starter-jdbc` + 手写 SQL：16 个 Repository、3371 行 JdbcTemplate 代码，
零 MyBatis 依赖。真正用 MyBatis-Plus 的只有项目工厂生成的业务项目模板。

这不是「文档写错了」，而是**约束被违反且没人发现**。它是 Kaiwu 立项前提
（「把工程约束沉淀为可执行的约束，让 AI 生成的产物保持可理解、可验证、可维护」）
的一次实证反例：架构约束只写在 Markdown 里，没有任何门禁能发现代码走偏。

## 决策

### 1. 平台与生成项目使用同一套数据层

平台控制面的数据访问全部改为 MyBatis-Plus，与
`templates/project/backend` 生成的业务项目对齐：同一个 `mybatis-plus-spring-boot4-starter`
版本、同一份只装分页插件的 `MybatisPlusConfig`。

同栈的实际收益不在性能或代码量，而在**认知一致**：平台开发者和业务项目开发者
（以及协作的 AI）在两边看到的是同一套东西，不需要在两种数据访问范式之间切换。

### 2. 分层：Mapper 承载 SQL，Repository 承载业务视图

- **实体**贴表结构，`@TableName` + `@TableId(type = INPUT)`（平台 ID 由
  `LongIdGenerator` 应用内生成，不用数据库自增，也不用 MP 雪花）。
  例外是两张审计日志表，它们本就是 `AUTO_INCREMENT`，用 `IdType.AUTO`。
- **Mapper** 只做数据访问。单表 CRUD 用 `BaseMapper`；MP 表达不了的写成注解 SQL。
- **Repository 保留**，把实体转成业务视图（record）。因此 Service 层在整次迁移中
  **一行未改**，影响面锁死在数据层内部。

### 3. 复杂查询使用 Mapper XML（由 ADR 0020 取代原决定）

单表 CRUD 使用 `BaseMapper`。多表 JOIN、动态条件、报表等复杂查询优先放 Mapper XML，获得 SQL
高亮、结构化动态标签和独立审阅能力。现有授权链路、状态机守卫、MySQL 专有函数与乐观锁注解
SQL 属于已验证高风险语义，不做机械迁移；后续修改时根据复杂度逐条选择并运行真 MySQL 契约测试。

### 4. 明确不改用条件构造器的四类 SQL

以下情形一律保留原样的注解 SQL，**不是遗留，是判断**：

| 类别 | 例子 | 理由 |
|---|---|---|
| 授权链路 | `AuthMapper.findPermissions`、`ProjectMapper.findCurrentPermissions` | 五六个 JOIN，决定谁能看到什么；借换 ORM 顺手改是不可接受的风险 |
| 状态机守卫 | `ProjectGenerationMapper.claim`、`ProjectSchedulerMapper.takeOverExpiredExecution` | `WHERE ... AND status = 'RUNNING'` 靠影响行数实现无锁抢占，先查后改会让同一任务被执行两次 |
| MySQL 专有 | `JSON_SET` / `JSON_EXTRACT`、`ON DUPLICATE KEY UPDATE`、多表 `UPDATE ... JOIN` | 条件构造器不支持；`JSON_SET` 只改一个语言键，整体替换会冲掉其它语言译文 |
| 乐观锁 | `I18nMapper.updateWithVersion` | 现有代码靠「带 version 条件的更新是否影响 1 行」判冲突，语义直白且上层已依赖；改用 `@Version` 需要多装拦截器并改变冲突行为 |

### 5. 复合主键关联表不继承 BaseMapper

`sys_user_department`、`sys_role_permission`、`sys_user_role`、`sys_project_member_role`
等复合主键表用纯 `@Mapper` + 注解 SQL。硬套 `BaseMapper` 就得在某一列上标 `@TableId`，
那是在实体里写一句假话——将来有人调 `selectById` 会拿到一行本不该唯一的数据。

## 后果

### 正向

- **CLAUDE.md 的架构约束第一次与代码一致**。
- **密码哈希的保护从约定变成机制**：`UserEntity.passwordHash` 标
  `@TableField(select = false)`，默认查询取不到密码。迁移前靠每个查询手写列白名单，
  漏写就泄露；现在漏写的默认行为是安全的。登录路径显式单独取，且只有一处。
- **消除了两处重复**：`ProjectServiceCredentials` 里与调度模块逐字相同的凭据查询
  （同一份安全 SQL 有两份副本），以及用户导出与列表各写一份的筛选条件。
- **关闭了字符串拼 SQL 的口子**：`LogCenterRepository` 的 4 处 `nosemgrep` 压制注释
  和 `AuditLogCleaner` 的表名拼接全部消失。

### 成本与限制

- **代码量增加约 1000 行**，几乎全是实体的 getter/setter。
- **引入了一类新的静默失败**：MyBatis-Plus 的 `updateById` / `update(entity, wrapper)`
  只把非 null 字段写进 SET，「清空某字段」会静默失效——界面显示保存成功但值没变。
  迁移中实际踩到三次（用户邮箱、菜单路由、角色描述）。
  **约定：凡是可清空字段的编辑，一律用 `LambdaUpdateWrapper` 显式 `set()`**，
  不用实体更新。这一条必须写进 `AGENTS.md`。
- **测试覆盖不到映射正确性**。136 个单元测试全是 Mockito 打桩，碰不到数据库；
  驼峰映射、`@TableField` 配置、`Boolean`↔`TINYINT` / `LocalDateTime`↔`DATETIME`
  类型转换只有真库能验证。见「后续」。

## 被否决方案

- **维持 JdbcTemplate，改 CLAUDE.md 迁就现状**：约束被违反时改约束，等于宣布约束不作数。
- **只迁单表 CRUD，JOIN 保留 JdbcTemplate**：同一个仓库里两套数据访问方式，
  比统一到任何一套都糟。
- **永远禁止 Mapper XML**：复杂查询塞进 Java 注解会降低可读性和工具支持，已由 ADR 0020 否决。
- **换用 MP 的 `@Version` 乐观锁与多租户插件**：见决策第 4 条；没有真实需求证据。

## 后续

1. **数据层测试是当前最大的缺口**。2026-08-06 立的「测试不连库不起容器」
   约束，其原始理由是**生成项目要能在别人的 runner 上无条件跑 CI**——那条理由对
   平台自身不成立（CI 自有、`dev-run.sh` 本就依赖 Docker）。建议限定该约束的范围，
   并为平台引入 Testcontainers + 真 MySQL 的 Mapper 契约测试，直接跑
   `sql/increment` 的 Flyway 迁移建库。这需要单独一条 ADR。
2. **补一条门禁**防止回退：`kaiwu-system-domain` 出现 `JdbcTemplate` 引用即构建失败。
   没有它，这次修好的约束会以同样的方式再次走偏。
3. `AGENTS.md` 补充「可清空字段必须显式 set()」与「一张表只有一份实体」两条约定。
