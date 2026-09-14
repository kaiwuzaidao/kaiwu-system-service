# ${projectName} 前端 Agent Contract

- 本仓库只属于 `${projectCode}`，使用 `@umijs/max + Ant Design 5 + ProComponents`。
- 权限码必须与后端 `@RequirePermission`、平台 `menu.sql` BUTTON 完全一致，
  由 `pnpm check:perm` 校验，**改完必须跑**。同一模块下新增 action（如 `:export`）
  不需要改契约文件；**新增模块**必须把 `permissionPrefix` 登记进
  `docs/kaiwu-project-blueprint.json` 的 `modules`，并同步补后端注解与 `menu.sql` seed。
  该文件是本仓库与后端仓库共享的模块契约，不得删除。
- 用户可见且需要翻译或运营配置的状态/枚举走 `@/hooks/useManagedDictionary` 与
  `@/components/ManagedDictSelect|ManagedDictText`，
  数据来自平台字典管理（global 字典 + 本项目覆盖项合并），禁止页面硬编码
  选项或 value→label 映射；未知值原样显示。新增枚举先到平台字典管理建
  `{module}.{resource}_status` 之类的 dictCode，再在页面引用。
  `pnpm check:dict` 会拦住页面里的硬编码 `valueEnum` 和非法 dictCode；
  它查不了「平台上是否真配过这个字典」——那属于平台侧体检，仓库 CI 看不到。
- 运行期可变且需要运营调整的展示参数默认走平台「参数配置」，用
  `@/hooks/useProjectConfig` 读取；领域不变量可以留在版本化代码中：

  ```tsx
  import useProjectConfig, { useProjectConfigNumber } from '@/hooks/useProjectConfig';

  const notice = useProjectConfig('order.notice.text', '');       // 必须给兜底值
  const pageSize = useProjectConfigNumber('order.page.size', 20);
  ```

  配置在平台侧随时可改，因此只能在组件内读取，不要提到模块作用域当常量缓存；平台不可达
  时返回 fallback，页面不得因取配置失败而崩。密钥类不走配置中心。
  **只用于展示**：限额、阈值、开关等参与校验的配置必须由后端读取并校验，前端读了再传回
  后端等于没有校验。
- 界面文案走 `src/locales/{locale}.ts`，用 `useIntl().formatMessage({ id })` 渲染。
  只对 `docs/kaiwu-project-blueprint.json` 的 `supportedLocales` 要求 key 完整；默认只启用
  `zh-CN`，增加语言后再补齐该语言。菜单名用 umi 的
  `menu.{name}` 约定，与 `config/config.ts` 里的 `name` 对应。
- **不要添加语言切换器、不要写 localStorage、不要认浏览器语言**：本前端嵌在 Kaiwu 平台内，
  语言由 `ProjectAccessProvider` 依据平台账户偏好设置，自建语言状态会造成平台与内嵌页面
  显示不同语言。
- 字典标签的多语言由平台按 `Accept-Language` 下发，页面照常用
  `useManagedDictionary` / `ManagedDictText` 即可，不要在前端做 value→多语言映射。
  字典项的译文在平台「字典管理」里维护。
- 请求必须携带平台 Access Token 和权威 `projectId`，后端授权才是安全边界。
- 页面请求统一放在 `src/services`，公共能力按
  `components/hooks/providers/services/utils/pages` 分层，禁止恢复单文件大壳层。
- 导出失败必须捕获并 `message.error` 提示——导出超限由后端返回 400，不提示会让用户
  以为按钮失灵。
- Secret 不得写入源码、构建参数、日志或提交。
- 具体分支策略由业务团队维护；本仓库生成后由业务团队独立维护。
- 不得把凭据或敏感个人信息写进 `console`（约束 `logging.no-sensitive-data`，MUST）：
  控制台会被录屏、被前端监控 SDK 采集、被截图发进工单。只输出标识、长度或掩码值，
  由 `pnpm check:log` 把关。
- 约束强度以 `docs/kaiwu-constraints.json` 为准；只有 WARN/DEFAULT 可通过
  `docs/kaiwu-constraint-waivers.json` 有期限偏离，MUST 不可豁免。
