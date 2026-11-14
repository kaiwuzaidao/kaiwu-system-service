#!/bin/bash
# compare.sh full|public mysql|dm 旧库本机端口 旧库名 新库本机端口 新库名 空输出目录
# 使用 JDK 21、对应 JDBC 驱动与仅供验证的一次性库。两边须使用相同的种子迁移输入和时钟。
set -eu
here=$(cd "$(dirname "$0")" && pwd)
case "$1" in
  full) old=full-old; new=candidate ;;
  public) old=public; new=public ;;
  *) echo '请选择 full 或 public 比对模式' >&2; exit 2 ;;
esac
case "$2" in mysql|dm) ;; *) exit 2 ;; esac
: "${R4_JDBC_CLASSPATH:?请提供对应数据库的 JDBC 驱动类路径}"
dest=$7
mkdir -p "$dest"
if [ -n "$(ls -A "$dest")" ]; then echo "需要空输出目录" >&2; exit 2; fi
R4_FIXTURE_PASSWORD="${R4_OLD_PASSWORD-}" java -cp "$R4_JDBC_CLASSPATH" "$here/Snapshot.java" "$2" "$3" "$4" "$old" "$dest/old" >"$dest/old.txt"
R4_FIXTURE_PASSWORD="${R4_NEW_PASSWORD-}" java -cp "$R4_JDBC_CLASSPATH" "$here/Snapshot.java" "$2" "$5" "$6" "$new" "$dest/new" >"$dest/new.txt"
diff -qr "$dest/old" "$dest/new"
