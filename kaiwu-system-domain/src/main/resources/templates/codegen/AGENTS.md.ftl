# ${projectName} 生成代码契约

- 本独立仓库只属于项目 `${projectCode}`；禁止把其他业务项目模块放进来。
- 后端固定 JDK 21 + Spring Boot 4，生成项目使用单一可部署 Maven 模块。
- 前端固定 `@umijs/max + Ant Design 5 + ProComponents`。
- 权限码必须在后端 `@RequirePermission`、前端 `PermissionButton`、平台 `menu.sql`
  BUTTON 节点三处完全一致。
- 字段中文名和检索标记可能来自平台受控的大模型建议，但源码、SQL、路由和权限仍由
  确定性模板生成；不得把生成说明当成可执行业务规则。
- 用户可见且需要翻译或运营配置的状态和枚举通过受管字典展示；内部状态机和协议码保留代码常量。
- 业务数据库变更只新增 `sql/increment/V{n}__*.sql`，并同步基线 schema。
- 外部 Access JWT 只由 Gateway 接受；业务服务只验证 audience/project 匹配的
  Kaiwu Context，并从 `StarterContext` 读取用户与项目。
- Secret 只允许环境变量注入，禁止进入代码、配置文件、生成日志或提交。
- 禁止直接在受保护分支实现；分支策略由业务团队维护。
