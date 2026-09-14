<#noparse>#!/usr/bin/env bash
#
# 报告测试基线：Controller 和 Service 是否有对应的测试类。
#
# 存在的意义：`mvn verify` 只运行**存在的**测试，删掉测试文件 CI 照样全绿。
# 多 AI 多轮迭代时，"测试挡路就删掉"是最省事也最常见的一种退化，而它在任何构建产物里
# 都看不出来。这个脚本让测试基线的消失变成 CI 红灯。
#
# 只检查存在性，不检查覆盖率：覆盖率门禁会诱导为凑数字而写的空测试，
# 而"这个类有人在测"是能机器判断且不容易造假的最低线。
#
# 默认只告警，不阻断业务推进；模板自身用 --strict 防止首版测试骨架被误删。
# 退出码：0 通过或默认告警；1 仅在 --strict 下有类缺测试。
set -euo pipefail

strict=false
if [ "${1:-}" = "--strict" ]; then
  strict=true
elif [ "$#" -gt 0 ]; then
  echo "用法：$0 [--strict]" >&2
  exit 2
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
missing=()
checked=0

while IFS= read -r source_file; do
  class_name="$(basename "${source_file}" .java)"
  case "${class_name}" in
    *Controller|*Service) ;;
    *) continue ;;
  esac
  checked=$((checked + 1))
  # 测试类允许放在任意 src/test 目录下，只要类名匹配即可，不绑定包路径——
  # 重构包结构不应该让门禁误报。
  if ! find "${repo_dir}" -path '*/src/test/java/*' \
      -name "${class_name}Test.java" -print -quit | grep -q .; then
    missing+=("${class_name}  (${source_file#"${repo_dir}"/})")
  fi
done < <(find "${repo_dir}" -path '*/src/main/java/*' \
  \( -name '*Controller.java' -o -name '*Service.java' \) | sort)

if [ "${checked}" -eq 0 ]; then
  echo "[check:test] 未发现 Controller/Service，跳过。"
  exit 0
fi

if [ "${#missing[@]}" -gt 0 ]; then
  echo "[check:test] WARN：以下类缺少同名测试，请优先补领域行为、权限反例或接口契约测试：" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  if [ "${strict}" = true ]; then
    echo "  --strict 已启用，测试骨架缺失会阻断模板验证。" >&2
    exit 1
  fi
  echo "  默认模式只报告，不以测试文件命名替代行为覆盖。" >&2
  exit 0
fi

echo "[check:test] 测试基线完整：${checked} 个 Controller/Service 均有对应测试类。"
</#noparse>
