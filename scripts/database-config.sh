#!/usr/bin/env bash
# 由 kaiwu.sh 加载。选择与连接信息只存于工作区私有文件，不写入仓库。
: "${runtime_env:?database-config.sh 必须由启动器提供运行配置路径}"

load_database_config() {
  local requested="${KAIWU_DB_TYPE:-}" key
  if [[ ! -f "${runtime_env}.database" && -f "$runtime_env" && "$requested" == dm ]]; then
    echo '既有 MySQL 部署不能原地改为达梦，请使用独立运行配置。' >&2
    return 1
  fi
  if [[ -f "${runtime_env}.database" ]]; then
    # 已保存的配置必须明确声明类型；空文件或截断文件不能回退为另一个数据库。
    unset KAIWU_DB_TYPE KAIWU_DB_HOST KAIWU_DB_PORT KAIWU_DB_NAME KAIWU_DB_USER KAIWU_DB_PASSWORD
    # shellcheck disable=SC1090 # 本脚本用 printf %q 写入的 Bash 赋值。
    source "${runtime_env}.database"
    for key in KAIWU_DB_TYPE KAIWU_DB_HOST KAIWU_DB_PORT KAIWU_DB_NAME KAIWU_DB_USER KAIWU_DB_PASSWORD; do
      if [[ -z "${!key+x}" ]]; then
        echo "数据库选择文件缺少 ${key}，请检查保存的配置；不会自动切换数据库。" >&2
        return 1
      fi
    done
    [[ -n "$KAIWU_DB_TYPE" ]] || { echo '保存的数据库类型不能为空。' >&2; return 1; }
    if [[ -n "$requested" && "$requested" != "$KAIWU_DB_TYPE" ]]; then
      echo "此部署已选择 ${KAIWU_DB_TYPE}，不能通过环境变量切换数据库；请使用独立运行配置创建新部署。" >&2
      return 1
    fi
  fi
  export KAIWU_DB_TYPE="${KAIWU_DB_TYPE:-mysql}"
  if [[ -n "${KAIWU_DB_PASSWORD:-}" ]]; then
    export KAIWU_MYSQL_PASSWORD="$KAIWU_DB_PASSWORD"
  fi
  case "$KAIWU_DB_TYPE" in
    mysql) ;;
    dm)
      : "${KAIWU_DB_HOST:?缺少数据库主机}" "${KAIWU_DB_PORT:?缺少数据库端口}" "${KAIWU_DB_NAME:?缺少 Schema}"
      export KAIWU_DB_DRIVER=dm.jdbc.driver.DmDriver
      export KAIWU_DB_JDBC_URL="jdbc:dm://${KAIWU_DB_HOST}:${KAIWU_DB_PORT}?schema=${KAIWU_DB_NAME}"
      ;;
    *) echo "不支持的数据库类型：${KAIWU_DB_TYPE}（mysql / dm）" >&2; return 1 ;;
  esac
}

# 混合模式只管理本地 MySQL；不能静默忽略外部库选择而启动另一个实例。
require_bundled_development_database() {
  if [[ "${KAIWU_DB_TYPE:-mysql}" != mysql || -n "${KAIWU_DB_HOST:-}" ]]; then
    echo 'dev 混合模式只支持内置 MySQL；达梦或外部 MySQL 请使用 up。' >&2
    return 1
  fi
}

