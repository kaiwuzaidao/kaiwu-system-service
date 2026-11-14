#!/bin/sh
# 临时 Chart 只扩充达梦载荷，确保按方言检查，且计算 UTF-8 字节而非字符数。
set -eu
root=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/deploy/helm/kaiwu" "$tmp/chart"
# 在副本中换掉达梦 SQL，避免基线增长或缩小改变测试边界。
rm "$tmp/chart/files/migrations-dm/"*.sql
fixture="$tmp/chart/files/migrations-dm/V999__size_fixture.sql"
python3 - "$fixture" <<'FIXTURE'
from pathlib import Path
import sys

# "--"、307199 个三字节字符和行尾换行，解码后合计 921600 字节。
Path(sys.argv[1]).write_text("--" + "测" * 307199 + "\n", encoding="utf-8")
FIXTURE
check="$root/scripts/check-migration-configmap-size.py"
python3 "$check" --chart "$tmp/chart" > "$tmp/boundary"
cat "$tmp/boundary"
grep -qx 'dm: data=921600 bytes, keys=1, limit=921600 bytes' "$tmp/boundary"

# 在第一行注释中加一个 ASCII 字节，保留换行。
sed 's/^--/--x/' "$fixture" > "$tmp/oversize.sql"
mv "$tmp/oversize.sql" "$fixture"
if python3 "$check" --chart "$tmp/chart" > "$tmp/result" 2>&1; then
    echo '超限的达梦迁移 ConfigMap 被放行' >&2
    exit 1
fi
cat "$tmp/result"
grep -qx 'dm: data=921601 bytes, keys=1, limit=921600 bytes' "$tmp/result"
grep -qx 'dm: 迁移 ConfigMap 超过 900 KiB，请改用独立迁移器镜像。' "$tmp/result"
