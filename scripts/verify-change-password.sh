#!/usr/bin/env bash
set -euo pipefail

# 验证自助修改密码：改密码生效、其它会话被下线、当前会话保留、旧密码错误返回 400。
# 脚本会把 admin 密码临时改成随机值，结束前一定改回 KAIWU_BOOTSTRAP_ADMIN_PASSWORD。

if [ -z "${KAIWU_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
  echo "缺少必需环境变量：KAIWU_BOOTSTRAP_ADMIN_PASSWORD" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "缺少验证依赖：jq" >&2
  exit 1
fi

base_url="${KAIWU_TEST_BASE_URL:-http://127.0.0.1:8088}"
original_password="$KAIWU_BOOTSTRAP_ADMIN_PASSWORD"
temp_password="Kaiwu-Verify-$(date +%s)-Tmp"
restored=0

login() {
  local password="$1"
  local body
  body="$(jq -n --arg password "$password" '{username:"admin", password:$password}')"
  curl --noproxy '*' -fsS -H 'Content-Type: application/json' \
    -d "$body" "$base_url/api/auth/login"
}

change_password() {
  local token="$1" old="$2" new="$3"
  local body
  body="$(jq -n --arg old "$old" --arg new "$new" \
    '{oldPassword:$old, newPassword:$new, confirmPassword:$new}')"
  curl --noproxy '*' -fsS -o /dev/null \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    -d "$body" "$base_url/api/auth/password"
}

me_status() {
  curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer $1" "$base_url/api/auth/me"
}

on_exit() {
  if [ "$restored" -ne 1 ]; then
    echo "" >&2
    echo "警告：脚本未走完恢复流程，admin 密码可能仍是临时值：$temp_password" >&2
    echo "请手工登录后改回，或用管理员重置。" >&2
  fi
}
trap on_exit EXIT

# 两个独立会话，模拟两台设备。
token_a="$(jq -er '.data.accessToken' <<<"$(login "$original_password")")"
token_b="$(jq -er '.data.accessToken' <<<"$(login "$original_password")")"

test "$(me_status "$token_a")" = "200"
test "$(me_status "$token_b")" = "200"

# 会话 A 发起改密码。
change_password "$token_a" "$original_password" "$temp_password"

# 当前会话必须保留，其它会话必须被下线。
test "$(me_status "$token_a")" = "200"
test "$(me_status "$token_b")" = "401"

# 新密码可登录，旧密码不可登录。
token_new="$(jq -er '.data.accessToken' <<<"$(login "$temp_password")")"
old_login_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg password "$original_password" '{username:"admin", password:$password}')" \
  "$base_url/api/auth/login")"
test "$old_login_status" = "401"

# 旧密码填错必须是 400，不能是 401：401 会让前端把用户踢去登录页。
wrong_old_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token_new" \
  -d '{"oldPassword":"definitely-wrong","newPassword":"Another-Password-1","confirmPassword":"Another-Password-1"}' \
  "$base_url/api/auth/password")"
test "$wrong_old_status" = "400"

# 两次新密码不一致同样是 400。
mismatch_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $token_new" \
  -d "$(jq -n --arg old "$temp_password" \
    '{oldPassword:$old, newPassword:"Password-One-1", confirmPassword:"Password-Two-2"}')" \
  "$base_url/api/auth/password")"
test "$mismatch_status" = "400"

# 恢复原密码。
change_password "$token_new" "$temp_password" "$original_password"
restored=1
curl --noproxy '*' -fsS -o /dev/null -X POST \
  -H "Authorization: Bearer $token_new" "$base_url/api/auth/logout"

echo "改密码生效、其它会话下线、当前会话保留、旧密码错误 400 均验证通过，密码已恢复。"
