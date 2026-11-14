#!/usr/bin/env sh
set -eu

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT HUP INT TERM
system="$fixture/kaiwu-system-service"
mkdir -p "$system/scripts/tests" "$fixture/kaiwu-system-starter" "$fixture/bin"
generator_dir="$system/kaiwu-system-domain/src/main/java/com/kaiwu/module/factory/renderer"
template_dir="$system/kaiwu-system-domain/src/main/resources/templates/project/backend"
mkdir -p "$generator_dir" "$template_dir"
cp "$repo_root/scripts/tests/check-starter-version-published.sh" "$system/scripts/tests/check.sh"
# 限定被测脚本可见的命令，使本机与 Alpine 运行相同的工具组合。
for tool in sh dirname grep sed sort head awk tr; do
    ln -s "$(command -v "$tool")" "$fixture/bin/$tool"
done
unset CI
printf 'public static final String STARTER_VERSION = "0.1.0";\n' > "$generator_dir/ProjectScaffoldGenerator.java"
printf '<kaiwu-system-starter.version>0.1.0</kaiwu-system-starter.version>\n' > "$system/pom.xml"
printf '<groupId>com.kaiwuzaidao</groupId>\n<artifactId>kaiwu-system-starter</artifactId>\n' > "$template_dir/domain-pom.xml.ftl"
cat > "$fixture/bin/curl" <<'SH'
#!/usr/bin/env sh
case "$*" in
    *kaiwu-excel*) printf '%s' "${KAIWU_TEST_EXCEL_STATUS:-${KAIWU_TEST_CENTRAL_STATUS:-200}}" ;;
    *kaiwu-data-scope*) printf '%s' "${KAIWU_TEST_DATA_SCOPE_STATUS:-${KAIWU_TEST_CENTRAL_STATUS:-200}}" ;;
    *) printf '%s' "${KAIWU_TEST_CENTRAL_STATUS:-200}" ;;
esac
exit "${KAIWU_TEST_CURL_EXIT:-0}"
SH
chmod +x "$fixture/bin/curl"
check_passes() {
    if ! PATH="$fixture/bin" sh "$system/scripts/tests/check.sh" > "$fixture/output" 2>&1; then
        cat "$fixture/output" >&2
        exit 1
    fi
}
check_fails() {
    if PATH="$fixture/bin" sh "$system/scripts/tests/check.sh" > "$fixture/output" 2>&1; then
        echo "版本门禁错误放行：$1" >&2
        exit 1
    fi
}

printf '    <version>0.1.0</version>\n' > "$fixture/kaiwu-system-starter/pom.xml"
check_passes
KAIWU_TEST_CURL_EXIT=28
export KAIWU_TEST_CURL_EXIT
check_passes
grep -q '跳过 Central 存在性检查' "$fixture/output"
CI=true
export CI
check_fails 'CI 不能跳过 Central 存在性检查'
grep -q '失败：.*连不上 repo1.maven.org' "$fixture/output"
unset CI
KAIWU_TEST_CURL_EXIT=0
printf '    <version>0.1.1-SNAPSHOT</version>\n' > "$fixture/kaiwu-system-starter/pom.xml"
check_passes
KAIWU_TEST_CENTRAL_STATUS=404
export KAIWU_TEST_CENTRAL_STATUS
check_fails '开发 SNAPSHOT 不能让缺失的固定发布制品通过'
KAIWU_TEST_CENTRAL_STATUS=200
printf '    <version>0.1.1</version>\n' > "$fixture/kaiwu-system-starter/pom.xml"
check_fails '发布版本漂移仍须拒绝'
printf '    <version>0.1.0</version>\n' > "$fixture/kaiwu-system-starter/pom.xml"
printf '<kaiwu-system-starter.version>0.1.1</kaiwu-system-starter.version>\n' > "$system/pom.xml"
check_fails '平台编译与模板版本必须一致'
printf '<kaiwu-system-starter.version>0.1.0</kaiwu-system-starter.version>\n' > "$system/pom.xml"

# 任何 *STARTER_VERSION 常量是 SNAPSHOT 都必须失败，哪怕 STARTER_VERSION 本身已发布。
printf 'public static final String DATA_SCOPE_STARTER_VERSION = "0.1.1-SNAPSHOT";\n' > "$generator_dir/DataScope.java"
check_fails '附加的 Starter 版本常量是 SNAPSHOT'
grep -q 'DATA_SCOPE_STARTER_VERSION=0.1.1-SNAPSHOT 是开发快照' "$fixture/output"
rm "$generator_dir/DataScope.java"

