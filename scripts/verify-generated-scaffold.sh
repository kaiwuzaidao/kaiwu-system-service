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

mvn -q -s .mvn/settings.xml \
  -f "${sample_root}/backend/pom.xml" verify

# 门禁脚本本身也必须在真实产物上跑通：新生成的项目第一次跑 CI 就红是不可接受的。
bash "${sample_root}/backend/scripts/check-permission-seed.sh"
bash "${sample_root}/backend/scripts/check-test-baseline.sh" --strict
sh "${sample_root}/backend/scripts/check-constraints.sh"
sh "${sample_root}/frontend/scripts/check-constraints.sh"

cd "${sample_root}/frontend"
corepack pnpm install --frozen-lockfile --ignore-scripts
corepack pnpm run setup
KAIWU_SERVICE_DIR="${sample_root}/backend" corepack pnpm verify

echo "生成后端三模块和分层前端的真实构建与权限/字典门禁验证通过。"
