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

# shellcheck source=database-config.sh
source "${repo_dir}/scripts/database-config.sh"

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
  cat <<EOF
Kaiwu local development launcher

Usage:
  ${KAIWU_CLI_NAME} doctor           Check the open-source local prerequisites
  ${KAIWU_CLI_NAME} repositories     Show repository sources and selected release ref
  ${KAIWU_CLI_NAME} init [--with-deploy]  Clone runtime repos; optionally include kaiwu-deploy
  ${KAIWU_CLI_NAME} deploy-init      Clone the optional kaiwu-deploy repository
  ${KAIWU_CLI_NAME} up [--build|--no-build]  Clone runtime repos and start Kaiwu (releases pull prebuilt images)
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
  ${KAIWU_CLI_NAME} reload-routes     Reload reviewed managed project routes in Compose mode
  ${KAIWU_CLI_NAME} project-up <backend-dir> [frontend-dir]  Run a generated project in Docker next to Kaiwu
  ${KAIWU_CLI_NAME} project-down <projectCode>  Stop a project started by project-up and keep its data
  ${KAIWU_CLI_NAME} login [--client <name>] [--local]  Authorize this CLI (device flow, max 7 days);
                                       --local approves it on this machine without the browser
  ${KAIWU_CLI_NAME} logout           Revoke the CLI session
  ${KAIWU_CLI_NAME} whoami           Show the signed-in user
  ${KAIWU_CLI_NAME} project new <code> --name <name> [--package <pkg>]  Register and generate a basic scaffold
  ${KAIWU_CLI_NAME} project status <code> [--wait]  Show or wait for the generation result
  ${KAIWU_CLI_NAME} project pull <code> [--dir <dir>]  Download, unzip and git-init both repositories
  ${KAIWU_CLI_NAME} project sync <backend-dir> [--apply] [--with-access]  Plan or apply kaiwu/*.yml dictionaries, configs and menus (roles.yml only with --with-access)
  ${KAIWU_CLI_NAME} access members|roles|permissions <code>  List project members, roles or grantable permission codes
  ${KAIWU_CLI_NAME} access member-set <code> <username> --roles a,b [--disabled]  Add or update a project member
  ${KAIWU_CLI_NAME} access member-remove <code> <username>  Remove a project member
  ${KAIWU_CLI_NAME} access role-create <code> <roleCode> --name <name> [--description <text>]  Create a project role
  ${KAIWU_CLI_NAME} access role-grant <code> <roleCode> --permissions p1,p2|--clear  Replace a role's permissions
  ${KAIWU_CLI_NAME} storage accounts|bindings [<code>]  List object-storage accounts or project bindings (platform admin)
  ${KAIWU_CLI_NAME} storage test <accountCode>  Probe a storage account (issues a temporary credential, writes and deletes a probe object)
  ${KAIWU_CLI_NAME} storage bind <code> --account <accountCode> [--name <storageName>] [--max-mb <n>] [--types a/b,c/d]  Bind a project to a storage account
  ${KAIWU_CLI_NAME} storage bind-status <bindingId> --status ACTIVE|READ_ONLY|DISABLED  Change a binding status
  ${KAIWU_CLI_NAME} help             Show this help
EOF
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少必需工具：$1" >&2
    exit 1
  fi
}

# A linked worktree stores .git as a file; require Git to validate either form.
is_git_worktree() {
  [[ -e "$1/.git" ]] &&
    [[ "$(git -C "$1" rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]
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
  if is_git_worktree "$target"; then
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
      if is_git_worktree "$repository_dir"; then
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
    if [[ -e "$target" ]] && ! is_git_worktree "$target"; then
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
  # 外部数据库口令由独立的 .database 文件保存并在加载时覆盖；这里仅生成内置实例口令。
  # Redis 仍沿用调用者提供的外部实例口令。
  mysql_user="$(openssl rand -hex 24)"
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
  load_database_config
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

# 发布版（System 签出在 vX.Y.Z tag 上）默认直接拉取 CI 发布的镜像，不在本机构建：
# 首次启动快，也不依赖 Docker Hub 上的构建基础镜像和 Maven/npm 依赖下载。
# 源码开发态没有对应版本的镜像，仍在本机构建；--build 强制本机构建，--no-build 只启动已有镜像。
release_image_tag() {
  local tag
  tag="$(git -C "$repo_dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
  if [[ "$tag" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

start_platform() {
  local tag
  case "$1" in
    no-build)
      compose up --detach
      return
      ;;
    build)
      compose up --detach --build
      return
      ;;
  esac
  tag="$(release_image_tag)"
  if [[ -z "$tag" ]]; then
    compose up --detach --build
    return
  fi
  echo "使用预构建镜像 ${KAIWU_IMAGE_REGISTRY:-ghcr.io/kaiwuzaidao}/kaiwu-*:${tag}（需要本机构建时加 --build）"
  if [[ "${KAIWU_DB_TYPE:-mysql}" == dm ]] && ! compose pull --quiet db-migrate; then
    echo '达梦迁移镜像拉取失败，改为从源码构建。' >&2
    compose up --detach --build
    return
  fi
  if compose pull --quiet system-service gateway-service system-web; then
    compose up --detach --no-build
    return
  fi
  echo "拉取预构建镜像失败，改为在本机构建。网络受限时可设置 KAIWU_IMAGE_REGISTRY 指向可访问的镜像仓库。" >&2
  compose up --detach --build
}

# AI 出站默认只放行首次引导里的三个预设服务商（DeepSeek、通义千问、OpenAI 的官方域名），
# 装好即可在对话里接入模型。出站仍经带白名单的受控代理，私网与其它域名照样被拒绝。
# 用其它模型服务时覆盖白名单；显式设为空字符串（KAIWU_AI_PROVIDER_ALLOWED_HOSTS=）则关闭 AI 出站。
readonly KAIWU_AI_PRESET_HOSTS="api.deepseek.com,dashscope.aliyuncs.com,api.openai.com"

compose() {
  local profile_args=()
  # 镜像标签与源码版本一一对应：发布 tag 上用版本号（拉取或本机构建都打这个标签），否则用 local。
  # 所有 compose 子命令看到同一组镜像，up --no-build、status、down 不会错配。
  export KAIWU_IMAGE_TAG="${KAIWU_IMAGE_TAG:-$(release_image_tag)}"
  export KAIWU_IMAGE_TAG="${KAIWU_IMAGE_TAG:-local}"
  export KAIWU_AI_PROVIDER_ALLOWED_HOSTS="${KAIWU_AI_PROVIDER_ALLOWED_HOSTS-$KAIWU_AI_PRESET_HOSTS}"
  # 只有白名单非空才拉起出站代理并让应用走它；为空时整条 AI 出站保持关闭（fail-closed）。
  if [[ -n "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS}" ]]; then
    export KAIWU_AI_PROVIDER_EGRESS_PROXY_URI="${KAIWU_AI_PROVIDER_EGRESS_PROXY_URI:-http://ai-egress-proxy:3128}"
    profile_args+=(--profile ai-egress)
  fi
  # 给了外部实例地址就自动叠加对应覆盖文件。不这样做的话，用户 export 了
  # KAIWU_DB_HOST 却发现仍然连着内置库，而且没有任何提示——设了不生效比不支持更难查。
  # 两者互相独立：只换数据库、Redis 仍用内置的，是常见组合。
  local overlay_args=()
  if [[ "${KAIWU_DB_TYPE:-mysql}" == dm ]]; then
    overlay_args+=(-f "${repo_dir}/docker-compose.dm.yml")
  elif [[ -n "${KAIWU_DB_HOST:-}" ]]; then
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

# 管理命令统一连接当前数据库，连接密码只在容器环境中读取。
database_sql() {
  if [[ "${KAIWU_DB_TYPE:-mysql}" == dm ]]; then
    compose run --rm --no-deps -T db-migrate sql
  else
    # shellcheck disable=SC2016 # 连接变量在容器内读取。
    compose run --rm --no-deps -T --entrypoint sh schema-compat-check -c \
      'export MYSQL_PWD="$DB_PASSWORD"; exec mysql --protocol=TCP -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" -N -B'
  fi
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
    printf '%s\n' "SELECT must_change_password FROM sys_user WHERE username='admin';" | database_sql 2>/dev/null | tr -d '[:space:]'
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

# ---------- 本机体验业务项目：project-up / project-down（ADR 0025 本机补充） ----------
# 只编排业务仓自带的 deploy/server 文件，不改写业务仓；平台侧只写两个受管目录：
#   routes.managed.d/<code>.yml  —— 原样复制业务仓评审过的 Gateway 显式路由
#   apps.managed.d/<code>.conf   —— 平台前端同源入口 /apps/<code>/ 与 /<code>-api/
# 业务库口令按项目生成一次并保存在 .kaiwu/projects/<code>.env（0600），重复执行时复用，
# 否则已有的 MySQL 数据卷会因初始口令不一致而拒绝连接。
project_code_pattern='^[a-z][a-z0-9-]{1,63}$'
apps_managed_dir="${repo_dir}/apps.managed.d"
routes_managed_dir="${repo_dir}/routes.managed.d"
project_state_dir="${runtime_dir}/projects"

reload_gateway_routes() {
  compose restart gateway-service
  for _attempt in {1..60}; do
    if curl --noproxy '*' --fail --silent \
        "http://127.0.0.1:${KAIWU_GATEWAY_PORT:-8088}/actuator/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Gateway 未在 60 秒内恢复，请执行 ${KAIWU_CLI_NAME} logs 查看受管路由错误。" >&2
  return 1
}

reload_platform_web() {
  # 先校验再重载：include 写错时保留旧配置继续服务，而不是让平台前端整体失效。
  compose exec -T system-web nginx -t >/dev/null
  compose exec -T system-web nginx -s reload >/dev/null
}

require_compose_platform() {
  local running service
  running="$(compose ps --status running --services 2>/dev/null || true)"
  for service in mysql system-service gateway-service system-web; do
    if [[ "$service" == mysql && ( "${KAIWU_DB_TYPE:-mysql}" == dm || -n "${KAIWU_DB_HOST:-}" ) ]]; then
      continue
    fi
    if ! grep -qx "$service" <<<"$running"; then
      echo "平台未以 Compose 模式运行（缺少 ${service}）。请先执行：${KAIWU_CLI_NAME} up" >&2
      echo "project-up 只支持 Compose 模式；${KAIWU_CLI_NAME} dev 混合模式请按 QUICKSTART 手动联调。" >&2
      exit 1
    fi
  done
  # 平台前端镜像与本仓 Compose 版本不一致时（旧镜像没有 include），业务入口会静默落回平台 SPA。
  # shellcheck disable=SC2016 # 路径在容器内判断。
  if ! compose exec -T system-web sh -c \
      'grep -q kaiwu-apps /etc/nginx/conf.d/default.conf && test -d /etc/nginx/kaiwu-apps'; then
    echo "当前平台前端还不支持挂载本机业务入口，请先执行：${KAIWU_CLI_NAME} up（按新版本重建平台前端）" >&2
    exit 1
  fi
}

read_project_code() {
  local backend_dir="$1" code
  code="$(sed -nE 's/^[[:space:]]*projectCode:[[:space:]]*([a-z0-9-]+)[[:space:]]*$/\1/p' \
    "${backend_dir}/deploy/server/gateway-route.yml" | head -1)"
  if [[ ! "$code" =~ $project_code_pattern ]]; then
    echo "无法从 ${backend_dir}/deploy/server/gateway-route.yml 读出合法的 projectCode。" >&2
    exit 1
  fi
  printf '%s' "$code"
}

ensure_project_secrets() {
  local secrets_file="$1"
  if [[ -f "$secrets_file" ]]; then
    return 0
  fi
  mkdir -p "$project_state_dir"
  (
    umask 077
    printf 'DB_PASSWORD=%s\nDB_ROOT_PASSWORD=%s\n' \
      "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" >"$secrets_file"
  )
}

write_web_network_override() {
  local code="$1" override_file="$2"
  cat >"$override_file" <<EOF
# 由 ${KAIWU_CLI_NAME} project-up 生成：让业务前端加入平台网络，供平台前端按服务名转发。
services:
  kaiwu-${code}-web:
    networks:
      - default
      - kaiwu-platform
networks:
  kaiwu-platform:
    external: true
    name: \${KAIWU_PLATFORM_NETWORK:-kaiwu_default}
EOF
}

write_app_entry() {
  local code="$1"
  mkdir -p "$apps_managed_dir"
  # 变量 + Docker 内置 DNS：业务容器没起来时只有该路径 502，平台前端照常启动与重载。
  # ^~ 阻止平台的静态资源正则抢走 /apps/<code>/ 下的 js/css。
  cat >"${apps_managed_dir}/${code}.conf" <<EOF
# 由 ${KAIWU_CLI_NAME} project-up 生成，${KAIWU_CLI_NAME} project-down ${code} 删除。
location ^~ /apps/${code}/ {
    resolver 127.0.0.11 valid=10s ipv6=off;
    set \$kaiwu_app_upstream kaiwu-${code}-web:8080;
    proxy_pass http://\$kaiwu_app_upstream;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Proto \$scheme;
}

# 业务 API 只进 Gateway（ADR 0025），不直连业务后端。
location ^~ /${code}-api/ {
    resolver 127.0.0.11 valid=10s ipv6=off;
    set \$kaiwu_api_upstream gateway-service:8088;
    proxy_pass http://\$kaiwu_api_upstream;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Proto \$scheme;
}
EOF
}

# 只在入口为空时登记同源相对入口 /apps/<code>/；已有入口一律不覆盖。
register_project_entry() {
  local code="$1" result
  result="$(database_sql \
    2>/dev/null <<SQL
UPDATE sys_project SET backend_url = '/apps/${code}/', updated_at = CURRENT_TIMESTAMP
 WHERE project_code = '${code}' AND built_in = 0 AND (backend_url IS NULL OR backend_url = '');
SELECT COALESCE(MAX(backend_url), '<missing>') FROM sys_project WHERE project_code = '${code}';
SQL
  )" || result="<error>"
  case "$result" in
    "/apps/${code}/") echo "项目入口：/apps/${code}/（工作台点击「进入」即可打开）" ;;
    "<missing>") echo "提示：平台里还没有项目 ${code}；在平台创建并生成后重新执行本命令即可登记入口。" ;;
    "<error>") echo "提示：未能登记项目入口，请在「项目管理 → 编辑项目」把业务后台入口设为 /apps/${code}/。" ;;
    *) echo "项目已有入口 ${result}，未覆盖；如需本机入口，请改为 /apps/${code}/。" ;;
  esac
}

# ---------------------------------------------------------------------------
# CLI：设备授权登录与项目开通（ADR 0035）
#
# 会话只保存为 HttpOnly Refresh Cookie 的 cookie jar（工作区外 .kaiwu/cli/，0600），
# 每条命令先用它换一个 15 分钟的 Access Token，不落盘、不打印。JSON 只取平铺的字段，
# 不依赖 jq/python；响应结构变复杂时应改由 Node 版 CLI 实现同一套命令。
# ---------------------------------------------------------------------------
cli_dir="${runtime_dir}/cli"
cli_cookie_jar="${cli_dir}/cli-session"
cli_base_url="${KAIWU_URL:-http://127.0.0.1:${KAIWU_WEB_PORT:-8000}}"
cli_base_url="${cli_base_url%/}"
CLI_STATUS=""
CLI_BODY=""
CLI_TOKEN=""

# 取响应里第一个同名字段的字符串值；字段不存在时输出空串。
cli_json_string() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
    | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"(.*)"$/\1/' || true
}

# 取响应里第一个同名字段的数字值。
cli_json_number() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*[0-9]+" | head -1 | grep -oE '[0-9]+$' || true
}

# 把字符串转成 JSON 字符串字面量的内容（不含两侧引号）。
cli_json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e $'s/\t/\\\\t/g' -e $'s/\r$//' \
    | awk 'BEGIN { ORS = "" } NR > 1 { print "\\n" } { print }'
}

# 发起请求；结果写入 CLI_STATUS / CLI_BODY。$3 为请求体文件，可省略。
cli_http() {
  local method="$1" path="$2" body_file="${3:-}" output
  local args=(-sS -X "$method" -b "$cli_cookie_jar" -c "$cli_cookie_jar"
    -H 'Accept: application/json' -w $'\n%{http_code}')
  if [[ -n "$CLI_TOKEN" ]]; then
    args+=(-H "Authorization: Bearer ${CLI_TOKEN}")
  fi
  if [[ -n "$body_file" ]]; then
    args+=(-H 'Content-Type: application/json' --data-binary "@${body_file}")
  fi
  if ! output="$(curl "${args[@]}" "${cli_base_url}${path}" 2>/dev/null)"; then
    # 轮询期间平台重启或网络抖动属于正常情况，由调用方决定是否继续等待。
    if [[ "${CLI_TOLERATE_NETWORK:-false}" == "true" ]]; then
      CLI_STATUS="000"
      CLI_BODY=""
      return 0
    fi
    echo "无法连接 ${cli_base_url}；请确认 Kaiwu 已启动，或用 KAIWU_URL 指定平台地址。" >&2
    exit 1
  fi
  CLI_STATUS="${output##*$'\n'}"
  CLI_BODY="${output%$'\n'*}"
}

# 发送 JSON 请求体；先写临时文件，避免大 DDL 撑爆命令行参数。
cli_http_json() {
  local method="$1" path="$2" json="$3" body_file
  body_file="$(mktemp)"
  printf '%s' "$json" >"$body_file"
  cli_http "$method" "$path" "$body_file"
  rm -f "$body_file"
}

# 非 2xx 时打印平台返回的错误信息并退出。
cli_require_ok() {
  if [[ "$CLI_STATUS" != 2* ]]; then
    local reason
    reason="$(cli_json_string "$CLI_BODY" message)"
    echo "${1}失败（HTTP ${CLI_STATUS}）：${reason:-${CLI_BODY:0:200}}" >&2
    exit 1
  fi
}

cli_prepare_dir() {
  mkdir -p "$cli_dir"
  chmod 700 "$cli_dir"
  umask 077
  touch "$cli_cookie_jar"
  chmod 600 "$cli_cookie_jar"
}

# 用 Refresh Cookie 换取本次命令的 Access Token；会话失效时要求重新登录。
cli_authenticate() {
  require_tool curl
  if [[ ! -s "$cli_cookie_jar" ]]; then
    echo "尚未登录；请先执行：${KAIWU_CLI_NAME} login" >&2
    exit 1
  fi
  cli_prepare_dir
  CLI_TOKEN=""
  cli_http POST /api/auth/refresh
  if [[ "$CLI_STATUS" != 2* ]]; then
    : >"$cli_cookie_jar"
    echo "登录已失效（最长 7 天或已被强制下线）；请重新执行：${KAIWU_CLI_NAME} login" >&2
    exit 1
  fi
  CLI_TOKEN="$(cli_json_string "$CLI_BODY" accessToken)"
}

# 本机零点击授权：用本机启动时生成的管理员密码临时登录，自行批准这次设备授权请求，随即登出临时会话。
# 只在平台地址是本机回环地址且本机有启动密钥时可用；成功返回 0，条件不满足或失败返回 1，
# 由调用方退回浏览器确认。CLI 拿到的仍是范围收窄的 CLI 会话，不是这个临时的网页会话。
cli_local_approve() {
  local user_code="$1" host web_jar web_token password status=1 saved_jar="$cli_cookie_jar"
  host="${cli_base_url#*://}"
  host="${host%%[:/]*}"
  case "$host" in
    127.0.0.1|localhost|"[::1]") ;;
    *) echo "--local 只在平台地址是本机时可用（当前：${cli_base_url}）。" >&2; return 1 ;;
  esac
  password="$(sed -n 's/^KAIWU_BOOTSTRAP_ADMIN_PASSWORD=//p' "$runtime_env" 2>/dev/null | head -1)"
  if [[ -z "$password" ]]; then
    echo "找不到本机管理员密码（${runtime_env}）。" >&2
    return 1
  fi
  web_jar="$(mktemp)"
  chmod 600 "$web_jar"
  cli_cookie_jar="$web_jar"
  CLI_TOKEN=""
  CLI_TOLERATE_NETWORK=true cli_http_json POST /api/auth/login \
    "{\"username\":\"admin\",\"password\":\"$(cli_json_escape "$password")\"}"
  if [[ "$CLI_STATUS" == 2* ]]; then
    web_token="$(cli_json_string "$CLI_BODY" accessToken)"
    CLI_TOKEN="$web_token"
    cli_http POST "/api/auth/device/${user_code}/approve"
    if [[ "$CLI_STATUS" == 2* ]]; then
      status=0
    else
      echo "本机批准失败（HTTP ${CLI_STATUS}）。" >&2
    fi
    cli_http POST /api/auth/logout
  else
    echo "本机管理员登录失败（HTTP ${CLI_STATUS}）；密码可能已被修改。" >&2
  fi
  CLI_TOKEN=""
  cli_cookie_jar="$saved_jar"
  rm -f "$web_jar"
  return "$status"
}

cli_login() {
  local client_name="${KAIWU_CLI_CLIENT:-kaiwu-cli}" local_mode=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --client) client_name="${2:-}"; shift 2 ;;
      --local) local_mode=true; shift ;;
      *) echo "用法：${KAIWU_CLI_NAME} login [--client <客户端名称>] [--local]" >&2; exit 2 ;;
    esac
  done
  require_tool curl
  cli_prepare_dir
  : >"$cli_cookie_jar"
  CLI_TOKEN=""
  cli_http_json POST /api/auth/device/start "{\"clientName\":\"$(cli_json_escape "$client_name")\"}"
  cli_require_ok "发起授权"
  local device_code user_code expires interval deadline status
  device_code="$(cli_json_string "$CLI_BODY" deviceCode)"
  user_code="$(cli_json_string "$CLI_BODY" userCode)"
  expires="$(cli_json_number "$CLI_BODY" expiresInSeconds)"
  interval="$(cli_json_number "$CLI_BODY" intervalSeconds)"
  if [[ "$local_mode" == true ]] && cli_local_approve "$user_code"; then
    echo "已在本机批准授权码 ${user_code}（${client_name}）。"
  else
    [[ "$local_mode" == true ]] && echo "改为浏览器确认。" >&2
    echo "请在浏览器中打开下面的链接，核对授权码与客户端名称后点击「允许」："
    echo
    echo "  ${cli_base_url}/device?code=${user_code}"
    echo
    echo "授权码：${user_code}（${client_name}，$(( ${expires:-600} / 60 )) 分钟内有效）"
    echo "等待授权中……"
  fi
  deadline=$(( $(date +%s) + ${expires:-600} ))
  while (( $(date +%s) < deadline )); do
    sleep "${interval:-5}"
    CLI_TOLERATE_NETWORK=true cli_http_json POST /api/auth/device/token "{\"deviceCode\":\"${device_code}\"}"
    if [[ "$CLI_STATUS" == "000" ]]; then
      continue
    fi
    cli_require_ok "查询授权结果"
    status="$(cli_json_string "$CLI_BODY" status)"
    case "$status" in
      APPROVED)
        echo "已授权：$(cli_json_string "$CLI_BODY" username)（会话最长 7 天，可在安全运营中心强制下线）。"
        return 0
        ;;
      DENIED) : >"$cli_cookie_jar"; echo "授权被拒绝。" >&2; exit 1 ;;
      EXPIRED) : >"$cli_cookie_jar"; echo "授权码已过期，请重新执行 ${KAIWU_CLI_NAME} login。" >&2; exit 1 ;;
    esac
  done
  : >"$cli_cookie_jar"
  echo "等待超时，请重新执行 ${KAIWU_CLI_NAME} login。" >&2
  exit 1
}

cli_logout() {
  if [[ -s "$cli_cookie_jar" ]]; then
    cli_authenticate
    cli_http POST /api/auth/logout
  fi
  rm -f "$cli_cookie_jar"
  echo "已退出 CLI 会话。"
}

cli_whoami() {
  cli_authenticate
  cli_http GET /api/auth/me
  cli_require_ok "查询当前用户"
  echo "$(cli_json_string "$CLI_BODY" username)（$(cli_json_string "$CLI_BODY" displayName)） @ ${cli_base_url}"
}

# ---------------------------------------------------------------------------
# 项目内成员与角色授权（对应业务后台的「项目成员」「角色授权」页面）。
#
# 走 /api/current/projects/{id}/access-admin：权限由调用者在该项目里的 access:* 权限码判定，
# 与 CLI 会话的平台权限范围无关——能不能操作取决于你在这个项目里是不是项目管理员或被授予了这些码。
# ---------------------------------------------------------------------------
access_name_pattern='^[A-Za-z0-9._@-]{1,64}$'
access_code_pattern='^[A-Za-z0-9:_.-]{1,128}$'

# 逗号分隔的编码转成 JSON 字符串数组；每一项只允许安全字符，避免把用户输入拼进 JSON。
cli_json_array() {
  local list="$1" item out="" first=true
  local IFS=','
  for item in $list; do
    if [[ ! "$item" =~ $access_code_pattern ]]; then
      echo "编码含有不支持的字符：${item}" >&2
      exit 2
    fi
    if [[ "$first" == true ]]; then first=false; else out+=","; fi
    out+="\"${item}\""
  done
  printf '[%s]' "$out"
}

# 取响应里所有不含嵌套对象的 JSON 对象（成员、角色、权限码清单都是这种形状）。
cli_json_objects() {
  printf '%s' "$1" | grep -oE '\{[^{}]*\}' || true
}

# 取对象里字符串数组字段的值，逗号分隔输出。
cli_json_array_field() {
  printf '%s' "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\[[^]]*\]" | head -1 \
    | sed -E 's/^[^[]*\[//; s/\]$//; s/"//g; s/[[:space:]]//g' || true
}

cli_access_prepare() {
  local code="$1"
  if [[ ! "$code" =~ $project_code_pattern ]]; then
    echo "项目编码格式不对：${code}" >&2
    exit 2
  fi
  require_tool curl
  cli_authenticate
  cli_lookup_project_id "$code"
  CLI_ACCESS_BASE="/api/current/projects/${CLI_PROJECT_ID}/access-admin"
}

cli_access_usage() {
  echo "用法：${KAIWU_CLI_NAME} access members|roles|permissions <项目编码>" >&2
  echo "      ${KAIWU_CLI_NAME} access member-set <项目编码> <登录名> --roles a,b [--disabled]" >&2
  echo "      ${KAIWU_CLI_NAME} access member-remove <项目编码> <登录名>" >&2
  echo "      ${KAIWU_CLI_NAME} access role-create <项目编码> <角色编码> --name <名称> [--description <说明>]" >&2
  echo "      ${KAIWU_CLI_NAME} access role-grant <项目编码> <角色编码> --permissions p1,p2 | --clear" >&2
  exit 2
}

cli_access_members() {
  [[ $# -eq 1 ]] || cli_access_usage
  cli_access_prepare "$1"
  cli_http GET "${CLI_ACCESS_BASE}/members"
  cli_require_ok "查询成员"
  local members="$CLI_BODY" roles_body entry username display status ids role_id codes role count=0
  cli_http GET "${CLI_ACCESS_BASE}/roles"
  cli_require_ok "查询角色"
  roles_body="$CLI_BODY"
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    username="$(cli_json_string "$entry" username)"
    display="$(cli_json_string "$entry" displayName)"
    status="$(cli_json_string "$entry" status)"
    ids="$(cli_json_array_field "$entry" roleIds)"
    codes=""
    local IFS=','
    for role_id in $ids; do
      [[ -z "$role_id" ]] && continue
      role="$(cli_json_objects "$roles_body" | grep -E "\"id\"[[:space:]]*:[[:space:]]*\"${role_id}\"" | head -1 || true)"
      role="$(cli_json_string "$role" roleCode)"
      codes+="${codes:+,}${role:-$role_id}"
    done
    unset IFS
    printf '%-24s %-8s %-20s %s\n' "$username" "$status" "${display:--}" "$codes"
    count=$((count + 1))
  done <<<"$(cli_json_objects "$members")"
  echo "共 ${count} 位成员。列：登录名 状态 显示名 角色编码"
}

cli_access_roles() {
  [[ $# -eq 1 ]] || cli_access_usage
  cli_access_prepare "$1"
  cli_http GET "${CLI_ACCESS_BASE}/roles"
  cli_require_ok "查询角色"
  local entry count=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    printf '%-24s %-8s %-8s %s\n' "$(cli_json_string "$entry" roleCode)" \
      "$(cli_json_string "$entry" status)" \
      "$(printf '%s' "$entry" | grep -qE '"builtIn"[[:space:]]*:[[:space:]]*true' && echo 内置 || echo 自定义)" \
      "$(cli_json_string "$entry" roleName)"
    count=$((count + 1))
  done <<<"$(cli_json_objects "$CLI_BODY")"
  echo "共 ${count} 个角色。列：角色编码 状态 类型 名称"
}

cli_access_permissions() {
  [[ $# -eq 1 ]] || cli_access_usage
  cli_access_prepare "$1"
  cli_http GET "${CLI_ACCESS_BASE}/permissions"
  cli_require_ok "查询权限码"
  local entry count=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    printf '%-36s %-16s %s\n' "$(cli_json_string "$entry" code)" \
      "$(cli_json_string "$entry" menuName)" "$(cli_json_string "$entry" name)"
    count=$((count + 1))
  done <<<"$(cli_json_objects "$CLI_BODY")"
  echo "共 ${count} 个权限码。列：权限码 所属菜单 名称"
}

cli_access_member_set() {
  local code="${1:-}" username="${2:-}" roles="" status="ACTIVE"
  [[ $# -ge 2 ]] || cli_access_usage
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --roles) roles="${2:-}"; shift 2 ;;
      --disabled) status="DISABLED"; shift ;;
      *) cli_access_usage ;;
    esac
  done
  [[ "$username" =~ $access_name_pattern && -n "$roles" ]] || cli_access_usage
  local array
  array="$(cli_json_array "$roles")"
  cli_access_prepare "$code"
  cli_http_json PUT "${CLI_ACCESS_BASE}/members/by-username/${username}" \
    "{\"roleCodes\":${array},\"status\":\"${status}\"}"
  cli_require_ok "保存成员"
  echo "已保存成员 ${username}（${status}，角色：${roles}）。"
}

cli_access_member_remove() {
  [[ $# -eq 2 && "$2" =~ $access_name_pattern ]] || cli_access_usage
  cli_access_prepare "$1"
  cli_http DELETE "${CLI_ACCESS_BASE}/members/by-username/${2}"
  cli_require_ok "移除成员"
  echo "已移除成员 ${2}。"
}

cli_access_role_create() {
  local code="${1:-}" role_code="${2:-}" name="" description=""
  [[ $# -ge 2 ]] || cli_access_usage
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      --description) description="${2:-}"; shift 2 ;;
      *) cli_access_usage ;;
    esac
  done
  [[ "$role_code" =~ $project_code_pattern && -n "$name" ]] || cli_access_usage
  cli_access_prepare "$code"
  cli_http_json POST "${CLI_ACCESS_BASE}/roles" \
    "{\"roleCode\":\"${role_code}\",\"roleName\":\"$(cli_json_escape "$name")\",\"description\":\"$(cli_json_escape "$description")\"}"
  cli_require_ok "创建角色"
  echo "已创建角色 ${role_code}。用 ${KAIWU_CLI_NAME} access role-grant ${code} ${role_code} --permissions ... 授权。"
}

cli_access_role_grant() {
  local code="${1:-}" role_code="${2:-}" permissions="" clear=false
  [[ $# -ge 2 ]] || cli_access_usage
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --permissions) permissions="${2:-}"; shift 2 ;;
      --clear) clear=true; shift ;;
      *) cli_access_usage ;;
    esac
  done
  [[ "$role_code" =~ $project_code_pattern ]] || cli_access_usage
  if [[ "$clear" == true && -n "$permissions" ]] || [[ "$clear" == false && -z "$permissions" ]]; then
    cli_access_usage
  fi
  local array="[]"
  [[ "$clear" == true ]] || array="$(cli_json_array "$permissions")"
  cli_access_prepare "$code"
  cli_http_json PUT "${CLI_ACCESS_BASE}/roles/by-code/${role_code}/permissions" "{\"permissionCodes\":${array}}"
  cli_require_ok "角色授权"
  if [[ "$clear" == true ]]; then
    echo "已清空角色 ${role_code} 的全部授权。"
  else
    echo "已把 ${permissions} 授予角色 ${role_code}（整体替换，上级菜单自动补齐）。"
  fi
}

cli_access() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    members) cli_access_members "$@" ;;
    roles) cli_access_roles "$@" ;;
    permissions) cli_access_permissions "$@" ;;
    member-set) cli_access_member_set "$@" ;;
    member-remove) cli_access_member_remove "$@" ;;
    role-create) cli_access_role_create "$@" ;;
    role-grant) cli_access_role_grant "$@" ;;
    *) cli_access_usage ;;
  esac
}

# ---- 对象存储（ADR 0040）：只封装不含密钥的管理动作；账号的创建与改密仍在网页完成。----
storage_name_pattern='^[a-z0-9][a-z0-9_-]{0,31}$'
storage_type_pattern='^[A-Za-z0-9.+*/-]{1,127}$'

