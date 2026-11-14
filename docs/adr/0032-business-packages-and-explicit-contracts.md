# ADR 0032：业务包分层与显式接口契约

- 状态：Accepted（结构与兼容边界已确定；迁移和验证另记证据）
- 日期：2026-10-14
- 范围：System、Gateway、Starter；未来生成模板的组织约定
- 前置：ADR 0002、0003、0017、0020、0029、0030
- 详细方案：[包结构与契约组织方案](../plans/2026-10-14-package-structure.md)

## 背景

当前 API/Domain/Boot 依赖方向合理，但 Agent 根包聚集了运行时与具体业务 Handler，
项目和元数据 Service 同时承载多组用例。旧项目的分层目录、显式转换和共享 HTTP 契约
有可复用价值；全局技术包则不利于按业务扩展。用户要求结合阿里巴巴开发规范重新设计。

## 决策

1. 保留三个 Maven 模块与独立仓库；采用分类 -> 技术层 -> 具体类。
   module 下收敛为 identity/project/configuration/operation/factory/connector/agent。
   identity 直接包含 controller/service 等包，Auth/User/Org 通过类名区分，不加功能中间层。
   API 与 Domain 使用对应分类；分类不改变原有功能边界、事务所有权或权限范围。
2. 对外业务 Service 使用接口与 Impl，必要的数据访问组合继续用 Repository，SQL 用 Mapper。
   不添加重复 DAO 层，不强制每个用例具备所有层次。
3. 已发布 DTO/VO 的 Java 包名、类型名暂时保留；新查询与写请求按职责分类。
4. 有真实消费者时才提供稳定 HTTP 契约。契约不包含服务端上下文、凭据或持久化实体；
   客户端装配与调用身份单独设计，不能因引用接口而获得管理权限。
5. 保留跨业务边界的窄 Port；Agent SPI 位于中立边界，业务 Handler 回归所属分类的 agent 包。
   Catalog 聚合业务 provider，Invoker 按已登记 Handler 分发。
6. Agent 核心直接按 controller/service/repository/entity/mapper 分层，
   planning/catalog/execution/presentation/protocol 等纯职责设专用包。
   保持当前数据范围、确认、幂等、审计、执行前权限复核及逐版本审批。
7. 用阿里巴巴的分层、模型职责、命名和稳定制品原则指导设计；项目现有 ADR 和风险分级
   继续约束具体实现。本提议不自动开启 P3C 全量规则、不更换 ORM/格式化器。

## 落地边界

先建立可验证基线，再逐功能迁移。Mapper XML、扫描配置、事务代理、Java 消费者和协议夹具
必须随各批检查。包移动不自动等于兼容：Java FQCN 变化影响制品消费者，wire 兼容需测试证明。
模板升级单独推进，不回写既有业务仓；服务间认证需求另立具体 ADR。

实现以 [后端包结构与契约规范 v1](../PACKAGE_STRUCTURE.md) 为准。
本 ADR 不作为已部署、已审批或聊天已验收的证明。
