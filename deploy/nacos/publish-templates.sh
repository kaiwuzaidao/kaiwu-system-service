#!/usr/bin/env bash
# 把本目录的两份模板发布到 Nacos。只做首发，不覆盖已存在的配置——
# 改配置应该在 Nacos 控制台做，那里有历史版本和回滚。
#
#   export KAIWU_NACOS_SERVER_URL='http://nacos.internal:8848'
#   export KAIWU_NACOS_NAMESPACE='<命名空间 ID>'      # 是 ID 不是名字
#   export KAIWU_SPRING_PROFILE=prod
#   ./publish-templates.sh
set -euo pipefail

: "${KAIWU_NACOS_SERVER_URL:?KAIWU_NACOS_SERVER_URL is required}"
: "${KAIWU_NACOS_NAMESPACE:?KAIWU_NACOS_NAMESPACE is required（命名空间 ID，不是名字）}"
profile="${KAIWU_SPRING_PROFILE:-dev}"
base="${KAIWU_NACOS_SERVER_URL%/}"
here="$(cd "$(dirname "$0")" && pwd)"

auth=()
if [[ -n "${KAIWU_NACOS_USERNAME:-}" ]]; then
  auth=(--data-urlencode "username=${KAIWU_NACOS_USERNAME}"
        --data-urlencode "password=${KAIWU_NACOS_PASSWORD:-}")
fi

for app in kaiwu-system-service kaiwu-gateway-service; do
  data_id="${app}-${profile}.yml"
  file="${here}/${app}.yml.example"
  [[ -f "$file" ]] || { echo "缺少模板：${file}" >&2; exit 1; }

  existing="$(curl -fsS --max-time 15 \
    "${base}/nacos/v1/cs/configs?dataId=${data_id}&group=DEFAULT_GROUP&tenant=${KAIWU_NACOS_NAMESPACE}" \
    2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    echo "已存在，跳过：${data_id}（如需修改请在 Nacos 控制台操作）"
    continue
  fi

  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 -X POST \
    "${base}/nacos/v1/cs/configs" \
    --data-urlencode "dataId=${data_id}" \
    --data-urlencode "group=DEFAULT_GROUP" \
    --data-urlencode "tenant=${KAIWU_NACOS_NAMESPACE}" \
    --data-urlencode "type=yaml" \
    --data-urlencode "content@${file}" \
    "${auth[@]+"${auth[@]}"}")"
  if [[ "$code" == "200" ]]; then
    echo "已发布：${data_id}"
  else
    echo "发布失败：${data_id}（HTTP ${code}）" >&2
    exit 1
  fi
done

echo
echo "发布完成。请在 Nacos 控制台核对数据库与 Redis 地址，再启动平台。"
