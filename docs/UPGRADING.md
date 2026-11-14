# 从 v0.1.0 升级到 v0.2.0

## 数据库

**v0.1.0（V44）不支持原地升级到 v0.2.0。** 新版的 MySQL 和达梦迁移均从 `V127__kaiwu_baseline.sql` 开始。先按当前库的成功迁移版本选择路径。保留数据库备份、旧版本配置与生成项目的 ZIP。V104 已撤销 GitLab 推送配置和项目体检，需要历史报告的安装应提前导出。

### V44

保留原库，在新数据库或新的达梦 Schema 上初始化 v0.2.0，并重新配置平台。全新安装也走此路径。

### V45-V126

先用**压缩前、与该安装同一迁移线**的 System 及其完整迁移目录升级到 V127，确认所有迁移成功，再按下一节操作。该版本可从备存发行包或引入 V127 单一基线之前的源码历史取得。

### V127

仅对已经执行完整旧链的库进行一次人工历史重置。停掉所有会写该库的应用、定时任务及迁移进程。备份完成后核对目标库名和成功版本，再移除旧历史表并显式执行 Flyway `baseline`。删除历史表保留所有业务表；仅清空历史行仍留有历史表，无法完成此操作。任一步失败即停止，保留备份，在恢复或查明原因之前保持停写。

#### MySQL 8.4

在装有 MySQL 客户端、mysqldump 和带 MySQL 驱动的 Flyway CLI 的维护终端运行。当前目录为新版 System 仓根目录。用本次维护连接的环境变量提供 `DB_HOST`、`DB_PORT`、`DB_NAME`、`DB_USER`、`DB_PASSWORD`。备份账号需要能导出该库的表、事件、例程与触发器。

```sh
(
  set -eu
  umask 077
  backup_dir=$(mktemp -d "./kaiwu-backup.XXXXXXXX")
  export MYSQL_PWD="$DB_PASSWORD"
  db() { mysql --protocol=TCP -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -NB "$DB_NAME" "$@"; }
  export FLYWAY_URL="jdbc:mysql://$DB_HOST:$DB_PORT/$DB_NAME"
  export FLYWAY_USER="$DB_USER" FLYWAY_PASSWORD="$DB_PASSWORD" FLYWAY_BASELINE_ON_MIGRATE=false
  export FLYWAY_LOCATIONS="filesystem:$PWD/sql/increment"

  # 1. 在新目录备份，不覆盖已有备份。
  mysqldump --protocol=TCP -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" \
    --single-transaction --routines --events --triggers --no-tablespaces \
    --set-gtid-purged=OFF "$DB_NAME" > "$backup_dir/platform.sql"
  test -s "$backup_dir/platform.sql"

  # 2. 核对旧链最高成功版本、零失败和旧 V127 脚本记录。
  test "$(db -e "SELECT IF(MAX(CASE WHEN success=1 THEN CAST(version AS UNSIGNED) END)=127
    AND SUM(success=0)=0 AND SUM(version='127' AND type='SQL'
    AND script='V127__backend_service_ui_i18n.sql')=1, 'OK', 'STOP') FROM flyway_schema_history")" = OK

  # 3. 移除旧历史，显式写入一条 V127 BASELINE 记录。
  db -e 'DROP TABLE flyway_schema_history'
  flyway -baselineVersion=127 baseline

  # 4. 应报告无待执行迁移，再检查唯一记录，启动同版 System 并登录。
  flyway migrate
  test "$(db -e "SELECT CASE WHEN COUNT(*)=1 AND MAX(CASE WHEN version='127' AND type='BASELINE' AND success=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END FROM flyway_schema_history")" = 1
)
```

#### 达梦 DM8

在装有 `dexp` 的维护终端运行。设置 `DB_HOST`、`DB_PORT`、`DB_NAME`、`DB_USER`、`DB_PASSWORD`，登录用户须能导出并管理目标平台 Schema。将 `DB_JDBC_URL` 设置为迁移容器可达的**同一实例和 Schema**，例如 `jdbc:dm://db.example.com:5236?schema=KAIWU`。使用 v0.2.0 的 `DM_MIGRATOR_IMAGE`。若实例使用容器网络，给下面的 `docker run` 加入该网络。以下命令在新版 System 仓根目录执行。

