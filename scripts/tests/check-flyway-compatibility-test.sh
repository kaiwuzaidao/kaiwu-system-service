#!/bin/sh
set -eu

repo_dir="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
checker="${repo_dir}/scripts/check-flyway-compatibility.sh"
fixture_dir="$(mktemp -d)"
output_file="${fixture_dir}/output.log"
trap 'rm -rf "$fixture_dir"' EXIT

touch "${fixture_dir}/V1__baseline.sql"
touch "${fixture_dir}/V5__latest.sql"

if "$checker" "$fixture_dir" 28 >"$output_file" 2>&1; then
  echo "期望旧 V28 数据库被拒绝，但检查通过了。" >&2
  exit 1
fi
grep -q "数据库迁移版本 28 高于当前代码最高版本 5" "$output_file"
grep -q "先备份并重建开发数据库" "$output_file"

"$checker" "$fixture_dir" 4 >/dev/null
"$checker" "$fixture_dir" 5 >/dev/null
"$checker" "$fixture_dir" "" >/dev/null

if DB_HOST=mysql DB_PORT=3306 DB_NAME="invalid-name" DB_USER=kaiwu DB_PASSWORD=test \
  "$checker" "$fixture_dir" >"$output_file" 2>&1; then
  echo "期望非法数据库名被拒绝，但检查通过了。" >&2
  exit 1
fi
grep -q "数据库名只能包含字母、数字和下划线" "$output_file"

echo "Flyway 版本线兼容检查测试通过。"
