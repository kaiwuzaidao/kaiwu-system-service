# ADR 0002：工作区聚合与多仓自治

- 状态：Accepted
- 日期：2026-07-23
- 依据：用户明确要求每个项目拥有独立仓库

> 2026-08-12 补充：第 7 条的固定个人分支约定由 ADR 0020 取代；独立仓库、CI、版本与发布边界继续有效。

## 背景

初始原型把 Gateway、System 后端、System 前端和 Starter 放入一个根 Git 仓库。虽然构建目录分开，但仓库权限、CI、版本、发布和回滚仍被绑定，不符合平台组件独立交付要求。

平台组件和业务前后端分别拥有独立仓库。Kaiwu 采用相同的仓库边界，并避免生成器把业务前端放进后端仓库。

## 决策

1. 四个仓库克隆到同一工作区父目录，工作区本身不创建 `.git`。
2. 平台固定四个独立仓库：
   - `kaiwu-gateway-service`
   - `kaiwu-system-service`
   - `kaiwu-system-web`
   - `kaiwu-system-starter`
3. 每个生成业务项目固定产生两个独立仓库：
   - `kaiwu-{projectCode}-service`
   - `kaiwu-{projectCode}-web`
4. 不使用 Git submodule，不建立根 monorepo，不使用源码相对路径跨仓依赖。
5. Java 跨仓复用只通过内部 Nexus 发布的 `kaiwu-system-api` 和 `kaiwu-system-starter`。
6. 跨仓正式架构、需求、ADR 与开发记录由 `kaiwu-system-service/docs` 维护。
7. 每个仓库独立维护 CI、Dockerfile、版本和自身分支策略；禁止直接在受保护分支实现。

## 结果

正向结果：

- 仓库授权与平台/业务边界一致。
- Gateway、System、Web、Starter 可以独立版本和发布。
- 业务前后端可以分别构建、扩容和回滚。
- 生成任务必须显式处理两个仓库，避免“目录分开但交付仍耦合”。

需要承担的成本：

- 跨仓变更需要多个小提交和分别验证。
- 代码生成任务需要维护 BACKEND/FRONTEND 两条仓库记录。
- 本地 Compose 必须按固定 sibling 布局引用多个仓库。

## 被否决方案

- 根 monorepo：交付和权限耦合。
- Git submodule：增加更新和 CI 复杂度，没有解除版本耦合。
- 后端仓库内放 `admin-web/`：前后端无法独立发布和回滚。
- 复制公共源码到业务仓库：产生多份事实源。
