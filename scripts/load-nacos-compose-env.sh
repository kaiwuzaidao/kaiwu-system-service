#!/usr/bin/env bash
set -euo pipefail

# 从受保护的 dev Nacos Data ID 读取 Compose 首启所需值；输出仅供 dev-nacos-run.sh source。
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

# 不同 Nacos 版本暴露的读配置端点不同：3.x 用 /v3/console，部分发行版只有
# /v3/admin，2.x 只有 /v1。按序探测并取第一个成功的，避免绑定单一版本。
fetch_config_content() {
  local content

  content="$(curl --connect-timeout 5 --max-time 15 --silent \
    --get "${nacos_base}/v3/console/cs/config" \
    --header "accessToken: ${nacos_token}" \
    --data-urlencode "username=${nacos_username}" \
    --data-urlencode "namespaceId=${nacos_namespace}" \
    --data-urlencode 'groupName=DEFAULT_GROUP' \
    --data-urlencode 'dataId=kaiwu-compose-dev.yml' 2>/dev/null \
    | jq -er '.data.content' 2>/dev/null)" && [[ -n "$content" ]] && {
    printf '%s' "$content"
    return 0
  }

  content="$(curl --connect-timeout 5 --max-time 15 --silent \
    --get "${nacos_base}/v3/admin/cs/config" \
    --header "accessToken: ${nacos_token}" \
    --data-urlencode "namespaceId=${nacos_namespace}" \
    --data-urlencode 'groupName=DEFAULT_GROUP' \
    --data-urlencode 'dataId=kaiwu-compose-dev.yml' 2>/dev/null \
    | jq -er '.data.content' 2>/dev/null)" && [[ -n "$content" ]] && {
    printf '%s' "$content"
    return 0
  }

  # v1 直接返回原始内容，不包 JSON。
  content="$(curl --connect-timeout 5 --max-time 15 --silent \
    --get "${nacos_base}/v1/cs/configs" \
    --header "accessToken: ${nacos_token}" \
    --data-urlencode "tenant=${nacos_namespace}" \
    --data-urlencode 'group=DEFAULT_GROUP' \
    --data-urlencode 'dataId=kaiwu-compose-dev.yml' 2>/dev/null)" \
    && [[ -n "$content" ]] && [[ "$content" != *'"status":4'* ]] && {
    printf '%s' "$content"
    return 0
  }

  echo "无法从 Nacos 读取 kaiwu-compose-dev.yml：已尝试 v3/console、v3/admin、v1 三种端点。" >&2
  echo "请确认 namespace ${nacos_namespace} 下存在该 Data ID，且账号有读权限。" >&2
  return 1
}

fetch_config_content | \
  ruby -ryaml -rshellwords -e '
    values = YAML.safe_load(STDIN.read, aliases: false).fetch("kaiwu").fetch("dev-compose")
    mapping = {
      "mysql-root-password" => "KAIWU_MYSQL_ROOT_PASSWORD",
      "mysql-password" => "KAIWU_MYSQL_PASSWORD",
      "redis-password" => "KAIWU_REDIS_PASSWORD",
      "bootstrap-admin-password" => "KAIWU_BOOTSTRAP_ADMIN_PASSWORD",
      "config-encryption-key" => "KAIWU_CONFIG_ENCRYPTION_KEY"
    }
    # 可选项：缺失时不报错，对应能力保持关闭。
    # AI 两项同时存在时，dev-nacos-run.sh 会启用受控出站代理 profile；
    # 同一份值也会注入 System，避免 Compose 的空环境变量覆盖 Nacos 应用配置。
    optional_mapping = {
      "notification-delivery-token" => "KAIWU_NOTIFICATION_DELIVERY_TOKEN",
      "ai-provider-allowed-hosts" => "KAIWU_AI_PROVIDER_ALLOWED_HOSTS",
      "ai-provider-egress-proxy-uri" => "KAIWU_AI_PROVIDER_EGRESS_PROXY_URI"
    }
    mapping.each do |key, environment|
      value = values.fetch(key).to_s
      raise "missing #{key}" if value.empty?
      puts "export #{environment}=#{Shellwords.shellescape(value)}"
    end
    optional_mapping.each do |key, environment|
      value = values[key].to_s
      next if value.empty?
      puts "export #{environment}=#{Shellwords.shellescape(value)}"
    end
  '
