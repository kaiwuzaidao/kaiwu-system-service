#!/usr/bin/env bash
set -euo pipefail

if [ -z "${KAIWU_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
  echo "缺少必需环境变量：KAIWU_BOOTSTRAP_ADMIN_PASSWORD" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "缺少验证依赖：jq" >&2
  exit 1
fi

base_url="${KAIWU_TEST_BASE_URL:-http://127.0.0.1:8088}"
username="verify_user_$(date +%s)"
initial_password="$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)"
new_password="$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)"

login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin", password:$password}')"
login_response="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' \
  -d "$login_body" \
  "$base_url/api/auth/login")"
access_token="$(jq -er '.data.accessToken' <<<"$login_response")"

create_body="$(jq -n \
  --arg username "$username" \
  --arg password "$initial_password" \
  '{username:$username, displayName:"验收用户", email:"verify@example.com", password:$password}')"
created="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $access_token" \
  -H 'Content-Type: application/json' \
  -d "$create_body" \
  "$base_url/api/users")"
user_id="$(jq -er '.data.id' <<<"$created")"
test "${#user_id}" -eq 19

target_login_body="$(jq -n \
  --arg username "$username" \
  --arg password "$initial_password" \
  '{username:$username, password:$password}')"
target_login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' \
  -d "$target_login_body" \
  "$base_url/api/auth/login")"
target_access_token="$(jq -er '.data.accessToken' <<<"$target_login")"
permission_denied_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $target_access_token" \
  "$base_url/api/users?current=1&size=10")"
test "$permission_denied_status" = "403"

updated="$(curl --noproxy '*' -fsS \
  -X PUT \
  -H "Authorization: Bearer $access_token" \
  -H 'Content-Type: application/json' \
  -d '{"displayName":"验收用户已更新","email":"updated@example.com"}' \
  "$base_url/api/users/$user_id")"
jq -e '.data.displayName == "验收用户已更新"' >/dev/null <<<"$updated"

disabled="$(curl --noproxy '*' -fsS \
  -X PUT \
  -H "Authorization: Bearer $access_token" \
  -H 'Content-Type: application/json' \
  -d '{"status":"DISABLED"}' \
  "$base_url/api/users/$user_id/status")"
jq -e '.data.status == "DISABLED"' >/dev/null <<<"$disabled"

revoked_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $target_access_token" \
  "$base_url/api/auth/me")"
test "$revoked_status" = "401"

reset_body="$(jq -n --arg password "$new_password" '{newPassword:$password}')"
curl --noproxy '*' -fsS -o /dev/null \
  -H "Authorization: Bearer $access_token" \
  -H 'Content-Type: application/json' \
  -d "$reset_body" \
  "$base_url/api/users/$user_id/reset-password"

page="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $access_token" \
  "$base_url/api/users?keyword=$username&current=1&size=10")"
jq -e --arg id "$user_id" \
  '.data.total == 1 and .data.records[0].id == $id
    and .data.records[0].status == "DISABLED"
    and (.data.records[0] | has("passwordHash") | not)' \
  >/dev/null <<<"$page"

curl --noproxy '*' -fsS -o /dev/null \
  -X POST \
  -H "Authorization: Bearer $access_token" \
  "$base_url/api/auth/logout"

echo "用户查询/创建/编辑、权限拒绝、停用撤销会话、重置密码与脱敏出参均验证通过。"
