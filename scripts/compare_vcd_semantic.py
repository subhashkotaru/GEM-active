#!/usr/bin/env python3
import argparse
import itertools
import sys


def semantic_lines(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            if line.startswith("$") or line.startswith("//"):
                continue
            if line.startswith("#") or line[0] in "01xz" or line.startswith("b") or line.startswith("r"):
                yield line


def compare(a_path, b_path):
    for idx, (left, right) in enumerate(
        itertools.zip_longest(semantic_lines(a_path), semantic_lines(b_path))
    ):
        if left != right:
            print("Mismatch at semantic line", idx)
            print("A:", left)
            print("B:", right)
            return 1
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="Semantic VCD compare that ignores headers and comments."
    )
    parser.add_argument("vcd_a")
    parser.add_argument("vcd_b")
    args = parser.parse_args()
    return compare(args.vcd_a, args.vcd_b)


if __name__ == "__main__":
    sys.exit(main())
