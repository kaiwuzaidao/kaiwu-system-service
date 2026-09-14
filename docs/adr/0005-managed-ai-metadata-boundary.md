# ADR 0005：受管大模型只增强代码生成元数据

- 状态：Accepted
- 日期：2026-07-23
- 决策范围：`kaiwu-system-service`、`kaiwu-system-web`

## 背景

Kaiwu 的 DDL 代码生成已经使用确定性 Parser 与 FreeMarker 模板，但缺少既有平台实践中的
已验证的 OpenAI-compatible Provider 配置和字段元数据增强。第一阶段仍明确排除
AI Development Harness、Agent 编排、模型直接写源码和自动业务逻辑生成。

## 决策

1. System 管理一条 OpenAI-compatible Provider 配置：名称、Base URL、模型、
   Temperature、超时、可选 Bearer API Key 和启停状态。
2. API Key 使用 `KAIWU_CONFIG_ENCRYPTION_KEY` 做 AES-256-GCM 加密；浏览器只得到
   `apiKeyConfigured`，不得得到密文、明文或可逆掩码。
3. Provider 管理权限为 `system:ai:list|save|test`，菜单和授权只登记到内置 system
   项目的 `sys_project_menu/sys_project_role_menu`。
4. 代码生成由用户显式选择是否调用模型。模型只能返回已解析表/字段的中文 label、
   `searchable` 建议和不超过 1000 字的设计摘要。
5. 服务端只接受输入中真实存在的表和字段，忽略模型返回的源码、SQL、权限、路由及
   未知节点；主键、逻辑删除和自动填充时间字段不能被模型改为搜索字段。
6. Java/TypeScript/SQL/权限仍全部由确定性模板生成。Provider 未配置、被禁用、超时、
   返回非 JSON 或解析失败时记录 `DETERMINISTIC_FALLBACK` 并继续生成。
7. 本能力不引入 AI Harness、Prompt 运营、调用计费、Agent、Runner、自动业务逻辑或
   第五个服务。

## 后果

- 正常 DDL 生成不依赖外部模型，模型故障不会阻断 ZIP。
- 管理员可使用内网或公网 OpenAI-compatible 服务；Base URL 允许 HTTP(S) 和内部地址，
  因为内网推理服务是有效场景，但接口只对 system 项目授权用户开放并记录审计。
- 数据库存储 Provider 配置后，其启停状态是运行时事实；不从普通应用配置或浏览器
  Secret 回退，避免多来源歧义。
