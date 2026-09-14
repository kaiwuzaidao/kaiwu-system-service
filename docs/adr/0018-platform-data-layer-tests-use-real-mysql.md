# ADR 0018：把「测试不连库不起容器」限定回生成项目，平台数据层用真 MySQL 验证

- 状态：Accepted
- 日期：2026-08-07
- 决策范围：`kaiwu-system-service`
- 修正：2026-08-06 开发记录中的「测试不连库不起容器」被扩大适用到平台自身

## 背景

### 这条约束原本是为什么立的

2026-08-06 立它时，上下文是**生成项目的测试基线**：

> 模板新增 `ServiceTest.java.ftl`（Mockito 打桩 Mapper）与 `ControllerTest.java.ftl`
> （standalone MockMvc + 打桩 Service）。**都不连数据库、不起 Spring 容器，CI 无条件可跑。**

理由是**可移植性**：生成的业务项目要交付到别人的 GitLab、跑在别人的 runner 上。
那里有没有 MySQL、有没有 Docker、能不能 privileged，平台无法假设也管不着。测试一旦依赖
这些，交付出去的项目 CI 第一次就红，而 ADR 0006 说好了平台不接管业务项目——想帮都没法帮。

### 它是怎么被扩大的

同一份记录往下 70 行，这条为**生成产物**立的可移植性约束，被用来否决**平台自身**的
技术选型（「没有用 springdoc：它需要起 Spring 容器和数据库，与刚立的约束冲突」）。
之后又被多份内部文档反复引用成「Kaiwu 的显式工程约束」，越传越像一条普遍原则。

对平台自身，原始理由**根本不成立**：平台的 CI 是自己的，不存在「别人的 runner」；
`dev-run.sh` 与 `docker-compose.yml` 本来就以 Docker 为前提；平台不交付给谁，没有可移植性诉求。

### 为什么现在必须解决

ADR 0017 把数据层换成 MyBatis-Plus 后，多了三类**只有真库能暴露**的错误：

1. 驼峰↔下划线自动映射拼错（`tokenCiphertext` → `token_ciphertext`）
2. `@TableId` / `@TableField` 配置错（如审计日志表必须用 `IdType.AUTO`）
3. 类型转换：`Boolean`↔`TINYINT`、`LocalDateTime`↔`DATETIME`、`Instant` 的时区换算

第 3 类尤其危险：`sys_scheduler_execution.scheduled_at` 是唯一键的一部分，
时区若有偏移，同一次调度会被认成两次。现有 138 个测试全是 Mockito 打桩，
**一个都碰不到这些**。

## 决策

### 1. 约束按范围拆分，而不是废除

| 范围 | 约束 | 理由 |
|---|---|---|
| 生成项目模板 | 维持不连库、不起容器 | 交付到别人的 runner，可移植性是硬需求 |
| 平台自身 | 允许起一次性容器跑数据层测试 | CI 自有、已依赖 Docker、换 ORM 后需要真库验证映射 |
| 任何环境 | **禁止连开发库或共享测试库跑测试** | 这才是原来「不连库」真正该挡的东西 |

第三行是原先没有的。旧表述只有「不连库」三个字，把**该禁的**（连共享库，会污染数据、
让失败难复现）和**该允许的**（起一次性容器，测完即毁）混成了一件事。

### 2. 平台数据层用 Testcontainers + 真 MySQL

- 用 MySQL 8 官方镜像，方言与生产一致——不用 H2（见「被否决方案」）。
- **直接跑 `sql/increment` 的 Flyway 迁移建库**，顺带把迁移本身也验证了。
  现在迁移只在 `dev-run.sh` 时才被执行到。
- 只测 Mapper 层，不启 Web 容器、不碰 Service。

### 3. 覆盖范围按风险排，不追求全覆盖

只写「错了看不出来」的那些：

- 每个实体的字段映射往返（写入后读回，逐字段比对）
- `IdType` 配置：INPUT 的表能写入应用生成的 19 位 ID，AUTO 的表能自增
- 时间与布尔类型的往返，特别是 `Instant`↔`DATETIME`
- 带守卫的状态机 SQL：`claim` / `takeOverExpiredExecution` / 乐观锁更新的影响行数
- `ON DUPLICATE KEY UPDATE` 的列清单（哪些列有意不更新）

不写 Service 编排逻辑的测试——那些 Mockito 已经覆盖，重复一遍只是让构建更慢。

### 4. 测试基线口径由 ADR 0020 调整

`check-test-baseline.sh` 仍然只查存在性、不查覆盖率，但由硬门禁降为默认告警；模板自身
使用 `--strict` 保证首版骨架完整。业务项目是否具备有效测试，以领域行为、权限反例和接口契约
覆盖为准。本 ADR 只决定平台数据层可以使用真库，不改变测试内容的风险排序。

## 后果

### 正向

- ADR 0017 引入的三类映射错误从「上线才发现」变成「构建就红」。
- Flyway 迁移第一次有了自动验证：以前只有人工 `dev-run.sh` 才会执行到它们。
- 「不连库」的真实意图（不要污染共享库）第一次被写清楚，不再靠口口相传。

### 成本与限制

- **构建需要 Docker**。本机与 CI 都已具备，但离线环境跑不了这部分测试。
- **构建变慢**：一次容器启动约 10 秒，同一次构建内复用。
- **生成项目不受益**。它们的测试仍然不连库——这是有意的，见决策第 1 条。

## 被否决方案

### H2 内存库

实测这个库跑不起来：

| 障碍 | 实测 |
|---|---|
| 建表语法 | 34 张表全带 `ENGINE=InnoDB` / `utf8mb4` / `COLLATE` |
| Flyway 增量 | 9 个文件用 `information_schema`、8 个用 `PREPARE`/`EXECUTE`、2 个用 `ROW_NUMBER() OVER` |
| 应用 SQL | `JSON_EXTRACT` ×4、`JSON_UNQUOTE` ×4、`JSON_OBJECT` ×3、`ON DUPLICATE KEY UPDATE` ×6 |
| JSON 列 | schema 里 1026 处涉及 JSON，H2 的 JSON 类型与路径语法和 MySQL 不兼容 |

要用 H2 就必须**手写一份 H2 版 schema**——第二份真相源，与 Flyway 那份必然漂移。
ADR 0015 刚因为「两个真相源」把内联 i18n 列整个退役，这里再引入一份是自打脸。

更要命的是失败模式：**H2 上绿、MySQL 上炸**。假阳性测试比没有测试更糟，
它会让人有信心跳过真实验证。

### 维持现状，靠 `scripts/verify-*.sh` 人工验证

成本为零，但反馈慢且靠人记得跑。ADR 0017 的迁移已经证明这类约束靠自觉不成立。

### 全面 `@SpringBootTest`

会把 Web 层、Redis、Nacos 一起拖进来，构建时间和不稳定性都不可接受。
本 ADR 只要数据层。

## 落地范围（另批执行）

1. `kaiwu-system-domain` 加 `testcontainers` 与 `mysql` 测试依赖。
2. 一个共享的 MySQL 容器基类，启动后跑 `sql/increment` 的 Flyway 迁移。
3. 按决策第 3 节的清单补 Mapper 契约测试，从 ADR 0017 里风险最高的三处起步：
   `ProjectSchedulerMapper` 的时间往返、`UserEntity` 的 `select = false`、
   两张审计日志表的 `IdType.AUTO`。
4. 更新 `AGENTS.md` 与开发记录，把「测试不连库不起容器」改成按范围表述，
   并修正各内部文档里被扩大引用的说法。