cli_storage_usage() {
  echo "用法：${KAIWU_CLI_NAME} storage accounts" >&2
  echo "      ${KAIWU_CLI_NAME} storage bindings [<项目编码>]" >&2
  echo "      ${KAIWU_CLI_NAME} storage test <账号编码>" >&2
  echo "      ${KAIWU_CLI_NAME} storage bind <项目编码> --account <账号编码> [--name <存储名>] [--max-mb <n>] [--types a/b,c/d]" >&2
  echo "      ${KAIWU_CLI_NAME} storage bind-status <绑定ID> --status ACTIVE|READ_ONLY|DISABLED" >&2
  exit 2
}

# 按账号编码取账号 ID 与名称；账号列表已脱敏，不含任何密钥。
cli_storage_lookup_account() {
  local code="$1" entry
  cli_http GET /api/storage/accounts
  cli_require_ok "查询存储账号"
  CLI_STORAGE_ACCOUNT_ID=""
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$(cli_json_string "$entry" accountCode)" == "$code" ]]; then
      CLI_STORAGE_ACCOUNT_ID="$(cli_json_string "$entry" id)"
      break
    fi
  done <<<"$(cli_json_objects "$CLI_BODY")"
  if [[ -z "$CLI_STORAGE_ACCOUNT_ID" ]]; then
    echo "平台上没有存储账号 ${code}；账号需先在网页「对象存储」页面创建。" >&2
    exit 1
  fi
}

