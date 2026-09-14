#!/usr/bin/env bash
set -euo pipefail

# 仅用于显式维护开发配置模板；日常启动禁止调用，避免覆盖 Nacos 中受管的 dev 运行值。
if [[ "${1:-}" != "--overwrite-template" ]]; then
  echo 'Refusing to overwrite managed dev Nacos values. Use dev-nacos-run.sh for normal startup.' >&2
  exit 2
fi
: "${KAIWU_NACOS_SERVER_URL:?KAIWU_NACOS_SERVER_URL is required}"
: "${KAIWU_NACOS_NAMESPACE:?KAIWU_NACOS_NAMESPACE is required}"
: "${KAIWU_NACOS_USERNAME:?KAIWU_NACOS_USERNAME is required}"
: "${KAIWU_NACOS_PASSWORD:?KAIWU_NACOS_PASSWORD is required}"
nacos_server_url="${KAIWU_NACOS_SERVER_URL%/}"
nacos_username="${KAIWU_NACOS_USERNAME}"
nacos_namespace="${KAIWU_NACOS_NAMESPACE}"
nacos_base="${nacos_server_url}"

nacos_token="$(curl --connect-timeout 5 --max-time 15 --fail-with-body --silent --show-error \
  --request POST "${nacos_base}/v1/auth/login" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "username=${nacos_username}" \
  --data-urlencode "password=${KAIWU_NACOS_PASSWORD}" | jq -er '.accessToken')"

# 不同 Nacos 版本的配置端点与参数名都不同：3.x 用 /v3/console + namespaceId/groupName，
# 部分发行版只有 /v3/admin，2.x 用 /v1 + tenant/group。先探测一次，后续读写都用同一套。
# 与 load-nacos-compose-env.sh 的回退顺序保持一致。
detect_config_api() {
  local flavor status
  for flavor in v3console v3admin v1; do
    case "$flavor" in
      v3console)
        status="$(curl --connect-timeout 5 --max-time 10 --silent --output /dev/null \
          --write-out '%{http_code}' \
          --get "${nacos_base}/v3/console/cs/config" \
          --header "accessToken: ${nacos_token}" \
          --data-urlencode "username=${nacos_username}" \
          --data-urlencode "namespaceId=${nacos_namespace}" \
          --data-urlencode 'groupName=DEFAULT_GROUP' \
          --data-urlencode 'dataId=__kaiwu_probe__' 2>/dev/null || true)"
        ;;
      v3admin)
        status="$(curl --connect-timeout 5 --max-time 10 --silent --output /dev/null \
          --write-out '%{http_code}' \
          --get "${nacos_base}/v3/admin/cs/config" \
          --header "accessToken: ${nacos_token}" \
          --data-urlencode "namespaceId=${nacos_namespace}" \
          --data-urlencode 'groupName=DEFAULT_GROUP' \
          --data-urlencode 'dataId=__kaiwu_probe__' 2>/dev/null || true)"
        ;;
      v1)
        status="$(curl --connect-timeout 5 --max-time 10 --silent --output /dev/null \
          --write-out '%{http_code}' \
          --get "${nacos_base}/v1/cs/configs" \
          --header "accessToken: ${nacos_token}" \
          --data-urlencode "tenant=${nacos_namespace}" \
          --data-urlencode 'group=DEFAULT_GROUP' \
          --data-urlencode 'dataId=__kaiwu_probe__' 2>/dev/null || true)"
        ;;
    esac
    # 探测的 dataId 不存在，返回 404 属于正常；只有端点本身缺失才排除该 flavor。
    # 端点缺失同样是 404，因此用 410（v1 被停用）和 000（连不上）之外的可达性判断：
    # 端点存在时 Nacos 会返回 200 或带 JSON 体的 404，两者都视为可用，最终由
    # 写入后的 read-back 摘要校验兜底。
    if [[ "$status" == "200" || "$status" == "404" ]]; then
      # 404 需要区分「配置不存在」和「端点不存在」，用一次带体的请求确认。
      if [[ "$status" == "404" ]] && probe_endpoint_missing "$flavor"; then
        continue
      fi
      printf '%s' "$flavor"
      return 0
    fi
  done
  echo "无法确定 Nacos 配置 API 版本：v3/console、v3/admin、v1 均不可用。" >&2
  return 1
}

