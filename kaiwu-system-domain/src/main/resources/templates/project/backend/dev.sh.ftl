#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

usage() {
  cat <<'USAGE'
用法：bash scripts/dev.sh [--verify]

  默认跳过测试直接打包启动，用于日常「改代码-重启」循环。
  --verify  启动前执行完整 mvn verify，提交前跑一次即可。
USAGE
}

run_tests=0
for arg in "$@"; do
  case "$arg" in
    --verify) run_tests=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "未知参数：$arg" >&2; usage; exit 2 ;;
  esac
done

export MAVEN_SKIP_RC=1
export DB_HOST="${r"${DB_HOST:-127.0.0.1}"}"
export DB_PORT="${r"${DB_PORT:-"}${localDbPort}}"
export DB_NAME="${r"${DB_NAME:-kaiwu_"}${normalizedProjectCode}}"
export DB_USER="${r"${DB_USER:-kaiwu_app}"}"
export SERVER_PORT="${r"${SERVER_PORT:-"}${localServerPort}}"

bash scripts/dev-check.sh
docker compose -f compose.local.yml up --detach --wait mysql

if ((run_tests)); then
  mvn verify
else
  mvn -DskipTests package
fi

echo "业务后端将监听 http://127.0.0.1:${r"${SERVER_PORT}"}"
echo 'Gateway 本地显式路由片段：docs/gateway-route-local.yml'
# 直接运行 repackage 出来的可执行 jar。不用 `mvn -pl <boot> spring-boot:run`：
# 那条命令会去本地仓库找兄弟模块，而 verify/package 并不安装它们，
# 干净机器上必然报 Could not find artifact kaiwu-${projectCode}-domain。
#
# 走 JAVA_HOME 下的 java 而不是 PATH：本机 PATH 上的 java 完全可能是 17，
# 而 Maven 用 JAVA_HOME 编出的是 21 字节码，用 PATH java 启动会
# UnsupportedClassVersionError——dev-check.sh 校验的也正是同一个 java。
exec "${r"${JAVA_HOME:+$JAVA_HOME/bin/}"}java" -jar \
  "kaiwu-${projectCode}-boot/target/kaiwu-${projectCode}-service.jar"
