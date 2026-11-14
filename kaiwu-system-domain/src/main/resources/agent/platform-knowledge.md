启动与登录
- 启动平台：在 kaiwu 入口目录执行 `./kaiwu doctor` 检查环境，再执行 `./kaiwu up`。第一次会下载镜像并在本机构建，需要 Git、Docker Compose v2、OpenSSL，建议给 Docker 至少 8 GB 内存。
- 首次登录：执行 `./kaiwu credentials` 查看初始账号，浏览器打开 http://127.0.0.1:8000 ，用 admin 登录后按提示修改密码。
- 查看状态与日志：`./kaiwu status` 看容器状态，`./kaiwu logs` 看最近日志（加 -f 持续跟随）。
- 停止与清理：`./kaiwu down` 停止平台并保留数据；`./kaiwu reset` 二次确认后删除全部本地数据。
- 端口：浏览器入口是 8000，Gateway 是 8088；System 的 8080 是内部端口，不能当浏览器入口。

项目从创建到运行
- 第一个项目：点工作台的「开始开通项目」或「项目管理 → 开通项目」，按向导填写项目名称、项目编码（如 order-center）、Java 包名（如 com.example.ordercenter）和说明。也可以直接在 AI 助手里描述要建的系统，助手会起草这些信息交给你核对。
- 项目编码：会进入仓库名、API 前缀、镜像名和服务名，创建后不要随意修改。
- 生成方式：只生成符合 Kaiwu 规范的前后端基础脚手架，不调用大模型；业务代码由你自己的 AI 编程工具在本机继续完成。一个项目只生成一次，成功后平台不再覆盖业务代码。
- 取走代码：生成成功后下载前后端两个 ZIP，或用命令行 `./kaiwu project pull` 取回；之后推送到哪个 Git 服务由你自己决定。
- 本机运行：把后端解压到 business/<项目编码>-service、前端解压到 business/<项目编码>-web，在入口目录执行 `./kaiwu project-up ../business/<项目编码>-service`；建议给 Docker 至少 6 GB 内存，低于 4 GB 会拒绝启动。停止用 `./kaiwu project-down <项目编码>`，数据保留。平台重新执行 `./kaiwu up` 后要再执行一次 project-up。
- 进入与验收：project-up 会把入口登记为 /apps/<项目编码>/，回到工作台「我参与的项目」点击项目卡片即可进入，不需要再次登录；业务请求应经过 /<项目编码>-api/。
- 要改代码、打断点：用开发模式，按 docs/QUICKSTART.md 第 04 步操作。

配置与权限
- 大模型：在左侧菜单「大模型配置」填写，支持 DeepSeek、通义千问、OpenAI 及其它 OpenAI 兼容接口；密钥只在该表单中填写，不要发到聊天里。它只用于平台自己的 AI 助手，生成项目不需要大模型。
- 成员与权限：在「项目管理」找到项目，进入「权限中心」添加成员、分配角色和菜单权限。非项目成员访问业务接口会得到 403。
- 新增业务菜单、字典、配置：写在业务后端仓的 `kaiwu/menus.yml`、`dicts.yml`、`configs.yml`，在入口目录执行 `./kaiwu project sync ../business/<项目编码>-service` 查看计划，加 `--apply` 写入，再到权限中心分配（只新增、不删除）。

排错与上线
- 平台起不来先看 `./kaiwu logs`；8000 或 8088 被占用时先停掉旧进程。
- 业务接口 401：请求是否绕过 Gateway 直连了业务端口；404：路由文件与路径前缀；403：用户是否为启用状态的项目成员、角色是否有权限。
- 上线路线：单台服务器看 docs/SERVER-DEPLOYMENT.md；Kubernetes 看 docs/KUBERNETES.md，并执行 `./kaiwu deploy-init` 获取部署仓。默认都不需要 Nacos。
