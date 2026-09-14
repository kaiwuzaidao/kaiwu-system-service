# ADR 0011：数据库国际化资源中心

- 状态：Accepted
- 日期：2026-08-05
- 范围：Kaiwu 平台 System、Gateway、Web 与 Starter 错误契约
- 取代：ADR 0010 中“运行期使用完整代码语言包、首期不建设数据库动态语言包”的决策
- 保留：ADR 0010 的用户语言持久化、稳定 key、机器值不翻译、历史事实不改写等边界

## 背景与目标

代码语言包已验证用户偏好和无刷新切换路径，但产生了两套事实源：固定页面文案在 Web，
菜单和字典在数据库，后端又保留中文异常。新增语言仍需跨仓修改，且后台启用语言并不等于
页面能够使用。真实需求是：运行期文案由数据库统一管理；新增语言只增加语言目录和译文，
不新增表字段，也不修改每一个页面。

本 ADR 建立数据库资源中心，并在替代链路验收后删除做到一半的静态双语实现。目标是：

1. 登录后平台固定 UI 与 API 提示以数据库为主事实源；
2. 菜单、字典仍由其业务表负责翻译，但遵循同一语言目录和回退规则；
3. System、Gateway、Starter 只产生稳定 `messageKey/messageArgs`，不以中文句子作为契约；
4. 新语言只有在资源覆盖完整时才对用户开放，杜绝半翻译界面；
5. 登录、资源中心或数据库异常时仍有最小可恢复界面。

## 事实源与边界

| 内容 | 主事实源 | 回退 |
|---|---|---|
| 固定 UI、校验、空状态、API 提示 | `sys_i18n_message` | Web 最小救援包 |
| 菜单名称 | `sys_project_menu.menu_name_i18n` | `menu_name` |
| 字典项标签 | `sys_dict_item.label_i18n` | `item_label`，最终回退机器值 |
| 运营或参数文案 | `sys_app_config`（值可引用 message key） | 配置自身 fallback |
| 审计 detail、已投递通知 | 写入时历史事实 | 不翻译、不回写 |

最小救援包只允许以下范围：登录表单、服务不可用、资源加载失败、会话失效和语言名称。
它随 Web 发布且不可后台编辑；除这组 key 外，完整 `src/locales/{locale}` 目录必须删除。

## 数据模型

### 国际化资源

`sys_i18n_message`：

- `id BIGINT`：19 位 ID；JSON 和 TypeScript 中始终为字符串；
- `message_key VARCHAR(160)`：全局唯一、稳定语义 key；
- `default_text VARCHAR(2000)`：固定为 `zh-CN` 默认文案；
- `translations_json JSON`：非默认语言译文，例如 `{"en-US":"Save","ja-JP":"保存"}`；
- `module_code VARCHAR(64)`：资源域，用于管理筛选，不参与 key 唯一性；
- `public_visible TINYINT`：是否允许匿名资源接口返回；只允许最小救援 key；
- `required_resource TINYINT`：语言启用覆盖率的必需资源；
- `status`、`description`、`version`、审计时间。

更新必须携带 `version` 并执行 CAS；版本不匹配返回 409，防止不同语言的并发编辑互相覆盖。
`message_key` 创建后不可修改；语义变更必须新建 key 并迁移调用方，避免后台编辑破坏已发布代码。
JSON 必须是 locale 到非空纯文本的对象；locale 必须来自 `platform.locale`；所有语言的
`{placeholder}` 集合必须与默认文案完全一致。不允许 HTML、脚本或富文本。

`sys_i18n_catalog_revision` 保存全局目录修订号。资源增删改与 revision 递增处于同一事务。
客户端只缓存内存快照，不写 Local Storage；revision 改变后重新加载。

### 语言目录

`platform.locale` 继续是语言唯一目录。字典值必须是规范 BCP 47 标签；日语为 `ja-JP`，
`jp` 非法。`extra_json` 定义：

```json
{
  "selectable": true,
  "antdLocale": "ja-JP",
  "dateLocale": "ja-JP"
}
```

`status=ENABLED` 只表示可以维护译文；只有 `selectable=true`、全部 required resource 有译文、
菜单与内置字典覆盖校验通过时，语言才出现在选择器。默认语言 `zh-CN` 使用 default_text。
语言选择器自身的语言名称也从该字典项的 `label_i18n` 解析，不维护固定语言名称数组。