configure_database() {
  if [[ -f "${runtime_env}.database" ]]; then
    load_database_config
    return
  fi
  # 既有安装保留 MySQL；不能在升级时弹向导或重新指向空库。
  if [[ -f "$runtime_env" ]]; then
    if [[ "${KAIWU_DB_TYPE:-mysql}" != mysql ]]; then
      echo "既有部署使用 MySQL，不能原地切换达梦。请指定新的 KAIWU_RUNTIME_ENV_FILE。" >&2
      return 1
    fi
    export KAIWU_DB_TYPE=mysql
    return
  fi
  local choice key value default_port
  if [[ -z "${KAIWU_DB_TYPE:-}" ]]; then
    if [[ ! -t 0 ]]; then
      echo "首次部署请选择数据库：设置 KAIWU_DB_TYPE=mysql 或 KAIWU_DB_TYPE=dm 后重试。" >&2
      return 1
    fi
    echo '请选择 Kaiwu 平台数据库：'
    echo '  1) MySQL（默认，可自动启动本地实例）'
    echo '  2) 达梦 DM8（连接已准备好的实例）'
    read -r -p '数据库 [1/2，默认 1]：' choice
    case "${choice:-1}" in
      1|mysql) KAIWU_DB_TYPE=mysql ;;
      2|dm) KAIWU_DB_TYPE=dm ;;
      *) echo '无效选择，请重新运行。' >&2; return 1 ;;
    esac
  fi
  case "$KAIWU_DB_TYPE" in
    mysql) default_port=3306 ;;
    dm) default_port=5236 ;;
    *) echo '数据库类型必须是 mysql 或 dm。' >&2; return 1 ;;
  esac
  if [[ -z "${KAIWU_DB_PASSWORD:-}" && -n "${KAIWU_MYSQL_PASSWORD:-}" ]]; then
    export KAIWU_DB_PASSWORD="$KAIWU_MYSQL_PASSWORD"
  fi
  if [[ "$KAIWU_DB_TYPE" == dm || -n "${KAIWU_DB_HOST:-}" ]]; then
    for key in KAIWU_DB_HOST KAIWU_DB_PORT KAIWU_DB_NAME KAIWU_DB_USER KAIWU_DB_PASSWORD; do
      value="${!key:-}"
      [[ "$key" != KAIWU_DB_PASSWORD ]] || value="${value:-${KAIWU_MYSQL_PASSWORD:-}}"
      if [[ -z "$value" && -t 0 ]]; then
        case "$key" in
          KAIWU_DB_HOST) read -r -p '数据库主机（需能从容器访问）：' value ;;
          KAIWU_DB_PORT) read -r -p "端口 [${default_port}]：" value; value="${value:-$default_port}" ;;
          KAIWU_DB_NAME) read -r -p '数据库名 / 达梦 Schema：' value ;;
          KAIWU_DB_USER) read -r -p '数据库用户：' value ;;
          KAIWU_DB_PASSWORD) IFS= read -r -s -p '数据库密码：' value; echo ;;
        esac
      fi
      [[ "$key" != KAIWU_DB_PORT ]] || value="${value:-$default_port}"
      if [[ -z "$value" ]]; then
        echo "缺少 ${key}，未保存数据库配置。" >&2
        return 1
      fi
      printf -v "$key" '%s' "$value"
      export "${key?}"
    done
    [[ "$KAIWU_DB_HOST" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || { echo '数据库主机格式无效。' >&2; return 1; }
    if [[ ! "$KAIWU_DB_PORT" =~ ^[0-9]{1,5}$ ]] || (( 10#$KAIWU_DB_PORT < 1 || 10#$KAIWU_DB_PORT > 65535 )); then
      echo '数据库端口必须为 1-65535。' >&2
      return 1
    fi
    [[ "$KAIWU_DB_NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo '数据库名 / Schema 只接受字母开头的字母、数字、下划线。' >&2; return 1; }
    export KAIWU_MYSQL_PASSWORD="$KAIWU_DB_PASSWORD"
  fi
  mkdir -p "$(dirname "$runtime_env")"
  (umask 077
    for key in KAIWU_DB_TYPE KAIWU_DB_HOST KAIWU_DB_PORT KAIWU_DB_NAME KAIWU_DB_USER KAIWU_DB_PASSWORD; do
      printf 'export %s=%q\n' "$key" "${!key:-}"
    done > "${runtime_env}.database"
  )
  load_database_config
}
