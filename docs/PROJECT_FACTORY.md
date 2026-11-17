# Kaiwu 项目工厂

## 已有产品前端

采购示例带有两个流程管理权限码。首次纳管会同步这两个按钮，现有项目用 `project sync <前端仓> --apply` 补上菜单。由项目管理员或取得 `workflow:definition:manage` 和 `workflow:document:manage` 两项授权的维护人导入流程；申请人和审批人的日常角色不需要这两项权限。

接入真实审批时，业务开发先实现接收审批结果的回调。在该项目的 Workflow 部署配置中登记 `kaiwu.workflow.callbacks.targets[purchase_request]` 的 `url`、`target-service`、`kid`、`secret-base64`、`not-before` 和 `not-after`。YAML 中的映射键写成 `"[purchase_request]"` 以保留下划线，从 Secret 注入密钥。然后执行 `./kaiwu workflow sync <前端仓>` 预览，首次加 `--apply` 后再次预览应为 `UNCHANGED`。403 时核对当前项目的两项权限及 Gateway 权限缓存；409 且原因为 `workflow.callbackTargetMissing` 时核对业务类型和回调登记。

在独立产品前端仓维护业务页面、规则、验收场景和平台清单。登录后运行 `./kaiwu project adopt <前端仓>` 预览，再加 `--apply` 登记并同步配置、下载后端。后端开发可通过 `pnpm dev:real` 联调。命令的复跑、仓库归属和配套后端门禁见 [ADR 0048](adr/0048-adopt-existing-frontend.md)。

项目工厂只生成符合 Kaiwu 规范的前后端基础脚手架，不调用 AI，也不根据 DDL 生成业务模块。

1. 登记业务项目并配置成员。
2. 创建基础脚手架生成任务，完成后下载前后端两个 ZIP，或通过 `./kaiwu project pull` 取回。
3. 在独立业务仓库中使用 AI 编程工具，遵循生成的 `AGENTS.md`、约束文件和项目测试继续开发。

一个项目只允许成功生成一次；成功后的制品不覆盖，已完成的历史任务仍可查看和下载。历史 DDL 任务不能重新提交或重试，已经排队或执行的旧任务仍按原输入完成。平台不再提供 MySQL 表结构导入接口。

CLI：`./kaiwu project new <项目编码> --name <项目名称> [--package <基础包名>]`。

接口：`POST /api/project-generations` 使用 `generationMode=BASIC_SCAFFOLD`，状态、重试与下载通过 `/api/project-generations/{taskNo}` 相关接口完成。业务权限、菜单、字典及配置由生成项目后续通过清单同步。

早期设计与已下线接口见 [历史记录](PROJECT_FACTORY-legacy.md)，仅供追溯。
