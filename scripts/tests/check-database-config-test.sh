#!/usr/bin/env bash
# 单引号内有意保留子 Bash 代码与密码中的命令替换字面量。
# shellcheck disable=SC2016
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

run_config() {
  bash -euo pipefail -c 'runtime_env="$1"; source "$2/scripts/database-config.sh"; configure_database' _ "$1" "$repo_dir"
}

if bash -euo pipefail -c 'unset KAIWU_DB_TYPE; runtime_env="$1/new.env"; source "$2/scripts/database-config.sh"; configure_database' _ "$fixture" "$repo_dir" >"$fixture/missing.log" 2>&1; then
  echo '首次安装不应静默回退 MySQL。' >&2
  exit 1
fi
test ! -f "$fixture/new.env.database"
KAIWU_DB_TYPE=mysql run_config "$fixture/mysql.env"
grep -Fq 'KAIWU_DB_TYPE=mysql' "$fixture/mysql.env.database"
KAIWU_DB_TYPE=mysql KAIWU_MYSQL_PASSWORD=contract-password run_config "$fixture/mysql-password.env"
grep -Fq 'KAIWU_DB_PASSWORD=contract-password' "$fixture/mysql-password.env.database"

# 密码中的 shell 字符应原样保存，加载时不得执行命令。
test_password='space dollar $ quote '\'' and $(touch SHOULD_NOT_RUN) `echo bad`'
KAIWU_DB_TYPE=dm KAIWU_DB_HOST=db.example.com KAIWU_DB_NAME=KAIWU KAIWU_DB_USER=kaiwu \
  KAIWU_DB_PASSWORD="$test_password" run_config "$fixture/dm.env"
test "$(stat -c %a "$fixture/dm.env.database" 2>/dev/null || stat -f %Lp "$fixture/dm.env.database")" = 600
env -u KAIWU_DB_TYPE TEST_PASSWORD="$test_password" bash -euo pipefail -c '
  runtime_env="$1"; source "$2/scripts/database-config.sh"; load_database_config
  test "$KAIWU_DB_TYPE" = dm
  test "$KAIWU_DB_PASSWORD" = "$TEST_PASSWORD"
  test "$KAIWU_MYSQL_PASSWORD" = "$TEST_PASSWORD"
  test "$KAIWU_DB_JDBC_URL" = "jdbc:dm://db.example.com:5236?schema=KAIWU"
' _ "$fixture/dm.env" "$repo_dir"
test ! -f SHOULD_NOT_RUN
if KAIWU_DB_TYPE=mysql run_config "$fixture/dm.env" >"$fixture/switch.log" 2>&1; then
  echo '不能通过环境变量切换既有部署数据库。' >&2
  exit 1
fi

touch "$fixture/legacy.env"
env -u KAIWU_DB_TYPE bash -euo pipefail -c 'runtime_env="$1"; source "$2/scripts/database-config.sh"; configure_database; test "$KAIWU_DB_TYPE" = mysql' _ "$fixture/legacy.env" "$repo_dir"
if KAIWU_DB_TYPE=dm run_config "$fixture/legacy.env" >"$fixture/legacy.log" 2>&1; then
  echo '旧 MySQL 部署不能原地改为达梦。' >&2
  exit 1
fi
if KAIWU_DB_TYPE=dm KAIWU_DB_HOST=db.example.com KAIWU_DB_NAME=KAIWU KAIWU_DB_USER=kaiwu \
  KAIWU_DB_PASSWORD=test KAIWU_DB_PORT=70000 run_config "$fixture/invalid.env" >"$fixture/invalid.log" 2>&1; then
  echo '端口超出范围必须拒绝。' >&2
  exit 1
fi
test ! -f "$fixture/invalid.env.database"
touch "$fixture/truncated.env.database"
if KAIWU_DB_TYPE=mysql run_config "$fixture/truncated.env" >"$fixture/truncated.log" 2>&1; then
  echo '缺少类型的保存配置不应回退为 MySQL。' >&2
  exit 1
fi
printf 'export KAIWU_DB_TYPE=mysql\n' > "$fixture/partial.env.database"
if KAIWU_DB_TYPE=mysql run_config "$fixture/partial.env" >"$fixture/partial.log" 2>&1; then
  echo '已保存类型但缺少连接字段的配置也必须拒绝。' >&2
  exit 1
fi

# 外部数据库部署没有内置 mysql 容器，但仍可运行生成项目的接入命令。
platform_check() {
  bash -euo pipefail -c '
    source <(sed -n "/^require_compose_platform()/,/^}/p" "$1/scripts/kaiwu.sh")
    compose() { if [[ "$1" == ps ]]; then printf "%s\n" system-service gateway-service system-web; fi; }
    KAIWU_CLI_NAME=./kaiwu
    require_compose_platform
  ' _ "$repo_dir"
}
KAIWU_DB_TYPE=dm KAIWU_DB_HOST=db.example.com platform_check
KAIWU_DB_TYPE=mysql KAIWU_DB_HOST=db.example.com platform_check
if KAIWU_DB_TYPE=mysql KAIWU_DB_HOST='' platform_check >"$fixture/missing-mysql.log" 2>&1; then
  echo '内置 MySQL 部署仍必须检查 mysql 容器状态。' >&2
  exit 1
fi
echo '数据库首次配置、保存、密码转义与防误切换检查通过。'