cli_storage_accounts() {
  [[ $# -eq 0 ]] || cli_storage_usage
  cli_authenticate
  cli_http GET /api/storage/accounts
  cli_require_ok "查询存储账号"
  local entry count=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    printf '%-24s %-18s %-8s %-8s %-8s %s\n' "$(cli_json_string "$entry" accountCode)" \
      "$(cli_json_string "$entry" providerType)" \
      "$(printf '%s' "$entry" | grep -qE '"enabled"[[:space:]]*:[[:space:]]*true' && echo 启用 || echo 停用)" \
      "$(cli_json_string "$entry" lastTestStatus)" \
      "$(cli_json_number "$entry" bindingCount)" "$(cli_json_string "$entry" bucket)"
    count=$((count + 1))
  done <<<"$(cli_json_objects "$CLI_BODY")"
  echo "共 ${count} 个存储账号。列：编码 类型 状态 最近测试 绑定数 桶名"
}

cli_storage_bindings() {
  [[ $# -le 1 ]] || cli_storage_usage
  local path=/api/storage/bindings
  if [[ $# -eq 1 ]]; then
    [[ "$1" =~ $project_code_pattern ]] || { echo "项目编码格式不对：${1}" >&2; exit 2; }
    path="${path}?projectCode=${1}"
  fi
  cli_authenticate
  cli_http GET "$path"
  cli_require_ok "查询存储绑定"
  local entry count=0
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    printf '%-20s %-8s %-14s %-24s %-10s %s\n' "$(cli_json_string "$entry" id)" \
      "$(cli_json_string "$entry" status)" "$(cli_json_string "$entry" storageName)" \
      "$(cli_json_string "$entry" projectCode)" "$(cli_json_number "$entry" maxObjectBytes)" \
      "$(cli_json_string "$entry" bucket)"
    count=$((count + 1))
  done <<<"$(cli_json_objects "$CLI_BODY")"
  echo "共 ${count} 条绑定。列：绑定ID 状态 存储名 项目 大小上限(字节) 桶名"
}

cli_storage_test() {
  [[ $# -eq 1 ]] || cli_storage_usage
  cli_authenticate
  cli_storage_lookup_account "$1"
  cli_http POST "/api/storage/accounts/${CLI_STORAGE_ACCOUNT_ID}/test"
  cli_require_ok "测试存储账号"
  local message
  message="$(cli_json_string "$CLI_BODY" message)"
  if printf '%s' "$CLI_BODY" | grep -qE '"success"[[:space:]]*:[[:space:]]*true'; then
    echo "存储账号 ${1} 测试通过（$(cli_json_number "$CLI_BODY" latencyMs) ms）。"
  else
    echo "存储账号 ${1} 测试失败：${message:-未知原因}" >&2
    exit 1
  fi
}

cli_storage_bind() {
  local code="${1:-}" account="" name="default" max_mb="" types=""
  [[ $# -ge 1 ]] || cli_storage_usage
  shift
  while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || cli_storage_usage
    case "$1" in
      --account) account="${2:-}"; shift 2 ;;
      --name) name="${2:-}"; shift 2 ;;
      --max-mb) max_mb="${2:-}"; shift 2 ;;
      --types) types="${2:-}"; shift 2 ;;
      *) cli_storage_usage ;;
    esac
  done
  [[ "$code" =~ $project_code_pattern && "$account" =~ $access_name_pattern && "$name" =~ $storage_name_pattern ]] \
    || cli_storage_usage
  if [[ -n "$max_mb" && ! "$max_mb" =~ ^[0-9]{1,4}$ ]] || [[ -n "$max_mb" && "$max_mb" -lt 1 ]] \
    || [[ -n "$max_mb" && "$max_mb" -gt 5120 ]]; then
    echo "--max-mb 需要 1～5120 的整数。" >&2
    exit 2
  fi
  local array="[]" item out="" first=true
  if [[ -n "$types" ]]; then
    local IFS=','
    for item in $types; do
      if [[ ! "$item" =~ $storage_type_pattern ]]; then
        echo "MIME 类型格式不对：${item}" >&2
        exit 2
      fi
      if [[ "$first" == true ]]; then first=false; else out+=","; fi
      out+="\"${item}\""
    done
    unset IFS
    array="[${out}]"
  fi
  cli_authenticate
  cli_lookup_project_id "$code"
  cli_storage_lookup_account "$account"
  local body="{\"projectId\":\"${CLI_PROJECT_ID}\",\"storageName\":\"${name}\",\"accountId\":\"${CLI_STORAGE_ACCOUNT_ID}\",\"allowedContentTypes\":${array}"
  if [[ -n "$max_mb" ]]; then
    body+=",\"maxObjectBytes\":$((max_mb * 1048576))"
  fi
  cli_http_json POST /api/storage/bindings "${body}}"
  cli_require_ok "绑定存储"
  echo "已把项目 ${code} 的存储 ${name} 绑定到账号 ${account}（绑定 ID：$(cli_json_string "$CLI_BODY" id)）。"
}

cli_storage_bind_status() {
  local binding_id="${1:-}" status=""
  [[ $# -ge 1 ]] || cli_storage_usage
  shift
  while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || cli_storage_usage
    case "$1" in
      --status) status="${2:-}"; shift 2 ;;
      *) cli_storage_usage ;;
    esac
  done
  [[ "$binding_id" =~ ^[0-9]{1,20}$ ]] || cli_storage_usage
  case "$status" in
    ACTIVE|READ_ONLY|DISABLED) ;;
    *) cli_storage_usage ;;
  esac
  cli_authenticate
  cli_http_json PUT "/api/storage/bindings/${binding_id}/status" "{\"status\":\"${status}\"}"
  cli_require_ok "修改绑定状态"
  echo "绑定 ${binding_id} 已改为 ${status}。"
}

cli_storage() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    accounts) cli_storage_accounts "$@" ;;
    bindings) cli_storage_bindings "$@" ;;
    test) cli_storage_test "$@" ;;
    bind) cli_storage_bind "$@" ;;
    bind-status) cli_storage_bind_status "$@" ;;
    *) cli_storage_usage ;;
  esac
}

