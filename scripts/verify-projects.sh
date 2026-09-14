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
suffix="$(date +%s)"
project_code="project-verify-$suffix"
member_username="project_member_$suffix"
member_password="$(openssl rand -base64 18 | tr -d '/+=' | head -c 16)"

admin_login_body="$(jq -n --arg password "$KAIWU_BOOTSTRAP_ADMIN_PASSWORD" \
  '{username:"admin", password:$password}')"
admin_login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' -d "$admin_login_body" "$base_url/api/auth/login")"
admin_token="$(jq -er '.data.accessToken' <<<"$admin_login")"
admin_user_id="$(jq -er '.data.user.id' <<<"$admin_login")"
echo "[1/8] 管理员登录通过"

user_body="$(jq -n --arg username "$member_username" --arg password "$member_password" \
  '{username:$username, displayName:"项目验收成员", password:$password}')"
user="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$user_body" "$base_url/api/users")"
member_id="$(jq -er '.data.id' <<<"$user")"
echo "[2/8] 验收成员创建通过"

project_body="$(jq -n --arg code "$project_code" \
  '{projectCode:$code, projectName:"项目管理验收", description:"独立项目登记验收"}')"
project="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$project_body" "$base_url/api/projects")"
project_id="$(jq -er '.data.id' <<<"$project")"
test "${#project_id}" -eq 19
echo "[3/8] 项目登记与 19 位 ID 通过"

roles="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" "$base_url/api/projects/$project_id/roles")"
admin_role_id="$(jq -er '.data[] | select(.roleCode == "project-admin") | .id' <<<"$roles")"

developer_role="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' \
  -d '{"roleCode":"developer","roleName":"开发人员","description":"验收角色"}' \
  "$base_url/api/projects/$project_id/roles")"
developer_role_id="$(jq -er '.data.id' <<<"$developer_role")"
echo "[4/8] 内置管理员角色与自定义角色通过"

root_menu="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' \
  -d '{"menuName":"订单管理","menuType":"MENU","routePath":"/orders",
       "permissionCode":"demo:dashboard:view","sortNo":10,"visible":true}' \
  "$base_url/api/projects/$project_id/menus")"
root_menu_id="$(jq -er '.data.id' <<<"$root_menu")"

child_body="$(jq -n --arg parentId "$root_menu_id" \
  '{parentId:$parentId,menuName:"查询订单",menuType:"BUTTON",
    permissionCode:"demo:order:list",sortNo:10,visible:true}')"
child_menu="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$child_body" \
  "$base_url/api/projects/$project_id/menus")"
child_menu_id="$(jq -er '.data.id' <<<"$child_menu")"

grant_body="$(jq -n --arg id "$child_menu_id" '{menuIds:[$id]}')"
granted="$(curl --noproxy '*' -fsS -X PUT \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$grant_body" \
  "$base_url/api/projects/$project_id/roles/$developer_role_id/menus")"
jq -e --arg root "$root_menu_id" --arg child "$child_menu_id" \
  '(.data.menuIds | index($root)) != null and (.data.menuIds | index($child)) != null' \
  >/dev/null <<<"$granted"
echo "[5/8] 项目菜单与角色授权通过"

member_body="$(jq -n --arg roleId "$developer_role_id" \
  '{roleIds:[$roleId],status:"ACTIVE"}')"
curl --noproxy '*' -fsS -o /dev/null -X PUT \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$member_body" \
  "$base_url/api/projects/$project_id/members/$member_id"

member_login_body="$(jq -n --arg username "$member_username" --arg password "$member_password" \
  '{username:$username,password:$password}')"
member_login="$(curl --noproxy '*' -fsS \
  -H 'Content-Type: application/json' -d "$member_login_body" "$base_url/api/auth/login")"
member_token="$(jq -er '.data.accessToken' <<<"$member_login")"
echo "[6/8] 成员加入项目并登录通过"

current_projects="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $member_token" "$base_url/api/current/projects")"
jq -e --arg id "$project_id" '.data[] | select(.id == $id)' >/dev/null <<<"$current_projects"

access="$(curl --noproxy '*' -fsS \
  -H "Authorization: Bearer $member_token" \
  "$base_url/api/current/projects/$project_id/access")"
jq -e \
  '.data.roleCodes == ["developer"]
   and (.data.permissions | index("demo:dashboard:view")) != null
   and (.data.permissions | index("demo:order:list")) != null
   and .data.menus[0].children[0].permissionCode == "demo:order:list"' \
  >/dev/null <<<"$access"
echo "[7/8] 当前用户项目、菜单与权限过滤通过"

disabled_member_body="$(jq -n --arg roleId "$developer_role_id" \
  '{roleIds:[$roleId],status:"DISABLED"}')"
curl --noproxy '*' -fsS -o /dev/null -X PUT \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d "$disabled_member_body" \
  "$base_url/api/projects/$project_id/members/$member_id"
disabled_access="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $member_token" \
  "$base_url/api/current/projects/$project_id/access")"
test "$disabled_access" = "403"

used_role_delete="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' -X DELETE \
  -H "Authorization: Bearer $admin_token" \
  "$base_url/api/projects/$project_id/roles/$developer_role_id")"
test "$used_role_delete" = "400"

creator_delete="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' -X DELETE \
  -H "Authorization: Bearer $admin_token" \
  "$base_url/api/projects/$project_id/members/$admin_user_id")"
test "$creator_delete" = "400"

builtin_role_status="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' -X PUT \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' -d '{"status":"DISABLED"}' \
  "$base_url/api/projects/$project_id/roles/$admin_role_id/status")"
test "$builtin_role_status" = "400"

invalid_permission="$(curl --noproxy '*' -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $admin_token" \
  -H 'Content-Type: application/json' \
  -d '{"menuName":"错误按钮","menuType":"BUTTON","permissionCode":"invalid",
       "sortNo":1,"visible":true}' \
  "$base_url/api/projects/$project_id/menus")"
test "$invalid_permission" = "400"
echo "[8/8] 停用隔离与边界保护通过"

echo "项目登记、创建人管理员、成员多角色、角色菜单、按人过滤、停用隔离与边界保护均验证通过。"
