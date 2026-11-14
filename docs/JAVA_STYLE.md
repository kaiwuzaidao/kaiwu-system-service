# Kaiwu Java 风格与中文 Javadoc 规范

- 版本：v1
- 适用范围：Kaiwu 平台、Starter、Gateway 及接入平台的 Java 后端项目。

## 1. 统一格式化

Java 源码唯一格式化器是 Maven Spotless 的 `palantirJavaFormat`。不手工对齐空格、
不保留未使用 import，也不使用多个格式化器交替改写同一文件。

提交前执行：

```bash
mvn spotless:apply
mvn verify
```

平台仓将 `spotless:check` 绑定到构建；业务项目至少必须保留
`mvn spotless:apply` 这个确定性修复入口。使用 4 空格缩进、K&R 大括号、每行一个语句；
条件、循环和 `else` 即使只有一条语句也必须使用大括号。

## 2. 命名与结构

遵循《阿里巴巴 Java 开发手册》的高信号约定，并保留 Kaiwu 已发布的协议、数据库和 API 名称：

- 包名全小写；类型用名词 PascalCase；方法用动宾或判断语义的 lowerCamelCase。
- 接口不使用 `I` 前缀；实现类使用 `Impl` 后缀；异常使用 `Exception` 后缀。
- 常量使用全大写下划线；布尔方法以 `is`、`has`、`can` 或 `should` 开头。
- 禁止通配符 import、裸 `new Thread`、`Executors` 工厂和 `SELECT *`；这些规则以既有
  架构门禁为准。
- Controller 只处理协议与输入校验，Service 承担业务编排，Mapper/Repository 承担持久化；
  不为排版或命名重写权限、状态机、SQL 和公开契约。

## 3. 中文 Javadoc

所有手写 Java 源码的类型、构造器和方法都使用中文 Javadoc；范围包含
`src/main/java` 与 `src/test/java`。编译器生成的 record accessor、Lombok 生成成员和
不落在源码中的桥接方法不要求重复注释。覆写方法也必须说明本实现承担的业务语义或边界。

类型注释说明职责、所属边界及关键不变量；方法注释说明完成的业务结果，并在需要时交代：

- 参数的业务含义、单位、可空性或授权来源；
- 返回值的范围、排序、脱敏或空值语义；
- 写操作的幂等、事务、确认、审计与状态迁移；
- 外部调用、缓存、线程、异常和失败关闭行为。

简单访问器仍给出简洁的中文语义，不写与方法名完全重复的模板句。对外 API、SPI、Port、
安全边界、Agent Handler、异步任务与 Mapper 查询必须额外写明调用约束或副作用。

```java
/**
 * 在当前项目授权范围内查询可见的订单记录。
 *
 * @param query 已完成分页上限校验的查询条件
 * @return 按创建时间倒序且已脱敏的记录页
 */
public PageResult<OrderRecordView> list(OrderRecordQuery query) {
    // ...
}
```

行内注释只解释“为什么”或不可直观推导的限制；不复述语法，不记录临时调试过程，更不得包含
密码、Token、个人信息或环境地址。

## 4. 存量治理与评审

新增或修改的类型、构造器、方法必须立即满足本规范。存量由模块分批补齐，优先顺序为：
公开 API 与 DTO/VO、权限和安全链路、写操作与状态机、Agent 能力、异步/外部集成，最后是
内部辅助代码。每一批都应同时运行格式化和对应的 Maven 验证，避免纯注释改动掩盖行为变化。

中文 Javadoc 的存在性可自动检查，但语义质量必须由评审判断；不以批量生成空泛注释冒充完成。
