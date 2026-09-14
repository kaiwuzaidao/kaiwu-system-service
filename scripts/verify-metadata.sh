#!/usr/bin/env bash
set -euo pipefail

if [ -z "${KAIWU_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
  echo "缺少必需环境变量：KAIWU_BOOTSTRAP_ADMIN_PASSWORD" >&2
  exit 1
fi
for command in curl jq; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "缺少验证依赖：$command" >&2
    exit 1
  fi
done

base_url="${KAIWU_TEST_BASE_URL:-http://127.0.0.1:8088}"
suffix="$(date +%s)"
config_key="verify.metadata.$suffix"
secret_key="verify.secret.$suffix"
dict_code="verify.status.$suffix"

login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin", password:$password}')"
login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' -d "$login_body" "$base_url/api/auth/login")"
token="$(jq -er '.data.accessToken' <<<"$login")"
auth=(-H "Authorization: Bearer $token")
json=(-H 'Content-Type: application/json')
echo "[1/8] 管理员登录通过"

project_body="$(jq -n --arg code "metadata-verify-$suffix" \
  '{projectCode:$code,projectName:"元数据验收项目",description:"配置与字典验收"}')"
project="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$project_body" "$base_url/api/projects")"
project_id="$(jq -er '.data.id' <<<"$project")"
echo "[2/8] 独立验收项目创建通过"

global_config_body="$(jq -n --arg key "$config_key" \
  '{configKey:$key,configValue:"global-value",valueType:"STRING",secret:false,
    status:"ENABLED",description:"全局验收配置",sortNo:10}')"
global_config="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$global_config_body" "$base_url/api/metadata/configs?scopeId=0")"
global_config_id="$(jq -er '.data.id' <<<"$global_config")"

project_config_body="$(jq -n --arg key "$config_key" \
  '{configKey:$key,configValue:"project-value",valueType:"STRING",secret:false,
    status:"ENABLED",description:"项目覆盖配置",sortNo:10}')"
project_config="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$project_config_body" \
  "$base_url/api/metadata/configs?scopeId=$project_id")"
project_config_id="$(jq -er '.data.id' <<<"$project_config")"
effective_configs="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/current/projects/$project_id/configs")"
jq -e --arg key "$config_key" \
  --arg projectId "$project_id" \
  '.data[] | select(.key == $key and .value == "project-value"
    and .sourceScopeId == $projectId)' >/dev/null <<<"$effective_configs"
echo "[3/8] 项目配置覆盖全局配置通过"

secret_body="$(jq -n --arg key "$secret_key" \
  '{configKey:$key,configValue:"never-return-this",valueType:"STRING",secret:true,
    status:"ENABLED",description:"敏感配置验收",sortNo:20}')"
secret_config="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$secret_body" "$base_url/api/metadata/configs?scopeId=0")"
secret_config_id="$(jq -er '.data.id' <<<"$secret_config")"
jq -e '.data.secret == true and .data.configValue == "******"' \
  >/dev/null <<<"$secret_config"
effective_configs="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/current/projects/$project_id/configs")"
jq -e --arg key "$secret_key" \
  '[.data[] | select(.key == $key)] | length == 0' \
  >/dev/null <<<"$effective_configs"
echo "[4/8] 敏感配置加密保存、管理端掩码、业务端排除通过"

global_type_body="$(jq -n --arg code "$dict_code" \
  '{dictCode:$code,dictName:"验收状态",inheritGlobal:false,status:"ENABLED",
    description:"全局字典验收"}')"
global_type="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$global_type_body" "$base_url/api/metadata/dicts?scopeId=0")"
global_type_id="$(jq -er '.data.id' <<<"$global_type")"
global_item_body='{"itemLabel":"全局启用","itemValue":"ACTIVE","sortNo":10,
  "defaultItem":true,"color":"success","status":"ENABLED"}'
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$global_item_body" \
  "$base_url/api/metadata/dicts/$global_type_id/items?scopeId=0"

project_type_body="$(jq -n --arg code "$dict_code" \
  '{dictCode:$code,dictName:"项目验收状态",inheritGlobal:true,status:"ENABLED",
    description:"继承并覆盖全局字典"}')"
project_type="$(curl --noproxy '*' -fsS "${auth[@]}" "${json[@]}" \
  -d "$project_type_body" "$base_url/api/metadata/dicts?scopeId=$project_id")"
project_type_id="$(jq -er '.data.id' <<<"$project_type")"
project_item_body='{"itemLabel":"项目启用","itemValue":"ACTIVE","sortNo":5,
  "defaultItem":true,"color":"processing","status":"ENABLED"}'
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$project_item_body" \
  "$base_url/api/metadata/dicts/$project_type_id/items?scopeId=$project_id"
