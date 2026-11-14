#!/usr/bin/env sh
set -eu

# CLI 设备授权与项目开通命令（ADR 0035）：参数校验、未登录提示、JSON 转义与令牌不外泄。
repo_dir="$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)"
launcher="$repo_dir/scripts/kaiwu.sh"

bash -n "$launcher"

# 帮助文字应显示实际调用入口，而不是未展开的变量占位符。
help_output="$(KAIWU_CLI_NAME=./kaiwu bash "$launcher" help)"
printf '%s\n' "$help_output" | grep -Fq './kaiwu project sync'
if printf '%s\n' "$help_output" | grep -Fq '${KAIWU_CLI_NAME}'; then
  echo '帮助文字泄露未展开的命令占位符。' >&2
  exit 1
fi

for required_text in \
  'cli_login' 'cli_local_approve' 'cli_logout' 'cli_whoami' 'cli_project_new' 'cli_project_status' 'cli_project_pull' 'cli_project_sync' \
  'cli_access_members' 'cli_access_roles' 'cli_access_permissions' 'cli_access_member_set' 'cli_access_member_remove' \
  'cli_access_role_create' 'cli_access_role_grant' '/access-admin' 'by-username' 'by-code' \
  'cli_storage_accounts' 'cli_storage_bindings' 'cli_storage_test' 'cli_storage_bind' 'cli_storage_bind_status' \
  '/api/storage/bindings' '/api/storage/accounts' \
  '/manifest/plan' '/manifest/apply' '--with-access' 'applyAccess' \
  '/api/auth/device/start' '/api/auth/device/token' '"generationMode\":\"BASIC_SCAFFOLD\"' \
  '拒绝覆盖已存在的目录'; do
  grep -Fq -- "$required_text" "$launcher"
done

# Access Token 只放在内存变量里用于请求头，不能被打印或写盘。
if grep -nE 'echo[^#]*CLI_TOKEN|CLI_TOKEN[^=]*>' "$launcher"; then
  echo "CLI 不得打印或落盘 Access Token。" >&2
  exit 1
fi

# 参数错误返回 2，且不发起任何网络请求。
set +e
KAIWU_URL=http://127.0.0.1:9 bash "$launcher" project new Bad_Code --name x >/dev/null 2>&1
status=$?
set -e
if [ "$status" -ne 2 ]; then
  echo "project new 参数错误应返回 2，实际 $status" >&2
  exit 1
fi

# DDL 参数已下线，必须在登记项目前拒绝旧命令。
set +e
KAIWU_URL=http://127.0.0.1:9 bash "$launcher" project new demo --name demo --ddl example.sql >/dev/null 2>&1
status=$?
set -e
if [ "$status" -ne 2 ]; then
  echo "旧 --ddl 参数应返回 2，实际 $status" >&2
  exit 1
fi

# access 子命令参数错误同样返回 2，且不发起任何网络请求。
for bad in "members" "member-set demo carol" "role-grant demo viewer" "role-grant demo viewer --permissions a --clear" "member-remove demo bad/name" "nonsense"; do
  set +e
  # shellcheck disable=SC2086 # 刻意按空格拆成多个参数
  KAIWU_URL=http://127.0.0.1:9 bash "$launcher" access $bad >/dev/null 2>&1
  status=$?
  set -e
  if [ "$status" -ne 2 ]; then
    echo "access $bad 参数错误应返回 2，实际 $status" >&2
    exit 1
  fi
done

# storage 子命令参数错误同样返回 2，且不发起任何网络请求（ADR 0040）。
for bad in "bind" "bind demo" "bind demo --account" "bind Bad_Code --account a" "bind demo --account a --max-mb 0" \
  "bind demo --account a --max-mb 9999" "bind demo --account a --types bad|type" "bind demo --account a --name Bad_Name" \
  "bind-status abc --status ACTIVE" "bind-status 1 --status FOO" "bind-status 1" "test" "accounts extra" "bindings Bad_Code" "nonsense"; do
  set +e
  # shellcheck disable=SC2086 # 刻意按空格拆成多个参数
  KAIWU_URL=http://127.0.0.1:9 bash "$launcher" storage $bad >/dev/null 2>&1
  status=$?
  set -e
  if [ "$status" -ne 2 ]; then
    echo "storage $bad 参数错误应返回 2，实际 $status" >&2
    exit 1
  fi
done

# 命令不得接触长期密钥：脚本里不能出现 accessKeySecret / secret 参数。
if grep -nE 'accessKeySecret|--secret' "$launcher"; then
  echo "CLI 不得处理存储账号密钥（ADR 0040）。" >&2
  exit 1
fi

# JSON 转义：引号、反斜杠、制表符与换行都必须转义，结果能被当作一行 JSON 字符串。
escape_body="$(sed -n '/^cli_json_escape()/,/^}/p' "$launcher")"
escaped="$(bash -c "${escape_body}
cli_json_escape \"\$1\"" _ "$(printf 'a"b\\c\td\ne')")"
expected='a\"b\\c\td\ne'
if [ "$escaped" != "$expected" ]; then
  echo "cli_json_escape 输出不符：$escaped" >&2
  exit 1
fi

# 同步计划的打印：新响应里条目带 category，授权类不计入未勾选时的待同步数，源环境已删除只提示不计数。
plan_body='{"planHash":"h","changes":[{"resource":"DICT","key":"a.b","action":"CREATE","detail":"x","category":"NORMAL"},{"resource":"ROLE","key":"fin","action":"CREATE","detail":"y","category":"ACCESS"},{"resource":"CONFIG","key":"old","action":"REMOVED_AT_SOURCE","detail":"z","category":"DELETE"}],"missingPermissions":[]}'
plan_output="$(bash -c ". <(sed -n '/^cli_json_string()/,/^}/p;/^cli_print_plan()/,/^}/p' \"$launcher\"); CLI_WITH_ACCESS=false; cli_print_plan '$plan_body'; echo COUNT=\$CLI_PLAN_COUNT")"
printf '%s' "$plan_output" | grep -Fq 'COUNT=1'
printf '%s' "$plan_output" | grep -Fq -- '- CONFIG'

echo "CLI 命令检查通过"
