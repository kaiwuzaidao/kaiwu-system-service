#!/usr/bin/env bash
set -euo pipefail

# 提示里自称什么命令。单仓直接用时就是本脚本；经开源入口 ./kaiwu 调用时由入口注入，
# 否则会让人照着提示去敲一个在当前目录并不存在的路径。
KAIWU_CLI_NAME="${KAIWU_CLI_NAME:-./scripts/kaiwu.sh}"

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
parent_dir="$(dirname "$repo_dir")"
workspace_config="${repo_dir}/kaiwu-workspace.env"
runtime_dir="${parent_dir}/.kaiwu"
runtime_env="${KAIWU_RUNTIME_ENV_FILE:-${runtime_dir}/dev.env}"
local_keys_env="${runtime_dir}/local/runtime-keys.env"
command_name="${1:-up}"
shift || true

if [[ ! -f "$workspace_config" ]]; then
  echo "缺少开源工作区清单：${workspace_config}" >&2
  exit 1
fi
# shellcheck disable=SC1090 # 仓库内版本化文件，只包含受控的工作区常量。
source "$workspace_config"
if [[ "${KAIWU_WORKSPACE_SCHEMA:-}" != "1" ]]; then
  echo "不支持的工作区清单版本：${KAIWU_WORKSPACE_SCHEMA:-未设置}" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Kaiwu local development launcher

Usage:
  ${KAIWU_CLI_NAME} doctor           Check the open-source local prerequisites
  ${KAIWU_CLI_NAME} repositories     Show repository sources and selected release ref
  ${KAIWU_CLI_NAME} init [--with-deploy]  Clone runtime repos; optionally include kaiwu-deploy
  ${KAIWU_CLI_NAME} deploy-init      Clone the optional kaiwu-deploy repository
  ${KAIWU_CLI_NAME} up [--no-build]  Clone runtime repos and start Kaiwu
  ${KAIWU_CLI_NAME} dev              Hybrid: infra in Docker, apps as native processes (hot reload)
  ${KAIWU_CLI_NAME} local-up         Start local processes; read MySQL/Redis from Nacos
  ${KAIWU_CLI_NAME} local-status     Show native-process status
  ${KAIWU_CLI_NAME} local-logs       Follow native-process logs
  ${KAIWU_CLI_NAME} local-down       Stop native processes and keep MySQL data
  ${KAIWU_CLI_NAME} status           Show container status
  ${KAIWU_CLI_NAME} logs             Follow application logs
  ${KAIWU_CLI_NAME} down             Stop containers and keep data
  ${KAIWU_CLI_NAME} reset            Delete all local Kaiwu data after confirmation
  ${KAIWU_CLI_NAME} credentials      Show the initial admin credential
  ${KAIWU_CLI_NAME} context-public-key  Print the running Gateway Context public key
  ${KAIWU_CLI_NAME} import-project-menu <sql>  Import a reviewed generated project menu locally
  ${KAIWU_CLI_NAME} reload-routes     Reload reviewed managed project routes in Compose mode
  ${KAIWU_CLI_NAME} help             Show this help
EOF
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少必需工具：$1" >&2
    exit 1
  fi
}

validate_repository_base_url() {
  if [[ -n "${KAIWU_REPOSITORY_BASE_URL:-}" ]]; then
    case "$KAIWU_REPOSITORY_BASE_URL" in
      https://*|ssh://*|git@*:*) ;;
      *)
        echo "KAIWU_REPOSITORY_BASE_URL 只接受 HTTPS 或 SSH Git 地址。" >&2
        exit 1
        ;;
    esac
  fi
}

repository_url() {
  local repository="$1" origin
  if [[ -n "${KAIWU_REPOSITORY_BASE_URL:-}" ]]; then
    printf '%s/%s.git' "${KAIWU_REPOSITORY_BASE_URL%/}" "$repository"
    return
  fi
  origin="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  case "$origin" in
    https://*|ssh://*|git@*:*)
      ;;
    *)
      echo "origin 不是受支持的 HTTPS/SSH Git 地址，拒绝自动克隆。" >&2
      echo "请检查当前仓库 remote，或手工克隆四个 Kaiwu 仓库。" >&2
      exit 1
      ;;
  esac
  if [[ "$origin" == *"kaiwu-system-service.git" ]]; then
    printf '%s' "${origin%kaiwu-system-service.git}${repository}.git"
    return
  fi
  if [[ "$origin" == *"kaiwu-system-service" ]]; then
    printf '%s' "${origin%kaiwu-system-service}${repository}"
    return
  fi
  echo "无法从 System 仓库 remote 推导 ${repository} 地址。" >&2
  echo "请把四个 Kaiwu 仓库克隆到同一父目录后重试。" >&2
  exit 1
}

