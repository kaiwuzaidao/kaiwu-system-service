# Agent 声明式输入表单：第一批

2026-09-27。范围：本地能力的文本输入表单基础；不是完整 CapabilityManifest v2，也没有新增字典或业务写能力。

## 接入方式

本地能力在参数 schema 后声明 `inputForm(titleKey, orderedNames, multilineNames, formats)`。必填和最大长度从参数 schema 派生；字段名称、权限必须与能力一致。当前控件只有文本和多行文本，格式只支持 text、slug、javaPackage，不接收脚本、HTML、任意正则或 URL。字段译文使用 `agent.input.<参数名>`，标题使用指定的资源 key。

注册了表单的能力可以保留不完整的单条计划。服务端校验已提供的参数和权限后返回描述；前端直接提交能力码和值，不提交描述，不让模型重写填写内容。表单声明不授予执行权，原有只读/写入审批与确认守卫继续执行。

项目创建已迁到此机制。写执行和预览仍使用既有 ProjectActionCoordinator，本批并未消除该业务执行分支。通用输入渲染不再依赖项目能力码；新增能力仍需要执行适配、资源译文和对应测试。

## 兼容与发布

后端先发布、前端后发布。旧前端可忽略新增 definition，仍可提交原请求。旧历史表单没有 definition 时，新前端提示重新发起，不猜测字段或恢复执行票据。已保存聊天记录不修改。

远程能力暂不接受此描述，防止未审核的 UI 元数据绕开 manifest 摘要。下一批应将输入/输出展示契约纳入注册、版本摘要、审核和 Starter，并建立明确的模型/浏览器投影，再接入 System 字典和业务项目配置试点。

## 本地验证

- AgentPlanValidatorTest 20 项、AgentServiceTest 31 项通过，覆盖缺参、未知字段、权限撤销、另一能力声明、元数据不一致、预览而非执行。
- Web 创建项目链路 11 项 Playwright 通过；额外另一能力码通用渲染用例通过。均为本地 mock API，不是 test 环境真实业务写入。
- Web pnpm verify 通过（跨仓 KAIWU_SERVICE_DIR / KAIWU_SQL_DIR 指向同批后端）；生产依赖审计无 high，仍有 1 low / 8 moderate。
- 后端 `spotless:apply` 与 `./scripts/verify.sh` 通过，包含临时 MySQL 数据层测试及生成后端/前端真实构建。发布状态以交接记录为准。

CI 补充：新分支的 Starter 预构建因未使用仓库 Maven 镜像，在下载编译检查器时长期等待 Maven Central 响应。预构建现复用 `.mvn/settings.xml`，分支 Maven 缓存允许回退到 dev；验证、格式、安全扫描和数据库门禁不变。CI YAML 本地解析通过；GitLab lint API 返回 HTTP 400，需以新提交的实际流水线验证为准。
