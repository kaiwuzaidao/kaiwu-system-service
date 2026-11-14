# 平台数据库选择：MySQL / 达梦 DM8

首次执行 `./kaiwu init` 或 `./kaiwu up` 时，终端询问平台使用哪种数据库。
MySQL 可自动创建本地实例；达梦连接部署方已准备好的 DM8 实例。
选择与连接信息保存到运行配置旁的 `dev.env.database`，权限为 `0600`。
之后的启动、停止、日志和管理员凭据检查复用同一份选择。

## MySQL

交互安装选择 `1`。自动安装明确指定：

```bash
KAIWU_DB_TYPE=mysql ./kaiwu up
```

使用外部 MySQL 时同时设置 `KAIWU_DB_HOST`、`KAIWU_DB_PORT`、`KAIWU_DB_NAME`、
`KAIWU_DB_USER` 和 `KAIWU_DB_PASSWORD`。兼容旧的 `KAIWU_MYSQL_PASSWORD` 输入名。

## 达梦

先按达梦许可准备 DM8 实例，并为 Kaiwu 创建独立用户 / Schema。
初始化实例使用 UTF-8、`PAGE_SIZE=16`、`CASE_SENSITIVE=0`；
按达梦官方 MySQL 移植指引配置 `COMPATIBLE_MODE=4` 并重启生效。
迁移用户应拥有本 Schema 建表、索引、约束和 DML 权限；不需要授予 DBA。
同时由数据库管理员授予参数视图的只读权限，供迁移前检查当前生效的兼容模式：

```sql
GRANT SELECT ON SYS.V$PARAMETER TO KAIWU;
```

将 `KAIWU` 替换为实际迁移账号。无需授予读取或修改整个 INI 文件的管理权限。
Schema 必须为空，不要指向其它系统的库或使用 SYSDBA Schema。
迁移前会只读检查当前生效的兼容模式、字符集、页大小和大小写设置。
参数不符时在创建迁移历史或平台表前退出；不会自动修改数据库实例参数。

终端选择 `2` 后依次输入主机、端口（默认 5236）、Schema、用户和密码。
主机必须能从应用容器访问；宿主机上的数据库在 Docker Desktop 通常使用
`host.docker.internal`，不能使用容器自己的 `127.0.0.1`。

自动安装示例（密码通过环境安全注入，不写入仓库）：

```bash
export KAIWU_DB_TYPE=dm
export KAIWU_DB_HOST=db.example.com
export KAIWU_DB_PORT=5236
export KAIWU_DB_NAME=KAIWU
export KAIWU_DB_USER=KAIWU
read -r -s -p '数据库密码：' KAIWU_DB_PASSWORD
export KAIWU_DB_PASSWORD
./kaiwu up
```

运行器使用 `dm.jdbc.driver.DmDriver` 和 `jdbc:dm://主机:端口?schema=Schema`。
达梦通过独立迁移镜像执行 Flyway；内置 MySQL 容器不会启动。
源码安装会构建该迁移镜像，发行安装拉取同版本的 `kaiwu-dm-migrator`。

本机混合开发命令 `dev` 目前只编排内置 MySQL；外部 MySQL 或达梦使用 `up` 或按 JDBC 参数在 IDE 启动。
`dev` 会读取同一份保存配置与 `KAIWU_RUNTIME_ENV_FILE`，复用已选口令；遇到外部数据库时在启动基础设施前拒绝运行。
Nacos 环境可使用模板中的 `DB_JDBC_URL` 与 `DB_DRIVER` 配置达梦连接。
平台选择只决定平台库；项目工厂当前的 DDL 导入和生成业务库仍使用 MySQL，业务数据库与平台库独立。
生成的 MySQL `menu.sql` 不能直接导入达梦；项目工厂在平台内登记菜单使用对应 Mapper 方言。

## 已有安装

已有 `dev.env` 且没有选择文件时，按既有 MySQL 安装处理。
数据库类型不能通过重新设置环境变量原地切换。
新建部署应使用独立工作区、Compose 项目名、端口和 `KAIWU_RUNTIME_ENV_FILE`。
切换已有业务数据需要单独的数据迁移，不属于首次安装向导。
外部数据库不会被 `down` 或本地 `reset` 清除；`reset` 只移除 Compose 管理的数据卷。

## Kubernetes

Chart 配置示例，密码保留在已有 Kubernetes Secret 中：

```yaml
database:
  type: dm
  embedded: false
  host: db.example.com
  port: 5236
  name: KAIWU
  username: KAIWU
```

`images.dmMigrator` 指向与应用配套发布的迁移镜像。Chart 根据 `database.type`
选择 JDBC、驱动和迁移文件目录；MySQL 仍使用原有迁移线。

## 迁移与验证

MySQL 和达梦从各自的 `V127__kaiwu_baseline.sql` 初始化，后续版本从 V128 起逐版对应。
基线包含平台结构与种子，安装切换步骤见 [升级说明](UPGRADING.md#数据库)。
普通自举仍由应用建立管理员及 system 项目。
每份达梦迁移需逐字复制到 `deploy/helm/kaiwu/files/migrations-dm/`。
不得启用自动 baseline、repair 或修改已应用迁移的校验和来绕过失败。

使用官方 DM8 镜像进行一次性数据库测试：

```bash
# 按达梦许可下载官方镜像并 docker load，填入本机实际镜像标签。
export KAIWU_TEST_DM_IMAGE=dm8_single:dm8_20241022_rev244896_x86_rh6_64
mvn -s .mvn/settings.xml -pl kaiwu-system-boot -am \
  -Dtest=DmDataLayerContractTest -Dsurefire.failIfNoSpecifiedTests=false test
```

未设置镜像时这组测试不运行；正式声称达梦验证通过必须显式运行并记录证据。
测试自行创建容器、用户和 Schema，不接收开发库地址。MySQL 继续执行现有
`MySqlDataLayerContractTest`。启动选择检查为
`bash scripts/tests/check-database-config-test.sh`。
混合开发配置复用检查为 `bash scripts/tests/check-dev-database-test.sh`。

官方参考：[MySQL 移植到达梦](https://eco.dameng.com/document/dm/zh-cn/start/mysql_dm.html)。
