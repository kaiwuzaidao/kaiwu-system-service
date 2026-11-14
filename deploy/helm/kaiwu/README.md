# Kaiwu Helm Chart

该 Chart 用同一组 Kaiwu 应用镜像部署 System、Gateway 和 Web，并在 System 启动前运行
Flyway。完整部署、生产准备、升级和回滚说明见
[`docs/KUBERNETES.md`](../../../docs/KUBERNETES.md)。

快速渲染：

```bash
helm lint deploy/helm/kaiwu
helm template kaiwu deploy/helm/kaiwu --namespace kaiwu
```

默认内置 MySQL 和 Redis 仅适合开发集群。生产环境请复制并审查
`values-production.yaml`，连接受管数据库和高可用 Redis，并使用外部 Secret 管理系统。

业务项目的 API 路由必须逐条声明。单仓或本地部署可使用 `gateway.managedRoutes`；正式 GitOps
部署推荐由 `kaiwu-deploy/gateway-routes/<env>` 生成 ConfigMap，再通过
`gateway.managedRoutesExistingConfigMap` 只读挂载。两者互斥。任一路由缺少 `PROJECT` 元数据或
id 重复都会启动失败；该入口不是 discovery locator，也不会从 Nacos 或 Kubernetes 自动暴露服务。

远程 Agent 写能力有独立的 `agent.remoteWriteEnabled`，默认关闭，要求
`agent.remoteReadEnabled=true`。Chart 将写开关同时传给 System 与 Gateway；
业务项目自己的 `KAIWU_AGENT_WRITE_ENABLED` 仍须单独开启。三个开关都不能代替
目标项目管理员对在线 manifest 的逐版审批、写入账本与权限回归。

## 时区

`timeZone`（默认 `Asia/Shanghai`）同时设置 system 容器的 `TZ` 和 JDBC 的 `connectionTimeZone`，
并开启 `forceConnectionTimeZoneToSession`，使 Java 写入的时间与数据库 `CURRENT_TIMESTAMP`
落在同一个时区。库里的 `DATETIME` 不带时区：

- 新库直接用默认值即可；
- 已有数据的库（例如 UTC 时区写入的 test 库）切换后，存量时间相对新数据相差整数小时，
  在线会话会立即视为过期、需要重新登录，调度器的 `next_run_time`/租约要避开任务运行期切换；
- 部署之后不要再改这个值。
