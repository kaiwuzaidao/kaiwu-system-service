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
- `kaiwu/menus.yml`、`kaiwu/dicts.yml`、`kaiwu/configs.yml`：平台资源清单（菜单与权限、受管字典、参数配置），
  用 `./kaiwu project sync` 同步到 Kaiwu System（不进业务库）。

- `scripts/check-permission-seed.sh`：权限码与菜单清单一致性门禁。
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
Java 风格和中文 Javadoc 遵守 [docs/JAVA_STYLE.md](docs/JAVA_STYLE.md)：所有手写类型、构造器
和方法都需要能说明职责、边界或副作用的中文 Javadoc。
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

## 统一待办

流程类需求（审批、工单、核对等）用 Starter 自动注入的 `TodoClient`，把「需要某人处理的事」投递到平台工作台，
办完后自动消失。**不要自建待办表**。与站内信的区别：站内信是不可变事实，待办的状态由**本服务**维护——
事项发生时打开，办完时关闭。

```java
// 提交审批：通知审批人。同一事项的多位处理人共用同一个业务键。
for (String approver : approverIds) {
    todoClient.open(approver, "approval:" + approval.getNo(), "待审批：" + approval.getTitle());
}
// 或签：有人办完后，一次关闭这个事项下所有人的待办。
todoClient.close("approval:" + approval.getNo());
// 会签：每人办完只关闭自己的。
todoClient.close("approval:" + approval.getNo(), currentApproverId);
// 事项取消：待办标为「已取消」而不是「办理完成」。
todoClient.cancel("approval:" + approval.getNo());
```

- 配置与站内信相同（`KAIWU_SYSTEM_SERVICE_URI`、`KAIWU_NOTIFICATION_DELIVERY_TOKEN`），无需新增；缺配置时静默跳过。
- `业务键` 是事项的唯一键，不超过 128 字符，只能含字母、数字与 `: _ . / # -`；同一个键重复 `open` 是幂等的，已关闭的会被重新打开。
- **打开**时处理人必须是本项目有效成员；**关闭**不要求（成员被移出后他的待办仍能关掉）。
- 链接缺省时点击待办进入本项目后台首页；`open` 的完整形式可带正文、链接与截止时间，过期后工作台显示「已逾期」。
- **只在明确的业务事件后显式调用**；失败只记日志、不抛异常；**业务流程不得依赖它推进状态**。
- 漏发 `close` 的待办超过 90 天会被平台兜底取消，但不能代替在业务状态变化时调用 `close`；每人每项目同时未处理上限 500。
- `TodoClient` 随 Starter 发布：`kaiwu-system-starter.version` 对应的版本需包含
  `com.kaiwu.starter.todo.client.TodoClient`，否则先升级该版本再写调用。

## 包结构与契约

遵守 [docs/PACKAGE_STRUCTURE.md](docs/PACKAGE_STRUCTURE.md) 和版本化 `docs/package-layout.json`。
业务采用 `module/分类/controller|service|repository|mapper|entity|agent`，不插入功能目录。
Service 接口与 `service/impl` 分离；新增写 DTO 位于 API 的 `dto/request`，查询 DTO 位于 `dto/query`。
布局门禁随 Maven verify 执行。新分类须更新契约；权限、数据范围与能力审批继续独立验证。
