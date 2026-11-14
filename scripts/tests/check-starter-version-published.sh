#!/bin/sh
set -eu

# 项目工厂生成的每个后端项目，pom 里都写死依赖
#   com.kaiwuzaidao:kaiwu-system-starter:<ProjectScaffoldGenerator.STARTER_VERSION>
# 开启数据范围的项目还会依赖同版本的 com.kaiwuzaidao:kaiwu-data-scope。
# 而生成的 pom 不声明任何 <repositories>，parent 是 spring-boot-starter-parent，
# 所以使用方的 Maven 只会去 Central 找。版本一旦指向 Central 上不存在的制品，
# 外部用户生成项目后第一次 mvn package 就是 Could not resolve dependencies，
# 而平台这边毫无察觉——常量在 system-service 仓，制品在 starter 仓，两者没有编译期关联。
#
# 本检查把这层跨仓耦合显式化：
#   1) 收集 kaiwu-system-domain/src/main 下所有 *STARTER_VERSION 常量与根 pom 的
#      kaiwu-system-starter.version，任何一个是 -SNAPSHOT 直接失败
#   2) 平台编译所用版本必须等于 STARTER_VERSION（生成项目所用版本）
#   3) 同工作区检出了发布版 starter 时，比对它的 pom 版本；开发 SNAPSHOT 单独验证
#   4) 每个版本对应的制品都必须在 Maven Central 上存在
# 仅本机网络不通时允许跳过第 4 步；CI 必须取得 Central 的响应。
# 不要为了让流水线变绿而放宽本脚本：版本未发布时，正确做法是等制品上 Central。

repo_root="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
workspace_root="$(CDPATH='' cd -- "$repo_root/.." && pwd)"

source_root="$repo_root/kaiwu-system-domain/src/main"
generator="$source_root/java/com/kaiwu/module/factory/renderer/ProjectScaffoldGenerator.java"
templates="$source_root/resources/templates/project"
template="$templates/backend/domain-pom.xml.ftl"

[ -f "$generator" ] || { echo "找不到 $generator"; exit 1; }
[ -f "$template" ] || { echo "找不到 $template"; exit 1; }

failed=0
fail() {
    echo "失败：$*"
    failed=1
}

# 1) 收集所有版本常量，格式为「常量名 版本」，每行一个。
constants="$(grep -rhoE '[A-Z_]*STARTER_VERSION[[:space:]]*=[[:space:]]*"[^"]*"' "$source_root/java" \
    | sed -E 's/^([A-Z_]*STARTER_VERSION)[[:space:]]*=[[:space:]]*"([^"]*)"$/\1 \2/' \
    | sort -u)"
[ -n "$constants" ] || { echo "无法在 $source_root 中找到任何 *STARTER_VERSION 常量"; exit 1; }

version="$(echo "$constants" | sed -n 's/^STARTER_VERSION //p' | head -1)"
[ -n "$version" ] || { echo "无法从 ProjectScaffoldGenerator 解析 STARTER_VERSION"; exit 1; }

own="$(sed -n 's/.*<kaiwu-system-starter\.version>\([^<]*\)<\/kaiwu-system-starter\.version>.*/\1/p' "$repo_root/pom.xml" | head -1)"
[ -n "$own" ] || { echo "失败：本仓 pom.xml 里找不到 kaiwu-system-starter.version 属性"; exit 1; }

group="$(grep -B1 'kaiwu-system-starter' "$template" | sed -n 's/.*<groupId>\([^<]*\)<\/groupId>.*/\1/p' | head -1)"
[ -n "$group" ] || { echo "无法从脚手架模板解析 starter 的 groupId"; exit 1; }

echo "脚手架将生成的依赖坐标：${group}:kaiwu-system-starter:${version}"
echo "待校验的版本："
echo "$constants" | sed 's/^/  /'
echo "  pom kaiwu-system-starter.version ${own}"

checked="$(printf '%s\npom %s\n' "$constants" "$own")"
snapshot="$(echo "$checked" | awk '$2 ~ /-SNAPSHOT$/')"
if [ -n "$snapshot" ]; then
    echo "$snapshot" | while read -r name value; do
        echo "失败：${name}=${value} 是开发快照。"
        echo "      SNAPSHOT 不在 Maven Central 上，生成项目和公开安装都无法解析它。"
    done
    failed=1
fi

# 2) 平台自己 compile 用的版本和告诉生成项目用的版本必须是同一个，否则平台侧验证过的
# 行为和用户拿到的 starter 并不是同一份代码。
if [ "$own" != "$version" ]; then
    fail "本仓 pom 依赖 starter ${own}，但 STARTER_VERSION=${version}。平台编译用的和生成项目用的必须是同一个版本。"
