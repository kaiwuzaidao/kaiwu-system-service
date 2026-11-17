# shellcheck shell=bash
# 业务流程版本通过业务 Gateway 路由导入，与 System 的平台清单独立。
cli_workflow_require_ok() {
  local action="$1" type="$2"
  case "$CLI_STATUS" in
    403) echo "检查当前项目的 workflow:definition:manage 和 workflow:document:manage 两项管理权限。刚同步权限时，待 Gateway 权限缓存刷新后再试。" >&2 ;;
    404) echo "检查项目 Workflow 路由及清单导入版本。" >&2 ;;
    409)
      if jq -e '[.messageKey,.message] | index("workflow.callbackTargetMissing") != null' <<<"$CLI_BODY" >/dev/null 2>&1; then
        echo "请在本项目 Workflow 部署中登记业务回调 kaiwu.workflow.callbacks.targets[$type]，配置实际接收地址、目标服务和凭据，再运行 workflow sync。" >&2
      fi ;;
  esac
  cli_require_ok "$action $type"
}

cli_workflow_sync() (
  if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != --apply ) || ! -d "$1" ]]; then
    echo "用法：${KAIWU_CLI_NAME} workflow sync <前端仓目录> [--apply]" >&2; exit 2
  fi
  local front code folder apply=false roles permissions root dir type payload plan work file extra source
  front="$(cd "$1" && pwd -P)"
  folder="$front/kaiwu/workflows"
  [[ -d "$folder" ]] || { echo "仓库没有流程清单。"; return 0; }
  [[ "${2:-}" != --apply ]] || apply=true
  require_tool jq
  code="$(read_project_code "$front")"
  cli_access_prepare "$code"
  local CLI_WORKFLOW_PROJECT_ID="$CLI_PROJECT_ID"
  root="/$code-svc/workflow/api/v1/workflow/manifest"
  work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
  shopt -s nullglob
  local files=("$folder"/*/binding.yml) plans=()
  (( ${#files[@]} > 0 )) || { echo "没有待导入的 binding.yml。"; return 0; }
  for file in "${files[@]}"; do
    dir="$(dirname "$file")"; type="$(basename "$dir")"
    [[ "$type" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,63}$ && ! -L "$dir" && ! -L "$file" ]] || { echo "流程目录名称或文件不合法" >&2; exit 1; }
    local args=(--arg t "$type" --rawfile binding "$file")
    for extra in definition template; do
      if [[ "$extra" == definition ]]; then source="$dir/process.bpmn20.xml"; else source="$dir/template.html"; fi
      [[ ! -L "$source" ]] || { echo "流程清单不能引用符号链接" >&2; exit 1; }
      if [[ -f "$source" ]]; then args+=(--rawfile "$extra" "$source"); else args+=(--argjson "$extra" null); fi
    done
    payload="$work/$type.json"
    jq -cn "${args[@]}" '{businessType:$t,binding:$binding,definition:$definition,template:$template}|with_entries(select(.value!=null))' > "$payload"
    cli_http POST "$root/plan" "$payload"
    cli_workflow_require_ok "预检流程" "$type"
    plan="$(jq -ce '.data | select(.action and .planHash and .roles and .initiatePermission)' <<<"$CLI_BODY")"
    if [[ -z "${roles:-}" ]]; then
      cli_http GET "${CLI_ACCESS_BASE}/roles"; cli_require_ok "读取项目角色"
      roles="$(jq -c '[.data[]|select(.status=="ACTIVE" or .status=="ENABLED")|.roleCode]' <<<"$CLI_BODY")"
      cli_http GET "${CLI_ACCESS_BASE}/permissions"; cli_require_ok "读取项目权限"
      permissions="$(jq -c '[.data[].code]' <<<"$CLI_BODY")"
    fi
    jq -e --argjson roles "$roles" --argjson permissions "$permissions" '. as $p | ((.roles-$roles)|length)==0 and ($permissions|index($p.initiatePermission)) != null' <<<"$plan" >/dev/null || { echo "流程 $type 所需的审批角色或发起权限未登记；先同步平台清单。" >&2; exit 1; }
    local action hash
    action="$(jq -r .action <<<"$plan")"; hash="$(jq -r .planHash <<<"$plan")"
    echo "$type  $action"
    if [[ "$action" == DRIFT && "$apply" == true ]]; then echo "当前绑定已被手工修改，请先核对。" >&2; exit 1; fi
    if [[ "$action" == CREATE || "$action" == UPDATE ]]; then
      jq --arg hash "$hash" '.+{planHash:$hash}' "$payload" > "$payload.apply"
      plans+=("$payload.apply")
    fi
  done
  if [[ "$apply" == true && -n "${plans[0]:-}" ]]; then
    for payload in "${plans[@]}"; do
      cli_http POST "$root/apply" "$payload"; cli_workflow_require_ok "发布流程" "$(jq -r .businessType "$payload")"
      echo "已导入 $(jq -r .businessType "$payload")"
    done
  fi
)
