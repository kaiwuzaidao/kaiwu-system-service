#!/usr/bin/env bash
# Data Scope 端到端联调（D6）：真实 System + Gateway + 示例业务服务，对着真实 MySQL / Redis 验证行级数据范围。
#
# 拓扑（低内存友好，约 1.5 GiB 够用）：
#   容器  MySQL 8.4（700 MiB 上限）+ Redis（64 MiB）
#   宿主机 Java 进程  System(8080) / Gateway(8088) / 示例服务 demo-crm(8316)
#
# 需要三个已检出的目录（都可以是 git worktree），默认值按本仓的工作区布局推断，可用环境变量覆盖：
#   E2E_SYSTEM_DIR   System 集成副本：必须含 D1 + D5 + 成员查询分支。缺省时用 prepare-integration.sh 自动合成
#   E2E_GATEWAY_DIR  Gateway（含 D2，即 feat/data-scope-d2）
#   E2E_STARTER_DIR  Starter 与 data-scope 模块（含 D3 的修复，即 feat/data-scope-d5）
# 示例服务每次 clean package：Maven 不会因为依赖（Starter / data-scope）变了就重打包，不 clean 会拿旧 jar 冒充新代码。
# 其它：E2E_WORK 工作目录（默认 ${TMPDIR}/kaiwu-ds-e2e）；--keep 结束后保留整套环境；--skip-build 复用已构建的 jar。
#
# 用法： scripts/e2e/data-scope/run.sh [--keep] [--skip-build]
# 退出码：0 全部通过；1 有场景失败；2 环境问题。耗时约 5～8 分钟（其中约 1.5 分钟是等 Gateway 30 秒缓存）。
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "${here}/../../.." && pwd)"
workspace="$(cd "${repo}/.." && pwd)"
keep=0
skip_build=0
for arg in "$@"; do
  case "${arg}" in
    --keep) keep=1 ;;
    --skip-build) skip_build=1 ;;
    *) echo "未知参数：${arg}" >&2; exit 2 ;;
  esac
done

export E2E_WORK="${E2E_WORK:-${TMPDIR:-/tmp}/kaiwu-ds-e2e}"
gateway_dir="${E2E_GATEWAY_DIR:-${workspace}/kaiwu-gateway-ds-d2}"
starter_dir="${E2E_STARTER_DIR:-${workspace}/kaiwu-starter-ds-d5}"
system_dir="${E2E_SYSTEM_DIR:-${E2E_WORK}/system}"
logs="${E2E_WORK}/logs"
run="${E2E_WORK}/run"
mysql_name=ds-e2e-mysql
redis_name=ds-e2e-redis
ports=(8080 8088 8316 23306 26379)
pids=()

fail() { echo "✗ $*" >&2; exit 2; }
step() { echo; echo "▶ $*"; }

