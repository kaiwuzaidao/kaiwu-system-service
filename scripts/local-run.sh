#!/usr/bin/env bash
set -euo pipefail

# 无 Docker 的 Nacos 直启模式：基础设施和运行配置都属于用户管理的 Nacos/MySQL/Redis，
# 本脚本只在当前开发机启动 System、Gateway、Web 三个进程，绝不修改数据库或 Redis。
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
parent_dir="$(dirname "$repo_dir")"
runtime_dir="${parent_dir}/.kaiwu"
local_dir="${runtime_dir}/local"
local_keys_env="${local_dir}/runtime-keys.env"
runtime_env="${runtime_dir}/dev.env"
command_name="${1:-up}"
started_processes=()

usage() {
  cat <<'EOF'
Kaiwu Nacos native launcher (without Docker)

Usage:
  ./scripts/kaiwu.sh dev            混合模式：基础设施跑 Docker，三个应用跑原生进程
  ./scripts/kaiwu.sh local-up       Nacos 直启：基础设施与配置都由你自己的 Nacos 提供
  ./scripts/kaiwu.sh local-status
  ./scripts/kaiwu.sh local-logs
  ./scripts/kaiwu.sh local-down

Required environment variables:
  KAIWU_NACOS_SERVER_ADDR, KAIWU_NACOS_NAMESPACE,
  KAIWU_NACOS_USERNAME, KAIWU_NACOS_PASSWORD

The Nacos namespace must already contain kaiwu-system-service-dev.yml and
kaiwu-gateway-service-dev.yml. Those Data IDs provide MySQL and Redis settings.
EOF
}

fail() {
  echo "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少本机依赖：$1"
}

# 优先用 JAVA_HOME 下的 java：本机 PATH 上的 java 完全可能是 17，
# 而 Maven 通过 JAVA_HOME 用的是 21，只查 PATH 会把正确配置的环境判成不合格。
require_java_21() {
  local java_bin version
  java_bin="${JAVA_HOME:+$JAVA_HOME/bin/}java"
  version="$("$java_bin" -version 2>&1 | awk -F '[\".]' '/version/ { print $2; exit }')"
  [[ "$version" == "21" ]] || fail "需要 JDK 21，当前 ${java_bin} 主版本为 ${version:-未知}（JAVA_HOME=${JAVA_HOME:-未设置}）。"
}

require_nacos_environment() {
  local var_name missing=()
  for var_name in KAIWU_NACOS_SERVER_ADDR KAIWU_NACOS_NAMESPACE KAIWU_NACOS_USERNAME KAIWU_NACOS_PASSWORD; do
    [[ -n "${!var_name:-}" ]] || missing+=("$var_name")
  done
  (( ${#missing[@]} == 0 )) || fail "缺少 Nacos 启动参数：${missing[*]}"
}

prepare_runtime_keys() {
  export KAIWU_ACCESS_PRIVATE_KEY KAIWU_ACCESS_PUBLIC_KEY
  export KAIWU_CONTEXT_PRIVATE_KEY KAIWU_CONTEXT_PUBLIC_KEY
  if [[ -f "$local_keys_env" ]]; then
    # shellcheck disable=SC1090 # 本脚本以 0600 创建，仅保存本轮本机进程共享的临时 RSA 密钥。
    source "$local_keys_env"
    return
  fi
  KAIWU_ACCESS_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
  KAIWU_ACCESS_PUBLIC_KEY="$(printf '%s' "$KAIWU_ACCESS_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"
  KAIWU_CONTEXT_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
  KAIWU_CONTEXT_PUBLIC_KEY="$(printf '%s' "$KAIWU_CONTEXT_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"
  umask 077
  {
    printf 'KAIWU_ACCESS_PRIVATE_KEY=%q\n' "$KAIWU_ACCESS_PRIVATE_KEY"
    printf 'KAIWU_ACCESS_PUBLIC_KEY=%q\n' "$KAIWU_ACCESS_PUBLIC_KEY"
    printf 'KAIWU_CONTEXT_PRIVATE_KEY=%q\n' "$KAIWU_CONTEXT_PRIVATE_KEY"
    printf 'KAIWU_CONTEXT_PUBLIC_KEY=%q\n' "$KAIWU_CONTEXT_PUBLIC_KEY"
  } >"$local_keys_env"
  chmod 600 "$local_keys_env"
}

pid_file() { printf '%s/%s.pid' "$local_dir" "$1"; }
start_marker_file() { printf '%s/%s.start' "$local_dir" "$1"; }
log_file() { printf '%s/%s.log' "$local_dir" "$1"; }
read_pid() { [[ -f "$(pid_file "$1")" ]] && tr -d '[:space:]' <"$(pid_file "$1")"; }
process_start_marker() { ps -p "$1" -o lstart= 2>/dev/null | tr -s ' ' | sed 's/^ //;s/ $//'; }

process_running() {
  local name="$1" pid expected_marker current_marker process_command
  pid="$(read_pid "$name" || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 1
  expected_marker="$(cat "$(start_marker_file "$name")" 2>/dev/null || true)"
  current_marker="$(process_start_marker "$pid")"
  [[ -n "$expected_marker" && "$expected_marker" == "$current_marker" ]] || return 1
  process_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$name" in
    system|gateway) [[ "$process_command" == *mvn* || "$process_command" == *java* ]] ;;
    web) [[ "$process_command" == *pnpm* || "$process_command" == *node* ]] ;;
    *) return 1 ;;
  esac
}

