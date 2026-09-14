#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
system_repo="$(cd "${script_dir}/../../../.." && pwd)"
workspace_dir="$(dirname "$system_repo")"
command_name="${1:-doctor}"
shift || true

usage() {
  cat <<'EOF'
Kaiwu agent development helper

Usage:
  kaiwu-agent.sh doctor             Check tools, repositories, branches and worktrees
  kaiwu-agent.sh init               Clone missing repositories and prepare local secrets
  kaiwu-agent.sh up [--no-build]    Start the complete local platform
  kaiwu-agent.sh status             Show the local platform status
  kaiwu-agent.sh verify [scope]     Verify auto, all, starter, system, gateway or web
  kaiwu-agent.sh context            Print a compact workspace map
  kaiwu-agent.sh adapters <action>  Manage per-tool skill adapters:
                                      list            Show every tool and its current state
                                      add <tool>...   Generate the adapter file
                                      remove <tool>...Delete the adapter file
                                      check           Fail if an existing adapter drifted

This helper never resets data, pushes commits, or deploys a cluster.
EOF
}

has_tool() {
  command -v "$1" >/dev/null 2>&1
}

print_tool() {
  local tool="$1"
  if has_tool "$tool"; then
    printf 'ok      %s\n' "$tool"
  else
    printf 'missing %s\n' "$tool"
  fi
}

repositories=(
  kaiwu-system-starter
  kaiwu-system-service
  kaiwu-gateway-service
  kaiwu-system-web
)

doctor() {
  local repository repo_path java_version missing_required=0

  echo "Required tools:"
  for tool in git docker openssl curl; do
    print_tool "$tool"
    if ! has_tool "$tool"; then
      missing_required=1
    fi
  done

  echo
  echo "Optional source-build tools:"
  for tool in mvn node corepack; do
    print_tool "$tool"
  done
  if has_tool java; then
    java_version="$(java -version 2>&1 | head -n 1)"
    if [[ "$java_version" == *'version "21.'* ]]; then
      echo "ok      java 21"
    else
      echo "warning java is not JDK 21; Docker quick start still works"
    fi
  else
    echo "missing java (optional; JDK 21 is required for source builds)"
  fi

  if has_tool docker; then
    if docker compose version >/dev/null 2>&1; then
      echo "ok      docker compose"
    else
      echo "missing docker compose v2"
      missing_required=1
    fi
  fi

  echo
  echo "Repositories:"
  for repository in "${repositories[@]}"; do
    repo_path="${workspace_dir}/${repository}"
    if [[ ! -d "${repo_path}/.git" ]]; then
      printf 'missing %-28s\n' "$repository"
      continue
    fi
    printf '%-7s %-28s branch=%s changes=%s\n' \
      "ok" \
      "$repository" \
      "$(git -C "$repo_path" branch --show-current)" \
      "$(git -C "$repo_path" status --porcelain | wc -l | tr -d ' ')"
  done

  if [[ "$missing_required" -ne 0 ]]; then
    echo
    echo "安装缺少的必需工具后重试。" >&2
    return 1
  fi
}

changed_repositories() {
  local repository repo_path
  for repository in "${repositories[@]}"; do
    repo_path="${workspace_dir}/${repository}"
    if [[ -d "${repo_path}/.git" ]] &&
      [[ -n "$(git -C "$repo_path" status --porcelain)" ]]; then
      printf '%s\n' "$repository"
    fi
  done
}

verify_starter() {
  (
    cd "${workspace_dir}/kaiwu-system-starter"
    mvn -s .mvn/settings.xml verify
  )
}

install_starter() {
  (
    cd "${workspace_dir}/kaiwu-system-starter"
    mvn -s .mvn/settings.xml -DskipTests install
  )
}

verify_system() {
  install_starter
  (
    cd "$system_repo"
    mvn -s .mvn/settings.xml verify
  )
}

verify_gateway() {
  (
    cd "${workspace_dir}/kaiwu-gateway-service"
    mvn -s .mvn/settings.xml verify
  )
}

verify_web() {
  (
    cd "${workspace_dir}/kaiwu-system-web"
    corepack pnpm install --frozen-lockfile
    corepack pnpm typecheck
    corepack pnpm check:dict
    corepack pnpm build
  )
}

verify_scope() {
  local scope="$1"
  case "$scope" in
    starter|kaiwu-system-starter)
      verify_starter
      ;;
    system|kaiwu-system-service)
      verify_system
      ;;
    gateway|kaiwu-gateway-service)
      verify_gateway
      ;;
    web|kaiwu-system-web)
      verify_web
      ;;
    *)
      echo "未知验证范围：${scope}" >&2
      return 2
      ;;
  esac
}

