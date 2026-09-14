# ADR 0014：字典项标签引用国际化资源，退役客户端隐式覆盖

- 状态：Accepted
- 日期：2026-08-06
- 决策范围：`kaiwu-system-service`、`kaiwu-system-web`
- 保留：ADR 0013 的引用式国际化模式（可空 key 列、写入时校验、就地新建）
- 修正：ADR 0010 阶段三「字典标签靠 `label_i18n`」的实现在全局字典场景下从未真正生效

## 背景

排查字典标签翻译时发现两条并存且互相打架的机制：

1. **`label_i18n`**：`sys_dict_item` 上的内联 JSON 列，管理页面「标签多语言」输入框编辑，
   由 `MetadataService.localizedLabel(item, locale)` 按 `Accept-Language` 解析。
2. **`dict.{dictCode}.{itemValue}` 约定 key**：前端 `useDict` 钩子对每个字典项标签都套一层
   `intl.formatMessage({id: 'dict.{code}.{value}', defaultMessage: option.label})`，
   命中平台 i18n 资源目录（`sys_i18n_message`）时直接覆盖显示。

问题是 `useDict` 消费的 `GET /api/metadata/dicts/effective/{dictCode}`
（`MetadataService.platformDict`）调用的是不带 locale 的 `toItemView(item)`，
**从未解析过 `label_i18n`，永远只返回录入原文**。也就是说：

- **全局（`scope_id=0`）字典的翻译，实际全部由机制 2（客户端隐式覆盖）决定**——这是平台
  绝大多数字典（状态、类型等）在管理后台各处实际展示时唯一生效的路径。
- 管理页面能编辑的「标签多语言」（机制 1）对这些字典**完全不起作用**，纯属摆设；
  用户填了译文，界面上什么变化都没有。
- 机制 2 是约定推导、不可见、不可编辑——用户在界面上找不到它，只能通过读代码才知道存在。

这不是风格不统一，是一个真实的功能性缺口，且与 ADR 0013 已经建立的「引用式国际化」
模式（显式 key、写入时校验、界面可见可编辑）相悖。

## 决策

### 1. 字典项新增可空引用列，两种模式都用「引用」

`sys_dict_item` 增加 `label_i18n_key VARCHAR(160) NULL`，与 ADR 0013 同样的约定：
非空即启用，不加布尔开关列。

与菜单不同，**字典项不区分「内置/业务」两种模式**——菜单当初的限制是「业务项目菜单名
无法预先登记为资源」，但字典项和参数配置一样，本就是运行期创建的对象，
「就地新建资源」已经解决了这个问题（配置早就是这么做的）。因此字典项统一用
`LocalizedNameField` 的「固定文案 / 引用国际化资源」双模式，不分全局还是项目范围。

「固定文案」模式保留现有的逐语言输入框（`platform.locale` 目录里有几门语言就有几个
输入框），这是 `label_i18n` 真正支持多语言、且比菜单/配置的单一兜底值更强的地方，
不能退化成单个文本框。

### 2. 解析顺序统一：引用 key → label_i18n → 录入原文

`MetadataService.toItemView(item, locale)` 改为：`label_i18n_key` 非空且解析成功 → 用它；
否则退回现有的 `label_i18n` JSON 解析；再否则退回 `itemLabel`。与菜单/配置的
「引用 → 内联 → 原文」顺序一致，不引入第四种规则。

### 3. `platformDict` 补上语言解析，退役客户端覆盖

`platformDict(dictCode, language)` 改为接收 `Accept-Language` 并调用
`toItemView(item, locale)`，让全局字典第一次真正在服务端完成翻译。

`useDict` 钩子删除 `intl.formatMessage({id: 'dict.{code}.{value}'})` 那层客户端覆盖——
服务端已经返回解析好的文本，继续保留客户端覆盖会造成两个真相源，且客户端覆盖的优先级
更高会掩盖服务端的结果，让人误以为改了 `label_i18n_key`没生效。

### 4. 存量的 `dict.{code}.{value}` 资源不物理删除，改为显式引用

`check:i18n` 的 `checkDictionaryCoverage()` 已经对 `DICT_FALLBACK` 覆盖的字典强制要求
`dict.{code}.{value}` 资源存在且中英双语齐全——这些资源本身是对的，只是消费方式是暗的。

迁移把这些已存在的资源**原样复用**为对应字典项的 `label_i18n_key`（不新建资源，
不改资源内容），和 ADR 0013 里 `menu.system.*` 的复用方式一致：约定 key 变成显式引用，
翻译内容不丢失、不重复。

### 5. `check:i18n` 门禁不变

`checkDictionaryCoverage()` 仍然按 `DICT_FALLBACK` 校验 `dict.{code}.{value}` 资源存在，
只是这些资源现在有了明确的消费方——某个字典项的 `label_i18n_key`。校验逻辑不需要改，
只是不再是「校验一个没人真正读的 key」。

## 后果

### 正向

- 全局字典标签翻译第一次在服务端真正生效，`label_i18n` 输入框不再是摆设。
- 管理页面显式可见「这个字典项翻译来自哪个资源」，与菜单/配置一致。
- 客户端不再有隐式覆盖，`Network` 面板看到的响应内容就是用户最终看到的内容。

### 成本与限制

- `platformDict` 从「纯读」变成「读 + 按语言解析」，多一次 JSON 解析和/或目录查询；
  量级与 `effectiveDict`（已有该开销）相同，可接受。
- 存量未被 `DICT_FALLBACK` 覆盖的全局字典项、以及所有项目范围字典项，
  行为从「客户端可能覆盖」变成「读 `label_i18n`」——这是把此前从未生效的死代码路径接活，
  不是回归；此前它们的实际显示是原文，现在若已填 `label_i18n` 会开始生效。

## 被否决方案

- **只加解析、不退役客户端覆盖**：会长期维持两个真相源，且客户端覆盖优先级更高，
  管理员改了引用资源却看不到效果，比现状更迷惑。
- **字典项也按「内置/业务」分裂两种模式**：字典项运行期创建时已有「就地新建资源」能解决
  key 不可预测的问题，複刻菜单的限制没有实际必要，徒增两套 UI 逻辑。
- **物理删除旧的 `dict.{code}.{value}` 资源再重建**：这些资源的翻译内容是对的，
  只是消费方式暗，删了重建纯粹增加风险和工作量。