else
    echo "  本仓 pom 依赖版本一致：${own}"
fi

# 3) sibling 仓库比对
starter_pom="$workspace_root/kaiwu-system-starter/pom.xml"
if [ -f "$starter_pom" ]; then
    actual="$(sed -n 's/^    <version>\([^<]*\)<\/version>.*/\1/p' "$starter_pom" | head -1)"
    if [ -z "$actual" ]; then
        echo "警告：读到了 starter 的 pom 但没解析出版本，跳过本项比对"
    elif echo "$actual" | grep -q -- '-SNAPSHOT$'; then
        echo "  sibling 为开发版本 ${actual}；平台和模板继续验证已发布的 ${version}。"
        echo "  开发版须在 Starter 仓独立 verify，不替代平台所用制品，也不能直接写入公网模板。"
    elif [ "$actual" != "$version" ]; then
        fail "STARTER_VERSION=${version}，但同工作区 starter 仓的 pom 是 ${actual}。发布新版 starter 后，必须同步修改 ProjectScaffoldGenerator.STARTER_VERSION。"
    else
        echo "  sibling starter 仓版本一致：${actual}"
    fi
else
    echo "  未检出 sibling starter 仓，跳过版本比对"
fi

[ "$failed" -eq 0 ] || exit 1

# 4) Central 上是否真的存在：每个版本常量都查 Starter；模板引用 data-scope 时，
# 生成项目所用版本还要查 kaiwu-data-scope（它与 Starter 同版本发布）。
coordinates="$(echo "$checked" | awk '{print "kaiwu-system-starter " $2}')"
if grep -q '<artifactId>kaiwu-data-scope</artifactId>' "$template"; then
    coordinates="$(printf '%s\nkaiwu-data-scope %s\n' "$coordinates" "$version")"
fi
# 可选 Excel 未默认加入 pom，但 README、AGENTS 等生成文件也向使用方承诺可解析的坐标。
if grep -rq 'kaiwu-excel' "$templates"; then
    coordinates="$(printf '%s\nkaiwu-excel %s\n' "$coordinates" "$version")"
else
    [ "$?" -eq 1 ] || { echo "失败：无法扫描脚手架模板中的 Excel 依赖"; exit 1; }
fi
coordinates="$(echo "$coordinates" | sort -u)"

group_path="$(echo "$group" | tr '.' '/')"
if command -v curl >/dev/null 2>&1; then
    central_status() {
        curl -s --max-time 25 -o /dev/null -w '%{http_code}' "$1"
    }
elif command -v wget >/dev/null 2>&1; then
    central_status() {
        # BusyBox 和 GNU wget 均将响应头写到 stderr，HTTP 404 时命令本身也会失败。
        wget_failed=0
        response="$(LC_ALL=C wget -S -T 25 -t 1 -O /dev/null "$1" 2>&1)" || wget_failed=1
        printf '%s\n' "$response" | awk -v failed="$wget_failed" '
            { sub(/^wget: server returned error: /, "") }
            $1 ~ /^HTTP\// && $2 ~ /^[0-9][0-9][0-9]$/ { code = $2 }
            END {
                if (!code || (failed && code < 400)) print "000"
                else print code
            }'
    }
else
    echo "失败：检查 Maven Central 需要 curl 或 wget。"
    exit 1
fi

offline=0
for coordinate in $(echo "$coordinates" | tr ' ' ':'); do
    artifact="${coordinate%%:*}"
    artifact_version="${coordinate#*:}"
    url="https://repo1.maven.org/maven2/${group_path}/${artifact}/${artifact_version}/${artifact}-${artifact_version}.pom"
    if ! code="$(central_status "$url")"; then
        code=000
    fi
    case "$code" in
        200)
            echo "  Maven Central 上存在：$url"
            ;;
        000)
            offline=1
            ;;
        *)
            fail "Maven Central 上没有 ${group}:${artifact}:${artifact_version}（HTTP ${code}）。生成的项目不声明额外仓库，使用方只会去 Central 找，因此会直接解析失败。要么先把该版本发布到 Central，要么把常量改回已发布的版本。"
            ;;
    esac
done

if [ "$offline" -eq 1 ]; then
    if [ "${CI+x}" = x ]; then
        fail "CI 连不上 repo1.maven.org，无法确认制品已发布到 Maven Central。"
    else
        echo "  警告：连不上 repo1.maven.org，跳过 Central 存在性检查（环境问题，非代码问题）"
    fi
fi

[ "$failed" -eq 0 ] || exit 1

echo "starter 版本检查通过"
