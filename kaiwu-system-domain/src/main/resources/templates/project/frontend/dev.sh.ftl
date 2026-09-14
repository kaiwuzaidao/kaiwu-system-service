#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

command -v node >/dev/null 2>&1 || { echo '缺少 Node.js 20+' >&2; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo '缺少 pnpm 9+' >&2; exit 1; }
node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if ((node_major < 20)); then
  echo "需要 Node.js 20+，当前：$(node --version)" >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  pnpm install --frozen-lockfile --ignore-scripts
fi
pnpm run setup
pnpm typecheck
PORT=${r"${PORT:-"}${localWebPort}} pnpm dev