```sh
(
  set -eu
  umask 077
  backup_dir=$(mktemp -d "$PWD/kaiwu-backup.XXXXXXXX")
  export DB_JDBC_URL DB_NAME DB_USER DB_PASSWORD
  dm() {
    docker run -i --rm -e DB_JDBC_URL -e DB_NAME -e DB_USER -e DB_PASSWORD \
      -v "$PWD/sql/dm:/migrations:ro" "$DM_MIGRATOR_IMAGE" "$@"
  }

  current_schema=$(printf '%s\n' "SELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') FROM dual;" | dm sql)
  test "$(printf '%s' "$current_schema" | tr '[:lower:]' '[:upper:]')" = "$(printf '%s' "$DB_NAME" | tr '[:lower:]' '[:upper:]')"

  # 1. 用原生导出工具备份平台 Schema（含迁移历史），确认导出成功。
  printf '%s\n' "$DB_PASSWORD" | dexp "USERID=$DB_USER@$DB_HOST:$DB_PORT" \
    "SCHEMAS=$DB_NAME" "FILE=$backup_dir/platform.dmp" "LOG=$backup_dir/export.log"
  test -s "$backup_dir/platform.dmp"

  # 2. 核对旧链最高成功版本、零失败和旧 V127 脚本记录。
  check=$(printf '%s\n' "SELECT CASE WHEN MAX(CASE WHEN success=1 THEN CAST(version AS INT) END)=127
    AND SUM(CASE WHEN success=0 THEN 1 ELSE 0 END)=0
    AND SUM(CASE WHEN version='127' AND type='SQL' AND script='V127__backend_service_ui_i18n.sql'
    THEN 1 ELSE 0 END)=1 THEN 'OK' ELSE 'STOP' END FROM flyway_schema_history;" | dm sql)
  test "$check" = OK

  # 3. 移除旧历史，人工调用迁移器的 baseline 子命令。
  printf '%s\n' 'DROP TABLE flyway_schema_history;' | dm sql
  dm baseline

  # 4. 应报告无待执行迁移，再核对唯一记录，启动同版 System 并登录。
  dm migrate
  count=$(printf '%s\n' "SELECT CASE WHEN COUNT(*)=1 AND MAX(CASE WHEN version='127' AND type='BASELINE' AND success=1 THEN 1 ELSE 0 END)=1 THEN 1 ELSE 0 END FROM flyway_schema_history;" | dm sql)
  test "$count" = 1
)
```

## 平台组件的升级顺序

1. 在维护窗口内暂停业务流量，准备同一发行版本的 System、Gateway、Web 和数据库迁移器，保留原有签名配置、配置加密密钥及 Redis 配置。先按上节完成数据库准备。
2. 先启动 System，确认就绪。System 提供设备授权、配置移交和模型用途配置 API，也决定项目访问快照中的服务、受众及数据范围。已有单后端项目保留默认服务；混用新旧副本时保持 `kaiwu.project-backend-services.multi-enabled=false`。
3. 再启动同版 Gateway，更新显式路由。设备授权的发起和轮询允许未登录请求，查看、同意和拒绝需要平台登录态。项目路由按服务绑定受众，Gateway 从 System 快照签发业务 Context。使用自定义路由的安装应对照新版本路由模板逐项核对。
4. 最后切换 Web 并刷新浏览器，验证登录、项目选择、CLI 设备授权，以及用普通成员进入一个有权访问的项目。确认工作台待办和项目权限符合预期后恢复流量。需启用多后端的项目，应等全部副本完成升级，再登记服务并应用对应路由。

## 配置变化

