"""Run ShellCheck across recipe shell scripts with a two-tier policy.

Strict tier (blocking): every shell script under recipes/pcs-scripts/ MUST pass
ShellCheck at default severity. A finding here fails the build.

Advisory tier (non-blocking): shell scripts elsewhere are checked at
warning-and-above severity and any findings are reported for awareness, but do
not fail the build. This lets existing scripts be cleaned up over time without
blocking unrelated work.

Vendored/generated files (e.g. Terraform module internals under .terraform/) are
skipped entirely.

If the `shellcheck` binary is not installed, the strict tier cannot be enforced;
the script prints a warning and exits non-zero so CI installs it. Set
SHELLCHECK_OPTIONAL=1 to downgrade a missing binary to a skip (used for local
convenience where shellcheck may be absent).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from . import utils

# Scripts under this path must pass ShellCheck cleanly.
STRICT_PREFIX = Path.joinpath(utils.RECIPES, "pcs-scripts")

# Severity floor for the advisory tier.
ADVISORY_SEVERITY = "warning"

# Path fragments to skip entirely (vendored or generated code).
SKIP_FRAGMENTS = ("/.terraform/",)


def find_shell_scripts():
    """Return (strict, advisory) lists of *.sh paths under recipes/."""
    strict, advisory = [], []
    for path in sorted(utils.RECIPES.rglob("*.sh")):
        posix = path.as_posix()
        if any(frag in posix for frag in SKIP_FRAGMENTS):
            continue
        try:
            path.relative_to(STRICT_PREFIX)
            strict.append(path)
        except ValueError:
            advisory.append(path)
    return strict, advisory


def run_shellcheck(path, severity=None):
    """Run shellcheck on one file. Return (ok, output)."""
    cmd = ["shellcheck"]
    if severity:
        cmd.append(f"--severity={severity}")
    cmd.append(str(path))
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode == 0, (proc.stdout + proc.stderr).strip()


def main():
    strict, advisory = find_shell_scripts()

    if shutil.which("shellcheck") is None:
        msg = "ShellCheck is not installed."
        if os.environ.get("SHELLCHECK_OPTIONAL") == "1":
            print(f"WARNING: {msg} Skipping (SHELLCHECK_OPTIONAL=1).")
            sys.exit(0)
        print(f"ERROR: {msg} Install it to enforce the pcs-scripts gate.")
        print("  Debian/Ubuntu: apt-get install -y shellcheck")
        print("  macOS: brew install shellcheck")
        print("  Or set SHELLCHECK_OPTIONAL=1 to skip locally.")
        sys.exit(1)

    # --- Advisory tier: report warning+ findings, never fail ----------------
    advisory_hits = 0
    for path in advisory:
        ok, output = run_shellcheck(path, severity=ADVISORY_SEVERITY)
        if not ok and output:
            advisory_hits += 1
            rel = path.relative_to(utils.REPO)
            print(f"[advisory] {rel}")
            for line in output.splitlines():
                print(f"    {line}")
    if advisory_hits:
        print(
            f"\nAdvisory: {advisory_hits} script(s) outside pcs-scripts have "
            f"ShellCheck findings at severity>={ADVISORY_SEVERITY} "
            "(non-blocking).\n"
        )
    else:
        print(
            f"Advisory: no ShellCheck findings at severity>={ADVISORY_SEVERITY} "
            f"across {len(advisory)} script(s) outside pcs-scripts.\n"
        )

    # --- Strict tier: any finding fails the build ---------------------------
    strict_failures = []
    for path in strict:
        ok, output = run_shellcheck(path)
        if not ok:
            rel = path.relative_to(utils.REPO)
            strict_failures.append((rel, output))

    if strict_failures:
        print(f"ShellCheck FAILED ({len(strict_failures)} script(s) in pcs-scripts):")
        print("Every script under recipes/pcs-scripts/ must pass ShellCheck.\n")
        for rel, output in strict_failures:
            print(f"  {rel}")
            for line in output.splitlines():
                print(f"    {line}")
        sys.exit(1)

    print(f"ShellCheck passed: {len(strict)} script(s) in pcs-scripts are clean.")


main()