# Nacos 对「端点不存在」返回的 message 形如 "No endpoint GET /nacos/v3/console/cs/config."
probe_endpoint_missing() {
  local flavor="$1" body path
  case "$flavor" in
    v3console) path="/v3/console/cs/config" ;;
    v3admin) path="/v3/admin/cs/config" ;;
    v1) path="/v1/cs/configs" ;;
  esac
  body="$(curl --connect-timeout 5 --max-time 10 --silent \
    --get "${nacos_base}${path}" \
    --header "accessToken: ${nacos_token}" \
    --data-urlencode "namespaceId=${nacos_namespace}" \
    --data-urlencode "tenant=${nacos_namespace}" \
    --data-urlencode 'groupName=DEFAULT_GROUP' \
    --data-urlencode 'group=DEFAULT_GROUP' \
    --data-urlencode 'dataId=__kaiwu_probe__' 2>/dev/null || true)"
  [[ "$body" == *'No endpoint'* ]]
}

read_config() {
  local flavor="$1" data_id="$2"
  case "$flavor" in
    v3console)
      curl --connect-timeout 5 --max-time 15 --fail-with-body --silent --show-error \
        --get "${nacos_base}/v3/console/cs/config" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "username=${nacos_username}" \
        --data-urlencode "namespaceId=${nacos_namespace}" \
        --data-urlencode 'groupName=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}" | jq -er '.data.content'
      ;;
    v3admin)
      curl --connect-timeout 5 --max-time 15 --fail-with-body --silent --show-error \
        --get "${nacos_base}/v3/admin/cs/config" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "namespaceId=${nacos_namespace}" \
        --data-urlencode 'groupName=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}" | jq -er '.data.content'
      ;;
    v1)
      # v1 直接返回原始内容，不包 JSON。
      curl --connect-timeout 5 --max-time 15 --fail-with-body --silent --show-error \
        --get "${nacos_base}/v1/cs/configs" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "tenant=${nacos_namespace}" \
        --data-urlencode 'group=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}"
      ;;
  esac
}

write_config() {
  local flavor="$1" data_id="$2" content="$3"
  case "$flavor" in
    v3console)
      curl --connect-timeout 5 --max-time 20 --fail-with-body --silent --show-error \
        --request POST "${nacos_base}/v3/console/cs/config" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "username=${nacos_username}" \
        --data-urlencode "namespaceId=${nacos_namespace}" \
        --data-urlencode 'groupName=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}" \
        --data-urlencode 'type=yaml' \
        --data-urlencode "content=${content}" >/dev/null
      ;;
    v3admin)
      curl --connect-timeout 5 --max-time 20 --fail-with-body --silent --show-error \
        --request POST "${nacos_base}/v3/admin/cs/config" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "namespaceId=${nacos_namespace}" \
        --data-urlencode 'groupName=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}" \
        --data-urlencode 'type=yaml' \
        --data-urlencode "content=${content}" >/dev/null
      ;;
    v1)
      curl --connect-timeout 5 --max-time 20 --fail-with-body --silent --show-error \
        --request POST "${nacos_base}/v1/cs/configs" \
        --header "accessToken: ${nacos_token}" \
        --data-urlencode "tenant=${nacos_namespace}" \
        --data-urlencode 'group=DEFAULT_GROUP' \
        --data-urlencode "dataId=${data_id}" \
        --data-urlencode 'type=yaml' \
        --data-urlencode "content=${content}" >/dev/null
      ;;
  esac
}

publish_config() {
  local data_id="$1"
  local content="$2"
  local expected_digest actual_content actual_digest

  expected_digest="$(printf '%s' "$content" | shasum -a 256 | awk '{print $1}')"
  write_config "$config_api" "$data_id" "$content"

  # 写入成功与否最终以回读摘要为准，避免各版本返回体差异导致误判。
  actual_content="$(read_config "$config_api" "$data_id")"
  actual_digest="$(printf '%s' "$actual_content" | shasum -a 256 | awk '{print $1}')"
  if [[ "$actual_digest" != "$expected_digest" ]]; then
    echo "Nacos dataId ${data_id} read-back digest mismatch." >&2
    exit 1
  fi
  echo "Published and verified ${data_id} in namespace ${nacos_namespace} (API: ${config_api})."
}

