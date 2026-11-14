#!/bin/sh
# System 新增的 /api 路径必须在 Gateway 的显式路由里注册，否则线上直接 404。
#
# ADR 0001 第 1 条：Gateway 禁止 discovery locator 自动暴露服务，只允许显式路由。
# 这条约束此前没有对应的检查，结果是 P1a 的 /api/agent/** 一路通过了全部门禁，
# 直到部署后访问才发现 404——代码、迁移、权限、前端全对，就是路由没配。
#
# 两处都要有：
#   kaiwu-gateway-service/src/main/resources/application-local.yml  本地开发
#   kaiwu-system-service/deploy/nacos/kaiwu-gateway-service.yml.example  运行环境模板
# 后者只是模板，真实运行值在 Nacos，改完仍需发布到对应 Data ID。
set -eu

service_root="$(cd "$(dirname "$0")/../.." && pwd)"
workspace_root="$(dirname "$service_root")"
gateway_local="$workspace_root/kaiwu-gateway-service/src/main/resources/application-local.yml"
nacos_template="$service_root/deploy/nacos/kaiwu-gateway-service.yml.example"

if [ ! -f "$gateway_local" ]; then
  echo "[skip] 未检出 kaiwu-gateway-service，跳过网关路由覆盖检查"
  exit 0
fi

# 取 System 所有 @RequestMapping("/api/...") 的一级路径段
prefixes="$(grep -rhoE '@RequestMapping\("/api/[a-z0-9-]+' "$service_root/kaiwu-system-domain/src/main/java" \
  | sed 's#@RequestMapping("/api/##' | sort -u)"

# internal 是有意不暴露的：ADR 0008 第 8 条要求 /api/internal/** 不接受浏览器 JWT，
# 外部 Gateway 必须继续阻断该路径。它由 starter 用应用凭据经内部地址调用。
excluded="internal"

missing=""
for prefix in $prefixes; do
  case " $excluded " in *" $prefix "*) continue ;; esac
  for file in "$gateway_local" "$nacos_template"; do
    [ -f "$file" ] || continue
    if ! grep -q "/api/$prefix" "$file"; then
      missing="$missing\n  /api/$prefix 缺失于 $(basename "$(dirname "$(dirname "$file")")")/$(basename "$file")"
    fi
  done
done

if [ -n "$missing" ]; then
  echo "以下 System 接口路径没有在 Gateway 显式路由里注册，线上会 404："
  printf "%b\n" "$missing"
  echo "修复：把路径加进上述文件的受保护路由 Path 断言；运行环境还需同步发布 Nacos 配置。"
  exit 1
fi

echo "网关路由覆盖检查通过（$(echo "$prefixes" | wc -l | tr -d ' ') 个接口前缀）。"
