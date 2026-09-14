#!/bin/sh
set -eu

repo_dir="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
migration="${repo_dir}/sql/increment/V6__group_project_factory_under_delivery.sql"
chart_copy="${repo_dir}/deploy/helm/kaiwu/files/migrations/V6__group_project_factory_under_delivery.sql"

if [ ! -f "$migration" ]; then
  echo "缺少项目工厂菜单归位迁移：$migration" >&2
  exit 1
fi
if [ ! -f "$chart_copy" ] || ! cmp -s "$migration" "$chart_copy"; then
  echo "项目工厂菜单归位迁移的 Helm 副本缺失或不同步。" >&2
  exit 1
fi

grep -q "project.project_code = 'system'" "$migration"
grep -q "factory.route_path = '/project-factory'" "$migration"
grep -q "delivery.id = 9000000000000014001" "$migration"
grep -q "factory.parent_id = delivery.id" "$migration"

echo "项目工厂菜单归位迁移约束检查通过。"
