#!/usr/bin/env sh
set -eu

repo_dir="$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)"
launcher="$repo_dir/scripts/kaiwu.sh"
native_launcher="$repo_dir/scripts/local-run.sh"

bash -n "$launcher" "$native_launcher"

for command_name in doctor repositories deploy-init local-up local-status local-logs local-down context-public-key reload-routes project-up project-down; do
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

# project-up：只编排业务仓自带文件，平台侧只写两个受管目录，且不得改写业务仓。
project_body="$(sed -n '/^  project-up)/,/^  project-down)/p' "$launcher")"
if printf '%s\n' "$project_body" | grep -Eq '>[[:space:]]*"?\$\{?(backend|frontend)_dir'; then
  echo "project-up 不得向业务仓写入任何文件。" >&2
  exit 1
fi
for required_text in \
  'location ^~ /apps/' \
  'resolver 127.0.0.11' \
  "(backend_url IS NULL OR backend_url = '')" \
  'umask 077' \
  'nginx -t' \
  'require_compose_platform' \
  'KAIWU_SKIP_MEMORY_CHECK' \
  '4294967296'; do
  if ! grep -Fq "$required_text" "$launcher"; then
    echo "project-up 缺少约束：$required_text" >&2
    exit 1
  fi
done
# 业务 Compose 必须显式 -p，否则环境里的 COMPOSE_PROJECT_NAME 会把业务栈并进平台项目。
if printf '%s\n' "$project_body" | grep -E 'docker compose' | grep -vq -- '-p "kaiwu-'; then
  echo "project-up 的业务 Compose 调用必须显式指定 -p kaiwu-<projectCode>。" >&2
  exit 1
fi
# 业务 API 只进 Gateway（ADR 0025），平台前端 include 不得直连业务后端。
if grep -Eq 'proxy_pass[^;]*-service:8080' "$launcher"; then
  echo "本机业务入口不得绕过 Gateway 直连业务后端。" >&2
  exit 1
fi
grep -Fq './apps.managed.d:/etc/nginx/kaiwu-apps:ro' "$repo_dir/docker-compose.yml"
# 生成前端的 nginx 以 kaiwu-kaiwu-gateway 反代 API；本机平台网络必须能在启动时解析该名字。
grep -Fq -- '- kaiwu-kaiwu-gateway' "$repo_dir/docker-compose.yml"
# AI 出站默认只放行三个预设服务商；必须用 ${VAR-默认}，保证显式设为空仍能关闭出站。
grep -Fq 'readonly KAIWU_AI_PRESET_HOSTS="api.deepseek.com,dashscope.aliyuncs.com,api.openai.com"' "$launcher"
grep -Fq '${KAIWU_AI_PROVIDER_ALLOWED_HOSTS-$KAIWU_AI_PRESET_HOSTS}' "$launcher"
# 发布版默认拉取预构建镜像，拉取失败必须回退本机构建；镜像标签由 compose() 统一决定。
grep -Fq 'compose pull --quiet system-service gateway-service system-web' "$launcher"
grep -Fq 'export KAIWU_IMAGE_TAG="${KAIWU_IMAGE_TAG:-$(release_image_tag)}"' "$launcher"
grep -Fq 'kaiwu-system-service:${KAIWU_IMAGE_TAG:-local}' "$repo_dir/docker-compose.yml"
echo "本机进程启动器约束检查通过。"
