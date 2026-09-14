#!/bin/sh
# 把应用侧同一个环境变量展开成 squid 的精确域名白名单，避免两处各维护一份导致漂移。
# 白名单为空则拒绝启动：宁可起不来，也不能变成开放代理。
set -eu

ALLOWLIST=/etc/squid/allowed-domains.txt

printf '%s\n' "${KAIWU_AI_PROVIDER_ALLOWED_HOSTS:-}" \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
  | grep -v '^$' > "$ALLOWLIST" || true

if [ ! -s "$ALLOWLIST" ]; then
  echo "KAIWU_AI_PROVIDER_ALLOWED_HOSTS 未设置或解析后为空，拒绝以开放代理方式启动" >&2
  exit 1
fi

echo "AI 出站白名单（$(wc -l < "$ALLOWLIST") 条）："
cat "$ALLOWLIST"

# -N 前台运行，-d 1 把启动与错误信息送到 stderr，便于 docker logs 排查。
exec squid -N -d 1 -f /etc/squid/squid.conf
