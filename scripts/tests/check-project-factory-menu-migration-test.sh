#!/bin/sh
set -eu

repo_dir="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)"
migration="${repo_dir}/sql/increment/V127__kaiwu_baseline.sql"
chart_copy="${repo_dir}/deploy/helm/kaiwu/files/migrations/V127__kaiwu_baseline.sql"

if [ ! -f "$migration" ]; then
  echo "缺少项目工厂菜单归位迁移：$migration" >&2
  exit 1
fi
if [ ! -f "$chart_copy" ] || ! cmp -s "$migration" "$chart_copy"; then
  echo "项目工厂菜单归位迁移的 Helm 副本缺失或不同步。" >&2
  exit 1
fi

# V127 的空库由 SystemProjectBootstrap 将项目工厂归入研发交付。
bootstrap="$repo_dir/kaiwu-system-domain/src/main/java/com/kaiwu/module/project/lifecycle/SystemProjectBootstrap.java"
mapper="$repo_dir/kaiwu-system-domain/src/main/java/com/kaiwu/module/project/mapper/SystemBootstrapMapper.java"
grep -Fq 'DELIVERY_DIRECTORY_ID = 9_000_000_000_000_014_001L' "$bootstrap"
grep -Fq 'mapper.moveMenuUnderParent(DELIVERY_DIRECTORY_ID, SYSTEM_PROJECT_CODE, "/project-factory")' "$bootstrap"
grep -Fq 'project.project_code = #{projectCode}' "$mapper"
grep -Fq 'factory.route_path = #{routePath}' "$mapper"
grep -Fq 'factory.parent_id = #{parentId}' "$mapper"
cmp "$repo_dir/scripts/check-flyway-compatibility.sh" "$repo_dir/deploy/helm/kaiwu/files/check-flyway-compatibility.sh"
echo "项目工厂菜单归位与 Helm 副本通过检查。"