# 业务仓默认目录：与 QUICKSTART 的布局一致，放在开源入口旁边的 business/。
cli_default_business_dir() {
  local parent_name entry_dir
  parent_name="$(basename "$parent_dir")"
  entry_dir="$(dirname "$parent_dir")"
  if [[ "$parent_name" == "workspace" && -f "${entry_dir}/kaiwu-entry.env" ]]; then
    printf '%s/business' "$(dirname "$entry_dir")"
  else
    printf '%s/business' "$parent_dir"
  fi
}

cli_project_state() {
  printf '%s/projects/%s.env' "$cli_dir" "$1"
}

# 按项目编码向平台查项目 ID；结果写入 CLI_PROJECT_ID。
cli_lookup_project_id() {
  local code="$1"
  cli_http GET "/api/projects?keyword=${code}&current=1&size=50"
  cli_require_ok "查询项目"
  CLI_PROJECT_ID="$(printf '%s' "$CLI_BODY" | grep -oE "\"id\"[[:space:]]*:[[:space:]]*\"[^\"]*\"[^{}]*\"projectCode\"[[:space:]]*:[[:space:]]*\"${code}\"" \
    | head -1 | sed -E 's/^"id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || true)"
  if [[ -z "$CLI_PROJECT_ID" ]]; then
    echo "平台上没有项目 ${code}；先执行 ${KAIWU_CLI_NAME} project new。" >&2
    exit 1
  fi
}

