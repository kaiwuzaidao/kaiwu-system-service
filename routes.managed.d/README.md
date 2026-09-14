# 受管业务路由

单台服务器部署时，把项目后端仓库生成的 `deploy/server/gateway-route.yml` 复制到本目录，
再重启 Gateway。这里只接受带完整 `PROJECT` 元数据的显式路由；错误文件、重复路由 id 或
缺失 `audience` / `projectCode` 会使 Gateway 启动失败。

本目录不是服务发现，也不会由平台自动改写。每个文件都应进入部署评审与版本管理；密钥不得
写入路由文件。