selected_repository_ref() {
  local exact_tag
  if [[ -n "${KAIWU_REPOSITORY_REF:-}" ]]; then
    printf '%s' "$KAIWU_REPOSITORY_REF"
    return
  fi
  if [[ "${KAIWU_DEFAULT_REPOSITORY_REF:-auto}" == "auto" ]]; then
    exact_tag="$(git -C "$repo_dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
    printf '%s' "$exact_tag"
    return
  fi
  printf '%s' "$KAIWU_DEFAULT_REPOSITORY_REF"
}

clone_repository() {
  local repository="$1" target url selected_ref
  validate_repository_base_url
  target="${parent_dir}/${repository}"
  if [[ -d "${target}/.git" ]]; then
    return
  fi
  if [[ -e "$target" ]]; then
    echo "目录已存在但不是 Git 仓库：${target}" >&2
    echo "请移走该目录，或手工克隆 ${repository}。" >&2
    exit 1
  fi
  url="$(repository_url "$repository")"
  selected_ref="$(selected_repository_ref)"
  echo "正在克隆 ${repository}${selected_ref:+（版本 ${selected_ref}）} ..."
  if [[ -n "$selected_ref" ]]; then
    git clone --branch "$selected_ref" --depth 1 "$url" "$target"
  else
    git clone --depth 1 "$url" "$target"
  fi
}

write_workspace_lock() {
  local lock_file="${runtime_dir}/workspace.lock" repository repository_dir
  mkdir -p "$runtime_dir"
  umask 077
  {
    printf 'schema=1\n'
    printf 'generated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    for repository in kaiwu-system-service $KAIWU_RUNTIME_REPOSITORIES $KAIWU_OPTIONAL_REPOSITORIES; do
      repository_dir="${parent_dir}/${repository}"
      if [[ -d "${repository_dir}/.git" ]]; then
        printf '%s=%s\n' "$repository" "$(git -C "$repository_dir" rev-parse HEAD)"
      fi
    done
  } >"$lock_file"
  chmod 600 "$lock_file"
}

ensure_repositories() {
  local repository
  for repository in $KAIWU_RUNTIME_REPOSITORIES; do
    clone_repository "$repository"
  done
  write_workspace_lock
}

ensure_deploy_repository() {
  local repository
  for repository in $KAIWU_OPTIONAL_REPOSITORIES; do
    clone_repository "$repository"
  done
  write_workspace_lock
}

show_repositories() {
  local repository selected_ref
  validate_repository_base_url
  selected_ref="$(selected_repository_ref)"
  echo "运行仓库（首次体验会自动获取）："
  for repository in $KAIWU_RUNTIME_REPOSITORIES; do
    printf '  %-28s %s\n' "$repository" "$(repository_url "$repository")"
  done
  echo "可选部署仓库（只在 Kubernetes/GitOps 阶段获取）："
  for repository in $KAIWU_OPTIONAL_REPOSITORIES; do
    printf '  %-28s %s\n' "$repository" "$(repository_url "$repository")"
  done
  if [[ -n "$selected_ref" ]]; then
    echo "版本策略：固定为 ${selected_ref}"
  else
    echo "版本策略：开发态使用各仓库默认分支；正式 Release 自动使用与 System 相同的 tag"
  fi
}

