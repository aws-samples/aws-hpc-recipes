"""Scan CloudFormation templates for hardcoded partition strings.

Catches 'arn:aws:' that should use ${AWS::Partition} instead.
Lines with '# partition-exception:' are excluded.
"""
import re
import sys
from pathlib import Path
from . import utils

HARDCODED_ARN = re.compile(r'arn:aws:')
PARTITION_SUB = re.compile(r'arn:\$\{AWS::Partition\}:')
EXCEPTION_MARKER = "partition-exception:"


def find_cfn_files():
    patterns = ["*.yaml", "*.yml", "*.json"]
    files = []
    for asset_dir in utils.RECIPES.rglob("assets"):
        if asset_dir.is_dir():
            for pat in patterns:
                files.extend(asset_dir.glob(pat))
    return sorted(files)


def check_file(filepath):
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for lineno, line in enumerate(f, start=1):
                if EXCEPTION_MARKER in line:
                    continue
                stripped = line.lstrip()
                if stripped.startswith("#"):
                    continue
                if HARDCODED_ARN.search(line) and not PARTITION_SUB.search(line):
                    violations.append((lineno, line.rstrip()))
    except Exception:
        pass
    return violations


def main():
    cfn_files = find_cfn_files()
    if not cfn_files:
        print("WARNING: No CloudFormation template files found.")
        sys.exit(0)
    all_violations = []
    for fp in cfn_files:
        rel = fp.relative_to(utils.REPO)
        for lineno, line in check_file(fp):
            all_violations.append(f"{rel}:{lineno}: {line}")
    if all_violations:
        print(f"Partition safety FAILED ({len(all_violations)} violations):")
        print("Use !Sub arn:${AWS::Partition}: instead of arn:aws:")
        print("To suppress: add '# partition-exception: <reason>'\n")
        for v in all_violations:
            print(f"  {v}")
        sys.exit(1)
    else:
        print(f"Partition safety passed: {len(cfn_files)} files scanned.")


main()
