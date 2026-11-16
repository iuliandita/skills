#!/usr/bin/env bash
set -euo pipefail

# Storefront-copy check for the first paragraph of every public skill. The
# skill set is the shared list_public_skills (so gitignored local skills and
# deprecated notices are out), and the body starts where the shared
# frontmatter parser says the frontmatter ends.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=./scripts/skill-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/skill-lib.sh"
cd "$ROOT"

frontmatter_cache_load skills flag:metadata.deprecated

files=()
while IFS= read -r name; do
  [[ -n "$name" ]] && files+=("skills/$name/SKILL.md")
done <<< "$(list_public_skills skills)"
if (( ${#files[@]} == 0 )); then
  printf '[!] first-paragraph check found no public skills under skills/\n' >&2
  exit 1
fi

set +e
output="$(python3 - "$FRONTMATTER_PY" "${files[@]}" <<'PY'
import importlib.util
import pathlib
import re
import sys

spec = importlib.util.spec_from_file_location("skill_frontmatter", sys.argv[1])
frontmatter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frontmatter)

flagged = 0
for arg in sys.argv[2:]:
    p = pathlib.Path(arg)
    try:
        frontmatter.load_frontmatter(str(p))
    except (OSError, ValueError) as exc:
        flagged += 1
        print(f"{p.parent.name} 0 INVALID-FRONTMATTER")
        print(f"    {exc}")
        continue
    # load_frontmatter accepted the file, so line 1 is the opening fence and
    # the next line that is exactly "---" closes it.
    lines = p.read_text(encoding="utf-8").splitlines()
    body = "\n".join(lines[lines[1:].index("---") + 2 :]) + "\n"
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
