#!/usr/bin/env bash
set -euo pipefail

# Release PR check (issue #464). A pull request into main is a release, so
# CHANGELOG.md must already hold the section the tag will publish. Takes the
# first numbered `## [X.Y.Z]` section and fails unless X.Y.Z is greater than
# the newest strict vX.Y.Z tag merged into the base, the tag vX.Y.Z does not
# exist yet, and changelog-notes.sh X.Y.Z yields notes. No reachable version
# tag (shallow or tagless checkout) is a failure, never a pass.
#
# Usage: check-release-changelog.sh [base]
#        check-release-changelog.sh --previous-tag <base>
# Without an argument the base is BASE_REF, and any base other than main is
# skipped: only pull requests into main are releases. --previous-tag prints the
# newest version tag merged into the base and nothing else.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RELEASE_BRANCH=main

print_previous=0
if [[ "${1:-}" == "--previous-tag" ]]; then
  print_previous=1
  shift
  if [[ -z "${1:-}" ]]; then
    echo "error: --previous-tag requires a base" >&2
    exit 2
  fi
fi
if (( $# > 1 )); then
  echo "error: usage: check-release-changelog.sh [base] | --previous-tag <base>" >&2
  exit 2
fi

base_ref="${1:-}"
if [[ -z "$base_ref" ]]; then
  base_ref="${BASE_REF:-}"
  if [[ "$base_ref" != "$RELEASE_BRANCH" ]]; then
    echo "Base is '${base_ref:-unset}', not ${RELEASE_BRANCH}; release changelog check skipped."
    exit 0
  fi
fi

base=""
for candidate in "$base_ref" "origin/$base_ref"; do
  if git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
    base="$candidate"
    break
  fi
done
if [[ -z "$base" ]]; then
  echo "error: base ref '${base_ref}' does not resolve to a commit" >&2
  exit 1
fi

# Strict version tags only, newest first.
merged_tags="$(git tag --merged "$base" --sort=-version:refname)"
previous="$(awk '/^v[0-9]+\.[0-9]+\.[0-9]+$/ { print; exit }' <<<"$merged_tags")"
if [[ -z "$previous" ]]; then
  echo "error: no vX.Y.Z tag is reachable from '${base}'; this check needs full history and tags (shallow checkout?)" >&2
  exit 1
fi

if (( print_previous )); then
  printf '%s\n' "$previous"
  exit 0
fi

changelog="$ROOT/CHANGELOG.md"
if [[ ! -f "$changelog" ]]; then
  echo "error: $changelog not found" >&2
  exit 1
fi
version="$(awk 'match($0, /^## \[[0-9]+\.[0-9]+\.[0-9]+\]/) { print substr($0, 5, RLENGTH - 5); exit }' "$changelog")"
if [[ -z "$version" ]]; then
  echo "error: CHANGELOG.md has no numbered '## [X.Y.Z]' section" >&2
  exit 1
fi

# version_gt A B: true when A is a higher X.Y.Z than B.
version_gt() {
  local -a a b
  local i
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  for i in 0 1 2; do
    if (( 10#${a[i]} > 10#${b[i]} )); then return 0; fi
    if (( 10#${a[i]} < 10#${b[i]} )); then return 1; fi
  done
  return 1
}

errors=0
if ! version_gt "$version" "${previous#v}"; then
  echo "error: the first CHANGELOG.md section is [$version], not newer than $previous, the newest tag merged into '${base}'; add a '## [X.Y.Z] - YYYY-MM-DD' section for this release" >&2
  errors=$((errors + 1))
fi
if git rev-parse --verify --quiet "refs/tags/v$version" >/dev/null; then
  echo "error: tag v$version already exists; the first CHANGELOG.md section must be the version this release will tag" >&2
  errors=$((errors + 1))
fi
if ! "$ROOT/scripts/changelog-notes.sh" "$version" "$changelog" >/dev/null; then
  echo "error: the [$version] section of CHANGELOG.md has no release notes" >&2
  errors=$((errors + 1))
fi

if (( errors > 0 )); then
  exit 1
fi
echo "release changelog check OK ($previous -> v$version)."
