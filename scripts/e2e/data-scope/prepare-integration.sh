#!/usr/bin/env bash
# 把「当前分支（含 D5 模板）+ D1 + 成员查询分支」合成一个临时集成副本，供 run.sh 联调用。
# 集成副本只在本机使用，不提交、不推送；合并时 sql/schema.sql 的追加段会有文本冲突，联调不读它，直接取当前侧。
#
# 用法：prepare-integration.sh <目标目录> [分支...]    默认合并 feat/data-scope-d1 与 feat/data-scope-members
set -euo pipefail
dest="${1:?用法：prepare-integration.sh <目标目录> [分支...]}"
shift || true
branches=("$@")
[[ ${#branches[@]} -gt 0 ]] || branches=(feat/data-scope-d1 feat/data-scope-members)
repo="$(cd "$(dirname "$0")/../../.." && pwd)"

if [[ -e "${dest}" ]]; then
  echo "目标已存在：${dest}（删除后重试，或直接把它作为 E2E_SYSTEM_DIR）" >&2
  exit 1
fi
git -C "${repo}" worktree add --detach "${dest}" HEAD >/dev/null
cd "${dest}"
git config user.name "ds-e2e" && git config user.email "ds-e2e@localhost"
for branch in "${branches[@]}"; do
  if git merge --no-edit --no-ff "${branch}" >/dev/null 2>&1; then
    echo "已合并 ${branch}"
    continue
  fi
  conflicts="$(git diff --name-only --diff-filter=U)"
  if [[ "${conflicts}" == "sql/schema.sql" ]]; then
    git checkout --ours sql/schema.sql
    git add sql/schema.sql
    git commit --no-edit >/dev/null
    echo "已合并 ${branch}（sql/schema.sql 取当前侧）"
  else
    git merge --abort || true
    echo "合并 ${branch} 失败，冲突文件：${conflicts}" >&2
    exit 1
  fi
done
echo "集成副本就绪：${dest}"
