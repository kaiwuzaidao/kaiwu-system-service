# ADR 0016：生成项目前端依赖 @kaiwu/web-starter，退役模板内的公共层副本

- 状态：Superseded by ADR 0028
- 日期：2026-08-07
- 决策范围：`kaiwu-web-starter`、`kaiwu-system-service`（项目工厂模板）
- 修正：开发记录中「`@kaiwu/web-starter` 已抽出但有意不改生成模板」这一临时状态

> **本 ADR 从未落地，且前提已失效。** §3 明确接受的代价是「生成项目硬依赖内部 Nexus」；
> ADR 0027 把 Kaiwu 转为开源交付后，该前提与目标冲突——外部用户拿到的生成产物会在第一次
> `pnpm install` 失败于一个他们无权访问的内网 registry。2026-08-16 由 ADR 0028 取代：
> 生成前端模板确认为公共层唯一事实源，`@kaiwu/web-starter` 一并退役。
> 下文保留原始决策内容以存档，**不再作为有效约束**。

## 背景

前端公共层现在是**两份源码**：

- `kaiwu-web-starter/src/` —— 已发布形态的 SDK（`@kaiwu/web-starter`），导出
  `PermissionButton`、`ManagedDictSelect`、`ManagedDictText`、`useManagedDictionary`、
  `useProjectId`、`useProjectConfig`、`ProjectAccessProvider`、`requestJson`、
  `configureAccessToken` 等平台契约。
- `templates/project/frontend/*.ftl` —— 项目工厂模板里同一批能力的 FreeMarker 副本
  （`permission-button.tsx.ftl`、`managed-dict-select.tsx.ftl`、`use-project-config.ts.ftl`
  等 9 个文件）。

抽出 SDK 时有意没动模板，因为包还没发布到内部 Nexus，改了模板会让生成项目
`pnpm install --frozen-lockfile` 直接失败。这个临时状态的代价是：**改一边必须记得同步另一边**，
忘了同步时生成项目编译能过、行为却和平台契约不一致——属于沉默失败，
与 `check:perm` / `check:i18n` 守的那两类同一种。

一次外部评审把这条列为"最可能误判"，2026-08-07 核实结果是**唯一仍然成立**的一条。

## 决策

### 1. 模板改为依赖 `@kaiwu/web-starter`，删除副本

生成项目的 `package.json` 依赖 `@kaiwu/web-starter`，模板中与 SDK 导出**一一对应**的
9 个副本文件删除，业务页面改为从包导入：

| 退役的模板文件 | 替代的 SDK 导出 |
|---|---|
| `permission-button.tsx.ftl` | `PermissionButton` |
| `managed-dict-select.tsx.ftl` | `ManagedDictSelect` |
| `managed-dict-text.tsx.ftl` | `ManagedDictText` |
| `use-managed-dictionary.ts.ftl` | `useManagedDictionary` |
| `use-project-id.ts.ftl` | `useProjectId` / `readProjectId` |
| `use-project-config.ts.ftl` | `useProjectConfig` 等 |
| `project-access-provider.tsx.ftl` | `ProjectAccessProvider` / `useProjectAccess` |
| `request.ts.ftl` | `requestJson` |
| `access-token.ts.ftl` | `configureAccessToken` 等 |

不在 SDK 导出范围内的模板文件（`app.tsx`、`module-page`、`module-service`、
`check-dict-consistency.mjs`、`check-permission-consistency.mjs`、`Dockerfile`、
`nginx.conf`、`gitlab-ci.yml`、`tsconfig`、`typings`、`README/AGENTS/CLAUDE`）
**继续由模板生成**——它们是每个项目自己的代码或工程配置，不是平台契约。

判据沿用 `kaiwu-web-starter/src/index.ts` 的既有口径：**平台契约进包，通用 UI 和项目自有代码不进包**。

### 2. 依赖版本写死，不用范围符

模板生成 `"@kaiwu/web-starter": "0.1.0"` 这样的**精确版本**，不用 `^`。

理由：每个项目只生成一次、生成后平台不接管（ADR 0006）。范围符会让同一份生成产物
在不同时间 install 出不同的公共层版本，而没有任何人为这种漂移负责。
精确版本让生成产物可复现；项目团队将来要升级是他们自己的显式动作。

### 3. 生成前校验包可用，不把失败推给使用者

项目工厂在生成前校验模板固定的那个 starter 版本在配置的 registry 上可解析；
解析不到就**在生成阶段失败并指明版本号**，不生成一个装不上的产物。

这是本决策接受的主要成本：生成项目从此**硬依赖内部 Nexus 可用与认证**
（外部评审原 4.3 从"坑"变成"必经路径"）。把它前移到生成阶段，
是为了让失败发生在有人盯着的时刻，而不是交付之后第一次 `pnpm install` 时。

模板同时生成 `.npmrc`，只为 `@kaiwu` scope 指定 registry，其余包走公共源。
`.npmrc` 里**不写任何凭据**，认证由使用者的环境提供。

### 4. 防回归门禁

模板目录不得再出现与 SDK 导出重名的公共层文件。加一条校验：
`templates/project/frontend/` 下若出现表格中已退役的文件名，构建失败。

没有这条，下一个人"图方便先在模板里改一版"就会悄悄把双源码复活——
这正是本 ADR 要消灭的状态。

## 后果

### 正向

- 公共层只有一份源码，改一次全部生成项目的**新安装**都拿到一致行为。
- 平台契约的变更有了版本号，可追溯、可回滚。
- 模板体积和维护面减小 9 个文件。

### 成本与限制

- **生成项目硬依赖内部 Nexus**。离线或无认证环境下无法 install 生成产物。
  这是明确接受的取舍：公共层一致性优先于生成产物的零内网依赖。
- **已生成的存量项目不受影响**，它们保留着自带副本。本 ADR 不做存量迁移——
  ADR 0006 明确平台不接管已交付项目，强行改动它们的源码越界。
  存量项目要收敛只能由项目团队自己按 SDK 重写。
- **starter 发布成为交付前置**。新增或修改平台契约后，必须先发版再改模板固定版本号，
  两步不能并成一步。

## 被否决方案

- **模板保持自包含，只加"两处必须同批改"的 CI 校验**：门禁只能比对文件是否同时被改动，
  比不出语义是否一致；且永久保留两份源码，每次公共层变更成本翻倍。
- **平台前端先接 starter、模板暂不动**：期间变成三份源码（SDK、已收敛的平台前端、模板副本），
  比现状更糟。
- **范围符 `^0.1.0`**：生成产物不可复现，且公共层的破坏性变更会波及没人看管的老项目。

## 落地范围（另批执行）

本 ADR 只确定方向。实施至少包含：starter 发版到内部 Nexus、模板 9 文件删除与导入改写、
`package.json.ftl` / `pnpm-lock.yaml.ftl` / `.npmrc` 更新、生成前版本校验、防回归门禁，
以及 `scripts/verify-generated-scaffold.sh` 对新产物的验证。按"一批一个可回滚纵切"拆分。