# 根 pom 的版本属性同样不得是 SNAPSHOT。
printf 'public static final String STARTER_VERSION = "0.1.1-SNAPSHOT";\n' > "$generator_dir/ProjectScaffoldGenerator.java"
printf '<kaiwu-system-starter.version>0.1.1-SNAPSHOT</kaiwu-system-starter.version>\n' > "$system/pom.xml"
check_fails 'STARTER_VERSION 与 pom 同为 SNAPSHOT'
printf 'public static final String STARTER_VERSION = "0.1.0";\n' > "$generator_dir/ProjectScaffoldGenerator.java"
printf '<kaiwu-system-starter.version>0.1.0</kaiwu-system-starter.version>\n' > "$system/pom.xml"

# 其他常量（如最低版本）也要在 Central 上存在。
printf 'public static final String MIN_STARTER_VERSION = "0.1.0";\n' > "$generator_dir/Min.java"
check_passes
KAIWU_TEST_CENTRAL_STATUS=404
check_fails '最低版本常量指向未发布版本'
KAIWU_TEST_CENTRAL_STATUS=200
rm "$generator_dir/Min.java"

# 模板引用 kaiwu-data-scope 时，同版本的 data-scope 也必须在 Central 上。
printf '<groupId>com.kaiwuzaidao</groupId>\n<artifactId>kaiwu-system-starter</artifactId>\n<artifactId>kaiwu-data-scope</artifactId>\n' > "$template_dir/domain-pom.xml.ftl"
check_passes
grep -q 'kaiwu-data-scope/0.1.0' "$fixture/output"
KAIWU_TEST_DATA_SCOPE_STATUS=404
export KAIWU_TEST_DATA_SCOPE_STATUS
check_fails 'kaiwu-data-scope 未发布'
unset KAIWU_TEST_DATA_SCOPE_STATUS

# 任一文档单独引用 Excel 时都要检查精确的同版 POM；没有引用则不检查。
KAIWU_TEST_EXCEL_STATUS=404
export KAIWU_TEST_EXCEL_STATUS
check_passes
for doc in README.md.ftl AGENTS.md.ftl; do
    printf '%s\n' 'com.kaiwuzaidao:kaiwu-excel:${starterVersion}' > "$template_dir/$doc"
    check_fails "只有 $doc 引用的 kaiwu-excel 未发布"
    grep -q 'kaiwu-excel:0.1.0（HTTP 404）' "$fixture/output"
    rm "$template_dir/$doc"
done
printf '%s\n' 'com.kaiwuzaidao:kaiwu-excel:${starterVersion}' > "$template_dir/README.md.ftl"
unset KAIWU_TEST_EXCEL_STATUS
check_passes
grep -Fq 'kaiwu-excel/0.1.0/kaiwu-excel-0.1.0.pom' "$fixture/output"

rm "$fixture/bin/curl"
check_fails '本机和 CI 都必须有 curl 或 wget'
grep -q '失败：.*curl.*wget' "$fixture/output"

# Alpine 只有 BusyBox wget。成功响应写在 stderr，404 还会返回非零。
cat > "$fixture/bin/wget" <<'SH'
#!/bin/sh
case "${KAIWU_TEST_CENTRAL_STATUS}" in
    200) echo '  HTTP/1.1 200 OK' >&2 ;;
    404) echo 'wget: server returned error: HTTP/1.1 404 Not Found' >&2; exit 1 ;;
    000) echo 'wget: bad address' >&2; exit 1 ;;
esac
SH
chmod +x "$fixture/bin/wget"
CI=true
export CI
check_passes
grep -q 'Maven Central 上存在：.*kaiwu-excel/0.1.0' "$fixture/output"
grep -q 'Maven Central 上存在：.*kaiwu-data-scope/0.1.0' "$fixture/output"
grep -q 'Maven Central 上存在：.*kaiwu-system-starter/0.1.0' "$fixture/output"
KAIWU_TEST_CENTRAL_STATUS=404
check_fails 'wget 收到 404 时必须报告坐标未发布'
grep -q 'kaiwu-excel:0.1.0（HTTP 404）' "$fixture/output"
grep -q 'kaiwu-data-scope:0.1.0（HTTP 404）' "$fixture/output"
grep -q 'kaiwu-system-starter:0.1.0（HTTP 404）' "$fixture/output"
KAIWU_TEST_CENTRAL_STATUS=000
check_fails '仅有 wget 的 CI 连不上 Central'
grep -q '失败：.*连不上 repo1.maven.org' "$fixture/output"
unset CI
check_passes
grep -q '跳过 Central 存在性检查' "$fixture/output"
echo 'Starter 发布与开发版本策略回归通过。'
