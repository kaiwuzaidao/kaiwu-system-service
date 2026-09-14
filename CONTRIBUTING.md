# Contributing to Kaiwu System Service

感谢参与 Kaiwu。提交变更前请先创建 Issue 说明问题或设计，安全漏洞请遵循
[SECURITY.md](SECURITY.md)，不要公开披露。

## 开发流程

1. 从最新开发分支创建短生命周期分支。
2. 保持提交聚焦，不提交密钥、内部地址、生成产物或无关格式化。
3. 先安装相邻 `kaiwu-system-starter`，再执行 `mvn -s .mvn/settings.xml verify`。
4. 提交 Merge Request，并说明行为变化、测试结果、数据库和兼容性影响。

`V1__kaiwu_baseline.sql` 只用于全新空库。已发布的 `sql/increment/V{n}__*.sql` 不可修改；
数据库变化从当前最高版本继续追加。API、权限、配置、字典或菜单契约变化必须同步更新
`sql/schema.sql`、文档和测试。
