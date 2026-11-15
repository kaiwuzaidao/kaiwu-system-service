<#noparse>---
name: kaiwu-data-scope
description: 新增或修改业务表、列表/详情/导出/统计接口、Agent 读写能力、定时任务、数据导入时使用。判断数据是否需要按人/部门隔离，并按 Kaiwu Data Scope 落地与验证。
---

只做菜单权限是最常见的错误：菜单权限只决定「能不能进这个功能」，不决定「能看到哪些行」。
本 Skill 让你在写 CRUD 时先回答一个问题、按一份清单做完、再跑一道门禁。

## 第一步：必须先回答

新表或新接口的数据，「同一菜单下，不同用户应该看到不同的行」吗？

- **是 / 不确定** → 按本 Skill 做成受控资源（不确定时默认受控：事后删除约束比事后补隔离便宜）。
- **否**（字典、配置、公共目录等全员共享的数据）→ 写进 `kaiwu/data-scopes.yml` 的 `exempt`，附上理由。
  不要什么都不写：「没有表态」和「决定不隔离」在评审里是两回事。

## 先决条件（只做一次）

项目默认没有引入数据范围。需要时：

1. 在 domain 模块 pom 加依赖（版本与 `kaiwu-system-starter` 一致，且需已发布到 Maven 仓库）：

   ```xml
   <dependency>
     <groupId>com.kaiwuzaidao</groupId><artifactId>kaiwu-data-scope</artifactId><version>${kaiwu-system-starter.version}</version>
   </dependency>
   ```

2. `MybatisPlusConfig` 已经按名字可选地注册了拦截器，并排在分页之前，不需要改。
3. 若要使用 `DataScopes.reassign`（归属转移），配置成员查询：
   `kaiwu.data-scope.members.system-address`、`kaiwu.data-scope.members.credential`（带 `member:read` 的项目服务凭据），
   或自己注册一个 `MemberDirectory` Bean。

**项目工厂交付后**：在业务后端新增表和实体时，按下面的清单建立索引、声明受控资源和验证行级权限。脚手架本身不包含你的业务数据模型。

## 受控资源清单（逐项打勾）

1. 表有 `owner_user_id`、`owner_dept_id`：`BIGINT NOT NULL`、无默认值，**各自一个单列索引**。
2. `kaiwu/data-scopes.yml` 已声明该表。清单里不写默认范围、不写任何授权信息：未配置的角色一律「仅本人」，
   授权由平台管理员在角色页完成。
3. 实体的两个归属字段必须这样声明（缺一个，应用启动失败）：

   ```java
   @TableField(fill = FieldFill.INSERT, updateStrategy = FieldStrategy.NEVER)
   private Long ownerUserId;
   @TableField(fill = FieldFill.INSERT, updateStrategy = FieldStrategy.NEVER)
   private Long ownerDeptId;
   ```

   项目已有自己的 `MetaObjectHandler` 时，在它的 `insertFill` 里先调用 `DataScopeOwnerFiller.fill(metaObject)`。
4. `SaveRequest` / `UpdateRequest` 不含 `owner_*` 字段；归属只能由服务端决定，变更只走 `DataScopes.reassign`。
5. 提供「按归属人批量转移」接口（调岗、离职交接用），挂独立权限码；内部用 `DataScopes.reassign`。
   `reassign` 抛出 `DataScopeReassignRejectedException`（新归属人不是有效成员、新部门不是其所属部门、为空或 0）时，
   由 Service 翻译成 4xx 的 `ApiException`；其它 `DataScopeViolationException`（没有 Context、成员查询故障等）是服务端缺陷或依赖故障，保持 5xx，不要吞掉。

6. 详情、修改、删除在查不到或影响 0 行时统一返回 **404**，不要返回 403——403 会泄露「数据存在但你看不到」。
7. 定时任务、消息消费、异步线程触达受控表时没有请求 Context，会直接抛异常：用
   `DataScopes.unrestricted("具体理由", () -> …)` 包住，插入时自己给出归属人和归属部门。
8. 不用 `JdbcTemplate` / `JdbcClient` 访问受控表；不对受控表写 upsert / `REPLACE` / `MERGE`
   （运行时直接拒绝）；缓存受控查询结果时，缓存键必须带 `DataScopes.current().fingerprint()`，否则不缓存。
9. 子表要么自己声明归属列，要么只通过受控父表访问；`LEFT JOIN` 受控表时，不可见的右表行会变成 NULL。
10. Agent 读写能力复用同一个 Service，manifest 的数据范围声明为 `ROLE_SCOPED`，不要声明 `ALL`。

## 禁止

- 在 Service 里手写 `where owner_user_id = 当前用户`：交给拦截器，手写的条件会与管理员配置的角色范围冲突。
- 为了让测试通过而包一层 `unrestricted`。
- 用前端按用户过滤来代替后端过滤。
- 把 `reason` 写成空串、变量或「test」之类无意义的值：它会进审计日志。

## 测试必须包含

- 两个用户（例如「仅本人」和「本部门及下级」）各查一次列表，断言行数不同。
- 越权修改 / 删除返回 404，数据未变化。
- 没有 Context 的线程查询受控表抛异常。
- 批量转移之后，原归属人看不到，新归属人看得到。

## 完成前

```bash
bash scripts/verify.sh            # 在业务后端根目录执行，含 DataScopeConventionTest

# 切换到 Kaiwu 入口仓目录，将路径替换为实际业务后端仓，再预览清单
./kaiwu project sync /path/to/business-service
```

## 门禁能查什么、查不到什么

`DataScopeConventionTest` 失败即构建变红的有四条：清单里的表在实体里存在且归属字段声明正确、归属列有单列索引；
`JdbcTemplate` 源码里不出现受控表名；`DataScopes.unrestricted/reassign` 的 `reason` 是非空字符串字面量；
`SaveRequest/UpdateRequest` 不含归属字段。

第五条**只打印提示**：被权限保护的 `*list*` / `*page*` / `*export*` 接口，对应资源既不在受控清单也不在 `exempt` 里时提醒你表态。
它按名字做启发式判断，**误报和漏报都会有，没有提示不代表安全**。真正的判断仍然是回答第一步的那个问题。

不经过 MyBatis 的路径（缓存、ES/外部检索）门禁看不到：用 ES 等外部检索时，写项目 ADR 说明如何按归属过滤。
</#noparse>