doctor_environment() {
  local failures=0 docker_memory=0 repository target
  echo "Kaiwu 开源环境检查"
  for tool in git docker openssl curl; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '  ✓ %-10s %s\n' "$tool" "$(command -v "$tool")"
    else
      printf '  ✗ 缺少 %s\n' "$tool"
      failures=$((failures + 1))
    fi
  done
  if command -v docker >/dev/null 2>&1; then
    if docker compose version >/dev/null 2>&1; then
      echo "  ✓ Docker Compose v2"
    else
      echo "  ✗ Docker Compose v2 不可用"
      failures=$((failures + 1))
    fi
    if docker info >/dev/null 2>&1; then
      echo "  ✓ Docker daemon 可连接"
      docker_memory="$(docker info --format '{{.MemTotal}}' 2>/dev/null || printf '0')"
      if [[ "$docker_memory" =~ ^[0-9]+$ ]] && (( docker_memory > 0 && docker_memory < 6442450944 )); then
        echo "  ! Docker 可用内存少于 6 GiB，首次构建可能较慢或失败"
      fi
    else
      echo "  ✗ Docker daemon 不可连接，请先启动 Docker Desktop 或 Colima"
      failures=$((failures + 1))
    fi
  fi
  for repository in $KAIWU_RUNTIME_REPOSITORIES; do
    target="${parent_dir}/${repository}"
    if [[ -e "$target" && ! -d "${target}/.git" ]]; then
      echo "  ✗ ${target} 已存在但不是 Git 仓库"
      failures=$((failures + 1))
    fi
  done
  if (( failures > 0 )); then
    echo "环境检查未通过：${failures} 项需要处理。" >&2
    return 1
  fi
  echo "环境检查通过，可以执行：${KAIWU_CLI_NAME} up"
}

# 既有安装缺少后来新增的键时就地补齐，不改动已有值。
# 只在首次生成时写全部键的话，老环境会在 compose 插值阶段直接失败，
# 而那个报错指向的是变量名，不会告诉你「跑一下 up 就能补上」。
backfill_runtime_env() {
  local key value
  # 预留为可追加清单；当前只有一个后来新增的兼容键。
  # shellcheck disable=SC2043
  for key in KAIWU_GATEWAY_INTERNAL_TOKEN; do
    if ! grep -q "^${key}=" "$runtime_env"; then
      value="$(openssl rand -hex 32)"
      printf '%s\n' "${key}=${value}" >>"$runtime_env"
      echo "已为既有本机环境补充 ${key}"
    fi
  done
}

create_runtime_env() {
  if [[ -f "$runtime_env" ]]; then
    backfill_runtime_env
    return
  fi

  mkdir -p "$runtime_dir"
  chmod 700 "$runtime_dir"
  umask 077
  local mysql_root mysql_user redis_password admin_password encryption_key gateway_token
  mysql_root="$(openssl rand -hex 24)"
  # 接外部 MySQL / Redis 时，密码由对方决定，必须沿用调用者给的值。随机生成一个新的
  # 只会让启动前的兼容性检查停在 Access denied——而那看起来像账号权限问题，
  # 不像"我们自己把密码换掉了"。内置实例没设这两个变量时行为不变。
  mysql_user="${KAIWU_MYSQL_PASSWORD:-$(openssl rand -hex 24)}"
  redis_password="${KAIWU_REDIS_PASSWORD:-$(openssl rand -hex 24)}"
  admin_password="Kaiwu-Aa1-$(openssl rand -hex 12)"
  encryption_key="$(openssl rand -base64 32 | tr -d '\n')"
  # Gateway 查询项目入口授权的内部凭据（ADR 0022）。不生成的话 PROJECT 路由一律 503，
  # 而那是"未配置"而非"无权"，排查时很难指向真正原因。
  gateway_token="$(openssl rand -hex 32)"
  printf '%s\n' \
    "KAIWU_MYSQL_ROOT_PASSWORD=${mysql_root}" \
    "KAIWU_MYSQL_PASSWORD=${mysql_user}" \
    "KAIWU_REDIS_PASSWORD=${redis_password}" \
    "KAIWU_BOOTSTRAP_ADMIN_PASSWORD=${admin_password}" \
    "KAIWU_CONFIG_ENCRYPTION_KEY=${encryption_key}" \
    "KAIWU_GATEWAY_INTERNAL_TOKEN=${gateway_token}" \
    >"$runtime_env"
  chmod 600 "$runtime_env"
  echo "已生成本机开发密钥：${runtime_env}"
}

