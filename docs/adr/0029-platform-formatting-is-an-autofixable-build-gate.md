# ADR 0029：平台仓格式化作为可自动修复的构建门禁

- 状态：Accepted
- 日期：2026-09-13
- 决策范围：Kaiwu 平台 Java 仓（`kaiwu-system-service`、`kaiwu-gateway-service`、`kaiwu-system-starter`）
- 部分取代：ADR 0020 第 8 节关于格式化强度的表述，仅限平台仓；项目工厂模板与生成业务项目不变

## 背景

ADR 0020 把格式化定为 `DEFAULT`：提供自动修复入口，不承担合并门禁职责。这条判断针对的是
生成业务项目——那里团队各异、工具各异，用排版拦合并只会制造摩擦。

但同一条判断被套用到平台仓之后出现了另一种代价。三个平台 Java 仓的 `pom.xml` 里
`spotless-maven-plugin` 配置齐全（palantirJavaFormat、removeUnusedImports、
trimTrailingWhitespace、endWithNewline），却没有 `<executions>`，不绑任何 phase；
`mvn verify` 不会触发它，全部 `.gitlab-ci.yml` 与 `scripts/` 里 `spotless` 出现 0 次。
结果不是"格式化是可选的"，而是**格式化从未发生过**。

2026-09-13 第一次真正执行时的实测数据：`kaiwu-system-service` 294 个文件、
5175 行增删，`kaiwu-gateway-service` 与 `kaiwu-system-starter` 各 33 个文件。
这些全是纯排版，没有一行逻辑变更。漂移在两年里静默累积，最终必须一次性支付，
而这一次重排让当时所有在途分支都产生了冲突。

关键区别在于：平台仓由少数几个维护者和 AI 工具共同改动，谁写的排版谁自己维护；
**而生成业务项目的第一个提交由项目工厂自动推送**，流水线先于任何人执行格式化命令就跑起来，
且生成代码的行宽取决于模块名与实体名——实体名一长，同一份模板渲染出来必然超出行宽限制。
同样一条门禁，在平台仓是"跑一条命令"，在生成项目是"首条流水线必红且无人可修"。

## 决策

### 1. 平台三个 Java 仓的 spotless check 绑定到 `validate`，失败阻断

只绑 `check` 不绑 `apply`：CI 里自动改写源码会让构建产物和仓库内容对不上。
绑 `validate` 而不是 `verify`，让格式问题在编译前就暴露，不用等跑完测试。
修复手段唯一且确定：`mvn spotless:apply`。

沿用 pom 里一直声明的 `palantirJavaFormat`，不改用 google-java-format：
在本仓实测 AOSP 风格的 churn 更大（8021 行 / 302 文件，palantir 是 5175 行 / 294 文件）。

### 2. 项目工厂模板与生成业务项目不变，格式化保持 `DEFAULT`

生成项目继续只提供 `mvn spotless:apply` 与 `pnpm format` 入口，不进 CI 门禁，
理由见背景第三段。生成前端的 `format:check` 挂在开发者侧的 `pnpm verify` 上，
不进 `.gitlab-ci.yml`；生成后端不绑定 spotless。

### 3. `DEFAULT` 允许在构建中阻断的条件

ADR 0020 第 1 节的分级表给 `DEFAULT` 的 CI 行为是"提供自动修复或样例"。本 ADR 补充：
当且仅当同时满足下面两条时，`DEFAULT` 约束可以在构建中阻断，级别不因此升为 `MUST`——
它仍然可豁免，仍然不承担架构评审职责：

- **修复是一条确定性命令**，不含任何人为判断，任何人和任何模型执行结果一致；
- **承担门禁的人就是仓库的维护者**，不存在"被别人的规则拦住且无法自行修复"的情况。

格式化在平台仓同时满足两条。业务规则、命名约定、注释覆盖率这类需要判断的约束不满足第一条，
不得据此升级。

### 4. 登记到约束目录

新增 `format.platform-gate`（`level: DEFAULT`、`scope: kaiwu-platform-java-repositories`、
`waivable: true`）。原有 `format.deterministic` 的 `scope` 是
`java-typescript-generated-code`，本就不覆盖平台仓，保持不变——平台仓的格式化此前
属于未登记状态，本条补齐 ADR 0020 第 1 节"每条长期约束必须登记"的要求。

## 后果

- 平台仓不会再次积累到需要一次性重排数千行的程度；代价是每个维护者提交前多跑一条命令，
  三个仓的 `CLAUDE.md` 已写明。
- 生成业务项目的交付体验不变，首条流水线不会因为排版变红。
- 分级表多了一条有边界的例外。边界写死在第 3 节的两个条件里，避免"既然格式化能阻断，
  那 XX 也能"这种沿用。
- 本 ADR 只改格式化这一项，ADR 0020 的其余部分（waiver 机制、分支策略归属、Flyway、
  字典范围、测试与 API 兼容、文档与语言）全部继续有效。
