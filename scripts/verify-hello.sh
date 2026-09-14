#!/usr/bin/env bash
set -euo pipefail

gateway_url="${KAIWU_GATEWAY_URL:-http://127.0.0.1:8088}"
web_url="${KAIWU_WEB_URL:-http://127.0.0.1:8000}"

for _ in $(seq 1 60); do
  if gateway_body="$(curl --noproxy '*' --fail --silent --show-error "$gateway_url/api/hello" 2>/dev/null)"; then
    break
  fi
  sleep 1
done

: "${gateway_body:?Gateway Hello did not become ready within 60 seconds}"
echo "$gateway_body" | grep -q '"service":"kaiwu-system-service"'

web_body="$(curl --noproxy '*' --fail --silent --show-error "$web_url/api/hello")"
echo "$web_body" | grep -q '"service":"kaiwu-system-service"'

curl --noproxy '*' --fail --silent --show-error --output /dev/null "$web_url/"

echo "Kaiwu Hello 黄金路径通过：Browser/Web -> Nginx -> Gateway -> System"
