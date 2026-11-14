# Kaiwu 后端包结构与契约规范 v1

状态：Accepted，2026-10-14。适用 System、Gateway、Starter 和项目工厂新生成的 Java 项目。
本规范描述源码与依赖边界；不表示能力已审批、代码已部署或聊天已验收。

## 业务应用

保留 `boot -> domain -> api`。业务源码按 **分类 → 技术层 → 类** 组织：

```text
com.example
├── common                         通用错误、分页等；不得承载业务
├── config                         全应用装配
├── port                           跨分类的窄接口与必要值类型
└── module
    └── identity
        ├── controller             AuthController / UserController / OrgController
        ├── service                对外用例接口；内部算法协作者可为具体类
        │   └── impl               AuthServiceImpl / UserServiceImpl / OrgServiceImpl
        ├── repository             有业务意义的数据访问组合；无需要则省略
        ├── mapper                 MyBatis-Plus / Mapper XML
        ├── entity                 唯一表实体及明确命名的 SQL 投影
        ├── convert                纯输入输出转换（有需要才建立）
        ├── agent                  本分类已显式接入的 Handler
        ├── adapter                Port 的实现
        └── config                 分类内配置
```

不增加 `identity/auth/controller` 或 `controller/identity`；类名表达 Auth/User/Org。
`dto`、`vo`、`api` 位于 API Maven 模块的对应分类下。新增查询用 `dto/query`，
写输入用 `dto/request`；请求、视图与实体职责分离，不强制重命名已有 Request/View/Entity。
Controller 通过 Service，不直接访问 Mapper/Repository；HTTP 输出不得泄露 Entity。
ServiceImpl 承担原来的事务与资源权限复核；接口不创建第二套业务实现。
纯加解密、令牌、导入导出、编排助手不为凑层次创建接口或 Manager/DAO。

System 的分类为 `identity/project/configuration/operation/factory/connector/agent`：

| 分类 | 所有权 |
| --- | --- |
| identity | 登录、用户、组织 |
| project | 项目、成员、角色、菜单、凭据、健康检查 |
| configuration | 参数、字典、国际化 |
| operation | 审计、通知、调度、搜索、平台探针 |
| factory | 蓝图、生成、脚手架、DDL 与模板渲染 |
| connector | AI Provider、GitLab 对接 |
| agent | 会话、审批、规划、执行与结果呈现 |

新业务项目根据业务选分类名，不复制七个空分类。SQL 表、权限码、URL 不因分类合并而改名。
分类合并也不扩大授权范围。跨业务核心依赖继续通过 `port`；具体业务 Agent Handler 回到
所属分类，Agent 运行时只通过显式契约调用。不得扫描 Controller 自动开放 CRUD。

Agent 内部允许 `planning/catalog/execution/presentation/protocol/store/audit` 职责包，
避免将协议值类型放入 Service 包，或让业务 Handler 依赖 Controller。

## HTTP、Java 与 Agent 契约

API 模块只包含 DTO、VO、错误及有真实消费者的稳定接口。共享 HTTP 接口可由 Controller
实现；不为每个 Controller 自动生成 API，不共享服务端注入/事务/Entity。
客户端需要独立装配超时、错误处理与调用身份；引用接口不会获得权限。
现有 Gateway Context 与内部专用凭证的边界继续适用，不新增通用管理权限入口。

已发布的 System API、Starter Java 类型按 FQCN 保留，列入 `docs/package-layout.json`
兼容清单；它们是迁移例外，不是新增类型的包结构模板。新公开类型按新结构加入。
删除或移动已发布类型需要具体消费者、版本与兼容方案，不能仅凭 JSON 相同判断兼容。
协议字段、能力 code/version/hash、URL、权限、SQL/Flyway 和 Spring bean 名在本次包迁移中
保持既有契约；注册仍逐版本审批，执行仍确认、幂等、审计及重新鉴权。

新 Agent 功能复用业务 Service、DTO 与声明式输入输出，并显式声明数据范围。
后台管理默认在授权范围查询业务数据；只有明确的个人场景才查询“我的记录”。
未接入与无权限必须分别说明，不能因目录存在就宣称能力可用。

## Gateway 与 Starter

Gateway 使用 `auth/controller|service|repository|model|config`、
`agent/controller|service|dto`、`route/config|service`，公共过滤器在 `filter`，
地址解析在 `client`。Gateway 无业务库、Entity 或业务 ServiceImpl。

Starter 是 SDK，使用 `agent/controller|config|protocol|typed` 等能力分类。
公开接口、DTO、已发布适配器、自动配置类及被引用的常量保留 FQCN。
新内部端点放 `agent/controller`；自动配置显式装配，不能依赖偶然的组件扫描。
SDK 不依赖 System API/Domain，业务项目不复制平台业务包。

## 可执行约束与演进

`docs/package-layout.json` 记录版本、组件 profile、允许的分类/层和公开类型兼容清单。
源码与测试路径必须匹配 package；生产业务包不得回到 module 根层堆叠。
架构测试检查布局、API 纯净、Controller/数据层边界及既有 Port 约束；项目工厂生成同类门禁。
布局是 ADR 0020 的 DEFAULT，安全、权限、制品兼容是 MUST；例外必须有显式记录，
不能降低安全规则或让无效源码路径静默通过。

先更新契约、门禁与消费模板，再迁移源码、测试、XML、扫描与源文件检查。
验证必须包含三仓构建、真实数据库集成测试、生成项目构建；提交/发布/部署与聊天验收另记证据。

依据：项目 ADR 0002/0003/0017/0020/0029/0030/0032，以及阿里巴巴开发规范的
[应用分层](https://github.com/alibaba/p3c/blob/master/p3c-gitbook/工程结构/应用分层.md)、
[命名风格](https://github.com/alibaba/p3c/blob/master/p3c-gitbook/编程规约/命名风格.md)和
[二方库依赖](https://github.com/alibaba/p3c/blob/master/p3c-gitbook/工程结构/二方库依赖.md)。
沿用 MyBatis-Plus、现有模型后缀及 Palantir 格式化器，不额外引入全量 P3C 检查。
