#!/usr/bin/env bash
# shellcheck disable=SC2016  # the date stub is written with literal $LC_ALL and $@
set -euo pipefail

# Git-fixture tests for scripts/check-freshness-dates.sh.

# Git hooks export GIT_DIR and friends; fixture repos must not inherit them.
while IFS= read -r var; do unset "$var"; done < <(git rev-parse --local-env-vars)
# Nor the host's hooks, signing, or templates.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CASES=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  [[ -z "${OUT:-}" ]] || printf '%s\n' "$OUT" >&2
  exit 1
}

# new_fixture <tracked file> <its one line>
new_fixture() {
  REPO="$TMP/repo-$CASES"
  CASES=$((CASES + 1))
  OUT=""
  mkdir -p "$REPO/scripts" "$(dirname "$REPO/$1")"
  cp "$ROOT/scripts/check-freshness-dates.sh" "$REPO/scripts/check-freshness-dates.sh"
  printf '%s\n' "$2" > "$REPO/$1"
  git -C "$REPO" init -q
  git -C "$REPO" add "$1"
}

run_check() {
  STATUS=0
  OUT="$(cd "$REPO" && "$@" bash scripts/check-freshness-dates.sh 2>&1)" || STATUS=$?
}

# A date that answers in another language unless the caller asks for the C locale.
STUB="$TMP/stub"
mkdir -p "$STUB"
printf '#!/usr/bin/env bash\nif [[ "${LC_ALL:-}" == C ]]; then exec "%s" "$@"; fi\necho "Kaimana 2026"\n' \
  "$(command -v date)" > "$STUB/date"
chmod +x "$STUB/date"

current_label="$(LC_ALL=C date +'%B %Y')"

new_fixture skills/alpha/SKILL.md "Pins verified $current_label."
run_check env PATH="$STUB:$PATH" LC_ALL=xx_XX.UTF-8
(( STATUS == 0 )) || fail "current marker under a non-English locale: expected exit 0, got $STATUS"

# README.md and INSTALL.md are scanned, not only files under skills/.
for doc in README.md INSTALL.md skills/alpha/SKILL.md; do
  new_fixture "$doc" "Pins verified January 2020."
  run_check env
  (( STATUS != 0 )) || fail "stale marker in $doc: expected failure, got exit 0"
  [[ "$OUT" == *"stale freshness marker in $doc:1"* ]] || fail "stale marker in $doc: finding not printed"
done

printf 'freshness-date tests passed (%d cases)\n' "$CASES"
