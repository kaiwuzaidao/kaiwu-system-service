<#noparse>#!/usr/bin/env sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
catalog="$root_dir/docs/kaiwu-constraints.json"
waivers="$root_dir/docs/kaiwu-constraint-waivers.json"
today="$(date -u +%F)"

jq -e '
  (.catalogVersion | type == "string" and length > 0) and
  (.constraints | type == "array" and length > 0) and
  ([.constraints[].id] | length == (unique | length)) and
  (all(.constraints[];
    (.id | type == "string" and length > 0) and
    (.level == "MUST" or .level == "WARN" or .level == "DEFAULT") and
    (.scope | type == "string" and length > 0) and
    (.rationale | type == "string" and length > 0) and
    (.enforcement | type == "string" and length > 0) and
    (.reviewAfter | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) and
    (.waivable | type == "boolean") and
    (if .level == "MUST" then (.waivable | not) else true end)))
' "$catalog" >/dev/null

jq -e --slurpfile catalog "$catalog" --arg today "$today" '
  (.waivers | type == "array") and
  (all(.waivers[];
    (.constraintId | type == "string" and length > 0) and
    (.owner | type == "string" and length > 0) and
    (.reason | type == "string" and length > 0) and
    (.expiresAt | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") and . >= $today) and
    (.constraintId as $id | any($catalog[0].constraints[];
      .id == $id and .waivable == true and .level != "MUST"))))
' "$waivers" >/dev/null

# 复核到期只报告、不阻断：日历到期本身不代表产物有问题，用红灯逼人改日期只会让人把日期
# 往后推十年；但完全没有行为的话，reviewAfter 就只是装饰。
expired="$(jq -r --arg today "$today" \
  '[.constraints[] | select(.reviewAfter < $today) | "\(.id)(\(.reviewAfter))"] | join("、")' \
  "$catalog")"
if [ -n "$expired" ]; then
  echo "[check:constraints] WARN 以下约束已过复核日期，请确认仍然成立后再顺延：$expired"
fi

echo "[check:constraints] 约束目录与 waiver 有效。"
</#noparse>
