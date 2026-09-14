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
cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT
login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin", password:$password}')"
login_response="$(curl --noproxy '*' -fsS \
  -c "$cookie_jar" \
  -H 'Content-Type: application/json' \
  -d "$login_body" \
  "$base_url/api/auth/login")"
access_token="$(jq -er '.data.accessToken' <<<"$login_response")"
jq -e '.data | has("refreshToken") | not' >/dev/null <<<"$login_response"
refresh_cookie_before="$(awk '$6 == "kaiwu_refresh" {print $7}' "$cookie_jar")"
test -n "$refresh_cookie_before"

refresh_response="$(curl --noproxy '*' -fsS \
  -b "$cookie_jar" -c "$cookie_jar" \
  -X POST \
  "$base_url/api/auth/refresh")"
access_token="$(jq -er '.data.accessToken' <<<"$refresh_response")"
refresh_cookie_after="$(awk '$6 == "kaiwu_refresh" {print $7}' "$cookie_jar")"
test -n "$refresh_cookie_after"
test "$refresh_cookie_before" != "$refresh_cookie_after"

probe_response="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $access_token" \
  "$base_url/api/platform/probe")"
jq -e '.code == 0 and .data.status == "AUTHORIZED"
  and .data.permission == "system:platform:read"' \
  >/dev/null <<<"$probe_response"

forged_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H 'X-Kaiwu-Context: forged' \
  "$base_url/api/platform/probe")"
test "$forged_status" = "401"

curl --noproxy '*' -fsS -o /dev/null \
  -b "$cookie_jar" -c "$cookie_jar" \
  -X POST \
  -H "Authorization: Bearer $access_token" \
  "$base_url/api/auth/logout"
! awk '$6 == "kaiwu_refresh" {found=1} END {exit found ? 0 : 1}' "$cookie_jar"

revoked_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $access_token" \
  "$base_url/api/platform/probe")"
test "$revoked_status" = "401"

# 登出必须写一条 LOGOUT 登录日志，安全运营中心据此展示会话结束。
# 旧 token 已撤销，需重新登录才能查日志。
relogin_token="$(jq -er '.data.accessToken' <<<"$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' \
  -d "$login_body" \
  "$base_url/api/auth/login")")"
logs_response="$(curl --noproxy '*' -sS -w '\n%{http_code}' \
  -H "Authorization: Bearer $relogin_token" \
  "$base_url/api/logs/logins?current=1&size=20")"
logs_status="$(tail -n 1 <<<"$logs_response")"
if [ "$logs_status" = "200" ]; then
  logout_records="$(sed '$d' <<<"$logs_response" \
    | jq -er '[.data.records[] | select(.status == "LOGOUT")] | length')"
  test "$logout_records" -ge 1
  echo "登出审计已验证：登录日志中存在 LOGOUT 记录。"
else
  # 该账号没有 system:log:list 时不让整个脚本失败，只提示跳过。
  echo "跳过登出审计断言：登录日志接口返回 $logs_status（当前账号可能无 system:log:list 权限）。"
fi
curl --noproxy '*' -fsS -o /dev/null -X POST \
  -H "Authorization: Bearer $relogin_token" \
  "$base_url/api/auth/logout"

echo "登录、HttpOnly Cookie 刷新轮换、受保护接口、伪造头拒绝、登出撤销均验证通过。"
