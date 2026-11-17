#!/usr/bin/env bash
set -euo pipefail
export MAVEN_SKIP_RC=1

java_bin="${JAVA_HOME:+$JAVA_HOME/bin/}java"
java_version="$("$java_bin" -version 2>&1 | head -n 1)"
case "$java_version" in
  *'"21.'*) ;;
  *) echo "生成模板验证必须使用 JDK 21，当前：$java_version（JAVA_HOME=${JAVA_HOME:-未设置}）" >&2; exit 1 ;;
esac
mvn -version 2>&1 | grep -q 'Java version: 21\.' || {
  echo "Maven 未使用 JDK 21，请检查 JAVA_HOME 和用户级 Maven 启动文件。" >&2
  exit 1
}

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
sample_root="${repo_dir}/kaiwu-system-domain/target/project-scaffold-sample"

cd "$repo_dir"
mvn -q -s .mvn/settings.xml \
  -pl kaiwu-system-domain -am \
  -Dtest=ProjectScaffoldGeneratorTest \
  -Dsurefire.failIfNoSpecifiedTests=false test

# 用 CLI 相同的 unzip 流程验证首次构建，捕获制品时间戳导致的 Maven 资源遗漏。
backend="$(mktemp -d)"
trap 'rm -rf "$backend"' EXIT
unzip -q "$sample_root/sample-backend-order-center.zip" -d "$backend"
mvn -q -s .mvn/settings.xml -f "$backend/pom.xml" verify

# 门禁脚本本身也必须在真实产物上跑通：新生成的项目第一次跑 CI 就红是不可接受的。
bash "$backend/scripts/check-permission-seed.sh"
bash "$backend/scripts/check-test-baseline.sh" --strict
sh "$backend/scripts/check-constraints.sh"
sh "${sample_root}/frontend/scripts/check-constraints.sh"

cd "${sample_root}/frontend"
corepack pnpm install --frozen-lockfile --ignore-scripts
corepack pnpm run setup
KAIWU_SERVICE_DIR="$backend" corepack pnpm verify

# 相同菜单改为行内 YAML 后，前后端应继续通过；普通菜单上的同名字段不能代替 BUTTON。
menu="$backend/kaiwu/menus.yml"
node - "$menu" <<'JS'
const fs = require('node:fs'), yaml = require('js-yaml'), file = process.argv[2];
const menus = yaml.safeLoad(fs.readFileSync(file, 'utf8'));
fs.writeFileSync(file, yaml.safeDump(menus, { flowLevel: 0 }));
JS
bash "$backend/scripts/check-permission-seed.sh"
KAIWU_SERVICE_DIR="$backend" corepack pnpm check:perm
node - "$menu" <<'JS'
const fs = require('node:fs'), yaml = require('js-yaml'), file = process.argv[2];
const menus = yaml.safeLoad(fs.readFileSync(file, 'utf8'));
const button = menus.flatMap(menu => menu.children).find(node => node.type === 'BUTTON');
button.type = 'MENU';
button.path = '/permission-check';
fs.writeFileSync(file, yaml.safeDump(menus, { flowLevel: 0 }));
JS
if bash "$backend/scripts/check-permission-seed.sh" >"$backend/check.log" 2>&1; then exit 1; fi
grep -q '无 BUTTON 声明' "$backend/check.log"
if KAIWU_SERVICE_DIR="$backend" corepack pnpm check:perm >"$backend/check.log" 2>&1; then exit 1; fi
grep -q '无 BUTTON 声明' "$backend/check.log"

echo "生成后端三模块和分层前端的真实构建与权限/字典门禁验证通过。"
