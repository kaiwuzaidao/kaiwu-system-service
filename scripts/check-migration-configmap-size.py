#!/usr/bin/env python3
"""从实际 Helm 模板读取迁移 ConfigMap，按方言检查解码后的 data 字节数。"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

LIMIT = 900 * 1024
CHART = Path(__file__).resolve().parents[1] / "deploy/helm/kaiwu"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chart", type=Path, default=CHART)
    args = parser.parse_args()
    if not shutil.which("helm"):
        sys.exit("缺少 helm，无法渲染迁移 ConfigMap。请安装 Helm 3 后重试。")
    try:
        import yaml
    except ImportError:
        sys.exit("缺少 PyYAML，无法解析 Helm 输出。请安装 PyYAML 后重试。")

    passed = True
    for dialect in ("mysql", "dm"):
        command = [
            "helm", "template", "size-check", str(args.chart),
            "--show-only", "templates/migrations-configmap.yaml",
            "--set", "migration.enabled=true", "--set", f"database.type={dialect}",
            "--set", "database.embedded=false", "--set-string", "database.host=db.example.test",
        ]
        rendered = subprocess.check_output(command)
        obj = yaml.safe_load(rendered)
        if not isinstance(obj, dict) or obj.get("kind") != "ConfigMap":
            sys.exit(f"{dialect}: 模板应生成一个迁移 ConfigMap")
        data = obj.get("data")
        if not isinstance(data, dict) or not data or not all(isinstance(v, str) for v in data.values()):
            sys.exit(f"{dialect}: ConfigMap.data 缺失、为空或包含非字符串")
        size = sum(len(value.encode("utf-8")) for value in data.values())
        print(f"{dialect}: data={size} bytes, keys={len(data)}, limit={LIMIT} bytes", flush=True)
        if size > LIMIT:
            print(f"{dialect}: 迁移 ConfigMap 超过 900 KiB，请改用独立迁移器镜像。", file=sys.stderr)
            passed = False
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
