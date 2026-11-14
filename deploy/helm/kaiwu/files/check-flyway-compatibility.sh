#!/bin/sh
set -eu

migrations_dir="${1:-}"
if [ -z "$migrations_dir" ] || [ ! -d "$migrations_dir" ]; then
  echo "用法：check-flyway-compatibility.sh <迁移目录> [数据库当前版本]" >&2
  exit 2
fi

highest_version=0
for migration in "$migrations_dir"/V*__*.sql; do
  [ -f "$migration" ] || continue
  filename="${migration##*/}"
  version="${filename#V}"
  version="${version%%__*}"
  case "$version" in
    ''|*[!0-9]*)
      echo "无法解析 Flyway 迁移版本：${filename}" >&2
      exit 2
      ;;
  esac
  if [ "$version" -gt "$highest_version" ]; then
    highest_version="$version"
  fi
done

if [ "$highest_version" -eq 0 ]; then
  echo "迁移目录中没有 Flyway 版本脚本：${migrations_dir}" >&2
  exit 2
fi

legacy_history=1
if [ "${2+x}" = x ]; then
  current_version="$2"
else
  missing_vars=""
  [ -n "${DB_HOST:-}" ] || missing_vars="${missing_vars} DB_HOST"
  [ -n "${DB_PORT:-}" ] || missing_vars="${missing_vars} DB_PORT"
  [ -n "${DB_NAME:-}" ] || missing_vars="${missing_vars} DB_NAME"
  [ -n "${DB_USER:-}" ] || missing_vars="${missing_vars} DB_USER"
  [ -n "${DB_PASSWORD:-}" ] || missing_vars="${missing_vars} DB_PASSWORD"
  if [ -n "$missing_vars" ]; then
    echo "缺少数据库连接环境变量：${missing_vars# }" >&2
    exit 2
  fi
  case "$DB_NAME" in
    *[!A-Za-z0-9_]*)
      echo "数据库名只能包含字母、数字和下划线。" >&2
      exit 2
      ;;
  esac
  case "$DB_PORT" in
    ''|*[!0-9]*)
      echo "数据库端口必须是纯数字。" >&2
      exit 2
      ;;
  esac
  # 连接失败必须说清楚。原先这里把 stderr 丢进 /dev/null，随后的算术比较在
  # set -e 下让脚本以非零码退出，但一个字都不打印——地址、端口或口令配错时
  # 用户只看到 "exit 1"，无从下手。接外部实例后这类配置失误是最常见的失败。
  if ! history_exists="$(MYSQL_PWD="$DB_PASSWORD" mysql --protocol=TCP \
    -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -Nse \
    "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${DB_NAME}' AND TABLE_NAME='flyway_schema_history'" \
    2>&1)"; then
    echo "无法连接数据库 ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}：" >&2
    echo "${history_exists}" >&2
    exit 2
  fi
  case "$history_exists" in
    ''|*[!0-9]*)
      echo "查询 flyway_schema_history 是否存在时返回了非数字结果：" >&2
      echo "${history_exists}" >&2
      exit 2
      ;;
  esac
  if [ "$history_exists" -eq 0 ]; then
    current_version=""
  else
    if ! summary="$(MYSQL_PWD="$DB_PASSWORD" mysql --protocol=TCP \
      -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" -Nse \
      "SELECT CONCAT(COALESCE(MAX(CASE WHEN success=1 THEN CAST(version AS UNSIGNED) END),0), ':',
         COALESCE(MAX(CASE WHEN CAST(version AS UNSIGNED)<127 OR
          (version='127' AND NOT (type='BASELINE' OR (type='SQL' AND script='V127__kaiwu_baseline.sql')))
          THEN 1 ELSE 0 END),0)) FROM flyway_schema_history WHERE version IS NOT NULL" \
      2>&1)"; then
      echo "读取 flyway_schema_history 失败：" >&2
      echo "${summary}" >&2
      exit 2
    fi
    case "$summary" in
      *:0|*:1) current_version=${summary%:*}; legacy_history=${summary##*:} ;;
      *) echo "无法识别迁移历史摘要" >&2; exit 2 ;;
    esac
  fi
fi

if [ -z "$current_version" ]; then
  exit 0
fi
case "$current_version" in
  *[!0-9]*)
    echo "数据库 Flyway 当前版本不是纯数字：${current_version}" >&2
    exit 2
    ;;
esac

if [ "$current_version" -gt "$highest_version" ]; then
  echo "数据库迁移版本 ${current_version} 高于当前代码最高版本 ${highest_version}。" >&2
  echo "该数据库来自不兼容的旧迁移线；继续启动会造成运行期 SQL 错误。" >&2
  echo "开发环境请先备份并重建开发数据库；生产或重要环境必须停止并制定前向升级方案。" >&2
  exit 1
fi

if [ -f "$migrations_dir/V127__kaiwu_baseline.sql" ] && [ "$legacy_history" = 1 ]; then
  if [ "$current_version" -le 44 ]; then
    echo "旧历史 V${current_version}：请新建数据库。见 docs/UPGRADING.md#v44" >&2
  elif [ "$current_version" -lt 127 ]; then
    echo "旧历史 V${current_version}：先用旧版迁至 V127。见 docs/UPGRADING.md#v45-v126" >&2
  else
    echo "旧历史 V${current_version}：须核对并手工重置历史。见 docs/UPGRADING.md#v127" >&2
  fi
  exit 1
fi
