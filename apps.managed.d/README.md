# 本机业务前端入口

`./kaiwu project-up <业务后端仓> [业务前端仓]` 在这里为每个项目生成 `<projectCode>.conf`，
由平台前端（Compose 中的 `system-web`）按 `include` 加载，让业务前端以同源路径
`/apps/<projectCode>/` 打开，业务 API `/<projectCode>-api/` 只转发到 Gateway（ADR 0025）。

- 只用于本机 Compose 体验；服务器和 Kubernetes 部署不挂载本目录，请按
  `docs/SERVER-DEPLOYMENT.md` 与 `docs/KUBERNETES.md` 在各自的边缘层配置。
- 文件由命令生成、由 `./kaiwu project-down <projectCode>` 删除，不要手工维护；目录里只有本
  README 时平台前端不产生任何额外路由。
- 这里不保存任何密钥。业务库口令保存在工作区外的 `.kaiwu/projects/<projectCode>.env`（0600）。
