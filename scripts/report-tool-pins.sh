#!/usr/bin/env bash
set -euo pipefail

# Advisory, networked report: compares the checksum-pinned CI binaries in
# .github/workflows/lint.yml with each project's latest GitHub release.
# Dependabot cannot see these pins, so the weekly tool-pins workflow runs this.
# Not a gate: it never runs in Quality Gates.
#
# Usage: report-tool-pins.sh [--issue]
#   Prints one line per pin and exits 0. With --issue, opens or updates a
#   single tracking issue while any pin is behind and closes it once all are
#   current (needs GH_TOKEN with issues: write).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/lint.yml"
ISSUE_TITLE="CI binary pins behind upstream"

# env var prefix in lint.yml -> upstream repository
declare -A REPOS=(
  [LYCHEE]=lycheeverse/lychee
  [ACTIONLINT]=rhysd/actionlint
  [GITLEAKS]=gitleaks/gitleaks
)

pinned_version() {
  sed -nE "s/^[[:space:]]*$1_VERSION:[[:space:]]*\"?([^\"[:space:]]+)\"?.*/\1/p" "$WORKFLOW" | head -n 1
}

normalize() {
  local v="$1"
  v="${v##*-v}"
  v="${v#v}"
  printf '%s' "$v"
}

stale=()
for tool in LYCHEE ACTIONLINT GITLEAKS; do
  repo="${REPOS[$tool]}"
  pinned="$(pinned_version "$tool")"
  if [[ -z "$pinned" ]]; then
    echo "ERROR: no ${tool}_VERSION pin found in $WORKFLOW" >&2
    exit 1
  fi
  tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name)"
  latest="$(normalize "$tag")"
  if [[ "$latest" == "$pinned" ]]; then
    printf 'current  %-10s %s\n' "$tool" "$pinned"
  else
    printf 'behind   %-10s %s -> %s (%s)\n' "$tool" "$pinned" "$latest" "$repo"
    stale+=("- ${tool,,}: pinned ${pinned}, latest ${latest} (https://github.com/${repo}/releases/tag/${tag})")
  fi
done

[[ "${1:-}" == "--issue" ]] || exit 0

existing="$(gh issue list --state open --search "\"$ISSUE_TITLE\" in:title" --json number,title \
  --jq ".[] | select(.title == \"$ISSUE_TITLE\") | .number" | head -n 1)"

if (( ${#stale[@]} == 0 )); then
  if [[ -n "$existing" ]]; then
    gh issue close "$existing" --comment "All checksum-pinned CI binaries match their latest release."
    echo "Closed issue #$existing"
  fi
  exit 0
fi

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
{
  echo "These CI binaries are pinned with a checksum in .github/workflows/lint.yml and are behind their latest release:"
  echo
  printf '%s\n' "${stale[@]}"
  echo
  echo "Update the version and the matching *_SHA256 value from the release's published checksums, then let Quality Gates run. Reported by the weekly tool-pins workflow."
} > "$body"

if [[ -n "$existing" ]]; then
  gh issue edit "$existing" --body-file "$body" >/dev/null
  echo "Updated issue #$existing"
else
  gh issue create --title "$ISSUE_TITLE" --body-file "$body"
fi
