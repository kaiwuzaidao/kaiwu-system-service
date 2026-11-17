<#noparse>#!/usr/bin/env bash
#
# 校验「后端注解 ⊆ 菜单清单」：每个 @RequirePermission 的权限码都必须在 kaiwu/menus.yml
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
export LC_ALL=C

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
menu_file="${repo_dir}/kaiwu/menus.yml"
if [[ -f "${repo_dir}/kaiwu/frontend-manifests" ]]; then
  frontend_name="$(cat "${repo_dir}/kaiwu/frontend-manifests")"
  menu_file="${KAIWU_FRONTEND_DIR:-${repo_dir}/../${frontend_name}}/kaiwu/menus.yml"
fi
code_pattern='[a-z][a-z0-9-]*:[a-z0-9-]+:[a-z0-9_-]+'

# 注解里的权限码。目录按 *-domain 匹配，避免绑定具体项目编码。
annotated="$(grep -rhoE '@RequirePermission\(\s*"[^"]+"' \
  --include='*.java' "${repo_dir}"/*-domain/src/main/java 2>/dev/null \
  | sed -E 's/.*"([^"]+)".*/\1/' | sort -u || true)"

if [ -z "${annotated}" ] && { [[ -f "${menu_file}" ]] || [[ -f "${repo_dir}/kaiwu/frontend-manifests" ]]; }; then
  echo "[check:perm] 未发现 @RequirePermission 注解，跳过比对。"
  exit 0
fi

if [ ! -f "${menu_file}" ]; then
  echo "[check:perm] 缺少 kaiwu/menus.yml：平台无法同步本项目的菜单与权限。" >&2
  echo "  改法：恢复该文件；新增受权限保护的接口时同步补 BUTTON 节点。" >&2
  exit 1
fi

# 复用 Spring Boot 管理的 SnakeYAML；静态检查只解析清单，无需编译业务代码或启动服务。
mvn -q -N -f "${repo_dir}/pom.xml" dependency:copy@menu-yaml
seeded="$(java -cp "${repo_dir}/target/menu-check/snakeyaml.jar" \
  "${repo_dir}/scripts/MenuPermissions.java" "${menu_file}" | LC_ALL=C sort -u)"

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
  echo "[check:perm] 后端有注解、kaiwu/menus.yml 无 BUTTON 声明（管理员无法授权，功能不可用）：" >&2
  printf '  - %s\n' ${unseeded} >&2
  echo "  改法：在 kaiwu/menus.yml 追加对应 BUTTON 节点，再用「./kaiwu project sync」同步；" >&2
  echo "  只在运行库里手工建菜单不算数，全新安装复现不出来。" >&2
fi

if [ "${failed}" -ne 0 ]; then
  exit 1
fi

echo "[check:perm] 权限码与菜单清单一致：$(printf '%s\n' "${annotated}" | wc -l | tr -d ' ') 个权限码全部有 BUTTON 节点。"
</#noparse>
