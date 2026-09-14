# ADR 0008：项目调度采用 System 控制面与业务 Starter 执行面

- 状态：Accepted
- 日期：2026-07-29

> 2026-08-12 补充：ADR 0020 将本方案定位为生成项目的分布式调度默认能力，不再禁止业务项目
> 使用本地调度。偏离时由业务项目承担多副本协调、幂等、运维入口和回滚责任。

## 背景

项目定时任务需要在 System 统一查看、启停和审计，但实际业务代码、数据库事务和依赖只存在
于各自业务服务。如果 System 直接反射业务类、执行 Shell，或回调任意 URL，会破坏项目隔离，
也会把 System 变成拥有所有业务执行权限的中心节点。

## 决策

采用 pull-based scheduler starter：

1. System 保存项目级 Cron、时区、JSON 参数、启停状态、配置版本、应用凭据和执行记录。
2. 业务项目通过 `kaiwu-system-starter` 注册固定 `taskType` 的
   `ProjectScheduledTaskHandler`；System 不能指定 Java 类、Shell 或任意 URL。
3. Starter 使用只绑定一个 `projectId` 的应用凭据周期同步，仅获得该项目的启用任务。
4. 每个逻辑触发由 `(job_id, scheduled_at)` 唯一键和租约原子抢占；多副本中只有一个实例
   获得执行权。
5. 长任务每分钟续租，System 每次将租约延长五分钟；实例失联后其他副本可回收过期租约。
6. 执行完成后 Starter 回传 `SUCCESS/FAILED` 和截断后的错误摘要，System 保存实例与时间线。
7. 浏览器操作继续使用 Gateway Context 和项目成员关系；Starter 使用独立应用凭据。
   明文只在轮换时返回一次，数据库只保存 BCrypt 哈希。
8. `/api/internal/**` 不接受浏览器 JWT，外部 Gateway 继续阻断该路径；业务服务通过内部
   System Service 地址调用。

## 结果

- System 是调度控制面，不持有业务代码执行能力。
- 任务与项目凭据双重绑定，不能跨项目同步或抢占。
- System 暂时不可达时，Starter 保留最后一次有效配置；单次失败不会停止后续 Cron。
- 删除任务采用软删除并停止下发，历史执行记录继续可查。
- 运维必须把一次性凭据以 `KAIWU_SCHEDULER_CREDENTIAL` 环境变量注入对应项目服务。
- 调度保证同一时刻只有一个有效租约，语义为 at-least-once：若业务副作用已完成但结果回传
  前实例永久失联，租约过期后可能恢复执行。Handler 必须以
  `executionId` 或 `jobId + scheduledAt` 实现业务幂等。
- Cron 触发与 Handler 执行共用 Starter 的调度线程池，Handler 在触发线程内同步运行。
  池被长任务占满时其它任务到点不会被触发而是排队，因此 `pool-size` 必须按并发任务数
  加余量设置。彻底隔离需要把执行拆到独立线程池，届时要一并定义队列上限与拒绝策略，
  当前不引入该复杂度。
- 触发时刻由各实例本地按 Cron 推导。推导结果是绝对时间点，各实例一致，因此租约去重
  不依赖时钟同步；但实例时钟偏快会导致提前触发，生产环境需保证 NTP 同步。
- 应用凭据不支持双凭据并行过渡：轮换需更新环境变量并重启实例。重启前旧凭据同步失败，
  Starter 保留最后一次有效配置继续执行，已配置任务不中断。

## 不采用

- System 反射业务 Bean：跨仓库、跨 ClassLoader，且权限边界不可控。
- System 执行 Shell/类名：等同远程代码执行。
- 任意 HTTP Webhook：无法证明目标一定属于当前项目，也绕过项目内事务与依赖。
- 每个副本独立 Cron 不抢占：水平扩容会重复执行同一逻辑任务。
