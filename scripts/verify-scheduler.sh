#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${KAIWU_BOOTSTRAP_ADMIN_PASSWORD:-}" ]]; then
  echo "缺少必需环境变量：KAIWU_BOOTSTRAP_ADMIN_PASSWORD" >&2
  exit 1
fi
for command in curl jq docker; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "缺少验证依赖：$command" >&2
    exit 1
  fi
done

base_url="${KAIWU_TEST_BASE_URL:-http://127.0.0.1:8088}"
system_container="${KAIWU_SYSTEM_CONTAINER:-kaiwu-system-service-1}"
mysql_container="${KAIWU_MYSQL_CONTAINER:-kaiwu-mysql-1}"
suffix="$(date +%s)"
project_id=""
job_id=""
claim_dir=""

login_body="$(jq -n \
  --arg username "${KAIWU_ADMIN_USERNAME:-Admin}" \
  --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:$username,password:$password}')"
login="$(curl --noproxy '*' -fsS -H 'Content-Type: application/json' \
  -d "$login_body" "$base_url/api/auth/login")"
access_token="$(jq -er '.data.accessToken' <<<"$login")"
auth=(-H "Authorization: Bearer $access_token")
json=(-H 'Content-Type: application/json')

cleanup() {
  if [[ -n "$claim_dir" && -d "$claim_dir" ]]; then
    rm -r -- "$claim_dir"
  fi
  if [[ -n "$job_id" ]]; then
    curl --noproxy '*' -fsS -o /dev/null -X DELETE \
      "${auth[@]}" "$base_url/api/scheduler/jobs/$job_id" || true
  fi
  if [[ -n "$project_id" ]]; then
    curl --noproxy '*' -fsS -o /dev/null -X PUT \
      "${auth[@]}" "${json[@]}" -d '{"status":"ARCHIVED"}' \
      "$base_url/api/projects/$project_id/status" || true
  fi
}
trap cleanup EXIT

internal_post() {
  local path="$1"
  local body="$2"
  docker exec \
    -e SCHEDULER_TOKEN="$scheduler_token" \
    -e SCHEDULER_BODY="$body" \
    -e SCHEDULER_PATH="$path" \
    "$system_container" sh -lc '
      wget -qO- \
        --header="Authorization: Bearer $SCHEDULER_TOKEN" \
        --header="Content-Type: application/json" \
        --post-data="$SCHEDULER_BODY" \
        "http://127.0.0.1:8080$SCHEDULER_PATH"
    '
}

project_body="$(jq -n --arg code "scheduler-verify-$suffix" \
  '{projectCode:$code,projectName:"调度验收项目",description:"可归档的自动化验收项目"}')"
project="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$project_body" "$base_url/api/projects")"
project_id="$(jq -er '.data.id' <<<"$project")"
echo "[1/7] 创建隔离验收项目通过"

credential="$(curl --noproxy '*' -fsS -X POST "${auth[@]}" \
  "$base_url/api/scheduler/projects/$project_id/credential/rotate")"
scheduler_token="$(jq -er '.data.token' <<<"$credential")"
echo "[2/7] 一次性项目凭据生成通过"

sync_body='{"instanceId":"verify-a","handlers":[{"taskType":"verify.echo","taskName":"验收回显"}]}'
sync="$(internal_post '/api/internal/scheduler/sync' "$sync_body")"
jq -e '.code == 0 and (.data | length) == 0' >/dev/null <<<"$sync"
echo "[3/7] Starter Handler 上报与项目隔离同步通过"

job_body="$(jq -n --arg projectId "$project_id" \
  '{projectId:$projectId,jobName:"调度抢占验收",taskType:"verify.echo",
    cronExpression:"0 * * * * *",zoneId:"UTC",payload:"{\"source\":\"verify\"}",
    enabled:true}')"
job="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$job_body" "$base_url/api/scheduler/jobs")"
job_id="$(jq -er '.data.id' <<<"$job")"
config_version="$(jq -er '.data.configVersion' <<<"$job")"
sync="$(internal_post '/api/internal/scheduler/sync' "$sync_body")"
jq -e --arg jobId "$job_id" \
  '.code == 0 and ([.data[] | select(.id == $jobId)] | length) == 1' \
  >/dev/null <<<"$sync"
echo "[4/7] 启用任务只下发给凭据绑定项目通过"

scheduled_at="$(date -u +%Y-%m-%dT%H:%M:00Z)"
claim_a_body="$(jq -n --arg jobId "$job_id" \
  --argjson version "$config_version" --arg at "$scheduled_at" \
  '{jobId:$jobId,configVersion:$version,scheduledAt:$at,instanceId:"verify-a"}')"
claim_b_body="$(jq -n --arg jobId "$job_id" \
  --argjson version "$config_version" --arg at "$scheduled_at" \
  '{jobId:$jobId,configVersion:$version,scheduledAt:$at,instanceId:"verify-b"}')"
