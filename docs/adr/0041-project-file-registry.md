# ADR 0041：项目内统一文件记录

- 状态：Accepted
- 日期：2026-10-29
- 决策范围：`kaiwu-system-starter`、`kaiwu-system-service`（项目模板）、`kaiwu-system-web`（项目详情，后续）
- 补充：ADR 0039（对象存储 STS）

## 背景

ADR 0039 让业务项目能把文件存进对象存储，但只规定业务表保存 `storage_ref` 与 `object_key`。
结果是：

- 项目里没有统一的「有哪些文件」，要看只能翻各个业务表；
- 一条记录挂多个附件很别扭；
- 预签名直传后前端没有回调确认时，对象成了没人知道的孤儿；
- 删除没有缓冲，误删无法恢复。

文件元数据（谁传的、属于哪条业务记录、大小、类型）按 ADR 0039 归业务项目，平台不保存。

## 决策

### 1. 每个项目库一张 `kaiwu_file` 表，由 Starter 提供读写

字段：`id`、`storage_ref`、`object_key`、`original_name`、`content_type`、`size_bytes`、`sha256`、
`biz_type`、`biz_id`、`status`（`PENDING` / `ACTIVE` / `DELETED`）、`uploader_id`、
`created_at`、`confirmed_at`、`deleted_at`。DDL 见 Starter 的 `docs/storage-file.sql`。

- 业务表只保存 `file_id`；`biz_type`、`biz_id` 是弱关联，不加外键。业务记录删除时由业务决定
  连带 `delete`，还是保留文件只解除关联。
- `object_key` 唯一；不保存完整 URL，沿用 ADR 0039。
- 数据留在项目自己的库里，不进入 System，也不增加业务请求对 System 的同步调用。

### 2. Starter 能力（默认关闭）

`kaiwu.starter.storage.files.enabled=true` 且项目有数据源、已启用对象存储时装配：

- `StoredFileService`：后端中转上传（写对象后登记，登记失败回收对象）、直传登记与确认
  （复核对象存在、大小与类型和声明一致，只有登记人能确认）、挂载业务记录、软删除、孤儿清理。
- `StoredFileRepository`：默认 JDBC 实现，业务可替换。
- `StoredFileController`（`/api/files`）：列表 `file:record:list`、下载 `file:record:download`、删除 `file:record:delete`；
  不暴露上传。支持预签名时返回直连地址，否则提供后端中转下载。响应形状与生成项目的 `Result` 一致。
- `StoredFilePurgeTask`：在平台调度里注册任务类型 `kaiwu.file.purge`，清理超时未确认的直传记录
  （默认 24 小时）和过保留期的软删除记录（默认 7 天）；先删对象再删记录，对象删除失败的保留到下一轮。
  不新增线程，复用已有的项目调度机制。

### 3. 权限边界

- Starter 不判断「谁能看哪个文件」，业务仍需先确认当前用户有权访问对应业务记录。
- 管理页的 `file:record:*` 权限码只授予项目管理员；普通用户在各业务页面里看自己有权访问的附件。
- 平台管理员在 System 项目详情里只读查看的聚合视图不属于本期（见「后续」）。

### 4. 项目模板与菜单（与「成员 / 角色授权」同一机制）

页面由项目模板自带，菜单与按钮由平台在创建项目时种入并授予项目管理员：

- 平台（`ProjectServiceImpl.seedAccessMenus`）种入「文件」菜单（`/project-files`，组件 `ProjectFiles`）
  和 `file:record:list|download|delete` 三个按钮；
- 项目模板在 `sql/schema.sql` 与首个迁移里带上 `kaiwu_file`，`application.yml` 打开
  `kaiwu.starter.storage.files.enabled`（`provider` 默认 `local`，生产切到 `kaiwu`），
  并生成「文件」页（列表、下载、删除）、路由、菜单文案与权限一致性检查豁免；
- 两处共用一个开关 `ProjectFilePermissions.REGISTRY_ENABLED`，**当前为 false**：
  生成项目固定 Starter `0.1.0`，没有 `/api/files`，打开会让菜单指向不存在的接口。
  发布包含本能力的 Starter（不低于 `MIN_STARTER_VERSION`）、升级 `STARTER_VERSION` 后再改为 true，
  `ProjectFilePermissionsTest` 校验两者一致；
- 已有项目不自动补：它们没有这张表和页面，需要时按同样步骤手工接入。

## 被否决的方案

- **只在业务表加列（ADR 0039 原状）**：没有统一列表，孤儿无法治理。
- **平台集中保存文件目录**：违反「文件数据不进平台」与「业务请求不同步调用 System」；平台不懂业务权限，
  列出来会绕过业务的访问规则；平台会成为所有项目文件信息的汇集点。
- **平台按前缀列桶内对象作为主方案**：没有业务信息（谁传的、属于哪条记录）。可作为后续的容量与孤儿对账补充。

## 后果

- 升级到新 Starter 的项目需要执行建表 SQL；默认关闭，不开启不受影响。
- 已有项目不自动接入；项目仍在开发阶段，需要时直接按新结构改，不做存量迁移。
- 删除是软删除：保留期内对象仍占用存储，保留期可配置。
- 定时清理依赖平台调度；未配置任务时孤儿只是不回收，不影响业务。

## 后续

1. Starter 发布后把 `REGISTRY_ENABLED` 打开。
2. System 项目详情页的只读容量与孤儿对账（按前缀列桶），与 ADR 0039 的出站白名单一致。
3. 在 System 的定时任务页面配置 `kaiwu.file.purge`（建议每小时），否则孤儿文件不回收。
