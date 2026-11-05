#!/usr/bin/env python3
"""Fail if any scanner suppression lacks a reason.

A gate anyone can silence is theatre. An inline `checkov:skip` or `trivy:ignore`
is allowed only when it carries a reason, so every suppression is a decision on
the record, not a quiet mute. This script fails the build if it finds a bare
suppression in the given directory (default: infra).

Expected shapes:
  # checkov:skip=CKV_AWS_123:<reason>
  # trivy:ignore:AVD-AWS-0123 <reason>
"""
import re
import sys
import pathlib

CHECKOV = re.compile(r"checkov:skip=([A-Za-z0-9_]+)(?::(.*))?")
TRIVY = re.compile(r"trivy:ignore:([A-Za-z0-9-]+)(.*)")


def main() -> int:
    target = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "infra")
    bad = []
    count = 0
    for tf in sorted(target.rglob("*.tf")):
        for num, line in enumerate(tf.read_text().splitlines(), start=1):
            for m in CHECKOV.finditer(line):
                count += 1
                reason = (m.group(2) or "").strip()
                if not reason:
                    bad.append(f"{tf}:{num}: checkov skip {m.group(1)} has no reason")
            for m in TRIVY.finditer(line):
                count += 1
                reason = (m.group(2) or "").strip()
                if not reason:
                    bad.append(f"{tf}:{num}: trivy ignore {m.group(1)} has no reason")

    if bad:
        print("Suppressions without a reason (every skip must say why):")
        for b in bad:
            print("  " + b)
        return 1

    print(f"OK: all {count} suppression(s) in {target}/ carry a reason.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
