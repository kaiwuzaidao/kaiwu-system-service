# ${projectName} 前端开发说明

项目编码：`${projectCode}`  
部署 base：`/apps/${projectCode}/`  
API 前缀：`/${projectCode}-api`  
脚手架版本：`${templateVersion}`

验证命令：
`pnpm install --frozen-lockfile && pnpm typecheck && pnpm check:dict && pnpm check:perm && pnpm build`。
四项都在 CI 门禁里，本地先跑完再提交。

`pnpm format` 使用固定 Prettier 版本消除不同人员与模型的排版差异；它是可自动修复的默认能力。

`docs/kaiwu-project-blueprint.json` 是本仓库与后端仓库共享的模块、权限与启用语言契约，
`check:perm` 依赖它；新增模块时往 `modules` 追加一条。后端仓库按
`../kaiwu-${projectCode}-service` 平级放置（或设 `KAIWU_SERVICE_DIR`）时，
`check:perm` 会自动升级为与后端注解、`menu.sql` 逐码比对。

目录约定：页面放在 `src/pages`，接口放在 `src/services`，公共能力分别放在
`src/components`、`src/hooks`、`src/providers` 和 `src/utils`。

约束强度见 `docs/kaiwu-constraints.json`；WARN/DEFAULT 的临时偏离写入
`docs/kaiwu-constraint-waivers.json`，必须包含责任人、原因和到期日。
