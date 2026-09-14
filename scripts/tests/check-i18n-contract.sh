#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
workspace_root="$(CDPATH= cd -- "$repo_root/.." && pwd)"
source_keys="$(mktemp)"
catalog_keys="$(mktemp)"
missing_keys="$(mktemp)"
public_keys="$(mktemp)"
allowed_public="$(mktemp)"
unexpected_public="$(mktemp)"
trap 'rm -f "$source_keys" "$catalog_keys" "$missing_keys" "$public_keys" "$allowed_public" "$unexpected_public"' EXIT

# System 自身永远参与校验；Gateway 和 Starter 是独立仓库，只在同工作区检出时纳入，
# 避免单仓 CI 因为缺少 sibling 目录而失败。三个仓库共用同一份数据库 catalog，
# 任何一侧新增 messageKey 都必须同批种入资源表，否则前端只能显示裸 key。
scan_dirs="$repo_root/kaiwu-system-domain/src/main/java $repo_root/kaiwu-system-api/src/main/java"
for sibling in kaiwu-gateway-service kaiwu-system-starter; do
  if [ -d "$workspace_root/$sibling/src/main/java" ]; then
    scan_dirs="$scan_dirs $workspace_root/$sibling/src/main/java"
  else
    echo "[skip] 未检出 $sibling，跳过其 messageKey 校验" >&2
  fi
done

# shellcheck disable=SC2086
{
  rg -o --no-filename '"(?:api|gateway|starter|client)\.[A-Za-z0-9_.:-]+"' $scan_dirs | tr -d '"'
  rg -o --no-filename '\{api\.[A-Za-z0-9_.:-]+\}' $scan_dirs | tr -d '{}'
} | sort -u > "$source_keys"
rg -o --no-filename "'(?:api|gateway|starter|client)\.[A-Za-z0-9_.:-]+'" \
  "$repo_root/sql/increment" \
  | tr -d "'" | sort -u > "$catalog_keys"

comm -23 "$source_keys" "$catalog_keys" > "$missing_keys"
if [ -s "$missing_keys" ]; then
  echo "以下后端 messageKey 未进入数据库国际化资源：" >&2
  cat "$missing_keys" >&2
  exit 1
fi

# 匿名 catalog 的开放范围必须与 I18nService.PUBLIC_KEYS 一致：SQL 单方面把业务文案标成
# public_visible=1 时，接口会下发它但保存接口会拒绝同样的值，两侧口径必须同时成立。
# 以 sql/schema.sql 为准：V15 用 UPDATE 翻转标志，增量脚本本身无法直接读出最终状态。
rg -o -r '$1' \
  "^\s*\(\d+, '([A-Za-z0-9_.:-]+)',.*, '[a-z][a-z0-9_.]*', 1, \d, '(?:ENABLED|DISABLED)'," \
  "$repo_root/sql/schema.sql" | sort -u > "$public_keys"
if [ ! -s "$public_keys" ]; then
  echo "sql/schema.sql 未解析到任何 public_visible 资源，公开范围校验失效。" >&2
  exit 1
fi
# 动态定位 PUBLIC_KEYS 的定义文件，不写死类名：它曾从 I18nService 挪到
# I18nMessageService，而本脚本还指着旧路径——sed 读不存在的常量只会得到空集，
# 于是所有 public_visible 资源都被误判成越界。写死类名让重构可以悄悄改变校验含义。
public_keys_file="$(rg -l --no-messages 'PUBLIC_KEYS = Set\.of\(' \
  "$repo_root/kaiwu-system-domain/src/main/java" | head -1)"
if [ -z "$public_keys_file" ]; then
  echo "未找到 PUBLIC_KEYS 的定义，公开范围校验失效。" >&2
  exit 1
fi
sed -n '/PUBLIC_KEYS = Set.of(/,/);/p' "$public_keys_file" \
  | rg -o -r '$1' '"([A-Za-z0-9_.:-]+)"' | sort -u > "$allowed_public"

grep -v '^login\.' "$public_keys" | comm -23 - "$allowed_public" > "$unexpected_public"
if [ -s "$unexpected_public" ]; then
  echo "以下资源在 SQL 里是 public_visible=1，但不在 I18nService.PUBLIC_KEYS 的最小救援范围内：" >&2
  cat "$unexpected_public" >&2
  exit 1
fi

if rg -n 'String i18nKey|navigationI18nKey' \
  "$repo_root/kaiwu-system-api/src/main/java" \
  "$repo_root/kaiwu-system-domain/src/main/java"; then
  echo "检测到已废弃的导航 i18nKey 派生链路。" >&2
  exit 1
fi

echo "国际化契约通过：跨服务稳定错误 key 均有数据库资源，$(wc -l < "$public_keys" | tr -d ' ') 个匿名可见资源均在最小救援范围内，旧导航 key 链路已删除。"
