#!/usr/bin/env sh
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)"
launcher="$repo_dir/scripts/kaiwu.sh"
native_launcher="$repo_dir/scripts/local-run.sh"

bash -n "$launcher" "$native_launcher"

for command_name in doctor repositories deploy-init local-up local-status local-logs local-down context-public-key import-project-menu reload-routes; do
  grep -Fq "$command_name" "$launcher"
done

# 只允许输出运行中 System 容器已有的 Context 公钥，不能读取或打印私钥。
grep -Fq "compose exec -T system-service" "$launcher"

for required_text in \
  'KAIWU_NACOS_SERVER_ADDR' \
  'SPRING_CONFIG_IMPORT=nacos:' \
  'SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false' \
  'SERVER_ADDRESS=127.0.0.1' \
  'KAIWU_ARTIFACT_ROOT=' \
  'process_start_marker' \
  'local-down'; do
  grep -Fq "$required_text" "$native_launcher"
done

nacos_launcher_body="$(sed -n '/^local_up()/,/^local_status()/p' "$native_launcher")"
if printf '%s\n' "$nacos_launcher_body" | grep -Fq 'dev.env'; then
  echo "Nacos 本机启动器不得读取或创建 Compose dev.env。" >&2
  exit 1
fi

# local-run.sh 同时承载混合 dev 模式；这里只约束 Nacos local_up 函数不能回退到 Docker。
if printf '%s\n' "$nacos_launcher_body" | grep -Eq '[[:space:]]docker[[:space:]]'; then
  echo "本机启动器不得调用 docker。" >&2
  exit 1
fi

if printf '%s\n' "$nacos_launcher_body" \
    | grep -Eq '[[:space:]](mysql|redis-server|redis-cli|flyway)[[:space:]]'; then
  echo "Nacos 本机启动器不得直接管理 MySQL、Redis 或 Flyway。" >&2
  exit 1
fi

echo "本机进程启动器约束检查通过。"