verify() {
  local scope="${1:-auto}" repository changed
  if [[ "$scope" == "all" ]]; then
    verify_starter
    verify_system
    verify_gateway
    verify_web
    return
  fi
  if [[ "$scope" != "auto" ]]; then
    verify_scope "$scope"
    return
  fi

  changed="$(changed_repositories)"
  if [[ -z "$changed" ]]; then
    echo "四个仓库均无未提交变更；无需自动选择验证范围。"
    return
  fi

  while IFS= read -r repository; do
    verify_scope "$repository"
  done <<<"$changed"
}

context() {
  cat <<EOF
Workspace: ${workspace_dir}
Entry:     ${system_repo}
Web:       http://127.0.0.1:8000
Gateway:   http://127.0.0.1:8088

Repositories:
  kaiwu-system-service  platform control plane, Compose, Flyway and Helm
  kaiwu-gateway-service authentication, trusted context and routing
  kaiwu-system-web      management UI
  kaiwu-system-starter  business-service SDK

Read first:
  ${system_repo}/docs/OVERVIEW.md
  ${system_repo}/docs/ARCHITECTURE.md
  each repository's AGENTS.md and CLAUDE.md
EOF
}

# ---------------------------------------------------------------------------
# 每工具适配层
#
# 适配层只做一件事：把工具带到 `.agents/skills/kaiwu-development/SKILL.md`。
# 因此它必须薄到不可能漂移——由模板逐字生成，而不是靠人（或模型）照抄。
#
# 为什么是"按需生成"而不是"预先写好一堆"：一个没人用的工具，它的适配文件在根目录上
# 多占一个点目录，翻找成本天天付，收益要等到真有人换工具那天才兑现。生成一次是一秒，
# 所以正确的默认是不存在，用的时候再 add。
#
# 为什么不让 AI 首次打开项目时自行生成：工具只会自动读它自己认识的路径，那个路径不存在
# 时它什么都读不到——包括"去生成适配层"这条指令本身。能读到引导指令的工具（读
# AGENTS.md 的那批）本来就不需要适配层，真正需要的那批永远触发不了。
# ---------------------------------------------------------------------------

adapter_tools="claude codebuddy cursor comate trae lingma"
adapter_description='Initialize, run, understand, develop, test, or deploy the four-repository Kaiwu platform'

adapter_label() {
  case "$1" in
    claude) echo "Claude Code" ;;
    codebuddy) echo "CodeBuddy" ;;
    cursor) echo "Cursor" ;;
    comate) echo "Comate" ;;
    trae) echo "Trae" ;;
    lingma) echo "Lingma" ;;
    *) return 1 ;;
  esac
}

adapter_path() {
  case "$1" in
    claude) echo ".claude/skills/kaiwu-development/SKILL.md" ;;
    codebuddy) echo ".codebuddy/skills/kaiwu-development/SKILL.md" ;;
    cursor) echo ".cursor/rules/kaiwu-development.mdc" ;;
    comate) echo ".comate/rules/kaiwu-development.mdr" ;;
    trae) echo ".trae/rules/kaiwu-development.md" ;;
    lingma) echo ".lingma/rules/kaiwu-development.md" ;;
    *) return 1 ;;
  esac
}

adapter_format() {
  case "$1" in
    claude|codebuddy) echo skill ;;
    cursor|comate) echo rule-frontmatter ;;
    trae|lingma) echo rule-plain ;;
    *) return 1 ;;
  esac
}

# 正文对所有工具逐字相同；只有头部按各工具的规则格式变化。
adapter_body() {
  cat <<'EOF'
When a request concerns Kaiwu workspace setup, startup, architecture, implementation, verification, Compose,
Flyway, Nacos, Helm, or Kubernetes, first read `.agents/skills/kaiwu-development/SKILL.md` completely and follow
it as the single source of truth. Resolve its relative paths from the `kaiwu-system-service` repository root.

Do not push, deploy, reset data, delete volumes, rotate secrets, or overwrite an existing directory unless the
user explicitly authorizes that action.
EOF
}

render_adapter() {
  case "$(adapter_format "$1")" in
    skill)
      printf -- '---\nname: kaiwu-development\ndescription: %s.\n---\n\n' "$adapter_description"
      ;;
    rule-frontmatter)
      # alwaysApply: false —— 默认手动选用，避免与仓库里其它规则争抢上下文。
      printf -- '---\ndescription: %s\nglobs:\nalwaysApply: false\n---\n\n' "$adapter_description"
      ;;
    rule-plain)
      printf -- '# Kaiwu development\n\n'
      ;;
  esac
  adapter_body
}

