#!/usr/bin/env bash
set -euo pipefail

# Tests for scripts/report-tool-pins.sh with a stubbed gh, plus the assertion
# that the Renovate custom manager in renovate.json still finds the zizmor
# version in .github/workflows/security.yml.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/report-tool-pins.sh"
CASES=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  [[ -z "${OUT:-}" ]] || printf '%s\n' "$OUT" >&2
  exit 1
}

pin() {
  sed -nE "s/^[[:space:]]*$1_VERSION:[[:space:]]*\"([^\"]+)\".*/\1/p" \
    "$ROOT/.github/workflows/ci.yml" "$ROOT/.github/workflows/security.yml" | head -n 1
}

LYCHEE="$(pin LYCHEE)"
ACTIONLINT="$(pin ACTIONLINT)"
GITLEAKS="$(pin GITLEAKS)"
[[ -n "$LYCHEE" && -n "$ACTIONLINT" && -n "$GITLEAKS" ]] || fail "could not read the workflow pins"

# Stub gh: release tags come from $TMP/tags (one "<repo> <tag>" per line), every
# call is logged, and an issue body file is copied for inspection.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$STUB_DIR/calls"
case "$1 $2" in
  "api repos/"*)
    repo="${2#repos/}"
    repo="${repo%/releases/latest}"
    while IFS=' ' read -r name tag; do
      if [[ "$name" == "$repo" ]]; then
        printf '%s\n' "$tag"
        exit 0
      fi
    done < "$STUB_DIR/tags"
    exit 1
    ;;
  "issue list")
    cat "$STUB_DIR/existing"
    ;;
  "issue create" | "issue edit")
    while (( $# > 0 )); do
      if [[ "$1" == "--body-file" ]]; then
        cp "$2" "$STUB_DIR/body"
      fi
      shift
    done
    ;;
  "issue close") ;;
  *)
    echo "unexpected gh call: $*" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$TMP/bin/gh"

# run <lychee tag> <actionlint tag> <gitleaks tag> [script args...]
run() {
  printf 'lycheeverse/lychee %s\nrhysd/actionlint %s\ngitleaks/gitleaks %s\n' "$1" "$2" "$3" > "$TMP/tags"
  shift 3
  rm -f "$TMP/calls" "$TMP/body"
  : > "$TMP/calls"
  RC=0
  OUT="$(STUB_DIR="$TMP" PATH="$TMP/bin:$PATH" "$SCRIPT" "$@" 2>&1)" || RC=$?
  CASES=$((CASES + 1))
}

: > "$TMP/existing"

run "lychee-v$LYCHEE" "v$ACTIONLINT" "v$GITLEAKS"
(( RC == 0 )) || fail "current pins should exit 0, got $RC"
[[ "$(grep -c '^current ' <<<"$OUT")" == 3 ]] || fail "current pins should print three current lines"

run "lychee-v$LYCHEE" "v$ACTIONLINT" "v$GITLEAKS" --issue
(( RC == 0 )) || fail "current pins with --issue should exit 0, got $RC"
! grep -qE '^issue (create|edit|close)' "$TMP/calls" || fail "no open issue and nothing behind should not write an issue"

run "lychee-v999.0.0" "v$ACTIONLINT" "v$GITLEAKS" --issue
(( RC == 0 )) || fail "a pin behind upstream should still exit 0, got $RC"
grep -q '^behind   LYCHEE' <<<"$OUT" || fail "a newer lychee release should be reported behind"
grep -q '^issue create' "$TMP/calls" || fail "a pin behind upstream should open the issue"
grep -qF "latest 999.0.0 (https://github.com/lycheeverse/lychee/releases/tag/lychee-v999.0.0)" "$TMP/body" \
  || fail "the issue body should link the upstream release"

echo 7 > "$TMP/existing"
run "lychee-v$LYCHEE" "v$ACTIONLINT" "v$GITLEAKS" --issue
(( RC == 0 )) || fail "closing the issue should exit 0, got $RC"
grep -q '^issue close 7' "$TMP/calls" || fail "all pins current should close the open issue"

# A tag that is not a plain tag name must never reach the issue body.
for hostile in 'v9.9.9)[x](https://example.com/' 'v9.9.9<img>' '-v9.9.9' 'v9.9.9..x'; do
  run "lychee-v$LYCHEE" "$hostile" "v$GITLEAKS" --issue
  (( RC == 1 )) || fail "tag '$hostile' should exit 1, got $RC"
  grep -q 'unexpected tag name' <<<"$OUT" || fail "tag '$hostile' should be named as unexpected"
  ! grep -qE '^issue ' "$TMP/calls" || fail "tag '$hostile' should not read or write the issue"
done
: > "$TMP/existing"

# The Renovate custom manager must match the zizmor version in security.yml.
CASES=$((CASES + 1))
OUT="$(python3 - "$ROOT/renovate.json" "$ROOT/.github/workflows/security.yml" <<'PY' 2>&1
import json
import re
import sys

config = json.load(open(sys.argv[1], encoding="utf-8"))
workflow = open(sys.argv[2], encoding="utf-8").read()
managers = [m for m in config.get("customManagers", []) if m.get("depNameTemplate") == "zizmorcore/zizmor"]
if len(managers) != 1:
    sys.exit(f"expected one zizmor custom manager, found {len(managers)}")
manager = managers[0]
if not any(re.fullmatch(p.strip("/"), ".github/workflows/security.yml") for p in manager["managerFilePatterns"]):
    sys.exit("the zizmor custom manager does not match .github/workflows/security.yml")
found = []
for pattern in manager["matchStrings"]:
    found += [m.group("currentValue") for m in re.finditer(pattern.replace("(?<", "(?P<"), workflow)]
pinned = re.findall(r'^\s+version: "([^"]+)"', workflow, flags=re.M)
if len(found) != 1 or found != pinned or not re.fullmatch(r"\d+(\.\d+)+", found[0]):
    sys.exit(f"custom manager found {found}, security.yml pins {pinned}")
if not re.fullmatch(manager["extractVersionTemplate"].replace("(?<", "(?P<"), "v" + found[0]):
    sys.exit("extractVersionTemplate does not accept a v-prefixed release tag")
PY
)" || fail "renovate.json no longer tracks the zizmor version in security.yml"

printf 'report-tool-pins tests passed (%d cases).\n' "$CASES"
