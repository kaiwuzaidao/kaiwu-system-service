# ADR 0028：生成前端模板自包含，退役 @kaiwu/web-starter

- 状态：Accepted
- 日期：2026-08-16
- 决策范围：项目工厂前端模板、`kaiwu-web-starter`
- 取代：ADR 0016

## 背景

ADR 0016（2026-08-07，Accepted）决定让生成项目前端依赖 `@kaiwu/web-starter`，删除模板里
9 个公共层副本，理由是消除"改一边忘同步另一边"的双源码沉默失败。

到 2026-08-16 开源准备复核时，实际状态是：

- 模板侧 6 个副本文件仍在（`permission-button.tsx.ftl`、`managed-dict-select.tsx.ftl`、
  `managed-dict-text.tsx.ftl`、`use-managed-dictionary.ts.ftl`、`use-project-config.ts.ftl`、
  `use-project-id.ts.ftl`）；
- `package.json.ftl` 没有声明 `@kaiwu/web-starter`；
- ADR §4 要求的防回归门禁不存在；
- `@kaiwu/web-starter` 未发布到任何 registry，且**全工作区零消费者**——平台前端
  `kaiwu-system-web` 不依赖它，生成模板不依赖它。

也就是说 ADR 0016 从未落地，而 ADR 0016 §3 明确承认的代价是"生成项目从此**硬依赖内部
Nexus 可用与认证**"。ADR 0027 把 Kaiwu 转为开源交付之后，这个前提直接与目标冲突：外部用户
克隆开源仓、走五分钟黄金路径生成第一个项目，拿到的产物会在第一次 `pnpm install` 失败，
且失败原因是一个他们没有访问权、也无从获取的内网 registry。

一份标着 Accepted 却没有实现、且前提已经失效的 ADR，比没有这条 ADR 更糟：它让文档和代码
互相矛盾，而 Kaiwu 对外的主张恰恰是"把工程约束沉淀为可执行的规则"。

## 决策

### 1. 生成前端模板是前端公共层的唯一事实源

`templates/project/frontend/` 下的公共层副本**保留**，并确认为唯一事实源。生成项目的
`package.json` 只依赖公共 npm 上可解析的包，不依赖任何 `@kaiwu` scope 包，模板不生成
指向私有 registry 的 `.npmrc`。

生成产物必须在只有公网 npm 的环境下 `pnpm install` 成功。这是开源交付的下限，优先于
公共层的单源码收敛。

### 2. 退役 `kaiwu-web-starter`

该 SDK 从工作区移除，不建仓、不进工作区清单、不开源、不发布。它是为 ADR 0016 提前抽出的
产物，随该 ADR 一同退役。源码移入工作区 `backups/` 保留一份，不删硬盘。

CLAUDE.md 的"只做能理解、能验证、能维护的能力"和"用例出现前不抽象"在这里是决定性的：
开源一个零消费者的包，等于要求外部读者判断"这个包我该不该用"，而正确答案是"不该"。

### 3. 前后端 Starter 不对称是有意的

保留 `kaiwu-system-starter`（后端）而退役 `kaiwu-web-starter`（前端），依据是**它们承载的
契约强度不同**，不是遗漏：

- 后端 Starter 承载**安全契约**——本地验证 Gateway 签发的 Context、执行接口权限与数据归属
  授权（ADR 0003、ADR 0022）。它有真实消费者（生成后端的 `domain-pom.xml.ftl` 直接依赖），
  且每个项目各自实现一遍必然出现可利用的实现差异。这类能力必须单源码。
- 前端副本承载的是**一致性契约**——权限按钮、受管字典、项目上下文的取值与展示。它们发散
  会造成体验不一致，但不会造成越权：前端权限码只控制按钮显隐，真正的拦截在后端注解和
  Gateway。权限三端同码由 `pnpm check:perm` 保证，不依赖这些文件是不是同一份源码。

安全契约必须收敛，一致性契约可以复制。这条判据也是将来判断"某个能力该不该抽 SDK"的口径。

### 4. 防回归门禁守真正的风险

ADR 0016 §4 的门禁（禁止模板出现与 SDK 同名文件）随该 ADR 作废——SDK 已退役，没有重名可言。

替换为守住本 ADR §1 下限的门禁：`package.json.ftl` 不得声明 `@kaiwu` scope 依赖，
`templates/project/frontend/` 不得出现 `.npmrc` 模板。由
`ProjectScaffoldArchitectureTest` 校验。

这条门禁比 ADR 0016 那条更有价值：它拦的是"生成产物装不上"这个**可验证的失败**，
而不是"两份源码可能不一致"这个只能靠人判断的风险。

## 后果

- 生成产物零私有 registry 依赖，开源黄金路径成立。
- 平台契约变更时，前端公共层仍需人工同步到模板——但同步目标从"两处"降为"一处"，
  因为 SDK 侧已不存在。
- 文档与代码恢复一致：不再有标着 Accepted 却未实现的 ADR。
- 放弃了 ADR 0016 追求的"公共层版本化、可追溯回滚"。这是明确接受的取舍：
  ADR 0006 规定项目只生成一次、生成后平台不接管，公共层的版本化回滚本就没有承接方。

## 被否决方案

- **把 `@kaiwu/web-starter` 发布到公网 npmjs，再按 ADR 0016 原样实施**：npm 发布是不可逆的
  对外动作（unpublish 有严格窗口限制），且会为一个当前零消费者的包永久占用 `@kaiwu` scope
  并背上公开维护义务。要为尚不存在的需求先付这个代价，与"用例出现前不抽象"直接冲突。
- **只把 ADR 0016 状态改为 Deferred，其余不动**：改动最小，但 `kaiwu-web-starter` 会继续以
  零消费者状态留在工作区，下一个人仍要重新判断它该不该用。
- **保留 SDK 并加跨仓一致性门禁**：两侧分处独立版本化的仓库，任一仓的 CI 都看不到对方，
  门禁只能落在工作区入口，而入口不得依赖产品仓同时在场（ADR 0027 §1）。技术上做不实。

## 不做什么

- 不改动已生成的存量项目。ADR 0006 规定平台不接管已交付项目。
- 不改动后端 `kaiwu-system-starter` 的任何边界。
- 不因为退役前端 SDK 而放松权限三端同码（`pnpm check:perm`）或受管字典（`pnpm check:dict`）门禁。