require_known_tool() {
  if ! adapter_path "$1" >/dev/null 2>&1; then
    echo "未知工具：$1（可选：${adapter_tools}）" >&2
    return 1
  fi
}

# present（与模板逐字一致）/ drifted（存在但被改过）/ absent（未生成）
adapter_state() {
  local path="${system_repo}/$(adapter_path "$1")"
  if [[ ! -f "$path" ]]; then
    echo absent
  elif render_adapter "$1" | diff -q - "$path" >/dev/null 2>&1; then
    echo present
  else
    echo drifted
  fi
}

adapters_list() {
  printf '%-10s %-12s %s\n' TOOL STATE PATH
  local tool
  for tool in $adapter_tools; do
    printf '%-10s %-12s %s\n' "$tool" "$(adapter_state "$tool")" "$(adapter_path "$tool")"
  done
}

adapters_add() {
  [[ "$#" -gt 0 ]] || { echo "用法：kaiwu-agent.sh adapters add <tool>...（${adapter_tools}）" >&2; return 2; }
  local tool path state
  for tool in "$@"; do
    require_known_tool "$tool" || return 1
    state="$(adapter_state "$tool")"
    path="${system_repo}/$(adapter_path "$tool")"
    mkdir -p "$(dirname "$path")"
    render_adapter "$tool" >"$path"
    case "$state" in
      absent) echo "created  $(adapter_path "$tool")" ;;
      drifted) echo "restored $(adapter_path "$tool")" ;;
      *) echo "ok       $(adapter_path "$tool")" ;;
    esac
  done
}

adapters_remove() {
  [[ "$#" -gt 0 ]] || { echo "用法：kaiwu-agent.sh adapters remove <tool>...（${adapter_tools}）" >&2; return 2; }
  local tool path directory
  for tool in "$@"; do
    require_known_tool "$tool" || return 1
    path="${system_repo}/$(adapter_path "$tool")"
    if [[ ! -f "$path" ]]; then
      echo "skipped  $(adapter_path "$tool")（本来就不存在）"
      continue
    fi
    rm -f "$path"
    # 只清理因此变空的目录。`.claude/` 之类可能还放着 settings 等与本适配层无关的文件，
    # rmdir 会因非空而失败，正好把它们留住。
    directory="$(dirname "$path")"
    while [[ "$directory" != "$system_repo" ]]; do
      rmdir "$directory" 2>/dev/null || break
      directory="$(dirname "$directory")"
    done
    echo "removed  $(adapter_path "$tool")"
  done
}

# 门禁：只校验**已存在**的适配层，不要求任何工具必须存在——"按需生成"意味着
# 一个都没有也是合法状态。它挡的是另一件事：有人把转发文件改成第二份会漂移的协议。
adapters_check() {
  local tool failed=0 checked=0
  for tool in $adapter_tools; do
    case "$(adapter_state "$tool")" in
      drifted)
        echo "适配层已偏离模板：$(adapter_path "$tool")" >&2
        echo "  用 'kaiwu-agent.sh adapters add ${tool}' 重新生成；" >&2
        echo "  流程与约束属于 SKILL.md，不要复制进适配文件。" >&2
        failed=1
        ;;
      present) checked=$((checked + 1)) ;;
    esac
  done
  if [[ "$failed" -ne 0 ]]; then
    return 1
  fi
  echo "适配层检查通过：${checked} 个已生成的适配文件与模板逐字一致。"
}

adapters() {
  local action="${1:-list}"
  shift || true
  case "$action" in
    list) adapters_list ;;
    add) adapters_add "$@" ;;
    remove) adapters_remove "$@" ;;
    check|--check) adapters_check ;;
    *)
      echo "未知的 adapters 动作：${action}（可选：list add remove check）" >&2
      return 2
      ;;
  esac
}

case "$command_name" in
  doctor)
    doctor
    ;;
  init)
    "$system_repo/scripts/kaiwu.sh" init "$@"
    ;;
  up)
    "$system_repo/scripts/kaiwu.sh" up "$@"
    ;;
  status)
    "$system_repo/scripts/kaiwu.sh" status "$@"
    ;;
  verify)
    verify "$@"
    ;;
  context)
    context
    ;;
  adapters)
    adapters "$@"
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