load_runtime_env() {
  if [[ ! -f "$runtime_env" ]]; then
    echo "尚未初始化本地环境，请先执行：${KAIWU_CLI_NAME} up" >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090 # 文件由本脚本生成，只包含受控 KEY=value。
  source "$runtime_env"
  set +a
}

prepare_compose_control_env() {
  load_runtime_env
  export KAIWU_ACCESS_PRIVATE_KEY="control-command"
  export KAIWU_ACCESS_PUBLIC_KEY="control-command"
  export KAIWU_CONTEXT_PRIVATE_KEY="control-command"
  export KAIWU_CONTEXT_PUBLIC_KEY="control-command"
}

prepare_runtime_keys() {
  export KAIWU_ACCESS_PRIVATE_KEY
  export KAIWU_ACCESS_PUBLIC_KEY
  export KAIWU_CONTEXT_PRIVATE_KEY
  export KAIWU_CONTEXT_PUBLIC_KEY
  KAIWU_ACCESS_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
  KAIWU_ACCESS_PUBLIC_KEY="$(printf '%s' "$KAIWU_ACCESS_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"
  KAIWU_CONTEXT_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
  KAIWU_CONTEXT_PUBLIC_KEY="$(printf '%s' "$KAIWU_CONTEXT_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"
}

compose() {
  local profile_args=()
  # 只有配置了 AI 出站白名单才拉起出站代理；未配置时保持默认关闭（fail-closed）。
  if [[ -n "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" ]]; then
    profile_args+=(--profile ai-egress)
  fi
  # 给了外部实例地址就自动叠加对应覆盖文件。不这样做的话，用户 export 了
  # KAIWU_DB_HOST 却发现仍然连着内置库，而且没有任何提示——设了不生效比不支持更难查。
  # 两者互相独立：只换数据库、Redis 仍用内置的，是常见组合。
  local overlay_args=()
  if [[ -n "${KAIWU_DB_HOST:-}" ]]; then
    overlay_args+=(-f "${repo_dir}/docker-compose.external-db.yml")
  fi
  if [[ -n "${KAIWU_REDIS_HOST:-}" ]]; then
    overlay_args+=(-f "${repo_dir}/docker-compose.external-redis.yml")
  fi
  docker compose \
    --project-directory "$repo_dir" \
    --env-file "$runtime_env" \
    -f "${repo_dir}/docker-compose.yml" \
    ${overlay_args[@]+"${overlay_args[@]}"} \
    ${profile_args[@]+"${profile_args[@]}"} \
    "$@"
}

# admin 是否已经改过密码。只查标志位，不读任何口令字段。
# 返回 0 表示「已改过，自举密码已失效」；容器没起来或查不到时返回非 0，
# 此时按「全新库」处理，宁可多打印一次也不要吞掉可用信息。
admin_password_already_changed() {
  local changed
  # compose 会对整份 compose 文件做变量插值，缺 RSA 占位符会直接报错，
  # 因此这里和 context-public-key 一样先补上控制命令用的占位值。
  changed="$(
    prepare_compose_control_env >/dev/null 2>&1
    # shellcheck disable=SC2016 # 变量必须在 mysql 容器内展开。
    compose exec -T mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -B kaiwu_platform -e "SELECT must_change_password FROM sys_user WHERE username=\"admin\""' 2>/dev/null | tr -d '[:space:]'
  )"
  [[ "$changed" == "0" ]]
}

show_credentials() {
  load_runtime_env
  echo
  echo "Kaiwu 地址：http://127.0.0.1:${KAIWU_WEB_PORT:-8000}"
  echo "用户名：admin"
  # 库里 admin 已经改过密码时打印自举密码是有害的：它一定登不进去，
  # 而使用者会拿着它反复尝试，把「我忘了密码」误判成「系统坏了」。
  if admin_password_already_changed; then
    echo "密码：请使用你自己设置的密码。"
    echo "提示：本数据库已存在且 admin 已改过密码，自举密码不再有效。"
    echo "      确实想从零开始时执行：${KAIWU_CLI_NAME} reset"
  else
    echo "初始密码：${KAIWU_BOOTSTRAP_ADMIN_PASSWORD}"
    echo "提示：初始密码只对全新数据库有效，首次登录后必须修改。"
  fi
}