claim_dir="$(mktemp -d)"
internal_post '/api/internal/scheduler/claim' "$claim_a_body" \
  >"$claim_dir/a.json" &
claim_a_pid=$!
internal_post '/api/internal/scheduler/claim' "$claim_b_body" \
  >"$claim_dir/b.json" &
claim_b_pid=$!
wait "$claim_a_pid"
wait "$claim_b_pid"
claim_a="$(<"$claim_dir/a.json")"
claim_b="$(<"$claim_dir/b.json")"
rm -r -- "$claim_dir"
claim_dir=""

acquired_count="$(jq -s '[.[].data | select(.acquired == true)] | length' \
  <<<"$claim_a"$'\n'"$claim_b")"
[[ "$acquired_count" == "1" ]]
if jq -e '.data.acquired == true' >/dev/null <<<"$claim_a"; then
  winning_claim="$claim_a"
  winning_instance="verify-a"
else
  winning_claim="$claim_b"
  winning_instance="verify-b"
fi
execution_id="$(jq -er '.data.executionId' <<<"$winning_claim")"
[[ "$execution_id" =~ ^[0-9]+$ ]]

# 模拟持有者宕机且租约到期，再让两个新实例并发恢复同一个逻辑触发。
docker exec -e TARGET_EXECUTION_ID="$execution_id" "$mysql_container" sh -lc '
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" kaiwu_platform -e "
    UPDATE sys_scheduler_execution
    SET lease_until = DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 SECOND)
    WHERE id = $TARGET_EXECUTION_ID AND status = '\''RUNNING'\'';
  " >/dev/null
'
claim_c_body="$(jq -n --arg jobId "$job_id" \
  --argjson version "$config_version" --arg at "$scheduled_at" \
  '{jobId:$jobId,configVersion:$version,scheduledAt:$at,instanceId:"verify-c"}')"
claim_d_body="$(jq -n --arg jobId "$job_id" \
  --argjson version "$config_version" --arg at "$scheduled_at" \
  '{jobId:$jobId,configVersion:$version,scheduledAt:$at,instanceId:"verify-d"}')"
claim_dir="$(mktemp -d)"
internal_post '/api/internal/scheduler/claim' "$claim_c_body" \
  >"$claim_dir/c.json" &
claim_c_pid=$!
internal_post '/api/internal/scheduler/claim' "$claim_d_body" \
  >"$claim_dir/d.json" &
claim_d_pid=$!
wait "$claim_c_pid"
wait "$claim_d_pid"
claim_c="$(<"$claim_dir/c.json")"
claim_d="$(<"$claim_dir/d.json")"
rm -r -- "$claim_dir"
claim_dir=""

takeover_count="$(jq -s '[.[].data | select(.acquired == true)] | length' \
  <<<"$claim_c"$'\n'"$claim_d")"
[[ "$takeover_count" == "1" ]]
if jq -e '.data.acquired == true' >/dev/null <<<"$claim_c"; then
  winning_claim="$claim_c"
  winning_instance="verify-c"
else
  winning_claim="$claim_d"
  winning_instance="verify-d"
fi
takeover_execution_id="$(jq -er '.data.executionId' <<<"$winning_claim")"
[[ "$takeover_execution_id" == "$execution_id" ]]
echo "[5/7] 首次抢占与过期租约并发恢复均只有一个实例成功"

renew_body="$(jq -n --arg instanceId "$winning_instance" \
  '{instanceId:$instanceId}')"
renew="$(internal_post \
  "/api/internal/scheduler/executions/$execution_id/renew" "$renew_body")"
jq -e '.code == 0 and .data == true' >/dev/null <<<"$renew"
complete_body="$(jq -n --arg instanceId "$winning_instance" \
  '{instanceId:$instanceId,status:"SUCCESS",message:"verify-ok"}')"
internal_post "/api/internal/scheduler/executions/$execution_id/complete" \
  "$complete_body" >/dev/null
executions="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/scheduler/executions?projectId=$project_id&current=1&size=10")"
jq -e --arg executionId "$execution_id" --arg instanceId "$winning_instance" \
  '.data.records[] | select(.id == $executionId and .status == "SUCCESS"
    and .instanceId == $instanceId)' >/dev/null <<<"$executions"
echo "[6/7] 续租、完成回传和执行记录查询通过"

curl --noproxy '*' -fsS -o /dev/null -X DELETE \
  "${auth[@]}" "$base_url/api/scheduler/jobs/$job_id"
job_id=""
jobs="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/scheduler/jobs?projectId=$project_id&current=1&size=10")"
jq -e '.data.total == 0' >/dev/null <<<"$jobs"
jq -e --arg executionId "$execution_id" \
  '.data.records[] | select(.id == $executionId)' >/dev/null <<<"$executions"
echo "[7/7] 任务软删除且历史执行记录保留通过"

echo "项目调度同步、抢占、续租、执行回传和软删除均验证通过。"
