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

# 用只读探针替代 mysql。任何额外命令或非 SELECT 语句都会失败。
mkdir "$fixture_dir/bin" "$fixture_dir/v127"
touch "$fixture_dir/v127/V127__kaiwu_baseline.sql"
cat > "$fixture_dir/bin/mysql" <<'MYSQL'
#!/bin/sh
for query do :; done
case "$query" in
  'SELECT COUNT(*) FROM information_schema.TABLES'*) echo 1 ;;
  'SELECT CONCAT('*'FROM flyway_schema_history'*) echo "$TEST_HISTORY" ;;
  *) exit 91 ;;
esac
MYSQL
chmod +x "$fixture_dir/bin/mysql"
export PATH="$fixture_dir/bin:$PATH" DB_HOST=localhost DB_PORT=3306 DB_NAME=crm DB_USER=test DB_PASSWORD=test
for item in 44:v44 90:v45-v126 127:v127; do
  if TEST_HISTORY="${item%:*}:1" "$checker" "$fixture_dir/v127" >"$output_file" 2>&1; then exit 1; fi
  grep -Fq "docs/UPGRADING.md#${item#*:}" "$output_file"
done
TEST_HISTORY=127:0 "$checker" "$fixture_dir/v127"
echo "Flyway 版本线兼容检查测试通过。"
