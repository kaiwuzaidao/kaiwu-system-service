# 声明式聊天结果展示

2026-09-27。Manifest 可选 `outputView`，与 `inputForm` 独立。当前渲染为聊天内表格，不添加页面跳转，也不代表分页、详情动作或全部业务能力已覆盖。

```java
new OutputViewSpec("试用配置详情", List.of(
    new OutputViewSpec.Field("id", "配置编号", OutputViewSpec.Format.TEXT, null),
    new OutputViewSpec.Field("enabled", "是否启用", OutputViewSpec.Format.BOOLEAN_ENABLED, null),
    new OutputViewSpec.Field("popupEnabled", "是否弹窗", OutputViewSpec.Format.BOOLEAN_ENABLED, null),
    new OutputViewSpec.Field("trialDays", "试用天数", OutputViewSpec.Format.TEXT, null)))
```

业务 Handler 只需增加声明、提升版本并重新审核，不需要在平台 AgentService 或 Cards 中增加能力码判断。前端和后端的权限校验、数据范围、字段白名单与脱敏先执行，显示声明不能扩大数据权限。清单必须由平台审核；模型输出、业务查询返回值均不能提供或覆盖它。

## 契约

- title/label：非空纯文本，最长100字，不能含控制字符。React 文本渲染，不执行 HTML、脚本、链接或翻译key。
- fields：有序、1–64项，名称不得重复，必须是 outboundFields 的子集。内部来源字段 sourceProjectId 不允许显示。未声明的列不渲染；本协议不会扩大或改变模型投影白名单。
- TEXT：原值文本。编号由业务返回字符串，前端不转换为 Number。
- BOOLEAN_ENABLED：使用平台 common.boolean_enabled 字典。仅对0/1及其字符串做布尔归一化；true/false也支持，未知值原样保留，不将任意非空值当作启用。
- DATETIME：仅将标准日期时间之间的T改为空格，保留原时区和精度；无效/未知时间原样保留。
- DICTIONARY：引用平台已有的受管字典；dictCode为有界点分代码，不允许URL或脚本。字典必须已通过平台正常字典流程接入，未知值仍原样展示。此批不提供子项目字典自动注册或跨项目字典代理。
- 空结果仍显示暂无数据；缺值显示短横线。未声明outputView的旧能力继续原有渲染。现有专用项目卡片尚未迁移。
- 用户明确要求不展示详情时，仍由既有AgentCardPolicy抑制整个卡片；展示声明不能覆盖用户的最小输出要求。查询卡片仍不持久化为可重放业务结果。

## 兼容、发布与验证

不声明 outputView 时不序列化该字段；旧13/14参数manifest构造器保留。V1和inputForm-v2黄金摘要不变。字段顺序、标签、格式、字典码均进入审核摘要，变化必须提升版本并重新审核。

新增fixture `agent-registration-output-v3.json` 在System与Starter共用，摘要为 `87c3885ce6fd15e8cc85ae3076de2d934a14bb904b18a5ca21c2dfd639dfb16f`。

部署顺序：System → Web → Starter SDK发布 → 子项目显式固定新SDK并注册提升后的能力版本 → 用户审核 → 真实聊天验收。未经审核不能称已开放。本地验证及发布证据记录于工作区本批交接。


## 2026-09-27：聊天内分页与行详情

`OutputViewSpec` 新增可选 `Pagination(pageParam, sizeParam)` 和 `Detail(label, capabilityCode, param, rowField)`，旧两参数构造器和旧版摘要兼容。新增声明进入逐版审核摘要。

- 分页必须为只读能力，声明完整 inputForm；页码与页大小为最小值1、明确上限和默认值的整数，页大小不超过50。保留当前已校验筛选，只修改页码；上一页/下一页走现有受控 input 调用，服务端重新校验能力版本、当前权限、参数和数据范围。
- 协议尚无 total，不伪造总数。满页才提供下一页，末尾允许到达空页并返回；不足页无下一页。达到页码上限或结果投影截断时不继续翻页，避免跳过未显示数据。
- 详情只能绑定同项目、当前可见、免确认只读且带 inputForm 的能力；当前支持一个字符串参数绑定一个显示白名单字段。缺失、非字符串或已脱敏字段不生成按钮，19位ID不转数字。目标还有其他未满足必填参数时不生成按钮。
- 元数据不包含URL、表达式或脚本。无权限/未审核/离线目标不显示按钮，点击旧按钮仍会由服务端重新拒绝。浏览器不能以按钮元数据授权操作。
- 点击会在同一会话新增一次查询及结果卡；旧卡保留为该次查询的结果，时间明确；恢复历史仍只恢复文本，不恢复可执行按钮。失败显示服务端原因，不当作成功，不自动重试。
- 写操作不通过详情按钮执行；编辑能力继续独立补参、预览和确认。此次不宣称完整CRUD或所有子项目已迁移。
