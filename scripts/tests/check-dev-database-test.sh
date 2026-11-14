#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
test_repo="$fixture/workspace/kaiwu-system-service"
mkdir -p "$test_repo/scripts" "$fixture/bin" "$fixture/workspace/.kaiwu/local" "$fixture/private"
cp "$repo_dir/scripts/local-run.sh" "$repo_dir/scripts/database-config.sh" "$test_repo/scripts/"
cat > "$fixture/bin/java" <<'MOCK'
#!/usr/bin/env bash
echo 'openjdk version "21.0.5"' >&2
MOCK
cat > "$fixture/bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf '%s' "$KAIWU_MYSQL_PASSWORD" > "$TEST_DOCKER_PASSWORD_FILE"
exit 1
MOCK
for tool in mvn pnpm curl lsof openssl; do
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fixture/bin/$tool"
done
printf '#!/usr/bin/env bash\necho fixture\n' > "$fixture/bin/openssl"
chmod +x "$fixture/bin/"*
cat > "$fixture/workspace/.kaiwu/local/runtime-keys.env" <<'KEYS'
KAIWU_ACCESS_PRIVATE_KEY=fixture
KAIWU_ACCESS_PUBLIC_KEY=fixture
KAIWU_CONTEXT_PRIVATE_KEY=fixture
KAIWU_CONTEXT_PUBLIC_KEY=fixture
KEYS
export PATH="$fixture/bin:$PATH"
export JAVA_HOME=''
export TEST_DOCKER_PASSWORD_FILE="$fixture/docker-password"
runtime_file="$fixture/workspace/.kaiwu/dev.env"
printf 'KAIWU_MYSQL_PASSWORD=generated-placeholder\n' > "$runtime_file"
printf 'export KAIWU_DB_TYPE=mysql\nexport KAIWU_DB_HOST=\nexport KAIWU_DB_PORT=\nexport KAIWU_DB_NAME=\nexport KAIWU_DB_USER=\nexport KAIWU_DB_PASSWORD=selected-password\n' > "$runtime_file.database"

# Docker 故意失败，只捕获到达首个基础设施命令时的口令；不启动任何服务。
bash "$test_repo/scripts/local-run.sh" dev > "$fixture/dev.log" 2>&1 || true
if [[ "$(cat "$TEST_DOCKER_PASSWORD_FILE")" != selected-password ]]; then
  echo '混合开发启动覆盖了已保存的数据库密码。' >&2
  exit 1
fi

printf 'KAIWU_MYSQL_PASSWORD=custom-runtime-password\n' > "$fixture/private/custom.env"
KAIWU_RUNTIME_ENV_FILE="$fixture/private/custom.env" bash "$test_repo/scripts/local-run.sh" dev > "$fixture/custom.log" 2>&1 || true
[[ "$(cat "$TEST_DOCKER_PASSWORD_FILE")" == custom-runtime-password ]]

for variant in dm external-mysql; do
  printf 'export KAIWU_DB_TYPE=%s\nexport KAIWU_DB_HOST=db.example.com\nexport KAIWU_DB_PORT=5236\nexport KAIWU_DB_NAME=KAIWU\nexport KAIWU_DB_USER=KAIWU\nexport KAIWU_DB_PASSWORD=fixture\n' \
    "$([[ "$variant" == dm ]] && echo dm || echo mysql)" > "$runtime_file.database"
  printf 'not-called' > "$TEST_DOCKER_PASSWORD_FILE"
  if bash "$test_repo/scripts/local-run.sh" dev > "$fixture/rejected.log" 2>&1; then
    echo '不受支持的混合开发数据库必须拒绝。' >&2
    exit 1
  fi
  [[ "$(cat "$TEST_DOCKER_PASSWORD_FILE")" == not-called ]]
done
echo '混合开发密码复用、自定义运行配置和数据库边界检查通过。'
