# Kaiwu 实现与发布记录

## 发布标识

公开源码、制品、配置、数据库种子和文档统一使用 `Kaiwu` / `kaiwu` 标识。
发布前通过全仓扫描验证，不保留旧品牌、外部项目名称或旧 Java 包名前缀。

公开仓库使用 Apache-2.0，并以干净的 squash 首次提交发布；开发分支历史不作为
公开仓库历史的一部分。

## 本轮独立实现范围

以下组件按照 Kaiwu 的接口、数据库字段、失败语义和安全要求重新实现：

- AI Provider 配置服务、持久化和 OpenAI-compatible HTTP 客户端；
- AI 字段元数据白名单增强器；
- 生成项目前端的请求、项目权限和受管字典壳层；
- 单一可部署 Maven 业务服务模板；
- 生成前端的构建、CI、容器和 Nginx 模板。

生成壳层使用 Kaiwu 自有命名：

- `requestJson`
- `ProjectAccessProvider`
- `PermissionButton`
- `useManagedDictionary`
- `ManagedDictText`
- `ManagedDictSelect`

模板版本为 `kaiwu-project-v12`。

## 验收要求

每次公开发布至少执行：

1. 四个仓库的旧品牌与外部项目名称扫描；
2. 三个 Java 仓库的 Maven `verify`；
3. System Web 和生成前端的 typecheck/build；
4. 生成后端的 Maven `verify`；
5. Semgrep、Gitleaks 与 Dockerfile 检查；
6. 独立只读代码复审。

Flyway 历史迁移在公开 squash 基线中统一为 Kaiwu 命名。已有开发数据库若记录过修改前
的迁移校验和，应在切换该基线时重建；不得直接把公开基线用于覆盖生产数据库。
