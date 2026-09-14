<#noparse>#!/usr/bin/env bash
#
# 校验「后端注解 ⊆ 菜单 seed」：每个 @RequirePermission 的权限码都必须在 sql/menu.sql
# 里有对应的 BUTTON 节点。
#
# 存在的意义：缺 seed 时接口本身能跑，但平台「项目菜单」里根本看不到这个按钮，
# 管理员无法把该权限授予任何角色，功能对所有非超管等于不存在。开发库通常手工加过菜单，
# 所以本地一切正常，问题只在全新安装时暴露——这正是要靠 CI 拦住的沉默失败。
#
# 权限码格式同时校验：格式错的码永远匹配不上前端和菜单，且不会有任何报错。
#
# 退出码：0 通过；1 发现不一致。
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
menu_file="${repo_dir}/sql/menu.sql"
code_pattern='[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+'

if [ ! -f "${menu_file}" ]; then
  echo "[check:perm] 缺少 sql/menu.sql：平台无法导入本项目的菜单与权限。" >&2
  echo "  改法：恢复该文件；新增受权限保护的接口时同步补 BUTTON 节点。" >&2
  exit 1
fi

# 注解里的权限码。目录按 *-domain 匹配，避免绑定具体项目编码。
annotated="$(grep -rhoE '@RequirePermission\(\s*"[^"]+"' \
  --include='*.java' "${repo_dir}"/*-domain/src/main/java 2>/dev/null \
  | sed -E 's/.*"([^"]+)".*/\1/' | sort -u || true)"

if [ -z "${annotated}" ]; then
  echo "[check:perm] 未发现 @RequirePermission 注解，跳过比对。"
  exit 0
fi

# 菜单 seed 里的权限码。按「三段冒号字面量」提取而不是绑定某种 INSERT 写法——
# 列顺序和换行方式在后续迁移里并不一致，绑死写法会漏。
seeded="$(grep -oE "'${code_pattern}'" "${menu_file}" \
  | tr -d "'" | sort -u || true)"

failed=0

malformed="$(printf '%s\n' "${annotated}" | grep -vE "^${code_pattern}$" || true)"
if [ -n "${malformed}" ]; then
  failed=1
  echo "[check:perm] 权限码不符合 {module}:{resource}:{action} 格式：" >&2
  printf '  - %s\n' ${malformed} >&2
fi

unseeded="$(comm -23 \
  <(printf '%s\n' "${annotated}" | grep -E "^${code_pattern}$" || true) \
  <(printf '%s\n' "${seeded}"))"
if [ -n "${unseeded}" ]; then
  failed=1
  echo "[check:perm] 后端有注解、sql/menu.sql 无 BUTTON seed（管理员无法授权，功能不可用）：" >&2
  printf '  - %s\n' ${unseeded} >&2
  echo "  改法：在 sql/menu.sql 追加对应 BUTTON 节点并导入平台库；" >&2
  echo "  只在运行库里手工建菜单不算数，全新安装复现不出来。" >&2
fi

if [ "${failed}" -ne 0 ]; then
  exit 1
fi

echo "[check:perm] 权限码与菜单 seed 一致：$(printf '%s\n' "${annotated}" | wc -l | tr -d ' ') 个权限码全部有 BUTTON 节点。"
</#noparse>