assert_port_available() {
  local port="$1" label="$2"
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    fail "端口 ${port} 已被占用，无法启动 ${label}。请先执行 local-down 或停止占用进程。"
  fi
}

start_process() {
  local name="$1" working_dir="$2"
  shift 2
  if process_running "$name"; then
    echo "${name} 已在运行（PID $(read_pid "$name")）。"
    return
  fi
  rm -f "$(pid_file "$name")" "$(start_marker_file "$name")"
  (
    cd "$working_dir"
    exec "$@"
  ) >>"$(log_file "$name")" 2>&1 &
  echo "$!" >"$(pid_file "$name")"
  process_start_marker "$!" >"$(start_marker_file "$name")"
  [[ -s "$(start_marker_file "$name")" ]] || fail "无法记录 ${name} 的启动标识。"
  started_processes+=("$name")
}

stop_process() {
  local name="$1" pid
  pid="$(read_pid "$name" || true)"
  [[ -n "$pid" ]] || return
  if process_running "$name"; then
    kill "$pid" 2>/dev/null || true
    for _attempt in {1..10}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
  elif kill -0 "$pid" 2>/dev/null; then
    echo "拒绝停止 PID ${pid}：它不再是 Kaiwu ${name} 进程。" >&2
  fi
  rm -f "$(pid_file "$name")" "$(start_marker_file "$name")"
}

