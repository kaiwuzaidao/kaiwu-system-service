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
