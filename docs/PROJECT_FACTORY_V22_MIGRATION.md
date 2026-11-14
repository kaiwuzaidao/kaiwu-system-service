# 项目工厂 v22：首页与账号布局

首页只提供当前项目有权限的业务模块入口，表名、生成成功提示与开发步骤不再展示给业务用户。无业务模块与无权限分别提示联系项目管理员；权限加载失败可重试。账号和 System 一致，集中在右上角。

现有项目不重新生成、不覆盖。由业务仓维护者参考本 MR 手动更新 `src/app.tsx`（关闭侧栏 footer）、`RightContent`（保留顶栏账号）、首页、语言包和相关样式；保留本仓业务逻辑及既有令牌/通知修复。采购示例另有独立业务 MR。

v21 为站内信方法修复 MR !207 预留；本 MR 从 dev 的 v20 顺延到 v22，不包含未合入分支代码。合并时协调版本，保留两项变更，不复用已发布 templateVersion，不改历史 ZIP 或生成记录。

验证：`./scripts/verify.sh`、空模板前端 `pnpm verify`、`node scripts/verify-generated-home.mjs`。最后一项在前两类产物均已构建后，使用生成项目安装的 Playwright 和本机 Chrome，在一次性本地 fixture 服务中验证页面，不访问真实平台、不读取 Secret。
