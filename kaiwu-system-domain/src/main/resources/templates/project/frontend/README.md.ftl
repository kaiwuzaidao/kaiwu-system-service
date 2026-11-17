# ${projectName} 管理前端

本仓库由 Kaiwu 项目工厂按脚手架版本 `${templateVersion}` 一次性生成。

## 快速开始（第一次运行）

**前置要求**：Node.js 20+、pnpm 9+。

推荐直接运行仓库自带的启动助手：

```bash
bash scripts/dev.sh
```

它会检查 Node.js/pnpm、按 lockfile 安装依赖、执行 Umi setup 和 typecheck，并默认在
`${localWebPort}` 启动（端口由项目编码派生，同机多个生成项目不会互撞，也避开 Kaiwu 主站 `8000`）。
下面保留等价的手工步骤。

### 1. 安装依赖

```bash
pnpm install --frozen-lockfile --ignore-scripts
pnpm run setup
```

`--ignore-scripts` 是为了避免 lifecycle 脚本在 CI/受限环境炸掉；`pnpm run setup`
执行本地一次性的 codegen（`umi setup`），首次和 lockfile 变更后都要跑。

### 2. 起 dev server

```bash
pnpm dev
```

开发服务器启动后，在打印的地址打开 `/__mock/`，选择编辑或只读身份。演示数据保存在开发进程内存中，重启或在面板点击重置即可清空。业务模块按蓝图注册；新页面的交互可在 `mock-support/` 补充。

后端联调使用 `pnpm dev:real`（启动助手默认此模式）。平台 `/api`、`/${projectCode}-api` 和 `/${projectCode}-svc` 转发到 Gateway，默认 `http://127.0.0.1:8088`，可通过 `KAIWU_GATEWAY` 修改。

生产构建：`pnpm build`；类型检查：`pnpm typecheck`。

### 主题维护

默认采用与 Kaiwu System 一致的冷蓝主题：`src/theme/tokens.ts` 管理颜色，
`src/theme/antd.ts` 配置 Ant Design 组件，`src/global.less` 管理布局和响应式样式。
这些文件随代码包一起生成，后续由本仓库维护，不依赖平台源码或私有前端主题包。

### 3. 打开页面

有三种方式：已经配好同源边缘路由时用**方式 A**；直接运行本地 dev server 时用**方式 B**。

## 三种访问方式

### 方式 A：通过 Kaiwu 主站（集成环境推荐）

Kaiwu 平台默认路径同源加载本前端，令牌由主站派发：

```
http://127.0.0.1:8000/apps/${projectCode}/?projectId=${projectId}
```

主站会自动处理登录、切项目、token 派发。前提是边缘 Nginx/Ingress 已把这个同源路径
转发到本前端，并且你在主站登录过。单独启动 Umi dev server 不会自动占用平台的 `8000`，
所以还没配置本地反向代理时请用方式 B。

### 方式 B：独立开发时手动注入 token

在受信任的同源开发宿主中打开应用，由已有会话桥发送短期令牌；单独调试时可在启动前引导内存令牌。应用 URL 需要携带真实的 projectId。

### 方式 C：本地演示

运行 `pnpm dev`，打开 `/__mock/` 选择身份。

## 部署交付

### 单台服务器（Docker Compose + 宿主机 Nginx）

```bash
docker compose -f deploy/server/compose.yml up -d --build
```

然后把 `deploy/server/nginx-locations.conf` 中两段 `location` 合并进 Kaiwu 平台域名的
`server {}`。`/apps/${projectCode}/` 指向本前端，`/${projectCode}-api/` 指向 Gateway；两者
缺一不可。浏览器入口必须登记为同源的
`/apps/${projectCode}/`；平台打开入口时会补上项目 ID，并用受 nonce 约束的桥接协议派发内存令牌。

### Kubernetes

1. 在 `deploy/k8s/kustomization.yaml` 设置前端镜像；
2. 在 `deploy/k8s/ingress.yaml` 修改实际域名；
3. `deploy/k8s/gateway-service.yaml` 默认把本项目 namespace 内的固定别名
   `kaiwu-platform-gateway` 指向 `kaiwu` namespace 的平台 Gateway。若平台 release 或 namespace
   不同，只修改 `externalName`，不要把业务 API 改成直连后端；
4. 执行 `kubectl apply -k deploy/k8s`。

Ingress 只把业务静态路径送到本前端，把业务 API 路径送到平台 Gateway。不要把业务 API
直接暴露到 Ingress，也不要让业务前端代理绕过 Gateway。

## 常见首次启动错误

| 现象 | 原因 | 处理 |
|---|---|---|
| `ERR_MODULE_NOT_FOUND` / 页面白屏 | 忘了 `pnpm run setup` | 跑一遍 setup |
| 页面一直转圈、控制台一堆 401 | 没登录/token 未派发 | 用方式 A 从主站进，或方式 B 手动注入 |
| 业务接口 404 | Gateway 上尚未为本项目配 route | 见后端 README 的"通过 Gateway 调业务接口"一节 |
| 端口 `${localWebPort}` 被占 | 与其它进程撞号 | `PORT=<新端口> bash scripts/dev.sh` |
| 独立 dev server 上业务接口 404 | Gateway 未登记本项目路由 | 见后端 `docs/gateway-route-local.yml` |

## 令牌处理契约（生产接入时看）

模板不持久化 Access Token。由 Kaiwu 主站通过同源、带随机 nonce 校验的
`postMessage` 协议把令牌一次性交给弹窗或 iframe；同页集成也可在渲染前调用
`configureAccessToken(token)`，或一次性设置 `window.__KAIWU_ACCESS_TOKEN__`。
令牌更新和清空都会触发权限重新加载。模板不会把令牌保存到 `localStorage`、
`sessionStorage`、Cookie 或 URL。直接打开生成站点且没有 Kaiwu 宿主时，权限接口
不会发送请求。
