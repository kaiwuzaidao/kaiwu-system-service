#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
required_vars=(
  KAIWU_MYSQL_ROOT_PASSWORD
  KAIWU_MYSQL_PASSWORD
  KAIWU_REDIS_PASSWORD
  KAIWU_BOOTSTRAP_ADMIN_PASSWORD
  KAIWU_CONFIG_ENCRYPTION_KEY
)
missing_vars=()

for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    missing_vars+=("$var_name")
  fi
done

if [ "${#missing_vars[@]}" -gt 0 ]; then
  echo "缺少必需环境变量：${missing_vars[*]}" >&2
  exit 1
fi

export KAIWU_ACCESS_PRIVATE_KEY
export KAIWU_ACCESS_PUBLIC_KEY
export KAIWU_CONTEXT_PRIVATE_KEY
export KAIWU_CONTEXT_PUBLIC_KEY
KAIWU_ACCESS_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
KAIWU_ACCESS_PUBLIC_KEY="$(printf '%s' "$KAIWU_ACCESS_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"
KAIWU_CONTEXT_PRIVATE_KEY="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
KAIWU_CONTEXT_PUBLIC_KEY="$(printf '%s' "$KAIWU_CONTEXT_PRIVATE_KEY" | openssl pkey -pubout 2>/dev/null)"

cd "$repo_dir"
# 只有配置了 AI 出站白名单才拉起出站代理；未配置时保持默认关闭（fail-closed）。
if [[ -n "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" ]]; then
  docker compose --profile ai-egress up --build
else
  docker compose up --build
fi
