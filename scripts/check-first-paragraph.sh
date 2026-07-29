#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set +e
output="$(python3 - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
flagged = 0
for p in sorted((root / "skills").glob("*/SKILL.md")):
    body = p.read_text().split("---", 2)[2]
    m = re.search(r"^# .+?\n+(.+?)(?:\n\n|\n\*\*)", body, re.S | re.M)
    para = " ".join(m.group(1).split()) if m else "(none)"
    flags = []
    if para.startswith("**"):
        flags.append("STARTS-WITH-BOLD-BLOCK")
    if len(para) > 350:
        flags.append("TOO-LONG")
    if len(para) < 110:
        flags.append("TOO-SHORT")
    if para.rstrip().endswith(":"):
        flags.append("ENDS-IN-COLON")
    if re.search(r"\d+\.\d+\.\d+", para):
        flags.append("CONTAINS-VERSION")
    if flags:
        flagged += 1
        print(f"{p.parent.name} {len(para)} {','.join(flags)}")
        print(f"    {para[:160]}")

sys.exit(1 if flagged else 0)
PY
)"
status=$?
set -e

if [[ -n "$output" ]]; then
  printf '[!] first-paragraph check failed for the following skills:\n' >&2
  printf '%s\n' "$output" >&2
fi

if (( status != 0 )); then
  exit 1
fi

printf 'All skill first paragraphs pass the storefront-copy check.\n'
