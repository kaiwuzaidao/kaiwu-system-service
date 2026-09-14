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
login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin",password:$password}')"
login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' -d "$login_body" "$base_url/api/auth/login")"
token="$(jq -er '.data.accessToken' <<<"$login")"

projects="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $token" "$base_url/api/projects?current=1&size=100")"
system_id="$(jq -er \
  '.data.records[]
   | select(.projectCode == "system" and .builtIn == true and .status == "ACTIVE")
   | .id' <<<"$projects")"
test "$(jq -r '.data.records[0].projectCode' <<<"$projects")" = "system"
echo "[1/4] system 内置项目存在、ACTIVE 且固定排在首位"

menus="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $token" "$base_url/api/projects/$system_id/menus")"
menu_count="$(jq '[.. | objects | select(has("menuType"))] | length' <<<"$menus")"
legacy_count="$(jq \
  '[.. | objects
    | select(
        .routePath? == "/roles"
        or .routePath? == "/menus"
        or .permissionCode? == "system:user:assign-role"
        or (.permissionCode? // "" | startswith("system:role:"))
        or (.permissionCode? // "" | startswith("system:menu:"))
      )] | length' <<<"$menus")"
test "$legacy_count" = "0"
echo "[2/4] system 平台菜单无 legacy 平行管理节点"

roles="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $token" "$base_url/api/projects/$system_id/roles")"
admin_menu_count="$(jq -er \
  '.data[] | select(.roleCode == "project-admin" and .builtIn == true)
   | (.menuIds | length)' <<<"$roles")"
test "$admin_menu_count" = "$menu_count"
echo "[3/4] system 内置管理员拥有全部菜单节点"

archive_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -X PUT -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' -d '{"status":"ARCHIVED"}' \
  "$base_url/api/projects/$system_id/status")"
test "$archive_status" = "400"
echo "[4/4] system 归档被服务端拒绝"

curl --noproxy '*' -fsS -o /dev/null -X POST \
  -H "Authorization: Bearer $token" "$base_url/api/auth/logout"

echo "system 项目、菜单归属、管理员授权和不可归档保护均验证通过。"