wait_until_ready() {
  local _attempt
  for _attempt in {1..120}; do
    if curl --noproxy '*' --fail --silent \
        "http://127.0.0.1:${KAIWU_GATEWAY_PORT:-8088}/actuator/health" >/dev/null 2>&1 \
        && curl --noproxy '*' --fail --silent \
        "http://127.0.0.1:${KAIWU_WEB_PORT:-8000}/" >/dev/null 2>&1; then
      echo
      echo "✓ MySQL 与 Redis 已就绪"
      echo "✓ System 与 Gateway 已就绪"
      echo "✓ Kaiwu Web 已就绪"
      show_credentials
      echo "第一次使用请打开 docs/QUICKSTART.md，暂时不需要 Nacos、Kubernetes 或 kaiwu-deploy。"
      return
    fi
    sleep 1
  done
  echo "Kaiwu 在等待时间内未就绪，请检查日志：" >&2
  compose ps >&2 || true
  compose logs --tail 120 db-migrate system-service gateway-service >&2 || true
  exit 1
}

case "$command_name" in
  doctor)
    if [[ $# -gt 0 ]]; then
      echo "doctor 不接受参数。" >&2
      usage
      exit 2
    fi
    doctor_environment
    ;;
  repositories)
    if [[ $# -gt 0 ]]; then
      echo "repositories 不接受参数。" >&2
      usage
      exit 2
    fi
    require_tool git
    show_repositories
    ;;
  init)
    include_deploy=false
    if [[ $# -eq 1 && "${1:-}" == "--with-deploy" ]]; then
      include_deploy=true
    elif [[ $# -gt 0 ]]; then
      echo "init 只接受可选参数 --with-deploy。" >&2
      usage
      exit 2
    fi
    require_tool git
    require_tool openssl
    ensure_repositories
    if [[ "$include_deploy" == "true" ]]; then
      ensure_deploy_repository
    fi
    create_runtime_env
    echo "Kaiwu 工作区已准备完成。"
    echo "下一步：${KAIWU_CLI_NAME} up"
    ;;
  deploy-init)
    if [[ $# -gt 0 ]]; then
      echo "deploy-init 不接受参数。" >&2
      usage
      exit 2
    fi
    require_tool git
    ensure_deploy_repository
    echo "Kubernetes/GitOps 部署仓已准备完成：${parent_dir}/kaiwu-deploy"
    echo "下一步请阅读：${parent_dir}/kaiwu-deploy/README.md"
    ;;
  up)
    build_argument="--build"
    if [[ "${1:-}" == "--no-build" ]]; then
      build_argument=""
    elif [[ $# -gt 0 ]]; then
      echo "未知参数：$1" >&2
      usage
      exit 2
    fi
    require_tool git
    require_tool docker
    require_tool openssl
    require_tool curl
    ensure_repositories
    create_runtime_env
    load_runtime_env
    prepare_runtime_keys
    if [[ -n "$build_argument" ]]; then
      compose up --detach --build
    else
      compose up --detach
    fi
    wait_until_ready
    ;;
  dev)
    if [[ $# -gt 0 ]]; then
      echo "dev 不接受参数。" >&2
      usage
      exit 2
    fi
    require_tool git
    require_tool openssl
    ensure_repositories
    create_runtime_env
    exec "$repo_dir/scripts/local-run.sh" dev
    ;;
  local-up)
    if [[ $# -gt 0 ]]; then
      echo "local-up 不接受参数。" >&2
      usage
      exit 2
    fi
    require_tool git
    require_tool openssl
    ensure_repositories
    exec "$repo_dir/scripts/local-run.sh" up
    ;;
  local-status|local-logs|local-down)
    if [[ $# -gt 0 ]]; then
      echo "${command_name} 不接受参数。" >&2
      usage
      exit 2
    fi
    exec "$repo_dir/scripts/local-run.sh" "${command_name#local-}"
    ;;
  status)
    require_tool docker
    prepare_compose_control_env
    compose ps
    ;;
  logs)
    require_tool docker
    prepare_compose_control_env
    # 默认打印最近日志后退出，不跟随。AGENTS.md 把本命令列为排查第二步，
    # 而 --follow 永远不返回——人可以 Ctrl-C，AI 编码工具会一直等下去。
    # 要跟随就显式加 -f / --follow，其余参数原样透传给 docker compose logs。
    if [[ $# -gt 0 ]]; then
      compose logs "$@"
    else
      compose logs --tail 200
    fi
    ;;
  down)
    require_tool docker
    prepare_compose_control_env
    compose down
    ;;
  reset)
    require_tool docker
    prepare_compose_control_env
    echo "该操作会永久删除本机 Kaiwu 的 MySQL、Redis 和生成制品数据。"
    read -r -p "输入 RESET 继续：" confirmation
    if [[ "$confirmation" != "RESET" ]]; then
      echo "已取消。"
      exit 0
    fi
    compose down --volumes
    echo "本地数据已删除。再次执行 up 会使用保存的初始凭据创建全新环境。"
    ;;
  credentials)
    show_credentials
    ;;
  context-public-key)
    if [[ $# -gt 0 ]]; then
      echo "context-public-key 不接受参数。" >&2
      usage
      exit 2
    fi
    if [[ -f "$local_keys_env" ]]; then
      # local-run.sh 以 0600 创建，只保存当前本机进程共用的临时 RSA 密钥。
      # shellcheck disable=SC1090
      source "$local_keys_env"
      printf '%s\n' "$KAIWU_CONTEXT_PUBLIC_KEY"
      exit 0
    fi
    require_tool docker
    prepare_compose_control_env
    # shellcheck disable=SC2016 # 公钥变量必须在 System 容器内展开。
    compose exec -T system-service sh -c 'printf "%s\n" "$KAIWU_CONTEXT_PUBLIC_KEY"'
    ;;
  import-project-menu)
    if [[ $# -ne 1 || ! -f "$1" ]]; then
      echo "用法：${KAIWU_CLI_NAME} import-project-menu <生成后端仓/sql/menu.sql>" >&2
      exit 2
    fi
    if ! grep -Fq 'INSERT INTO sys_project_menu' "$1"; then
      echo "拒绝导入：文件不包含生成项目菜单 INSERT，请确认选择了 sql/menu.sql。" >&2
      exit 1
    fi
    if grep -Eiq '^[[:space:]]*(DROP|ALTER|DELETE|TRUNCATE|GRANT|CREATE|REPLACE|UPDATE|CALL|LOAD)[[:space:]]' "$1"; then
      echo "拒绝导入：项目菜单文件包含 INSERT 以外的数据库变更语句。" >&2
      exit 1
    fi
    unexpected_target="$(grep -Eio 'INSERT[[:space:]]+INTO[[:space:]]+`?[a-zA-Z0-9_]+' "$1" \
      | sed -E 's/.*[[:space:]]+`?([a-zA-Z0-9_]+)$/\1/I' \
      | grep -v '^sys_project_menu$' || true)"
    if [[ -n "$unexpected_target" ]]; then
      echo "拒绝导入：项目菜单文件包含非 sys_project_menu 写入。" >&2
      exit 1
    fi
    require_tool docker
    prepare_compose_control_env
    # shellcheck disable=SC2016 # MYSQL_PASSWORD 必须在 mysql 容器内展开。
    compose exec -T mysql sh -c \
      'exec mysql -ukaiwu -p"$MYSQL_PASSWORD" kaiwu_platform' < "$1"
    echo "项目菜单已导入；请在平台为项目角色分配菜单权限。"
    ;;
  reload-routes)
    if [[ $# -gt 0 ]]; then
      echo "reload-routes 不接受参数。" >&2
      exit 2
    fi
    require_tool docker
    require_tool curl
    prepare_compose_control_env
    compose restart gateway-service
    for _attempt in {1..60}; do
      if curl --noproxy '*' --fail --silent \
          "http://127.0.0.1:${KAIWU_GATEWAY_PORT:-8088}/actuator/health" >/dev/null 2>&1; then
        echo "Gateway 已重新载入 routes.managed.d/。"
        exit 0
      fi
      sleep 1
    done
    echo "Gateway 未在 60 秒内恢复，请执行 ${KAIWU_CLI_NAME} logs 查看受管路由错误。" >&2
    exit 1
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "未知命令：${command_name}" >&2
    usage
    exit 2
    ;;
esac