config_api="$(detect_config_api)"

system_config="$(cat <<'YAML'
server:
  port: 8080

spring:
  datasource:
    url: jdbc:mysql://mysql:3306/kaiwu_platform?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai
    username: kaiwu
    password: ${KAIWU_MYSQL_PASSWORD}
    driver-class-name: com.mysql.cj.jdbc.Driver
  data:
    redis:
      host: redis
      port: 6379
      password: ${KAIWU_REDIS_PASSWORD}

kaiwu:
  notification:
    delivery-token: ${KAIWU_NOTIFICATION_DELIVERY_TOKEN:}
  metadata:
    encryption-key: ${KAIWU_CONFIG_ENCRYPTION_KEY}
  codegen:
    artifact-root: ${KAIWU_ARTIFACT_ROOT:/var/lib/kaiwu/artifacts}
    gitlab:
      base-url: ${KAIWU_GITLAB_URL:}
      token: ${KAIWU_GITLAB_TOKEN:}
  auth:
    access-private-key: ${KAIWU_ACCESS_PRIVATE_KEY}
    bootstrap-admin-password: ${KAIWU_BOOTSTRAP_ADMIN_PASSWORD}
    access-ttl-seconds: ${KAIWU_ACCESS_TTL_SECONDS:900}
    refresh-ttl-seconds: ${KAIWU_REFRESH_TTL_SECONDS:604800}
    refresh-cookie-secure: true
  starter:
    enabled: true
    context-public-key: ${KAIWU_CONTEXT_PUBLIC_KEY}
    audience: kaiwu-system-service
    include-paths:
      - /api/**
    exclude-paths:
      - /api/hello
      - /api/auth/login
      - /api/auth/refresh
      - /api/internal/**
      - /actuator/health
      - /actuator/health/**
YAML
)"

gateway_config="$(cat <<'YAML'
server:
  port: 8088

spring:
  data:
    redis:
      host: redis
      port: 6379
      password: ${KAIWU_REDIS_PASSWORD}
  cloud:
    gateway:
      server:
        webflux:
          discovery:
            locator:
              enabled: false
          httpclient:
            connect-timeout: 3000
            response-timeout: 10s
          routes:
            - id: system-public-hello
              uri: ${KAIWU_SYSTEM_SERVICE_URI}
              predicates:
                - Path=/api/hello
                - Method=GET
              metadata:
                accessMode: PUBLIC
                audience: kaiwu-system-service
            - id: system-public-auth
              uri: ${KAIWU_SYSTEM_SERVICE_URI}
              predicates:
                - Path=/api/auth/login,/api/auth/refresh
                - Method=POST
              metadata:
                accessMode: PUBLIC
                audience: kaiwu-system-service
            - id: system-platform
              uri: ${KAIWU_SYSTEM_SERVICE_URI}
              predicates:
                - Path=/api/auth/logout,/api/auth/me,/api/auth/me/locale,/api/auth/menus,/api/auth/password,/api/platform/**,/api/users/**,/api/projects/**,/api/current/**,/api/metadata/**,/api/ai/**,/api/project-generations/**,/api/gitlab/**,/api/logs/**,/api/org/**,/api/scheduler/**,/api/search
              metadata:
                accessMode: PLATFORM
                audience: kaiwu-system-service

kaiwu:
  gateway:
    auth:
      access-public-key: ${KAIWU_ACCESS_PUBLIC_KEY}
      context-private-key: ${KAIWU_CONTEXT_PRIVATE_KEY}
      context-ttl-seconds: 60
YAML
)"

publish_config 'kaiwu-system-service-dev.yml' "$system_config"
publish_config 'kaiwu-gateway-service-dev.yml' "$gateway_config"
