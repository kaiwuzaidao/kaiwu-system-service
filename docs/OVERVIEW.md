# 10 分钟看懂 Kaiwu

Kaiwu 是一个用于创建和管理业务后台项目的控制面。它把用户、项目、角色、菜单、配置、
字典、代码生成和交付入口放在同一个平台中。

## 最短体验路径

第一次使用只需要 Git、Docker 和 OpenSSL：

```bash
git clone https://github.com/<你的组织>/kaiwu-system-service.git
cd kaiwu-system-service
./scripts/kaiwu.sh up
```

脚本会自动获取另外三个仓库、生成本地密钥、运行 Flyway，并启动完整平台。打开
`http://127.0.0.1:8000`，使用终端打印的 admin 初始密码登录。

完整步骤和故障处理见[从零开始快速使用](QUICKSTART.md)。

需要在 IDE 内直接调试、且已在 Nacos 配好 MySQL/Redis/路由运行配置时，可使用不依赖 Docker 的
入口：`./scripts/kaiwu.sh local-up`。它以 `dev` profile 直连 Nacos；详细前置条件见
[Nacos 可选配置](NACOS.md)。第一次使用不需要 Nacos。

## 请求如何流动

```text
浏览器
  │
  ▼
System Web :8000
  │ /api
  ▼
Gateway :8088 ── 鉴权、上下文、路由
  │
  ▼
System Service :8080 ── 用户、项目、权限、配置、字典、项目工厂
  ├── MySQL：业务事实与 Flyway 版本
  ├── Redis：在线会话与短期状态
  └── Artifact Volume：生成制品
```

浏览器只访问 Web。Web 将 `/api` 转给 Gateway，Gateway 验证身份并将受信上下文传给
System Service。MySQL、Redis 和内部服务默认不暴露到宿主机或公网。

## 四个仓库

| 仓库 | 何时需要理解 |
| --- | --- |
| `kaiwu-system-web` | 修改管理页面、菜单展示和交互 |
| `kaiwu-gateway-service` | 修改统一鉴权、上下文和路由 |
| `kaiwu-system-service` | 修改平台业务、数据库迁移、Compose 或 Helm |
| `kaiwu-system-starter` | 让生成的业务服务接入 Kaiwu 权限上下文 |

只想体验时无需逐个构建。`kaiwu.sh` 会把四个仓库放在同一父目录并统一编排。

## 第一次登录后

推荐用一条最短业务链路理解系统：

1. 创建普通用户；
2. 创建业务项目；
3. 将用户加入项目并分配角色；
4. 给角色分配菜单权限；
5. 在项目工厂根据 DDL 生成并下载前后端代码。

AI 生成、GitLab 推送、站内信投递是可选能力。未配置时不会影响上述基础链路。

## 从本地到 Kubernetes

本地和 Kubernetes 使用相同的三个应用镜像，没有第二套应用实现：

| 本地 Compose | Kubernetes |
| --- | --- |
| `.kaiwu/dev.env` | 已存在的 Kubernetes Secret |
| Compose MySQL/Redis | 演示 StatefulSet 或生产受管服务 |
| `db-migrate` 容器 | Flyway initContainer |
| Docker volume | PVC |
| `127.0.0.1:8000` | port-forward 或 TLS Ingress |

准备部署时先构建并推送 System、Gateway、Web 镜像，然后使用
[Kubernetes 部署与升级](KUBERNETES.md)中的 Helm 命令。生产环境应接入受管 MySQL、
高可用 Redis、外部密钥系统、TLS Ingress 和数据库备份。

## 文档入口

- [架构图谱：用 7 张图看懂 Kaiwu 的项目生成、运行鉴权与部署方式](ARCHITECTURE-GUIDE.md)
- [从下载到第一个业务项目](QUICKSTART.md)
- [传统服务器部署](SERVER-DEPLOYMENT.md)
- [Kubernetes 部署、升级与回滚](KUBERNETES.md)
- [系统架构](ARCHITECTURE.md)
- [Nacos 可选配置](NACOS.md)
- [项目工厂](PROJECT_FACTORY.md)
- [安全策略](../SECURITY.md)
- [贡献指南](../CONTRIBUTING.md)