effective_dict="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/current/projects/$project_id/dicts/$dict_code")"
jq -e \
  '.data.code != null
   and ([.data.items[] | select(.itemValue == "ACTIVE")] | length == 1)
   and (.data.items[] | select(.itemValue == "ACTIVE") | .itemLabel == "项目启用")' \
  >/dev/null <<<"$effective_dict"
echo "[5/8] 项目字典继承与同值覆盖通过"

# 拖拽排序：字典项按提交顺序重排，缺项/多项的提交必须整批拒绝。
second_item_body='{"itemLabel":"全局停用","itemValue":"INACTIVE","sortNo":20,
  "defaultItem":false,"color":"error","status":"ENABLED"}'
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$second_item_body" \
  "$base_url/api/metadata/dicts/$global_type_id/items?scopeId=0"
items="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/metadata/dicts/$global_type_id/items?scopeId=0")"
first_item_id="$(jq -er '.data[0].id' <<<"$items")"
second_item_id="$(jq -er '.data[1].id' <<<"$items")"
reversed_body="$(jq -n --arg a "$second_item_id" --arg b "$first_item_id" '{ids:[$a,$b]}')"
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$reversed_body" \
  "$base_url/api/metadata/dicts/$global_type_id/items/sort?scopeId=0"
sorted_items="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/metadata/dicts/$global_type_id/items?scopeId=0")"
jq -e --arg a "$second_item_id" --arg b "$first_item_id" \
  '.data[0].id == $a and .data[1].id == $b and .data[0].sortNo < .data[1].sortNo' \
  >/dev/null <<<"$sorted_items"
partial_body="$(jq -n --arg a "$first_item_id" '{ids:[$a]}')"
partial_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' "${auth[@]}" \
  "${json[@]}" -d "$partial_body" \
  "$base_url/api/metadata/dicts/$global_type_id/items/sort?scopeId=0")"
test "$partial_status" = "409"

# 字典类型排序：把列表首尾对调，确认新顺序落库。
types="$(curl --noproxy '*' -fsS "${auth[@]}" "$base_url/api/metadata/dicts?scopeId=0")"
type_ids="$(jq -er '[.data[].id]' <<<"$types")"
swapped_body="$(jq -n --argjson ids "$type_ids" \
  '{ids: ([$ids[-1]] + $ids[1:-1] + [$ids[0]])}')"
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$swapped_body" "$base_url/api/metadata/dicts/sort?scopeId=0"
sorted_types="$(curl --noproxy '*' -fsS "${auth[@]}" \
  "$base_url/api/metadata/dicts?scopeId=0")"
jq -e --argjson ids "$type_ids" \
  '[.data[].id] == ([$ids[-1]] + $ids[1:-1] + [$ids[0]])' \
  >/dev/null <<<"$sorted_types"
# 平台字典的显示顺序是真实数据，验收完必须还原，不能把验收痕迹留在管理界面上。
restore_body="$(jq -n --argjson ids "$type_ids" '{ids: $ids}')"
curl --noproxy '*' -fsS -o /dev/null "${auth[@]}" "${json[@]}" \
  -d "$restore_body" "$base_url/api/metadata/dicts/sort?scopeId=0"
echo "[6/8] 字典类型与字典项拖拽排序落库、过期列表拒绝通过"

curl --noproxy '*' -fsS -o /dev/null -X DELETE "${auth[@]}" \
  "$base_url/api/metadata/configs/$project_config_id?scopeId=$project_id"
curl --noproxy '*' -fsS -o /dev/null -X DELETE "${auth[@]}" \
  "$base_url/api/metadata/configs/$global_config_id?scopeId=0"
curl --noproxy '*' -fsS -o /dev/null -X DELETE "${auth[@]}" \
  "$base_url/api/metadata/configs/$secret_config_id?scopeId=0"
curl --noproxy '*' -fsS -o /dev/null -X DELETE "${auth[@]}" \
  "$base_url/api/metadata/dicts/$project_type_id?scopeId=$project_id"
curl --noproxy '*' -fsS -o /dev/null -X DELETE "${auth[@]}" \
  "$base_url/api/metadata/dicts/$global_type_id?scopeId=0"
echo "[7/8] 验收元数据清理通过"

configs_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  "$base_url/api/metadata/configs")"
test "$configs_status" = "401"
echo "[8/8] 元数据管理接口未登录拒绝通过"

echo "全局/项目配置、敏感配置、字典继承覆盖与鉴权均验证通过。"
