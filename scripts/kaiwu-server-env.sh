#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:-}"

if [[ -z "$target" ]]; then
  echo "用法：./scripts/kaiwu-server-env.sh <仓库外/runtime.env>" >&2
  exit 2
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "缺少必需工具：openssl" >&2
  exit 1
fi
target_dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd)" || {
  echo "目标目录不存在：$(dirname "$target")" >&2
  exit 1
}
target_path="${target_dir}/$(basename "$target")"
case "$target_path" in
  "$repo_dir"/*)
    echo "运行密钥文件必须放在 kaiwu-system-service 仓库之外。" >&2
    exit 1
    ;;
esac
if [[ -e "$target_path" ]]; then
  echo "拒绝覆盖已有运行密钥文件：$target_path" >&2
  exit 1
fi

access_private="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
access_public="$(printf '%s' "$access_private" | openssl pkey -pubout 2>/dev/null)"
context_private="$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)"
context_public="$(printf '%s' "$context_private" | openssl pkey -pubout 2>/dev/null)"

umask 077
{
  printf "KAIWU_MYSQL_ROOT_PASSWORD='%s'\n" "$(openssl rand -hex 24)"
  printf "KAIWU_MYSQL_PASSWORD='%s'\n" "$(openssl rand -hex 24)"
  printf "KAIWU_REDIS_PASSWORD='%s'\n" "$(openssl rand -hex 24)"
  printf "KAIWU_BOOTSTRAP_ADMIN_PASSWORD='%s'\n" "Kaiwu!$(openssl rand -hex 12)"
  printf "KAIWU_CONFIG_ENCRYPTION_KEY='%s'\n" "$(openssl rand -base64 32 | tr -d '\n')"
  printf "KAIWU_GATEWAY_INTERNAL_TOKEN='%s'\n" "$(openssl rand -hex 32)"
  printf "KAIWU_NOTIFICATION_DELIVERY_TOKEN='%s'\n" "$(openssl rand -hex 32)"
  printf "KAIWU_ACCESS_PRIVATE_KEY='%s'\n" "$access_private"
  printf "KAIWU_ACCESS_PUBLIC_KEY='%s'\n" "$access_public"
  printf "KAIWU_CONTEXT_PRIVATE_KEY='%s'\n" "$context_private"
  printf "KAIWU_CONTEXT_PUBLIC_KEY='%s'\n" "$context_public"
} > "$target_path"
chmod 600 "$target_path"

echo "服务器运行密钥已创建：${target_path}（权限 0600）"
echo "请纳入主机密钥备份，禁止提交 Git；升级必须复用同一文件。"
