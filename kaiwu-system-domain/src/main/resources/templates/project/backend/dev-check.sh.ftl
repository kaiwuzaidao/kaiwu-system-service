#!/usr/bin/env bash
set -euo pipefail

missing_tools=()
for tool in mvn docker; do
  command -v "$tool" >/dev/null 2>&1 || missing_tools+=("$tool")
done
if ((${r"${#missing_tools[@]}"} > 0)); then
  printf '缺少本地开发工具：%s\n' "${r"${missing_tools[*]}"}" >&2
  exit 1
fi

java_bin="${r"${JAVA_HOME:+$JAVA_HOME/bin/}"}java"
java_version="$($java_bin -version 2>&1 | head -n 1)"
case "$java_version" in
  *'"21.'*) ;;
  *)
    printf '需要 JDK 21，当前：%s（JAVA_HOME=%s）\n' \
      "$java_version" "${r"${JAVA_HOME:-未设置}"}" >&2
    exit 1
    ;;
esac

mvn -version 2>&1 | grep -q 'Java version: 21\.' || {
  echo 'Maven 未使用 JDK 21，请检查 JAVA_HOME。' >&2
  exit 1
}
docker compose version >/dev/null

missing_env=()
for key in DB_PASSWORD KAIWU_LOCAL_DB_ROOT_PASSWORD KAIWU_CONTEXT_PUBLIC_KEY; do
  [[ -n "${r"${!key:-}"}" ]] || missing_env+=("$key")
done
if ((${r"${#missing_env[@]}"} > 0)); then
  printf '缺少本地启动环境变量：%s\n' "${r"${missing_env[*]}"}" >&2
  exit 1
fi

# 端口默认值由项目编码派生，同一台机器上跑多个 Kaiwu 生成项目才不会互撞。
# 真撞上时报错形式是 Docker 端口占用或 Spring 启动失败，都不指向真正原因，
# 所以这里提前判定并直接说明改哪个变量。
port_in_use() {
  (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
}

db_port="${r"${DB_PORT:-"}${localDbPort}}"
server_port="${r"${SERVER_PORT:-"}${localServerPort}}"

# 本项目自己的 MySQL 已经在跑时不算冲突。
own_mysql="$(docker compose -f compose.local.yml ps --status running --quiet mysql 2>/dev/null || true)"
if [[ -z "$own_mysql" ]] && port_in_use "$db_port"; then
  printf '本地 MySQL 端口 %s 已被其它进程占用；换一个端口重跑：DB_PORT=<新端口> bash scripts/dev.sh\n' \
    "$db_port" >&2
  exit 1
fi
if port_in_use "$server_port"; then
  printf '后端端口 %s 已被占用；换一个端口重跑：SERVER_PORT=<新端口> bash scripts/dev.sh\n' \
    "$server_port" >&2
  printf '注意：改了 SERVER_PORT 要同步改 Gateway 本地路由（docs/gateway-route-local.yml）。\n' >&2
  exit 1
fi

echo "本地开发环境检查通过（MySQL ${r"${db_port}"}、后端 ${r"${server_port}"}）。"
