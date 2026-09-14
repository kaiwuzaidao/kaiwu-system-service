#!/usr/bin/env sh
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)"
launcher="$repo_dir/scripts/kaiwu.sh"
workspace_config="$repo_dir/kaiwu-workspace.env"

bash -n "$launcher"
test -f "$workspace_config"

output="$({
  KAIWU_REPOSITORY_BASE_URL='https://github.com/example' \
  KAIWU_REPOSITORY_REF='v1.2.3' \
    "$launcher" repositories
})"

for repository in kaiwu-system-starter kaiwu-gateway-service kaiwu-system-web kaiwu-deploy; do
  printf '%s\n' "$output" | grep -Fq "https://github.com/example/$repository.git"
done
printf '%s\n' "$output" | grep -Fq '可选部署仓库'
printf '%s\n' "$output" | grep -Fq '版本策略：固定为 v1.2.3'

if KAIWU_REPOSITORY_BASE_URL='file:///tmp/not-allowed' "$launcher" repositories \
    >/dev/null 2>&1; then
  echo "仓库来源不应接受本地 file URL。" >&2
  exit 1
fi

if "$launcher" init --with-deploy unexpected >/dev/null 2>&1; then
  echo "init 不应忽略多余参数。" >&2
  exit 1
fi

for command_name in doctor repositories deploy-init '--with-deploy'; do
  "$launcher" help | grep -Fq -- "$command_name"
done

# 默认只匹配任何组织都适用的信号；自己的组织名用 KAIWU_INTERNAL_PATTERN 追加。
# 本文件也会随开源发布，不硬编码任何组织的名字。
internal_pattern='\.internal\b|(^|[^0-9.])(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}'
if [[ -n "${KAIWU_INTERNAL_PATTERN:-}" ]]; then
  internal_pattern="${KAIWU_INTERNAL_PATTERN}|${internal_pattern}"
fi
# 文档里的占位地址（example.internal / example.com 等）是我们希望读者照抄的写法，
# 不能被当成泄露——第一版守卫就是在这里误伤了 README 的 nacos.example.internal。
hits=$(grep -nE "$internal_pattern" \
    "$repo_dir/README.md" "$repo_dir/docs/QUICKSTART.md" "$workspace_config" \
    | grep -vE 'example\.(internal|com|org|net|invalid)|\.example\.' || true)
if [[ -n "$hits" ]]; then
  printf '%s\n' "$hits" >&2
  echo "开源首次使用入口中不得出现组织内地址。" >&2
  exit 1
fi

echo "开源工作区初始化契约检查通过。"
