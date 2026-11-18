<#noparse>#!/usr/bin/env bash
#
# 本地一键校验：提交前跑一遍，结果与 CI 的 verify 门禁一致。
#
#   bash scripts/verify.sh            约束 + 权限清单 + 测试基线 + mvn verify
#   bash scripts/verify.sh --static   只跑前三项静态检查（几秒，不需要 Docker，适合改一行就跑）
#
# AI 编程工具在每次改动后、提交前都应运行它；全部通过才算完成。
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "${repo_dir}"

echo "== 约束与豁免"
sh scripts/check-constraints.sh

echo "== 权限码与菜单清单（kaiwu/menus.yml）"
bash scripts/check-permission-seed.sh

echo "== 测试基线"
bash scripts/check-test-baseline.sh --strict

if [ "${1:-}" = "--static" ]; then
  echo "静态脚本执行完成；各项跳过情况见上方输出，未运行 mvn verify。"
  if [[ -f kaiwu/frontend-manifests ]]; then
    echo "纳管项目还需从配套前端执行 pnpm verify，并在真实服务复验业务场景。"
  fi
  exit 0
fi

echo "== mvn verify"
mvn -q verify

echo "本地校验全部通过。"
</#noparse>
