# 跨项目声明式聊天表单

2026-09-27。协议增量：manifest 可选 `inputForm`。本批不是完整 Manifest v2，也没有自动开放业务接口或新增任何业务写能力。

## 业务项目如何接入

现有 Handler 继续处理领域权限、数据范围、事务及预览/确认。仅需升级 Starter，在该 Handler 的 `CapabilityManifest` 末尾增加 `InputFormSpec`，并提升业务能力版本。例如已有 keyword、enabled、pageSize 参数的能力：

```java
new InputFormSpec("查询客户记录", List.of(
    new InputFormSpec.Field("keyword", "关键词", false),
    new InputFormSpec.Field("enabled", "是否启用", false),
    new InputFormSpec.Field("pageSize", "返回条数", false)))
```

字段类型、必填、长度和整数边界从原 params 派生，不另写一份 UI schema。表单必须覆盖全部参数，不允许多余、重复、身份、凭据或未知字段。支持 STRING、INT、BOOL、ENUM、DATETIME；对象选择、上传和秘密输入尚不支持。多行只允许 STRING。标题和标签是最长100字的纯文本，由项目声明、平台审核；不是模型生成的 HTML 或平台翻译 key。当前标签随 manifest 固定语言，多语言元数据后续演进。

注册仍使用既有凭据和审核流程。代码和镜像上线不等于能力获准执行，新增或变化清单必须提升版本并审核。普通相同类型表单不需要在 AgentDock 或 AgentService 增加能力码分支。

## 摘要兼容与部署顺序

- 不声明表单时，JSON 不输出 inputForm，v1 黄金摘要保持 `3827d7734ca1f6cc6c550a615a721a7cfed86fbf2326b4c0af83a4861f3600b2`。旧构造器保留，旧项目无需同步改造。
- params 的键、outboundFields 和枚举 values 仍按集合规范化。inputForm.fields 是有序序列，调序、改标题、改标签均改变审核摘要。System 和 Starter 用同一黄金 fixture 校验摘要一致性。
- 先发布 System，再发布 Web，最后发布新版 Starter 并让业务方显式采用。旧 System 不支持有表单的清单，不应提前发送；新版 Starter 未声明表单时仍兼容旧 System。
- 表单提交只携带 capabilityCode 和 scalar values，不携带权限、schema、URL 或执行凭据。重新读取当前能力、版本和项目权限。产生的新写预览仍走原确认与幂等链路，不复用旧预览。

## 权限和数据类型

平台用户权限列表不包含子项目权限。远程表单只有通过 System 的目标项目授权和实时复核后才会返回；前端提交入口只检查 `system:agent:ask`，不伪造业务权限。业务权限仍取 manifest.permission，由 System 与目标服务校验。撤权、离线、撤销及摘要不匹配均不可使用。

结构化提交保留布尔 false 和整数0。显式表单值的类型、边界严格校验，不使用模型参数的自动转换、截断或钳制。未知字段及嵌套对象拒绝。模型规划的原有归一化策略不变。

## 验证与范围

- System 完整 `./scripts/verify.sh` 通过：422 domain tests，0失败；另有2个既有 smoke skip。
- Starter 完整 `./scripts/verify.sh` 通过：102 tests，0失败。
- 前端13项聊天回归通过，包括没有子项目权限快照时正确显示远程表单，false/0提交为原类型、提交不携带表单定义、保持写入确认边界。
- 同一 fixture 在 System、Starter 断言相同摘要；旧 v1 fixture 保持兼容。覆盖非法/重复字段、不支持类型、字段顺序变更、无权限与权限撤销、整数类型和范围。
- 这些是本地与模拟接口验证。尚未将实际 CRM Handler 升级注册为带表单的新版本，因此不宣称真实业务已完成表单接入。发布状态看本轮交接记录。

后续优先补枚举/字典、日期、列表/详情/分页动作，以及 System 字典和 CRM 配置两个真实试点。业务功能列表覆盖与通用执行 SPI 仍需继续建设。


## 枚举与日期时间控件（2026-09-27 增量）

枚举字段从 params.values 取得有限候选值，并在 inputForm.fields 中声明受管字典：

```java
new InputFormSpec.Field("status", "记录状态", false, "crm.record_status")
new InputFormSpec.Field("since", "开始时间", false)
```

上述字典代码仅为接入示例，业务需使用实际已存在的受管字典。status 的参数类型为 ENUM，since 为 DATETIME。每个枚举字段必须声明合法 dictCode，其他类型不得声明。字典标签不会扩张批准候选值；字典找不到的候选值按原始值显示，不自动替换或隐藏。字段新增 dictCode 会改变清单摘要，未声明该字段的旧清单摘要保持不变。

日期时间使用统一 AntD DatePicker，提交 `YYYY-MM-DDTHH:mm:ss` 本地时间字符串，与既有 LocalDateTime 协议一致，不转 UTC、不附带浏览器时区。字段仍由服务端严格校验，非法日期、清单之外的枚举值不能执行。表单不会跳过业务写预览或最终确认。

平台本地能力可使用 inputForm 的 dictionaries 重载，字段名映射受管字典代码；远程能力由审核后的清单自动生成。接入这些字段不需要修改 AgentDock 或增加能力码分支。本批平台支持不等于所有现有业务清单自动升级；业务采用扩展后仍须提升版本并审核。
