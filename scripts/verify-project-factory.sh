#!/usr/bin/env bash
set -euo pipefail

if [ -z "${KAIWU_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
  echo "缺少必需环境变量：KAIWU_BOOTSTRAP_ADMIN_PASSWORD" >&2
  exit 1
fi
for command in curl jq unzip; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "缺少验证依赖：$command" >&2
    exit 1
  fi
done

base_url="${KAIWU_TEST_BASE_URL:-http://127.0.0.1:8088}"
suffix="$(date +%s)"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin", password:$password}')"
login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' -d "$login_body" "$base_url/api/auth/login")"
token="$(jq -er '.data.accessToken' <<<"$login")"
auth=(-H "Authorization: Bearer $token")
json=(-H 'Content-Type: application/json')
echo "[1/7] 管理员登录通过"

project_code="factory-verify-$suffix"
project_body="$(jq -n --arg code "$project_code" \
  '{projectCode:$code,projectName:"项目工厂验收",
    description:"一次性双仓脚手架验收",
    packageName:"com.kaiwu.business.factoryverify"}')"
project="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$project_body" "$base_url/api/projects")"
project_id="$(jq -er '.data.id' <<<"$project")"
echo "[2/7] 独立业务项目与 project-admin 创建通过"

generate_body="$(jq -n --arg projectId "$project_id" \
  '{projectId:$projectId,generationMode:"BASIC_SCAFFOLD"}')"
task="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$generate_body" "$base_url/api/project-generations")"
task_no="$(jq -er '.data.taskNo' <<<"$task")"

for _ in $(seq 1 60); do
  task="$(curl --noproxy '*' -fsS "${auth[@]}" \
    "$base_url/api/project-generations/$task_no")"
  status="$(jq -er '.data.status' <<<"$task")"
  case "$status" in
    SUCCESS) break ;;
    FAILED)
      jq -r '.data.lastError' <<<"$task" >&2
      exit 1
      ;;
  esac
  sleep 1
done
test "$status" = "SUCCESS"
# templateVersion 只校验形状，不钉死具体版本号：这里原本写死 `kaiwu-project-v1`，
# 而 ProjectScaffoldGenerator.TEMPLATE_VERSION 早已升到 v3，脚本却没人改——
# 于是这道验收长期红着，红的原因还与被验收的能力无关。要验的是「产物带了模板版本戳」，
# 版本号本身升级是正常演进，不该每升一次就要改一次验收脚本。
jq -e \
  '.data.generationMode == "BASIC_SCAFFOLD"
   and (.data.templateVersion // "" | test("^kaiwu-project-v[0-9]+$"))
   and (.data.backendFiles | index("AGENTS.md")) != null
   and (.data.frontendFiles | index("AGENTS.md")) != null' \
  >/dev/null <<<"$task"
echo "[3/7] 异步双仓脚手架生成通过"

for repository_type in BACKEND FRONTEND; do
  zip_path="$temp_dir/${repository_type,,}.zip"
  output_dir="$temp_dir/${repository_type,,}"
  curl --noproxy '*' -fsS "${auth[@]}" \
    -o "$zip_path" \
    "$base_url/api/project-generations/$task_no/download/$repository_type"
  unzip -qq "$zip_path" -d "$output_dir"
  test -f "$output_dir/AGENTS.md"
  test -f "$output_dir/CLAUDE.md"
  test -f "$output_dir/.gitlab-ci.yml"
done
test -f "$temp_dir/backend/pom.xml"
test -d "$temp_dir/backend/kaiwu-$project_code-api"
test -f "$temp_dir/frontend/package.json"
test ! -d "$temp_dir/backend/admin-web"
test ! -f "$temp_dir/frontend/pom.xml"
echo "[4/7] 后端 ZIP、前端 ZIP 和独立仓库边界通过"

duplicate_status="$(curl --noproxy '*' -sS \
  -o "$temp_dir/duplicate.json" -w '%{http_code}' \
  "${auth[@]}" "${json[@]}" -d "$generate_body" \
  "$base_url/api/project-generations")"
test "$duplicate_status" = "409"
echo "[5/7] 同一项目第二次生成失败关闭"

system_project_id="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/projects" \
  | jq -er '.data.records[] | select(.projectCode == "system") | .id')"
system_body="$(jq -n --arg projectId "$system_project_id" \
  '{projectId:$projectId,generationMode:"BASIC_SCAFFOLD"}')"
system_status="$(curl --noproxy '*' -sS \
  -o "$temp_dir/system.json" -w '%{http_code}' \
  "${auth[@]}" "${json[@]}" -d "$system_body" \
  "$base_url/api/project-generations")"
test "$system_status" = "400"
echo "[6/7] 内置 system 项目生成失败关闭"

git_config="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/gitlab/config")"
jq -e '.data | has("token") | not' >/dev/null <<<"$git_config"
echo "[7/7] GitLab 配置响应不回传 Token"

echo "项目工厂一次生成、双 ZIP、分仓边界和防覆盖约束验证通过。"
