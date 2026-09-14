# ${projectName} 后端开发说明

项目编码：`${projectCode}`  
基础包名：`${basePackage}`  
脚手架版本：`${templateVersion}`

仓库地图：

- `kaiwu-${projectCode}-api`：稳定 DTO、VO 与统一响应契约。
- `kaiwu-${projectCode}-domain`：Controller、Service、Entity 与 Mapper。
- `kaiwu-${projectCode}-boot`：启动类、运行配置与可执行包。
- `kaiwu-${projectCode}-boot/src/main/resources/db/migration`：Flyway 迁移，
  应用启动时自动执行；新增 `V{n}__desc.sql`，已发布版本不可修改。
- `sql/schema.sql`：累积快照，仅供审阅对照，运行时不执行。
- `sql/menu.sql`：平台项目菜单/权限种子，导入到 Kaiwu System 库（不进业务库）。

- `scripts/check-permission-seed.sh`：权限码与菜单 seed 一致性门禁。
- `scripts/check-test-baseline.sh`：测试基线报告；默认告警，模板自验使用 `--strict`。
- `docs/kaiwu-project-blueprint.json`：与前端仓库共享的模块、权限与启用语言契约。
- `docs/api-contract.txt`：对外接口最低兼容基线；兼容新增放行，破坏性变化阻断。
- `docs/kaiwu-constraints.json`：MUST/WARN/DEFAULT 约束目录。
- `docs/kaiwu-constraint-waivers.json`：WARN/DEFAULT 的有期限偏离记录。

依赖方向只能是 `boot -> domain -> api`。
验证命令（三项都在 CI 门禁里）：

```bash
bash scripts/check-permission-seed.sh && bash scripts/check-test-baseline.sh && mvn verify
```
格式化使用 `mvn spotless:apply`，它是可自动修复的默认能力，不是业务逻辑门禁。
首次启动会自动跑 Flyway V1 初始化全新空库；
已有 schema 必须单独制定迁移方案，生成项目不会自动接管。

## 站内信

Starter 自动注入 `NotificationClient`，向平台统一收件箱投递消息：

```java
notificationClient.send(order.getOwnerUserId(),
        "订单已超时", "订单 " + order.getOrderNo() + " 超过 24 小时未支付",
        "/order/" + order.getId());
```

需要 `KAIWU_SYSTEM_SERVICE_URI` 和 `KAIWU_NOTIFICATION_DELIVERY_TOKEN` 两个环境变量；
缺任一个时客户端静默跳过，不影响启动和业务。收件人必须是本项目有效成员，否则被拒绝。
投递失败只记日志，业务流程不得依赖站内信做状态流转。

`KAIWU_SYSTEM_SERVICE_URI` 的 scheme 决定由谁解析地址（ADR 0024）：`http(s)://` 交给
底层网络（本地地址、Kubernetes Service DNS 都是这一类），`lb://` 交给 Spring Cloud
LoadBalancer。切换部署形态只改这个变量的值，不要引入部署模式开关或 if/else 分支。
用 `lb://` 需自行添加 loadbalancer 与注册中心依赖，缺失时启动即失败。