## API 与鉴权

- `GET /api/public/i18n/catalog?locale=`：精确 PUBLIC 路由，只返回 `public_visible=1`；
- `GET /api/i18n/catalog?locale=&revision=`：PLATFORM 路由，所有已登录用户可读，不需要角色权限；
- `GET/POST/DELETE /api/i18n/resources`：PLATFORM 路由，分别要求
  `system:i18n:list/save/delete`；
- `GET /api/i18n/locales?locale=`：按界面语言返回语言名称、配置状态和覆盖缺口，登录用户可读；
- 管理端菜单与 BUTTON 权限必须写入 system 项目的 `sys_project_menu`。

匿名接口不返回内部错误文案、权限名称或管理文案。Gateway 继续精确白名单，禁止开放
`/api/public/**` 前缀。资源读取不改变 JWT、Context、会话或权限快照。

## 前端运行时

Web 复用 Umi 已创建的唯一 `IntlProvider`，通过运行期 `addLocale` 原子替换其消息快照，禁止再
嵌套第二个 Provider；消息集合为“最小救援包 + 当前数据库 catalog”。现有
`useIntl/FormattedMessage` 继续使用同一 React Intl Context，不再维护 API 错误专用静态
catalog。登录前读取 public catalog；登录成功后以 `sys_user.locale` 读取完整 catalog；切换语言
先预取并校验目标完整 catalog，再保存服务端偏好，最后原子切换 Provider 和 Ant Design locale。
资源服务故障因此不会把用户偏好写成当前客户端无法展示的语言。

Kaiwu 为初始语言预打包 Ant Design 组件 locale；数据库新增语言不要求修改业务页面。若新 locale
暂无组件适配器，应用文案仍使用数据库译文，Ant Design 内置文案安全回退英文。

加载失败不清除登录态、不切换到半份资源；保留上一份完整 catalog 并提示安全错误。首次加载
失败时进入最小救援界面。菜单 API 返回已按用户 locale 解析的 `name`，前端删除 `i18nKey`
路径推导；字典继续按 locale 返回有效标签。

## 后端提示契约

业务代码使用受约束的 key 常量和安全参数。`ApiException`、认证异常、Bean Validation、参数绑定、
Gateway 和 Starter 错误都必须有 `messageKey`；CI 禁止新增只有用户可见中文 `message` 的异常。
HTTP status 和机器 code 保持原义。兼容期 `message` 由 System 用 `default_text` 解析；资源库不可用
时只返回固定通用安全句，不允许错误处理再次访问失败的数据源形成递归故障。

## 缓存、一致性与回滚

System 按 `(locale, publicOnly, revision)` 使用有界内存缓存；写操作提交后使本实例缓存失效，
其它实例在下一次请求读取全局 revision 后收敛。响应携带 revision/ETag，查询参数 revision 或
`If-None-Match` 命中时返回 304。禁止 Redis
成为文案事实源。

迁移采用 expand/migrate/contract：先新增表和兼容读取，迁移并验证全量资源，再删除静态双语包、
路径菜单映射和无 key 异常构造器。应用回滚使用上一版 Web/System/Gateway/Starter 镜像；新增表
与 JSON 字段保持向后兼容，不反向删除，已发布 Flyway 不得修改或 repair。资源中心故障时新版
Web 只进入最小救援界面，不伪装成完整语言包。

CI 同时校验前端静态引用 key、跨语言插值占位符、System 稳定错误 key 与数据库资源的闭环；
无 key 异常构造器被删除，让遗漏在编译期失败。

## 完成条件

以下全部满足才算完成，不能以“表和 CRUD 已有”交付：

1. 现有 zh-CN/en-US 固定 UI 与稳定 API key 全量种入数据库，key/placeholder 门禁通过；
2. 登录、切换语言、跨浏览器恢复、资源更新生效和资源故障回退通过 E2E；
3. 菜单、字典、API 错误使用同一 locale；无 `jp` 等非法语言；
4. Web 完整静态语言目录、`apiMessage.ts` 静态 import、后端路径到菜单 key 映射已删除；
5. System/Gateway/Starter 无缺 key 的用户可见异常，相关 verify 全绿；
6. Flyway 新装、V9 升级、幂等重跑及 Helm 副本一致性通过。
