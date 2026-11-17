<#noparse>#!/usr/bin/env sh
# 在同一镜像内检查实际静态站点与 Nginx 的 HTTP 响应。
set -eu
image=${1:?运行镜像}
code=${2:?项目编码}
cid=$(docker run -d --network none --add-host kaiwu-kaiwu-gateway:127.0.0.1 "$image")
trap 'docker rm -f "$cid" >/dev/null' EXIT
docker exec "$cid" sh -eu -c '
  site="/usr/share/nginx/html/apps/$1"
  test -s "$site/index.html"
  for dir in /app/mock /app/mock-support "$site/mock" "$site/mock-support"; do
    test ! -e "$dir"
  done
  if grep -rE "kaiwu_mock_role|/__mock/|mock[.]notImplemented" "$site" >/dev/null; then
    echo "运行镜像含有演示资源" >&2
    exit 1
  else
    test "$?" -eq 1
  fi
  root=http://127.0.0.1:8080
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    wget -T 2 -q -O /tmp/kaiwu-home "$root/apps/$1/" && break
    sleep 1
  done
  cmp /tmp/kaiwu-home "$site/index.html"
  response=$(wget -T 3 -S -O /dev/null "$root/__mock/" 2>&1) && exit 1
  echo "$response" | grep -Eq "HTTP/[0-9.]+ 404([[:space:]]|$)"
  echo "运行镜像通过，项目首页返回发布产物，/__mock/ 返回 404。"
' sh "$code"
</#noparse>
