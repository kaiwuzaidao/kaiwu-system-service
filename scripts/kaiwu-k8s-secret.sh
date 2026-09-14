#!/usr/bin/env bash
set -euo pipefail

namespace="${1:-kaiwu}"
secret_name="${2:-kaiwu-runtime}"

for tool in kubectl openssl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "缺少必需工具：${tool}" >&2
    exit 1
  fi
done

if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
  echo "Secret ${namespace}/${secret_name} 已存在，拒绝自动轮换。" >&2
  echo "升级 Kaiwu 时应复用现有 Secret；如需轮换，请先制定会话和密文迁移方案。" >&2
  exit 1
fi

temporary_dir="$(mktemp -d)"
cleanup() {
  find "$temporary_dir" -type f -delete 2>/dev/null || true
  rmdir "$temporary_dir" 2>/dev/null || true
}
trap cleanup EXIT
umask 077

mysql_root_password="$(openssl rand -hex 24)"

# 外部数据库与 Redis（database.embedded=false / redis.embedded=false）时，密码由对方
# 决定，这里必须沿用而不是新生成——生成一个新的只会让 Flyway 连不上，而报错停在
# "Access denied"，不容易看出根因是密钥与实例不一致。
#
# 用法：先读进环境变量再调用，避免密码进 shell 历史：
#   read -r -s -p 'DB password: ' KAIWU_DATABASE_PASSWORD; export KAIWU_DATABASE_PASSWORD
#   read -r -s -p 'Redis password: ' KAIWU_REDIS_PASSWORD; export KAIWU_REDIS_PASSWORD
#   ./scripts/kaiwu-k8s-secret.sh prod-kaiwu
# 不设则照旧随机生成，内置演示 MySQL/Redis 的场景不受影响。
database_password="${KAIWU_DATABASE_PASSWORD:-$(openssl rand -hex 24)}"
redis_password="${KAIWU_REDIS_PASSWORD:-$(openssl rand -hex 24)}"
bootstrap_admin_password="Kaiwu-Aa1-$(openssl rand -hex 12)"
config_encryption_key="$(openssl rand -base64 32 | tr -d '\n')"
notification_delivery_token="$(openssl rand -hex 32)"

printf '%s' "$mysql_root_password" >"${temporary_dir}/mysql-root-password"
printf '%s' "$database_password" >"${temporary_dir}/database-password"
printf '%s' "$redis_password" >"${temporary_dir}/redis-password"
printf '%s' "$bootstrap_admin_password" >"${temporary_dir}/bootstrap-admin-password"
printf '%s' "$config_encryption_key" >"${temporary_dir}/config-encryption-key"
printf '%s' "$notification_delivery_token" >"${temporary_dir}/notification-delivery-token"
# Gateway 查询项目入口授权的内部凭据（ADR 0022）。缺失时 PROJECT 路由一律 503。
printf '%s' "$(openssl rand -hex 32)" >"${temporary_dir}/gateway-internal-token"

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "${temporary_dir}/access-private-key" 2>/dev/null
openssl pkey -in "${temporary_dir}/access-private-key" -pubout \
  -out "${temporary_dir}/access-public-key" 2>/dev/null
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "${temporary_dir}/context-private-key" 2>/dev/null
openssl pkey -in "${temporary_dir}/context-private-key" -pubout \
  -out "${temporary_dir}/context-public-key" 2>/dev/null

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create secret generic "$secret_name" \
  -n "$namespace" \
  --from-file=mysql-root-password="${temporary_dir}/mysql-root-password" \
  --from-file=database-password="${temporary_dir}/database-password" \
  --from-file=redis-password="${temporary_dir}/redis-password" \
  --from-file=bootstrap-admin-password="${temporary_dir}/bootstrap-admin-password" \
  --from-file=config-encryption-key="${temporary_dir}/config-encryption-key" \
  --from-file=notification-delivery-token="${temporary_dir}/notification-delivery-token" \
  --from-file=gateway-internal-token="${temporary_dir}/gateway-internal-token" \
  --from-file=access-private-key="${temporary_dir}/access-private-key" \
  --from-file=access-public-key="${temporary_dir}/access-public-key" \
  --from-file=context-private-key="${temporary_dir}/context-private-key" \
  --from-file=context-public-key="${temporary_dir}/context-public-key" \
  >/dev/null

echo "已创建 Kubernetes Secret：${namespace}/${secret_name}"
echo "用户名：admin"
echo "初始密码：${bootstrap_admin_password}"
echo "请立即把初始密码保存到密码管理器；全新数据库首次登录后必须修改。"