cleanup() {
  local code=$?
  if (( keep == 1 )); then
    echo; echo "环境已保留（--keep）：日志 ${logs}；清理请执行：docker rm -f ${mysql_name} ${redis_name}；kill ${pids[*]:-}"
    return
  fi
  for pid in "${pids[@]:-}"; do [[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true; done
  docker rm -f "${mysql_name}" "${redis_name}" >/dev/null 2>&1 || true
  exit "${code}"
}
trap cleanup EXIT

# ───────────── 环境检查 ─────────────
step "环境检查"
java_bin="${JAVA_HOME:+${JAVA_HOME}/bin/}java"
"${java_bin}" -version 2>&1 | head -1 | grep -q '"21\.' || fail "需要 JDK 21（当前：$("${java_bin}" -version 2>&1 | head -1)）"
for tool in docker mvn openssl python3 curl; do command -v "${tool}" >/dev/null || fail "缺少 ${tool}"; done
docker info >/dev/null 2>&1 || fail "docker 不可用（colima 没启动？）"
docker image inspect mysql:8.4 >/dev/null 2>&1 || fail "缺少本地镜像 mysql:8.4（内网可先 docker pull docker.m.daocloud.io/library/mysql:8.4 再 docker tag 为 mysql:8.4）"
docker image inspect redis:7.4-alpine >/dev/null 2>&1 || fail "缺少本地镜像 redis:7.4-alpine"
for port in "${ports[@]}"; do
  if lsof -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then fail "端口 ${port} 已被占用（上一次 --keep 没清理？）"; fi
done
[[ -d "${gateway_dir}" ]] || fail "找不到 Gateway：${gateway_dir}（设置 E2E_GATEWAY_DIR）"
[[ -d "${starter_dir}/data-scope" ]] || fail "找不到 Starter：${starter_dir}（设置 E2E_STARTER_DIR）"
mkdir -p "${logs}" "${run}"

if [[ ! -d "${system_dir}" ]]; then
  step "合成 System 集成副本"
  "${here}/prepare-integration.sh" "${system_dir}"
fi

# ───────────── 构建 ─────────────
if (( skip_build == 0 )); then
  step "构建 Starter 与 kaiwu-data-scope（安装到本机 Maven 仓库）"
  (cd "${starter_dir}" && mvn -q -DskipTests install) >"${logs}/build-starter.log" 2>&1 || { tail -20 "${logs}/build-starter.log"; fail "Starter 构建失败"; }
  (cd "${starter_dir}/data-scope" && mvn -q -DskipTests install) >>"${logs}/build-starter.log" 2>&1 || { tail -20 "${logs}/build-starter.log"; fail "data-scope 构建失败"; }
  step "构建 System / Gateway / 示例服务"
  (cd "${system_dir}" && mvn -q -DskipTests -pl kaiwu-system-boot -am package) >"${logs}/build-system.log" 2>&1 || { tail -20 "${logs}/build-system.log"; fail "System 构建失败"; }
  (cd "${gateway_dir}" && mvn -q -DskipTests package) >"${logs}/build-gateway.log" 2>&1 || { tail -20 "${logs}/build-gateway.log"; fail "Gateway 构建失败"; }
  (cd "${here}/demo-crm" && mvn -q -DskipTests clean package) >"${logs}/build-demo.log" 2>&1 || { tail -20 "${logs}/build-demo.log"; fail "示例服务构建失败"; }
fi
system_jar="${system_dir}/kaiwu-system-boot/target/kaiwu-system-service.jar"
gateway_jar="${gateway_dir}/target/kaiwu-gateway-service.jar"
demo_jar="${here}/demo-crm/target/demo-crm-0.0.1.jar"
for jar in "${system_jar}" "${gateway_jar}" "${demo_jar}"; do [[ -f "${jar}" ]] || fail "缺少 ${jar}（去掉 --skip-build 重试）"; done

# ───────────── 基础设施 ─────────────
step "启动 MySQL 与 Redis（本次专用的一次性容器）"
docker rm -f "${mysql_name}" "${redis_name}" >/dev/null 2>&1 || true
docker run -d --name "${mysql_name}" --memory=700m -p 23306:3306 -e MYSQL_ROOT_PASSWORD=rootpw -e MYSQL_DATABASE=kaiwu_platform \
  -e MYSQL_USER=kaiwu -e MYSQL_PASSWORD=kaiwupw mysql:8.4 --performance_schema=off --innodb-buffer-pool-size=96M \
  --max-connections=100 --character-set-server=utf8mb4 >/dev/null
docker run -d --name "${redis_name}" --memory=64m -p 26379:6379 redis:7.4-alpine redis-server --requirepass redispw >/dev/null
for _ in $(seq 1 60); do docker exec "${mysql_name}" mysqladmin ping -uroot -prootpw --silent >/dev/null 2>&1 && break; sleep 2; done
docker exec "${mysql_name}" mysqladmin ping -uroot -prootpw --silent >/dev/null 2>&1 || fail "MySQL 没起来"
docker exec "${mysql_name}" mysql -uroot -prootpw -e "CREATE DATABASE IF NOT EXISTS kaiwu_democrm; GRANT ALL ON kaiwu_democrm.* TO 'kaiwu'@'%';" 2>/dev/null

step "执行 System 的 Flyway 迁移（同一份 sql/increment，含 V118/V119）"
(cd "${system_dir}" && mvn -q -o dependency:build-classpath -pl kaiwu-system-domain -Dmdep.includeScope=test -Dmdep.outputFile="${run}/migrate.cp") >"${logs}/classpath.log" 2>&1 \
  || (cd "${system_dir}" && mvn -q dependency:build-classpath -pl kaiwu-system-domain -Dmdep.includeScope=test -Dmdep.outputFile="${run}/migrate.cp") >>"${logs}/classpath.log" 2>&1 \
  || fail "取迁移 classpath 失败，见 ${logs}/classpath.log"
(cd "${system_dir}" && "${java_bin}" -cp "$(cat "${run}/migrate.cp")" "${here}/Migrate.java" \
  "jdbc:mysql://127.0.0.1:23306/kaiwu_platform?allowPublicKeyRetrieval=true&useSSL=false" kaiwu kaiwupw sql/increment) >"${logs}/migrate.log" 2>&1 \
  || { tail -20 "${logs}/migrate.log"; fail "迁移失败"; }
tail -1 "${logs}/migrate.log"

# ───────────── 密钥与环境变量 ─────────────
step "生成本次专用的临时密钥"
umask 077
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${run}/access.pem" 2>/dev/null
openssl pkey -in "${run}/access.pem" -pubout -out "${run}/access.pub" 2>/dev/null
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${run}/context.pem" 2>/dev/null
openssl pkey -in "${run}/context.pem" -pubout -out "${run}/context.pub" 2>/dev/null
mkdir -p "${run}/artifacts" "${run}/routes.local.d"
export SPRING_PROFILES_ACTIVE=local
export SPRING_CLOUD_NACOS_CONFIG_ENABLED=false SPRING_CLOUD_NACOS_DISCOVERY_ENABLED=false
export DB_HOST=127.0.0.1 DB_PORT=23306 DB_NAME=kaiwu_platform DB_USER=kaiwu DB_PASSWORD=kaiwupw
export REDIS_HOST=127.0.0.1 REDIS_PORT=26379 REDIS_PASSWORD=redispw
export KAIWU_GATEWAY_INTERNAL_TOKEN=gw-internal-token-e2e
export KAIWU_CONFIG_ENCRYPTION_KEY="$(openssl rand -base64 32 | tr -d '\n')"
export KAIWU_NOTIFICATION_DELIVERY_TOKEN="$(openssl rand -hex 32)"
export KAIWU_BOOTSTRAP_ADMIN_PASSWORD='Kaiwu!e2e-admin-1'
export KAIWU_ARTIFACT_ROOT="${run}/artifacts"
export KAIWU_ACCESS_PRIVATE_KEY="$(cat "${run}/access.pem")" KAIWU_ACCESS_PUBLIC_KEY="$(cat "${run}/access.pub")"
export KAIWU_CONTEXT_PRIVATE_KEY="$(cat "${run}/context.pem")" KAIWU_CONTEXT_PUBLIC_KEY="$(cat "${run}/context.pub")"
# 签发 member:read 项目服务凭据（reassign 校验新归属要用）默认关闭，联调时显式打开；线上启用要单独评估（C5）。
export KAIWU_SERVICE_CREDENTIALS_MULTI_ENABLED=true
export E2E_CONTEXT_KEY="${run}/context.pem"
export KAIWU_LOCAL_ROUTES_DIR="${run}/routes.local.d"

cat >"${run}/routes.local.d/demo-crm.yml" <<'YAML'
- id: demo-crm-project-local
  uri: http://127.0.0.1:8316
  predicates:
    - Path=/demo-crm-api/**
  filters:
    - RewritePath=/demo-crm-api/(?<segment>.*), /${segment}
  metadata:
    accessMode: PROJECT
    audience: kaiwu-demo-crm-service
    projectCode: demo-crm
YAML

wait_http() { # url 超时秒数 名称
  for _ in $(seq 1 "$2"); do
    [[ "$(curl -s -o /dev/null -w '%{http_code}' "$1" 2>/dev/null)" == "200" ]] && return 0
    sleep 1
  done
  fail "$3 没有在 $2 秒内就绪，日志：${logs}"
}

step "启动 System 与 Gateway"
(cd "${system_dir}" && exec "${java_bin}" -Xmx384m -jar "${system_jar}") >"${logs}/system.log" 2>&1 &
pids+=("$!")
wait_http http://127.0.0.1:8080/actuator/health 180 System
(cd "${gateway_dir}" && SERVER_PORT=8088 KAIWU_GATEWAY_LOCAL_ROUTES_DIR="${run}/routes.local.d" exec "${java_bin}" -Xmx256m -jar "${gateway_jar}") >"${logs}/gateway.log" 2>&1 &
pids+=("$!")
wait_http http://127.0.0.1:8088/api/hello 120 Gateway

# ───────────── 种子 → 示例服务 → 场景 ─────────────
step "种子：部门、用户、项目、清单（含角色范围）、成员、服务凭据"
python3 "${here}/seed.py" >"${logs}/seed.log" 2>&1 || { tail -20 "${logs}/seed.log"; fail "种子失败"; }
echo "已写入 ${E2E_WORK}/state.json"
project_id="$(python3 -c "import json,os;print(json.load(open(os.environ['E2E_WORK']+'/state.json'))['project_id'])")"
credential="$(python3 -c "import json,os;print(json.load(open(os.environ['E2E_WORK']+'/state.json'))['credential'])")"

step "启动示例业务服务 demo-crm"
docker exec -i "${mysql_name}" mysql -ukaiwu -pkaiwupw kaiwu_democrm <"${here}/demo-crm/schema.sql" 2>/dev/null
(cd "${here}/demo-crm" && KAIWU_PROJECT_ID="${project_id}" DEMO_MEMBER_CREDENTIAL="${credential}" exec "${java_bin}" -Xmx256m -jar "${demo_jar}") >"${logs}/demo.log" 2>&1 &
pids+=("$!")
wait_http http://127.0.0.1:8316/demo/agent-meta 120 "示例服务"

step "场景验证（约 2 分钟，其中两处要等 Gateway 的 30 秒缓存）"
set +e
python3 "${here}/scenarios.py"
code=$?
set -e
echo
echo "报告：${E2E_WORK}/report.md"
exit "${code}"
