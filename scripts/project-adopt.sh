# shellcheck shell=bash
# 从产品前端的蓝图和清单登记项目；所有远端写入由现有设备会话和 API 鉴权。
cli_project_adopt() (
  if [[ $# -lt 1 || $# -gt 2 || ( $# -eq 2 && "$2" != --apply ) || ! -d "$1/kaiwu" ]]; then
    echo "用法：${KAIWU_CLI_NAME} project adopt <前端仓目录> [--apply]" >&2
    exit 2
  fi
  require_tool jq
  require_tool git
  local front blueprint code name identity version origin description project pid backend task task_no status deadline
  front="$(cd "$1" && pwd -P)"
  blueprint="$front/docs/kaiwu-project-blueprint.json"
  code="$(read_project_code "$front")"
  if [[ "$code" == system || -f "$front/.kaiwu-starter" || ! -f "$front/kaiwu/menus.yml" ]]; then
    echo "请指定已初始化的业务前端。" >&2; exit 2
  fi
  name="$(jq -er '.projectName // .projectCode | strings | select(length > 0 and length <= 100)' "$blueprint")"
  identity="$(jq -er 'if has("adoptionId") then .adoptionId | strings | select(test("^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$")) else "" end' "$blueprint")"
  if [[ -z "$identity" ]]; then
    # 兼容已有 Git 前端；同一仓库的 clone、换目录、切产品分支保留相同登记身份。
    local roots
    if [[ "$(git -C "$front" rev-parse --is-shallow-repository 2>/dev/null)" != false ]]; then
      echo "缺少 adoptionId 的前端需要完整 Git 历史以识别初始提交。" >&2; exit 2
    fi
    roots="$(git -C "$front" rev-list --max-parents=0 HEAD | LC_ALL=C sort)"
    [[ -n "$roots" ]] || { echo "请先提交前端基线，或在蓝图中登记 adoptionId。" >&2; exit 2; }
    identity="git-$(printf '%s\n%s\n' "$code" "$roots" | git -C "$front" hash-object --stdin)"
  fi
  version="$(jq -er '.templateVersion // "existing" | strings | select(test("^[A-Za-z0-9._-]{1,100}$"))' "$blueprint")"
  origin="$(git -C "$front" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$origin" && ! "$origin" =~ ^(https://[A-Za-z0-9.-]+(:[0-9]+)?/|ssh://git@[A-Za-z0-9.-]+(:[0-9]+)?/|git@[A-Za-z0-9.-]+:)[A-Za-z0-9._/-]+$ ]]; then
    echo "前端 origin 需要使用无凭据的 HTTPS 或 Git SSH 地址。" >&2; exit 2
  fi
  description="产品前端 $identity ($version)"
  backend="$(dirname "$front")/$code-service"
  cli_authenticate
  cli_http GET "/api/projects?keyword=$code&current=1&size=50"
  cli_require_ok "查询待纳管项目"
  project="$(jq -cer --arg code "$code" '[.data.records[] | select(.projectCode==$code)] | first // {}' <<<"$CLI_BODY")"
  pid="$(jq -r '.id // empty' <<<"$project")"
  if [[ -n "$pid" ]] && ! jq -e --arg prefix "产品前端 $identity (" '(.description // "" | startswith($prefix)) and .builtIn==false and .status=="ACTIVE"' <<<"$project" >/dev/null; then
    echo "平台已有同编码项目，登记信息与此前端不一致。" >&2; exit 1
  fi
  if [[ -e "$backend" ]]; then
    if [[ -z "$pid" ]] || ! jq -e --arg id "$pid" --arg c "$code" '.projectId==$id and .projectCode==$c and .generationMode=="ADOPT_FRONTEND"' "$backend/docs/kaiwu-project-blueprint.json" >/dev/null; then
      echo "已有后端目录与本次登记不匹配：$backend" >&2; exit 1
    fi
  fi
  echo "项目 ${code}（${name}），现有前端 ${front}，配套后端 ${backend}。"
  if [[ -z "$pid" && "${2:-}" != --apply ]]; then
    echo "将新建项目，再由平台预检并导入以下清单（含角色授权）："
    for file in menus dicts configs roles jobs i18n data-scopes; do
      [[ ! -f "$front/kaiwu/$file.yml" ]] || echo "  kaiwu/$file.yml"
    done
    echo "执行纳管请加 --apply。"; exit 0
  fi
  if [[ "${2:-}" == --apply ]]; then
    require_tool unzip
    local lock="$backend.adopt-lock"
    mkdir "$lock" || { echo "该后端目录已有纳管正在进行：$lock" >&2; exit 1; }
    echo "$$" > "$lock/pid"
    trap 'rm -f "$lock/pid"; rmdir "$lock"' EXIT
  fi
  if [[ -z "$pid" ]]; then
    cli_http_json POST /api/projects "$(jq -cn --arg c "$code" --arg n "$name" --arg d "$description" --arg r "$origin" '{projectCode:$c,projectName:$n,description:$d,repositoryUrl:(if $r=="" then null else $r end)}')"
    cli_require_ok "登记已有前端"
    pid="$(jq -er '.data.id | strings' <<<"$CLI_BODY")"
  fi
  cli_http GET "/api/project-generations?projectId=$pid"
  cli_require_ok "查询配套后端生成任务"
  task="$(jq -cer '.data | first // {}' <<<"$CLI_BODY")"
  local sync_mode=adopt
  if [[ "$task" != '{}' ]]; then
    if ! jq -e --arg id "$pid" '.generationMode=="ADOPT_FRONTEND" and .projectId==$id' <<<"$task" >/dev/null; then
      echo "项目已有其他生成任务，无法作为此产品前端继续纳管。" >&2; exit 1
    fi
    # 历史版本可能在空计划时没有写移交回执；已有生成任务同样证明首次同步已结束。
    sync_mode=normal
  fi
  if [[ "${2:-}" != --apply ]]; then
    cli_sync_manifests "$sync_mode" "$front"
    echo "执行纳管请加 --apply。"; exit 0
  fi
  cli_sync_manifests "$sync_mode" "$front" --apply
  if [[ "$task" == '{}' ]]; then
    cli_http_json POST /api/project-generations "$(jq -cn --arg id "$pid" '{projectId:$id,generationMode:"ADOPT_FRONTEND"}')"
    cli_require_ok "生成配套后端"
    task="$(jq -cer '.data' <<<"$CLI_BODY")"
  fi
  task_no="$(jq -er --arg id "$pid" 'select(.generationMode=="ADOPT_FRONTEND" and .projectId==$id) | .taskNo | strings | select(test("^PG-[a-zA-Z0-9-]+$"))' <<<"$task")"
  if [[ "$(jq -r .status <<<"$task")" == FAILED ]]; then
    cli_http_json POST "/api/project-generations/$task_no/retry" '{}'
    cli_require_ok "重试配套后端生成"
  fi
  deadline=$((SECONDS + 600))
  while true; do
    cli_http GET "/api/project-generations/$task_no"
    cli_require_ok "查询配套后端状态"
    status="$(jq -er '.data.status' <<<"$CLI_BODY")"
    case "$status" in
      SUCCESS) break ;;
      PENDING|RUNNING) ;;
      *) echo "任务 $task_no 状态为 ${status}：$(jq -r '.data.lastError // empty' <<<"$CLI_BODY")" >&2; exit 1 ;;
    esac
    ((SECONDS < deadline)) || { echo "等待超时，重新执行纳管可继续。" >&2; exit 1; }
    sleep 2
  done
  CLI_TASK_NO="$task_no"
  [[ -d "$backend" ]] || cli_pull_repository BACKEND "$backend"
  echo "已纳管 ${code}，平台项目 ID ${pid}，配套后端 ${backend}。"
)
