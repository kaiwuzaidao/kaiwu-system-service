#!/bin/sh
set -eu

# 项目工厂生成的每个后端项目，pom 里都写死依赖
#   com.kaiwuzaidao:kaiwu-system-starter:<ProjectScaffoldGenerator.STARTER_VERSION>
# 而生成的 pom 不声明任何 <repositories>，parent 是 spring-boot-starter-parent，
# 所以使用方的 Maven 只会去 Central 找。这个常量一旦指向 Central 上不存在的版本，
# 外部用户生成项目后第一次 mvn package 就是 Could not resolve dependencies，
# 而平台这边毫无察觉——常量在 system-service 仓，制品在 starter 仓，两者没有编译期关联。
#
# 本检查把这层跨仓耦合显式化：
#   1) 同工作区检出了 starter 时，比对它的 pom 版本（离线、最快发现漂移）
#   2) 无论如何，确认该版本在 Maven Central 上确实存在
# 网络不通时跳过第 2 步而不是判失败——那是环境问题，不是代码问题。

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
workspace_root="$(CDPATH= cd -- "$repo_root/.." && pwd)"

generator="$repo_root/kaiwu-system-domain/src/main/java/com/kaiwu/module/projectgeneration/ProjectScaffoldGenerator.java"
template="$repo_root/kaiwu-system-domain/src/main/resources/templates/project/backend/domain-pom.xml.ftl"

[ -f "$generator" ] || { echo "找不到 $generator"; exit 1; }
[ -f "$template" ] || { echo "找不到 $template"; exit 1; }

version="$(sed -n 's/.*STARTER_VERSION *= *"\([^"]*\)".*/\1/p' "$generator" | head -1)"
[ -n "$version" ] || { echo "无法从 ProjectScaffoldGenerator 解析 STARTER_VERSION"; exit 1; }

group="$(grep -B1 'kaiwu-system-starter' "$template" | sed -n 's/.*<groupId>\([^<]*\)<\/groupId>.*/\1/p' | head -1)"
[ -n "$group" ] || { echo "无法从脚手架模板解析 starter 的 groupId"; exit 1; }

echo "脚手架将生成的依赖坐标：${group}:kaiwu-system-starter:${version}"

# 1) 本仓自身编译所用的 starter 版本
# 平台自己 compile 用的版本和告诉生成项目用的版本必须是同一个，否则平台侧验证过的
# 行为和用户拿到的 starter 并不是同一份代码。
own="$(sed -n 's/.*<kaiwu-system-starter\.version>\([^<]*\)<\/kaiwu-system-starter\.version>.*/\1/p' "$repo_root/pom.xml" | head -1)"
if [ -z "$own" ]; then
    echo "失败：本仓 pom.xml 里找不到 kaiwu-system-starter.version 属性"
    exit 1
elif [ "$own" != "$version" ]; then
    echo "失败：本仓 pom 依赖 starter ${own}，但 STARTER_VERSION=${version}。"
    echo "      平台编译用的和生成项目用的必须是同一个版本。"
    exit 1
else
    echo "  本仓 pom 依赖版本一致：${own}"
fi

# 2) sibling 仓库比对
starter_pom="$workspace_root/kaiwu-system-starter/pom.xml"
if [ -f "$starter_pom" ]; then
    actual="$(sed -n 's/^    <version>\([^<]*\)<\/version>.*/\1/p' "$starter_pom" | head -1)"
    if [ -z "$actual" ]; then
        echo "警告：读到了 starter 的 pom 但没解析出版本，跳过本项比对"
    elif [ "$actual" != "$version" ]; then
        echo "失败：STARTER_VERSION=${version}，但同工作区 starter 仓的 pom 是 ${actual}。"
        echo "      发布新版 starter 后，必须同步修改 ProjectScaffoldGenerator.STARTER_VERSION。"
        exit 1
    else
        echo "  sibling starter 仓版本一致：${actual}"
    fi
else
    echo "  未检出 sibling starter 仓，跳过版本比对"
fi

# 3) Central 上是否真的存在
path="$(echo "$group" | tr '.' '/')/kaiwu-system-starter/${version}/kaiwu-system-starter-${version}.pom"
url="https://repo1.maven.org/maven2/${path}"
code="$(curl -s --max-time 25 -o /dev/null -w '%{http_code}' "$url" || echo "000")"

case "$code" in
    200)
        echo "  Maven Central 上存在：$url"
        ;;
    000)
        echo "  警告：连不上 repo1.maven.org，跳过 Central 存在性检查（环境问题，非代码问题）"
        ;;
    *)
        echo "失败：Maven Central 上没有 ${group}:kaiwu-system-starter:${version}（HTTP ${code}）。"
        echo "      生成的项目不声明额外仓库，使用方只会去 Central 找，因此会直接解析失败。"
        echo "      要么先把该版本发布到 Central，要么把 STARTER_VERSION 改回已发布的版本。"
        exit 1
        ;;
esac

echo "starter 版本检查通过"
