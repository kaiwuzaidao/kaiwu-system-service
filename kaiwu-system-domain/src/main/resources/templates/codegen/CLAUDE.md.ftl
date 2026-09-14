# ${projectName} 开发说明

项目编码：`${projectCode}`  
基础包名：`${basePackage}`  
分支策略：由业务团队维护；禁止直接在受保护分支实现。

后端模块采用 `${projectCode}-api -> ${projectCode}-domain -> ${projectCode}-boot`。
生成的 CRUD 位于 `${projectCode}-domain`，业务逻辑在明确理解后增量补充。

验证命令：

```bash
mvn verify
cd admin-web && pnpm typecheck && pnpm build
```