| 使用场景 | 需要核对的配置 |
| --- | --- |
| 首次非交互安装 | 显式设置 `KAIWU_DB_TYPE=mysql` 或 `dm`。沿用已有运行配置且没有数据库选择文件的安装仍按 MySQL 处理。达梦需另建部署配置。 |
| 外部 MySQL 或达梦 DM8 | 设置 `KAIWU_DB_HOST`、`KAIWU_DB_NAME`、`KAIWU_DB_USER` 和 `KAIWU_DB_PASSWORD`。密码兼容原有 `KAIWU_MYSQL_PASSWORD`。端口用 `KAIWU_DB_PORT` 指定，默认分别为 3306 和 5236。启动器根据达梦连接参数生成 JDBC URL 和驱动设置。Helm 安装选择 `database.type=dm` 并关闭内置数据库。见 [DATABASES.md](DATABASES.md)。 |
| 使用 Nacos | 启动时显式提供 `KAIWU_NACOS_SERVER_URL`、`KAIWU_NACOS_SERVER_ADDR`、`KAIWU_NACOS_NAMESPACE`、`KAIWU_NACOS_USERNAME` 和 `KAIWU_NACOS_PASSWORD`。对照本版 System 与 Gateway 的 Data ID 模板更新数据源和路由，保留部署方的连接参数。见 [NACOS.md](NACOS.md)。 |
| 开启项目对象存储 | 在 System 设置 `KAIWU_STORAGE_ALLOWED_HOSTS`，包含实际 STS 与存储服务的主机名，并配置存储账号和项目绑定；按网络需要设置 `KAIWU_STORAGE_EGRESS_PROXY_URI`。主机白名单为空时出站请求被拒绝。 |
| 使用 AI 助手 | 模型出站需要 `KAIWU_AI_PROVIDER_ALLOWED_HOSTS` 和 `KAIWU_AI_PROVIDER_EGRESS_PROXY_URI`。可分别配置 PLAN 和 ANSWER；已有默认模型继续用于未绑定的用途，空库需先配置模型。项目工厂生成脚手架无需模型配置。 |
| 启用远程 Agent 能力 | 默认关闭。使用 Helm 时配置 `agent.remoteReadEnabled`，如需写入再启用 `agent.remoteWriteEnabled`。目标业务项目需独立启用对应处理器，项目管理员审核能力版本后才可执行。见 [Chart 接入说明](../deploy/helm/kaiwu/README.md) 和 [远程执行说明](AGENT_REMOTE_EXECUTION.md)。 |
| 保留既有时间语义 | Compose 的 `KAIWU_TIME_ZONE`、Chart 的 `timeZone` 默认均为 `Asia/Shanghai`。升级前与原库写入 `DATETIME` 时所用时区核对，避免会话过期和调度时间偏移。 |

## 已生成的业务项目

v0.1.0 交付的模板标识为 `kaiwu-project-v13`，v0.2.0 的目标为 `kaiwu-project-v26`。平台升级不会回写业务仓，也不会改动已下载的 ZIP。

1. 先从原生成记录核对 `templateVersion`，在业务仓建立升级分支。保留原生成记录和业务源码，另建示例项目以取得本版基础脚手架，比对配置、清单、构建脚本与前后端目录。业务数据模型和 CRUD 在原业务仓中维护。逐项合并到业务仓，保留业务实现和授权定制。
2. 按版本顺序采用相应的迁移说明。v22 调整首页和账号入口，v23 引入授权菜单和本人待办，v24 调整主题，v25 统一页面边距。见 [v22](PROJECT_FACTORY_V22_MIGRATION.md)、[v23](PROJECT_FACTORY_V23_MIGRATION.md)、[v24](PROJECT_FACTORY_V24_MIGRATION.md)、[v25](PROJECT_FACTORY_V25_MIGRATION.md)。
3. 按发行包中的 `docs/PROJECT_FACTORY_V26_MIGRATION.md` 更新 Starter 版本。启用数据范围的项目还依赖同版本的 `kaiwu-data-scope`。两个 0.2.0 坐标发布到 Maven Central 后再构建。Spring Boot 主类应使用业务包名，如 `com.example.crm`，避免组件扫描绕过 Starter 的接口装配开关。
4. 运行生成后端的 Maven 验证和前端的 `pnpm verify`。核对普通成员的菜单、待办、文件及数据权限，再按项目原有发布流程上线。

## Argo CD 服务端应用与旧迁移 ConfigMap

早期用 Helm 创建、随后改由 Argo CD 以服务端应用（SSA）管理的安装，可能保留旧管理器写入的迁移键。升级到 V127 时，新旧 SQL 同时留在同一 ConfigMap 中，可能超过 Kubernetes 的 1 MiB 限额，导致同步失败。CI 的 900 KiB 检查只衡量目标 Chart 的载荷。

1. 在受控升级窗口确认应用、命名空间、实际 release 名、覆盖值和数据库方言。用目标 Chart 和相同的 release 参数渲染 `templates/migrations-configmap.yaml`，记下其 `metadata.name` 和完整的 `data` 键清单，核对 Argo CD 目标清单确实会重建此对象。检查在线对象的键名和字段管理记录，确认是上述旧 Helm 对象。
2. 暂停自动同步，等正在使用该卷的迁移任务结束。只删除上一步核实的迁移 ConfigMap，例如 `kubectl -n "$namespace" delete configmap "$migration_configmap"`，随后立即同步指定的目标版本。操作范围仅限这个可重建对象，保留数据库、数据卷以及其余配置。
3. 确认新对象已创建，按键名逐项对照渲染结果，包括所选方言的 SQL 和 MySQL 的兼容检查脚本。核对迁移初始化和应用就绪状态，再恢复自动同步。若重建失败，保持升级窗口并从已核对的目标清单恢复该对象。