cleanup_failed_local_start() {
  local index
  trap - EXIT
  for ((index=${#started_processes[@]} - 1; index >= 0; index--)); do
    stop_process "${started_processes[index]}"
  done
  # 若本轮失败后没有本机应用仍依赖这组密钥，即使本轮复用了旧密钥也必须清理。
  if ! process_running system && ! process_running gateway && ! process_running web; then
    rm -f "$local_keys_env"
  fi
}

wait_for_http() {
  local url="$1" label="$2"
  for _attempt in {1..120}; do
    if curl --noproxy '*' --fail --silent "$url" >/dev/null 2>&1; then
      echo "${label} 已就绪。"
      return
    fi
    sleep 1
  done
  fail "${label} 未在 120 秒内就绪，请执行 ./scripts/kaiwu.sh local-logs 查看日志。"
}

# 混合模式：MySQL/Redis 用 Docker，System/Gateway/Web 用本机进程。
#
# 存在的理由是调试节奏：全容器模式下改一行前端要等镜像重建（本机实测 250 秒），
# 没人会用这种循环写代码；而 Nacos 直启模式又要求你先自备一套 Nacos。
# 这一档不碰 Nacos，配置全部来自 local profile 与 .kaiwu/dev.env。
dev_up() {
  require_tool docker
  require_tool java
  require_tool mvn
  require_tool pnpm
  require_tool curl
  require_tool lsof
  require_tool openssl
  require_java_21

  [[ -f "$runtime_env" ]] || fail "尚未初始化本地环境，请先执行：./scripts/kaiwu.sh up"
  set -a
  # shellcheck disable=SC1090 # 由 kaiwu.sh 生成，只包含受控 KEY=value。
  source "$runtime_env"
  set +a

  local mysql_port="${KAIWU_DEV_MYSQL_PORT:-3306}"
  local redis_port="${KAIWU_DEV_REDIS_PORT:-6379}"

  mkdir -p "$local_dir" "${runtime_dir}/artifacts"
  chmod 700 "$local_dir" "${runtime_dir}/artifacts"

  if ! process_running system; then assert_port_available 8080 "System Service"; fi
  if ! process_running gateway; then assert_port_available 8088 "Gateway"; fi
  if ! process_running web; then assert_port_available 8000 "System Web"; fi

  # 必须先备好 RSA 密钥再调 compose：compose 会对**整份文件**做变量插值，
  # 哪怕只启动 mysql/redis 也会校验 gateway 服务引用的 KAIWU_*_KEY，缺值直接报错。
  prepare_runtime_keys
  trap cleanup_failed_local_start EXIT

  # 只起基础设施并跑完迁移；应用容器不启动，由本机进程取代。
  echo "启动基础设施（MySQL/Redis）并执行迁移 ..."
  (cd "$repo_dir" && docker compose -f docker-compose.yml -f compose.dev-ports.yml \
    up --detach --wait mysql redis db-migrate)

  MAVEN_SKIP_RC=1 mvn -s "$parent_dir/kaiwu-system-starter/.mvn/settings.xml" \
    -f "$parent_dir/kaiwu-system-starter/pom.xml" -DskipTests install

  # 只把 boot 模块放进 reactor 来跑 spring-boot:run：带 -am 时 Maven 会先在父 pom
  # 上执行该目标，而父 pom 没有 main class，直接 BUILD FAILURE。
  # 代价是 api/domain 必须先装进本地仓库，因此这里先 install 一次。
  MAVEN_SKIP_RC=1 mvn -s "$repo_dir/.mvn/settings.xml" -f "$repo_dir/pom.xml" \
    -pl kaiwu-system-boot -am -DskipTests install

  start_process system "$repo_dir" env \
    MAVEN_SKIP_RC=1 JAVA_HOME="${JAVA_HOME:-}" SPRING_PROFILES_ACTIVE=local SERVER_PORT=8080 SERVER_ADDRESS=127.0.0.1 \
    SPRING_CLOUD_NACOS_CONFIG_ENABLED=false SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false \
    DB_HOST=127.0.0.1 DB_PORT="$mysql_port" DB_NAME=kaiwu_platform DB_USER=kaiwu \
    DB_PASSWORD="$KAIWU_MYSQL_PASSWORD" \
    REDIS_HOST=127.0.0.1 REDIS_PORT="$redis_port" REDIS_PASSWORD="$KAIWU_REDIS_PASSWORD" \
    KAIWU_CONFIG_ENCRYPTION_KEY="$KAIWU_CONFIG_ENCRYPTION_KEY" \
    KAIWU_BOOTSTRAP_ADMIN_PASSWORD="$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
    KAIWU_GATEWAY_INTERNAL_TOKEN="$KAIWU_GATEWAY_INTERNAL_TOKEN" \
    KAIWU_ACCESS_PRIVATE_KEY="$KAIWU_ACCESS_PRIVATE_KEY" \
    KAIWU_CONTEXT_PUBLIC_KEY="$KAIWU_CONTEXT_PUBLIC_KEY" \
    KAIWU_ARTIFACT_ROOT="${runtime_dir}/artifacts" \
    mvn -s .mvn/settings.xml -f kaiwu-system-boot/pom.xml spring-boot:run
  wait_for_http http://127.0.0.1:8080/actuator/health "System Service"

  start_process gateway "$parent_dir/kaiwu-gateway-service" env \
    MAVEN_SKIP_RC=1 JAVA_HOME="${JAVA_HOME:-}" SPRING_PROFILES_ACTIVE=local SERVER_PORT=8088 SERVER_ADDRESS=127.0.0.1 \
    SPRING_CLOUD_NACOS_CONFIG_ENABLED=false SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false \
    REDIS_HOST=127.0.0.1 REDIS_PORT="$redis_port" REDIS_PASSWORD="$KAIWU_REDIS_PASSWORD" \
    KAIWU_SYSTEM_SERVICE_URI=http://127.0.0.1:8080 \
    KAIWU_GATEWAY_INTERNAL_TOKEN="$KAIWU_GATEWAY_INTERNAL_TOKEN" \
    KAIWU_ACCESS_PUBLIC_KEY="$KAIWU_ACCESS_PUBLIC_KEY" \
    KAIWU_CONTEXT_PRIVATE_KEY="$KAIWU_CONTEXT_PRIVATE_KEY" \
    mvn -s .mvn/settings.xml spring-boot:run
  wait_for_http http://127.0.0.1:8088/actuator/health "Gateway"

  start_process web "$parent_dir/kaiwu-system-web" pnpm dev --port 8000
  wait_for_http http://127.0.0.1:8000 "System Web"
  trap - EXIT

  echo
  echo "Kaiwu 混合开发模式已启动：http://127.0.0.1:8000"
  echo "  前端改代码热更新生效；后端改代码需重启对应进程。"
  echo "  日志：./scripts/kaiwu.sh local-logs    停止：./scripts/kaiwu.sh local-down"
  echo "  基础设施仍在 Docker 中运行，local-down 不会停掉它们。"
}

local_up() {
  require_tool java
  require_tool mvn
  require_tool pnpm
  require_tool curl
  require_tool lsof
  require_tool openssl
  require_java_21
  require_nacos_environment
  mkdir -p "$local_dir" "${runtime_dir}/artifacts"
  chmod 700 "$local_dir" "${runtime_dir}/artifacts"

  if ! process_running system; then assert_port_available 8080 "System Service"; fi
  if ! process_running gateway; then assert_port_available 8088 "Gateway"; fi
  if ! process_running web; then assert_port_available 8000 "System Web"; fi
  prepare_runtime_keys
  trap cleanup_failed_local_start EXIT

  MAVEN_SKIP_RC=1 mvn -s "$parent_dir/kaiwu-system-starter/.mvn/settings.xml" \
    -f "$parent_dir/kaiwu-system-starter/pom.xml" -DskipTests install

  # 只把 boot 模块放进 reactor 来跑 spring-boot:run：带 -am 时 Maven 会先在父 pom
  # 上执行该目标，而父 pom 没有 main class，直接 BUILD FAILURE。
  # 代价是 api/domain 必须先装进本地仓库，因此这里先 install 一次。
  MAVEN_SKIP_RC=1 mvn -s "$repo_dir/.mvn/settings.xml" -f "$repo_dir/pom.xml" \
    -pl kaiwu-system-boot -am -DskipTests install

  start_process system "$repo_dir" env \
    MAVEN_SKIP_RC=1 SPRING_PROFILES_ACTIVE=dev SERVER_PORT=8080 SERVER_ADDRESS=127.0.0.1 \
    SPRING_CONFIG_IMPORT=nacos:kaiwu-system-service-dev.yml \
    NACOS_SERVER_ADDR="$KAIWU_NACOS_SERVER_ADDR" NACOS_USER="$KAIWU_NACOS_USERNAME" \
    NACOS_PASSWORD="$KAIWU_NACOS_PASSWORD" NACOS_NAMESPACE="$KAIWU_NACOS_NAMESPACE" \
    SPRING_CLOUD_NACOS_CONFIG_ENABLED=true SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false \
    KAIWU_ACCESS_PRIVATE_KEY="$KAIWU_ACCESS_PRIVATE_KEY" \
    KAIWU_CONTEXT_PUBLIC_KEY="$KAIWU_CONTEXT_PUBLIC_KEY" \
    KAIWU_ARTIFACT_ROOT="${runtime_dir}/artifacts" \
    mvn -s .mvn/settings.xml -f kaiwu-system-boot/pom.xml spring-boot:run
  wait_for_http http://127.0.0.1:8080/actuator/health "System Service"

  start_process gateway "$parent_dir/kaiwu-gateway-service" env \
    MAVEN_SKIP_RC=1 SPRING_PROFILES_ACTIVE=dev SERVER_PORT=8088 SERVER_ADDRESS=127.0.0.1 \
    SPRING_CONFIG_IMPORT=nacos:kaiwu-gateway-service-dev.yml \
    NACOS_SERVER_ADDR="$KAIWU_NACOS_SERVER_ADDR" NACOS_USER="$KAIWU_NACOS_USERNAME" \
    NACOS_PASSWORD="$KAIWU_NACOS_PASSWORD" NACOS_NAMESPACE="$KAIWU_NACOS_NAMESPACE" \
    SPRING_CLOUD_NACOS_CONFIG_ENABLED=true SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false \
    KAIWU_SYSTEM_SERVICE_URI=http://127.0.0.1:8080 \
    KAIWU_ACCESS_PUBLIC_KEY="$KAIWU_ACCESS_PUBLIC_KEY" \
    KAIWU_CONTEXT_PRIVATE_KEY="$KAIWU_CONTEXT_PRIVATE_KEY" \
    mvn -s .mvn/settings.xml spring-boot:run
  wait_for_http http://127.0.0.1:8088/actuator/health "Gateway"

  start_process web "$parent_dir/kaiwu-system-web" pnpm dev --port 8000
  wait_for_http http://127.0.0.1:8000 "System Web"
  trap - EXIT
  echo "Kaiwu Nacos 本机进程已启动：http://127.0.0.1:8000"
  echo "日志目录：${local_dir}"
}

local_status() {
  for name in system gateway web; do
    if process_running "$name"; then echo "${name}: running (PID $(read_pid "$name"))"; else echo "${name}: stopped"; fi
  done
  curl --noproxy '*' --fail --silent http://127.0.0.1:8088/actuator/health || true
}

local_logs() {
  mkdir -p "$local_dir"
  tail -n 120 -F "$(log_file system)" "$(log_file gateway)" "$(log_file web)"
}

case "$command_name" in
  dev) dev_up ;;
  up) local_up ;;
  status) local_status ;;
  logs) local_logs ;;
  down)
    for name in web gateway system; do stop_process "$name"; done
    rm -f "$local_keys_env"
    echo "Kaiwu 本机进程已停止；Nacos、MySQL、Redis 均未被修改。"
    ;;
  help|--help|-h) usage ;;
  *) usage; exit 2 ;;
esac
