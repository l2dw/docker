#!/usr/bin/env python3
"""Render teleport.yaml from the example (cluster_name + public_addr)."""
import sys


def main() -> None:
    if len(sys.argv) != 5:
        print("usage: render-config.py SRC DST CLUSTER_NAME PUBLIC_ADDR", file=sys.stderr)
        sys.exit(2)
    src, dst, cluster, paddr = sys.argv[1:5]
    text = open(src, encoding="utf-8").read()
    out = []
    for line in text.splitlines(True):
        stripped = line.lstrip()
        indent = line[: len(line) - len(stripped)]
        if stripped.startswith("cluster_name:"):
            line = f"{indent}cluster_name: {cluster}\n"
        elif stripped.startswith("public_addr:"):
            line = f"{indent}public_addr: {paddr}\n"
        out.append(line)
    open(dst, "w", encoding="utf-8").writelines(out)


if __name__ == "__main__":
    main()
