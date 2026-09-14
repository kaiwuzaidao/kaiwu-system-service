#!/usr/bin/env sh
set -eu
export MAVEN_SKIP_RC=1

java_bin="${JAVA_HOME:+$JAVA_HOME/bin/}java"
java_version="$("$java_bin" -version 2>&1 | head -n 1)"
case "$java_version" in
  *'"21.'*) ;;
  *) echo "Kaiwu System 必须使用 JDK 21，当前：$java_version（JAVA_HOME=${JAVA_HOME:-未设置}）" >&2; exit 1 ;;
esac
mvn_version="$(mvn -version 2>&1)"
echo "$mvn_version" | grep -q 'Java version: 21\.' || {
  echo "Maven 未使用 JDK 21：$mvn_version" >&2
  exit 1
}

mvn ${MAVEN_CLI_OPTS:-} -s .mvn/settings.xml verify
exec ./scripts/verify-generated-scaffold.sh