# 按项目编码取项目 ID 与最近一次生成任务号；优先读本机记录，没有时向平台查询。
cli_resolve_generation() {
  local code="$1" state_file project_id="" task_no=""
  state_file="$(cli_project_state "$code")"
  if [[ -f "$state_file" ]]; then
    project_id="$(sed -n 's/^project_id=//p' "$state_file")"
    task_no="$(sed -n 's/^task_no=//p' "$state_file")"
  fi
  if [[ -z "$project_id" ]]; then
    cli_lookup_project_id "$code"
    project_id="$CLI_PROJECT_ID"
  fi
  if [[ -z "$task_no" ]]; then
    cli_http GET "/api/project-generations?projectId=${project_id}"
    cli_require_ok "查询生成任务"
    task_no="$(cli_json_string "$CLI_BODY" taskNo)"
    if [[ -z "$task_no" ]]; then
      echo "项目 ${code} 还没有生成任务。" >&2
      exit 1
    fi
  fi
  CLI_PROJECT_ID="$project_id"
  CLI_TASK_NO="$task_no"
}

# 打印计划里的变化条目：+ 新增、~ 更新、! 漂移（只报告）。返回值为待执行条目数。
cli_print_plan() {
  local body="$1" entries count=0 resource key action detail mark category
  entries="$(printf '%s' "$body" | grep -oE '\{"resource":"[^"]*","key":"([^"\\]|\\.)*","action":"[A-Z_]+","detail":"([^"\\]|\\.)*"(,"category":"[A-Z]+")?\}' || true)"
  if [[ -z "$entries" ]]; then
    echo "平台与清单一致，没有需要同步的内容。"
    CLI_PLAN_COUNT=0
    return 0
  fi
  while IFS= read -r entry; do
    resource="$(cli_json_string "$entry" resource)"
    key="$(printf '%s' "$entry" | sed -E 's/.*"key":"(([^"\\]|\\.)*)","action".*/\1/')"
    action="$(cli_json_string "$entry" action)"
    category="$(cli_json_string "$entry" category)"
    detail="$(printf '%s' "$entry" | sed -E 's/.*"detail":"(([^"\\]|\\.)*)"(,"category":"[A-Z]+")?\}$/\1/')"
    case "$action" in
      CREATE) mark="+"; [[ "$category" == "ACCESS" && "${CLI_WITH_ACCESS:-false}" != "true" ]] || count=$((count + 1)) ;;
      UPDATE|REENABLE) mark="~"; count=$((count + 1)) ;;
      REMOVED_AT_SOURCE) mark="-" ;;
      *) mark="!" ;;
    esac
    printf '  %s %-10s %s  %s\n' "$mark" "$resource" "$key" "$detail"
  done <<<"$entries"
  CLI_PLAN_COUNT="$count"
}

cli_project_entry() {
  if [[ $# -ne 3 || ! "$1" =~ $project_code_pattern ]]; then
    echo "用法：${KAIWU_CLI_NAME} project entry <项目编码> <入口名称> <服务根地址>" >&2
    return 1
  fi
  local code="$1" label="$2" service="$3"
  cli_authenticate
  cli_lookup_project_id "$code"
  cli_http_json PUT "/api/projects/${CLI_PROJECT_ID}/entry" \
    "{\"backendLabel\":\"$(cli_json_escape "$label")\",\"serviceUrl\":\"$(cli_json_escape "$service")\"}"
  cli_require_ok "登记项目入口"
  echo "$(cli_json_string "$CLI_BODY" backendLabel) $(cli_json_string "$CLI_BODY" backendUrl) $(cli_json_string "$CLI_BODY" serviceUrl)"
}

cli_project_sync() {
  local backend_dir="" apply="false" with_access="false" code files="" name file commit plan_hash missing names apply_access
  if [[ $# -gt 0 && "$1" != --* ]]; then
    backend_dir="$1"
    shift
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply) apply="true"; shift ;;
      --with-access) with_access="true"; shift ;;
      *) backend_dir=""; break ;;
    esac
  done
  if [[ -z "$backend_dir" || ! -d "$backend_dir" ]]; then
    echo "用法：${KAIWU_CLI_NAME} project sync <业务后端仓目录> [--apply] [--with-access]" >&2
    exit 2
  fi
  backend_dir="$(cd "$backend_dir" && pwd)"
  code="$(read_project_code "$backend_dir")"
  names="dicts.yml configs.yml menus.yml jobs.yml i18n.yml data-scopes.yml"
  # 授权（角色及授权码）属于安全决策：只有显式加 --with-access 才上传 roles.yml 并导入。
  [[ "$with_access" == "true" ]] && names="$names roles.yml"
  for name in $names; do
    file="${backend_dir}/kaiwu/${name}"
    if [[ -f "$file" ]]; then
      files="${files:+${files},}\"${name}\":\"$(cli_json_escape "$(cat "$file")")\""
    fi
  done
  if [[ -z "$files" ]]; then
    echo "${backend_dir}/kaiwu/ 下没有 dicts.yml、configs.yml、menus.yml、jobs.yml、i18n.yml、data-scopes.yml（或 --with-access 时的 roles.yml）。" >&2
    exit 1
  fi
  CLI_WITH_ACCESS="$with_access"
  apply_access="$with_access"
  commit="$(git -C "$backend_dir" rev-parse HEAD 2>/dev/null || true)"
  cli_authenticate
  cli_lookup_project_id "$code"
  cli_http_json POST "/api/projects/${CLI_PROJECT_ID}/manifest/plan" "{\"files\":{${files}},\"gitCommit\":\"${commit}\"}"
  cli_require_ok "计算同步计划"
  echo "项目 ${code} 的同步计划（+ 新增  ~ 更新  ! 平台多出，不会删除  - 源环境已删除，命令行不删除）："
  cli_print_plan "$CLI_BODY"
  missing="$(printf '%s' "$CLI_BODY" | grep -oE '"missingPermissions":\[[^]]*\]' | sed -E 's/.*\[(.*)\]/\1/; s/"//g')"
  if [[ -n "$missing" ]]; then
    echo "当前账号缺少平台权限：${missing}；补齐授权后才能执行。" >&2
    [[ "$apply" == "true" ]] && exit 1
  fi
  if [[ "$apply" != "true" ]]; then
    [[ "$CLI_PLAN_COUNT" -gt 0 ]] && echo "确认无误后执行：${KAIWU_CLI_NAME} project sync ${backend_dir} --apply$([[ "$with_access" == "true" ]] && echo " --with-access")"
    return 0
  fi
  if [[ "$CLI_PLAN_COUNT" -eq 0 ]]; then
    return 0
  fi
  plan_hash="$(cli_json_string "$CLI_BODY" planHash)"
  cli_http_json POST "/api/projects/${CLI_PROJECT_ID}/manifest/apply" "{\"files\":{${files}},\"gitCommit\":\"${commit}\",\"planHash\":\"${plan_hash}\",\"applyAccess\":${apply_access}}"
  cli_require_ok "执行同步"
  echo "已同步 ${CLI_PLAN_COUNT} 项。新增的菜单已授予项目管理员；其它角色的授权请用 --with-access 导入，或在平台「项目管理」中分配。"
  echo "源环境已删除的条目不会由命令行删除，请在平台「配置移交」页签中逐项确认。"
}

cli_project_new() {
  local code="" name="" package_name="" description=""
  if [[ $# -gt 0 && "$1" != --* ]]; then
    code="$1"
    shift
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; shift 2 ;;
      --package) package_name="${2:-}"; shift 2 ;;
      --description) description="${2:-}"; shift 2 ;;
      *) code="" ; break ;;
    esac
  done
  if [[ ! "$code" =~ $project_code_pattern || -z "$name" ]]; then
    echo "用法：${KAIWU_CLI_NAME} project new <项目编码> --name <项目名称> [--package <基础包名>] [--description <描述>]" >&2
    echo "项目编码：小写字母开头，只含小写字母、数字和连字符，2-64 位。" >&2
    exit 2
  fi
  cli_authenticate
  cli_http_json POST /api/projects "{\"projectCode\":\"${code}\",\"projectName\":\"$(cli_json_escape "$name")\",\"description\":\"$(cli_json_escape "$description")\",\"packageName\":\"$(cli_json_escape "$package_name")\"}"
  cli_require_ok "登记项目"
  local project_id task_no
  project_id="$(cli_json_string "$CLI_BODY" id)"
  cli_http_json POST /api/project-generations "{\"projectId\":\"${project_id}\",\"generationMode\":\"BASIC_SCAFFOLD\"}"
  cli_require_ok "提交生成"
  task_no="$(cli_json_string "$CLI_BODY" taskNo)"
  mkdir -p "${cli_dir}/projects"
  printf 'project_id=%s\ntask_no=%s\n' "$project_id" "$task_no" >"$(cli_project_state "$code")"
  echo "已登记项目 ${code} 并提交生成（任务 ${task_no}）。"
  echo "等待完成：${KAIWU_CLI_NAME} project status ${code} --wait"
}

cli_project_status() {
  local code="${1:-}" wait="false" deadline status
  if [[ "${2:-}" == "--wait" ]]; then
    wait="true"
  fi
  if [[ ! "$code" =~ $project_code_pattern || $# -gt 2 || ( $# -eq 2 && "$wait" != "true" ) ]]; then
    echo "用法：${KAIWU_CLI_NAME} project status <项目编码> [--wait]" >&2
    exit 2
  fi
  cli_authenticate
  cli_resolve_generation "$code"
  deadline=$(( $(date +%s) + 600 ))
  while true; do
    cli_http GET "/api/project-generations/${CLI_TASK_NO}"
    cli_require_ok "查询生成状态"
    status="$(cli_json_string "$CLI_BODY" status)"
    case "$status" in
      SUCCESS)
        echo "${code} 生成完成。取回代码：${KAIWU_CLI_NAME} project pull ${code}"
        return 0
        ;;
      FAILED)
        echo "${code} 生成失败：$(cli_json_string "$CLI_BODY" lastError)" >&2
        exit 1
        ;;
    esac
    if [[ "$wait" != "true" ]]; then
      echo "${code} 当前状态：${status}"
      return 0
    fi
    if (( $(date +%s) >= deadline )); then
      echo "等待 10 分钟仍未完成（当前 ${status}），稍后再查。" >&2
      exit 1
    fi
    sleep 3
  done
}

# 下载一个仓库的 ZIP 并展开到目标目录；ZIP 若只有一个顶层目录则去掉这一层。
cli_pull_repository() {
  local repository_type="$1" target="$2" work zip extracted entries
  work="$(mktemp -d)"
  zip="${work}/artifact.zip"
  if ! curl -sS -f -o "$zip" -H "Authorization: Bearer ${CLI_TOKEN}" \
    "${cli_base_url}/api/project-generations/${CLI_TASK_NO}/download/${repository_type}"; then
    rm -rf "$work"
    echo "下载 ${repository_type} 失败；确认生成已完成且当前账号有下载权限。" >&2
    exit 1
  fi
  mkdir -p "${work}/unzip"
  unzip -q "$zip" -d "${work}/unzip"
  extracted="${work}/unzip"
  entries="$(find "$extracted" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  if [[ "$entries" == "1" ]] && [[ -d "$(find "$extracted" -mindepth 1 -maxdepth 1)" ]]; then
    extracted="$(find "$extracted" -mindepth 1 -maxdepth 1)"
  fi
  mkdir -p "$(dirname "$target")"
  mv "$extracted" "$target"
  rm -rf "$work"
  git -C "$target" init -q
  git -C "$target" add -A
  if ! git -C "$target" commit -q -m "chore: Kaiwu 项目工厂生成的初始代码" >/dev/null 2>&1; then
    echo "提示：${target} 已初始化并暂存全部文件，但未能提交（多半是未配置 git user.name/user.email）。" >&2
  fi
}

cli_project_pull() {
  local code="" target_dir=""
  if [[ $# -gt 0 && "$1" != --* ]]; then
    code="$1"
    shift
  fi
  if [[ "${1:-}" == "--dir" ]]; then
    target_dir="${2:-}"
    shift 2 || true
  fi
  if [[ ! "$code" =~ $project_code_pattern || $# -gt 0 ]]; then
    echo "用法：${KAIWU_CLI_NAME} project pull <项目编码> [--dir <业务仓父目录>]" >&2
    exit 2
  fi
  require_tool unzip
  require_tool git
  target_dir="${target_dir:-$(cli_default_business_dir)}"
  local backend="${target_dir}/${code}-service" frontend="${target_dir}/${code}-web"
  for existing in "$backend" "$frontend"; do
    if [[ -e "$existing" ]]; then
      echo "拒绝覆盖已存在的目录：${existing}" >&2
      exit 1
    fi
  done
  cli_authenticate
  cli_resolve_generation "$code"
  cli_http GET "/api/project-generations/${CLI_TASK_NO}"
  cli_require_ok "查询生成状态"
  if [[ "$(cli_json_string "$CLI_BODY" status)" != "SUCCESS" ]]; then
    echo "${code} 还没有生成成功；先执行 ${KAIWU_CLI_NAME} project status ${code} --wait" >&2
    exit 1
  fi
  cli_pull_repository BACKEND "$backend"
  cli_pull_repository FRONTEND "$frontend"
  echo "已取回两个独立仓库："
  echo "  后端：${backend}"
  echo "  前端：${frontend}"
  echo "在本机运行并接入平台：${KAIWU_CLI_NAME} project-up ${backend} ${frontend}"
  echo "推送到你的 Git 服务前先确认远端仓库为空，不要 force push。"
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
    configure_database
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
    up_mode=auto
    case "${1:-}" in
      "") ;;
      --build) up_mode=build ;;
      --no-build) up_mode=no-build ;;
      *)
        echo "未知参数：$1" >&2
        usage
        exit 2
        ;;
    esac
    require_tool git
    require_tool docker
    require_tool openssl
    require_tool curl
    configure_database
    ensure_repositories
    create_runtime_env
    load_runtime_env
    prepare_runtime_keys
    start_platform "$up_mode"
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
    configure_database
    require_bundled_development_database
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
    echo "该操作会永久删除当前 Compose 管理的数据库、Redis 和生成制品数据卷；外部数据库保留。"
    read -r -p "输入 RESET 继续（不区分大小写）：" confirmation
    # macOS 自带 bash 3.2 不支持 ${var^^}，用 tr 统一大小写并去掉误输入的空白。
    confirmation="$(printf '%s' "$confirmation" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
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
  reload-routes)
    if [[ $# -gt 0 ]]; then
      echo "reload-routes 不接受参数。" >&2
      exit 2
    fi
    require_tool docker
    require_tool curl
    prepare_compose_control_env
    reload_gateway_routes
    echo "Gateway 已重新载入 routes.managed.d/。"
    ;;
  project-up)
    if [[ $# -lt 1 || $# -gt 2 ]]; then
      echo "用法：${KAIWU_CLI_NAME} project-up <业务后端仓目录> [业务前端仓目录]" >&2
      exit 2
    fi
    require_tool docker
    require_tool curl
    require_tool openssl
    backend_dir="$(cd "$1" 2>/dev/null && pwd)" || {
      echo "找不到业务后端仓目录：$1" >&2
      exit 1
    }
    for required_file in deploy/server/compose.yml deploy/server/gateway-route.yml; do
      if [[ ! -f "${backend_dir}/${required_file}" ]]; then
        echo "${backend_dir} 缺少 ${required_file}；请确认它是项目工厂生成的后端仓。" >&2
        exit 1
      fi
    done
    project_code="$(read_project_code "$backend_dir")"
    if [[ $# -eq 2 ]]; then
      frontend_dir="$(cd "$2" 2>/dev/null && pwd)" || {
        echo "找不到业务前端仓目录：$2" >&2
        exit 1
      }
    else
      # 生成的两个仓按约定并排放置：xxx-service 旁边就是 xxx-web。
      frontend_dir="${backend_dir%-service}-web"
    fi
    if [[ ! -f "${frontend_dir}/deploy/server/compose.yml" ]]; then
      echo "找不到 ${frontend_dir}/deploy/server/compose.yml；请把业务前端仓目录作为第二个参数传入。" >&2
      exit 1
    fi
    prepare_compose_control_env
    require_compose_platform
    # 平台与业务项目同时运行时再编译前端，内存不足的虚拟机会触发 OOM：实测 2 GiB 时连平台 MySQL
    # 都被杀掉。低于 4 GiB 直接拒绝（比构建到一半把平台拖垮更好）；4~6 GiB 与 doctor 一样只提示。
    docker_memory="$(docker info --format '{{.MemTotal}}' 2>/dev/null || printf '0')"
    if [[ "$docker_memory" =~ ^[0-9]+$ ]] && (( docker_memory > 0 && docker_memory < 6442450944 )); then
      if (( docker_memory < 4294967296 )) && [[ "${KAIWU_SKIP_MEMORY_CHECK:-}" != "1" ]]; then
        echo "Docker 可用内存少于 4 GiB，同时运行平台和业务项目会因内存不足失败，甚至拖垮平台数据库。" >&2
        echo "请先调大内存：Docker Desktop 在设置中调整；colima 执行 colima stop && colima start --memory 8。" >&2
        echo "确认要继续时可设置 KAIWU_SKIP_MEMORY_CHECK=1。" >&2
        exit 1
      fi
      echo "注意：Docker 可用内存少于 6 GiB，业务前端构建可能因内存不足失败。" >&2
      echo "      Docker Desktop 在设置中调大内存；colima 执行 colima stop && colima start --memory 8。" >&2
    fi
    secrets_file="${project_state_dir}/${project_code}.env"
    ensure_project_secrets "$secrets_file"
    # 公钥取自运行中的 System，不读取私钥；平台每次 up 都会轮换密钥，重新 up 后需再执行本命令。
    # shellcheck disable=SC2016 # 公钥变量必须在 System 容器内展开。
    context_public_key="$(compose exec -T system-service sh -c 'printf "%s\n" "$KAIWU_CONTEXT_PUBLIC_KEY"')"
    echo "[1/4] 构建并启动 ${project_code} 后端（首次构建需要几分钟）…"
    # 显式 -p：环境里的 COMPOSE_PROJECT_NAME 会压过业务 Compose 的 name:，把业务栈并进平台项目，
    # 业务的 mysql 服务就会顶替平台的 mysql 容器。-p 优先级最高，也与 project-down 的停止方式一致。
    KAIWU_CONTEXT_PUBLIC_KEY="$context_public_key" docker compose -p "kaiwu-${project_code}" \
      -f "${backend_dir}/deploy/server/compose.yml" --env-file "$secrets_file" \
      up --detach --build --wait
    echo "[2/4] 登记业务仓自带的 Gateway 显式路由…"
    mkdir -p "$routes_managed_dir"
    cp "${backend_dir}/deploy/server/gateway-route.yml" "${routes_managed_dir}/${project_code}.yml"
    reload_gateway_routes
    echo "[3/4] 构建并启动 ${project_code} 前端…"
    override_file="${project_state_dir}/${project_code}-web.override.yml"
    write_web_network_override "$project_code" "$override_file"
    if ! docker compose -p "kaiwu-${project_code}-web" \
      -f "${frontend_dir}/deploy/server/compose.yml" -f "$override_file" \
      up --detach --build --wait; then
      echo "业务前端构建或启动失败。编译中途被终止且没有报错时，多半是 Docker 内存不足；" >&2
      echo "调大内存后重新执行本命令即可，已构建的后端会直接复用。" >&2
      exit 1
    fi
    echo "[4/4] 接入平台同源入口…"
    write_app_entry "$project_code"
    reload_platform_web
    register_project_entry "$project_code"
    echo
    echo "${project_code} 已在本机运行：http://127.0.0.1:${KAIWU_WEB_PORT:-8000}/apps/${project_code}/"
    echo "从 Kaiwu 工作台进入即可自动登录；业务请求经 /${project_code}-api/** 进入 Gateway。"
    echo "平台重新执行 ${KAIWU_CLI_NAME} up 会轮换密钥，届时再执行一次本命令；停止：${KAIWU_CLI_NAME} project-down ${project_code}"
    ;;
  project-down)
    if [[ $# -ne 1 || ! "$1" =~ $project_code_pattern ]]; then
      echo "用法：${KAIWU_CLI_NAME} project-down <projectCode>" >&2
      exit 2
    fi
    require_tool docker
    require_tool curl
    project_code="$1"
    prepare_compose_control_env
    # 按 Compose 项目名停止，不需要业务仓目录；数据卷与口令保留，便于再次 project-up。
    docker compose -p "kaiwu-${project_code}-web" down
    docker compose -p "kaiwu-${project_code}" down
    rm -f "${apps_managed_dir}/${project_code}.conf" "${routes_managed_dir}/${project_code}.yml"
    if compose ps --status running --services 2>/dev/null | grep -qx system-web; then
      reload_platform_web
      reload_gateway_routes
    fi
    echo "${project_code} 已停止；业务数据卷与口令保留，再次执行 project-up 即可恢复。"
    ;;
  login)
    cli_login "$@"
    ;;
  logout)
    if [[ $# -gt 0 ]]; then
      echo "logout 不接受参数。" >&2
      exit 2
    fi
    cli_logout
    ;;
  whoami)
    if [[ $# -gt 0 ]]; then
      echo "whoami 不接受参数。" >&2
      exit 2
    fi
    cli_whoami
    ;;
  access)
    cli_access "$@"
    ;;
  storage)
    cli_storage "$@"
    ;;
  project)
    subcommand="${1:-}"
    shift || true
    case "$subcommand" in
      new) cli_project_new "$@" ;;
      status) cli_project_status "$@" ;;
      pull) cli_project_pull "$@" ;;
      entry) cli_project_entry "$@" ;;
      sync) cli_project_sync "$@" ;;
      *)
        echo "用法：${KAIWU_CLI_NAME} project new|status|pull|sync|entry ..." >&2
        exit 2
        ;;
    esac
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
