#!/usr/bin/env bash
set -euo pipefail

# 发布 Nacos dev 配置、生成本次进程的临时签名密钥，再启动完整 Compose。
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_images=true
detach=false
for argument in "$@"; do
  case "$argument" in
    --no-build)
      build_images=false
      ;;
    --detach)
      detach=true
      ;;
    --help|-h)
      echo 'Usage: ./scripts/dev-nacos-run.sh [--no-build] [--detach]'
      exit 0
      ;;
    *)
      echo "Unknown argument: ${argument}" >&2
      exit 2
      ;;
  esac
done
required_vars=(
  KAIWU_NACOS_SERVER_URL
  KAIWU_NACOS_SERVER_ADDR
  KAIWU_NACOS_NAMESPACE
  KAIWU_NACOS_USERNAME
  KAIWU_NACOS_PASSWORD
)
missing_vars=()

for var_name in "${required_vars[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    missing_vars+=("$var_name")
  fi
done

if (( ${#missing_vars[@]} > 0 )); then
  echo "缺少必需环境变量：${missing_vars[*]}" >&2
  exit 1
fi

# 日常启动只需要 Nacos bootstrap 参数；Compose 其余运行值由受保护的 dev Data ID 提供。
# shellcheck disable=SC1090 # 受控脚本输出经 Shellwords 转义后作为当前进程环境载入。
source <("${repo_dir}/scripts/load-nacos-compose-env.sh")

if [[ -n "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" ]] \
    && [[ -z "${KAIWU_AI_PROVIDER_EGRESS_PROXY_URI:-}" ]]; then
  echo "kaiwu-compose-dev.yml 已配置 AI 白名单，但缺少 ai-provider-egress-proxy-uri。" >&2
  exit 1
fi
if [[ -z "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" ]] \
    && [[ -n "${KAIWU_AI_PROVIDER_EGRESS_PROXY_URI:-}" ]]; then
  echo "kaiwu-compose-dev.yml 已配置 AI 出站代理，但缺少 ai-provider-allowed-hosts。" >&2
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
compose_args=(-f docker-compose.yml -f docker-compose.nacos.yml)
if [[ -n "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" ]]; then
  compose_args+=(--profile ai-egress)
fi
compose_args+=(up)
if [[ "$build_images" == true ]]; then
  compose_args+=(--build)
fi
if [[ "$detach" == true ]]; then
  compose_args+=(--detach)
fi
docker compose "${compose_args[@]}"
