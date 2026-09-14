# ADR 0009：生成项目与 System 工程结构对齐

- 状态：Accepted
- 日期：2026-07-31
- 决策范围：`kaiwu-system-service` 生成器、生成的业务后端与业务前端
- 取代：ARCHITECTURE 6.1 和 GEN-003 中“生成后端为单一 Maven 模块”的约束
- 保留：ADR 0002 的前后端独立仓库边界、ADR 0006 的一次性生成与确定性模板边界

## 背景

项目工厂 v2 生成的业务后端是单 Maven 模块，Controller、Service、Entity、Mapper、
启动类和响应契约放在同一个 `src` 下；生成前端又把令牌桥接、权限、请求和字典全部集中在
`src/shell/index.tsx`。这些产物能够构建，但和开发者已经熟悉的 Kaiwu System 工程组织
不同，接手后需要先重新理解一套目录和依赖规则。

项目工厂的价值不仅是生成可运行代码，也应让生成项目与平台自身遵循同一套可理解、
可维护的工程约束。

## 决策

### 1. 后端统一为三模块

每个生成后端仓库固定包含：

```text
kaiwu-{code}-service/
├── pom.xml
├── kaiwu-{code}-api/
├── kaiwu-{code}-domain/
└── kaiwu-{code}-boot/
```

依赖方向固定为：

```text
boot -> domain -> api
```

- API：统一响应、DTO、VO，不放 Controller、Entity、Mapper 或运行配置。
- Domain：Controller、Service、Entity、Mapper 和业务配置。
- Boot：启动类、`application.yml`、Flyway migration、驱动和可执行包。

生成业务项目仍是一个独立后端仓库，不引用 System 源码；Starter 继续通过制品仓库依赖。

### 2. 前端统一分层目录

生成前端继续是独立 Umi Max 仓库，并按 System Web 的组织方式拆分：

- `components/`：PermissionButton、字典展示和选择组件；
- `hooks/`：项目 ID、受管字典 Hook；
- `providers/`：项目访问权限上下文；
- `services/`：统一请求和各业务模块 API；
- `utils/`：同源内存令牌桥接；
- `pages/`：页面本身，不在页面目录重复维护请求实现。

不复制 System 控制面专属的登录、用户、项目管理等页面。业务前端只复用工程结构和安全
契约，仍由 Kaiwu 主站通过同源 `postMessage` 注入内存 Access Token。

### 3. 可复现构建

- 模板版本升级为 `kaiwu-project-v3`。
- 生成前端必须携带经过验证的 `pnpm-lock.yaml`。
- Docker 和 CI 必须使用 `pnpm install --frozen-lockfile`。
- 模板门禁必须清空旧样例目录，再对生成后端运行 `mvn verify`、对生成前端运行
  `pnpm typecheck` 和 `pnpm build`，防止旧文件或依赖缓存掩盖缺失产物。

## 后果

### 正向

- 平台后端与生成业务后端使用同一依赖方向，开发者无需学习第二套结构。
- API 契约与领域实现分离，启动装配不会混入业务模块。
- 前端公共能力不再集中在超大 `shell.tsx`，页面、请求和组件职责清晰。
- 锁文件使新用户和 CI 得到与模板验证一致的依赖图。

### 成本

- 生成仓库文件数和 Maven 模块数增加。
- `api/domain/boot` 仍在一个业务后端仓库内一起发布，不承诺三个模块独立版本。
- v2 已成功生成的项目不会被平台覆盖；由项目团队自行决定是否手工迁移到 v3。
