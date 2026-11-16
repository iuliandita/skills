#!/usr/bin/env bash
set -euo pipefail

# Advisory, networked report: compares the checksum-pinned CI binaries in
# .github/workflows/ci.yml and security.yml with each project's latest GitHub
# release. Renovate cannot see these pins, so the weekly Tool Pins workflow
# runs this. Not a gate: it never runs in CI or Security. The zizmor version
# in security.yml is not listed here: a Renovate custom manager tracks it.
#
# Usage: report-tool-pins.sh [--issue]
#   Prints one line per pin and exits 0. With --issue, opens or updates a
#   single tracking issue while any pin is behind and closes it once all are
#   current (needs GH_TOKEN with issues: write).
#   Exits 1, without touching the issue, when a pin is missing or an upstream
#   tag name is not a plain tag (letters, digits, dot, underscore, hyphen).

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOWS=("$ROOT/.github/workflows/ci.yml" "$ROOT/.github/workflows/security.yml")
ISSUE_TITLE="CI binary pins behind upstream"

# env var prefix in the workflows -> upstream repository
declare -A REPOS=(
  [LYCHEE]=lycheeverse/lychee
  [ACTIONLINT]=rhysd/actionlint
  [GITLEAKS]=gitleaks/gitleaks
)

pinned_version() {
  sed -nE "s/^[[:space:]]*$1_VERSION:[[:space:]]*\"?([^\"[:space:]]+)\"?.*/\1/p" "${WORKFLOWS[@]}" | head -n 1
}

normalize() {
  local v="$1"
  v="${v##*-v}"
  v="${v#v}"
  printf '%s' "$v"
}

stale=()
invalid=0
for tool in LYCHEE ACTIONLINT GITLEAKS; do
  repo="${REPOS[$tool]}"
  pinned="$(pinned_version "$tool")"
  if [[ -z "$pinned" ]]; then
    echo "error: no ${tool}_VERSION pin found in ${WORKFLOWS[*]}" >&2
    exit 1
  fi
  tag="$(gh api "repos/$repo/releases/latest" --jq .tag_name)"
  latest="$(normalize "$tag")"
  # The tag goes into an issue body and a URL: accept only plain tag and version shapes.
  if [[ ! "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ || ! "$latest" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    printf 'error: %s latest release has an unexpected tag name: %q\n' "$repo" "$tag" >&2
    invalid=1
    continue
  fi
  if [[ "$latest" == "$pinned" ]]; then
    printf 'current  %-10s %s\n' "$tool" "$pinned"
  else
    printf 'behind   %-10s %s -> %s (%s)\n' "$tool" "$pinned" "$latest" "$repo"
    stale+=("- ${tool,,}: pinned ${pinned}, latest ${latest} (https://github.com/${repo}/releases/tag/${tag})")
  fi
done

# An unreadable upstream leaves the report incomplete: fail before touching the issue.
(( invalid == 0 )) || exit 1

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
  echo "These CI binaries are pinned with a checksum in .github/workflows/ci.yml or security.yml and are behind their latest release:"
  echo
  printf '%s\n' "${stale[@]}"
  echo
  echo "Update the version and the matching *_SHA256 value from the release's published checksums, then let CI and Security run. Reported by the weekly Tool Pins workflow."
} > "$body"

if [[ -n "$existing" ]]; then
  gh issue edit "$existing" --body-file "$body" >/dev/null
  echo "Updated issue #$existing"
else
  gh issue create --title "$ISSUE_TITLE" --body-file "$body"
fi
