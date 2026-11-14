# 项目工厂 v26：Starter 统一为正式版 0.2.0

v25→v26。生成项目依赖的 `kaiwu-system-starter` 从 `0.1.0` 升到 `0.2.0`，并且不再区分是否开启数据范围：
v25 中只要有一张表开启 `dataScoped`，父 pom 的 `kaiwu-system-starter.version` 就会被写成
`0.1.1-SNAPSHOT`，而生成的 pom 不声明额外仓库，外部使用者在 Maven Central 上解析不到。
v26 起两种蓝图都使用同一个已发布的正式版本，`kaiwu-data-scope` 沿用同一属性，与 Starter 同版本。

可选 Excel 组件也从 `com.kaiwuzaidao:kaiwu-excel:0.1.1-SNAPSHOT` 改为 Central 坐标 `com.kaiwuzaidao:kaiwu-excel:0.2.0`；使用它的项目同步依赖版本，删除仅用于 Excel 的快照仓库配置。

同时更新了随项目生成的两处说明：`README.md` 的「聊天能力接入」与 `docs/AGENT_CAPABILITIES.md`
第 1 步。0.2.0 已包含 `AgentReadCapabilityHandler` / `AgentWriteCapabilityHandler`，无需再另行升级，
运行开关仍默认关闭。

既有业务项目不覆盖、不重新生成、不修改历史 ZIP。维护者在父 `pom.xml` 中把
`kaiwu-system-starter.version` 改为 `0.2.0`（原为 `0.1.0` 或 `0.1.1-SNAPSHOT` 均可直接替换），
删除为解析 SNAPSHOT 临时加入的仓库配置，然后运行 `mvn verify`。两处说明文档可按 diff 手动同步。

验证：完整 System verify；`ProjectScaffoldGeneratorTest` 断言带数据范围与不带的蓝图生成的 Starter
版本相同且不含 SNAPSHOT；`scripts/tests/check-starter-version-published.sh` 校验所有 Starter 版本常量
均为正式版且在 Maven Central 上存在。
