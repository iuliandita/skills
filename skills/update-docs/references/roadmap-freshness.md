# Roadmap Freshness Check

Full procedure for update-docs Step 1.5. Run it from the repository root.

Roadmaps drift the hardest because they restate facts the code, tags, and commit history already prove. Run this check whenever the repo has a roadmap - committed OR gitignored. If no roadmap is found, the step is silent and you move on; absence of `ROADMAP.md` is not an error.

```bash
# Discover all roadmap files (tracked AND gitignored). Normalize the leading ./ from find
# so it doesn't duplicate paths returned by git ls-files.
ROADMAPS=$(
  { git ls-files '*ROADMAP*' '*roadmap*' 2>/dev/null
    find . -maxdepth 4 -iname 'ROADMAP*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
      | sed 's|^\./||'
  } | sort -u
)

if [[ -n "$ROADMAPS" ]]; then
  # Resolve the source-of-truth version (try common manifests in order)
  REPO_VER=""
  [[ -f package.json   ]] && REPO_VER=$(node -p "require('./package.json').version ?? ''" 2>/dev/null)
  [[ -z "$REPO_VER" && -f Cargo.toml     ]] && REPO_VER=$(grep -m1 '^version' Cargo.toml     | sed -E 's/.*"([^"]+)".*/\1/')
  [[ -z "$REPO_VER" && -f pyproject.toml ]] && REPO_VER=$(grep -m1 '^version' pyproject.toml | sed -E 's/.*"([^"]+)".*/\1/')
  [[ -z "$REPO_VER" && -f setup.py       ]] && REPO_VER=$(grep -oE "version=['\"][^'\"]+" setup.py | sed -E "s/.*['\"]//")
  LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
  HEAD_DATE=$(git log -1 --format=%cs HEAD 2>/dev/null)

  # For each roadmap, parse the stated Current/Updated/Version header and compare
  while read -r rm; do
    [[ -f "$rm" ]] || continue
    STATED=$(grep -hE '^>.*(Current|Updated|Version)' "$rm" 2>/dev/null | head -3)
    RM_VER=$(printf '%s' "$STATED"  | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    RM_DATE=$(printf '%s' "$STATED" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}'  | head -1)
    [[ -z "$RM_VER$RM_DATE" ]] && continue  # no parseable header, skip silently

    # Informational counts (used in the drift output, not as triggers - commit count is a
    # bad proxy for staleness when an agentic /loop session can ship 5 commits in 20 min).
    COMMITS=0; TAGS=0
    if [[ -n "$RM_VER" ]]; then
      COMMITS=$(git rev-list --count "${RM_VER}..HEAD" 2>/dev/null || echo 0)
      TAGS=$(git tag --sort=v:refname 2>/dev/null | awk -v r="$RM_VER" 'found{c++} $0==r{found=1} END{print c+0}')
    fi

    # Tags cut AFTER the roadmap's stated date - the cleanest "you shipped, roadmap is
    # behind" signal. Releases are deliberate punctuation; arbitrary commits are not.
    NEWER_TAGS=$(git for-each-ref --sort=-creatordate \
      --format='%(creatordate:short) %(refname:short)' refs/tags 2>/dev/null \
      | awk -v d="${RM_DATE:-9999-99-99}" '$1 > d {print $2}')
    NEW_TAG_COUNT=$(printf '%s\n' "$NEWER_TAGS" | grep -c .)

    # Calendar-day staleness fallback for projects that do not tag releases. Portable across
    # GNU date (Linux) and BSD date (macOS).
    DAYS_BEHIND=0
    if [[ -n "$RM_DATE" && -n "$HEAD_DATE" ]]; then
      H=$(date -d "$HEAD_DATE" +%s 2>/dev/null || date -j -f %Y-%m-%d "$HEAD_DATE" +%s 2>/dev/null)
      R=$(date -d "$RM_DATE"   +%s 2>/dev/null || date -j -f %Y-%m-%d "$RM_DATE"   +%s 2>/dev/null)
      [[ -n "$H" && -n "$R" ]] && DAYS_BEHIND=$(( (H - R) / 86400 ))
    fi

    # Drift if ANY of: stated version older than latest tag; one or more releases cut since
    # the header date; or >14 calendar days since the header date with no release activity.
    DRIFT=0
    [[ -n "$RM_VER" && -n "$LAST_TAG" && "$(printf '%s\n' "$RM_VER" "$LAST_TAG" | sort -V | tail -1)" != "$RM_VER" ]] && DRIFT=1
    [[ "$NEW_TAG_COUNT" -gt 0 ]] && DRIFT=1
    [[ "$DAYS_BEHIND" -gt 14 ]] && DRIFT=1

    if [[ "$DRIFT" -eq 1 ]]; then
      echo "ROADMAP DRIFT: $rm states ${RM_VER:-?} / ${RM_DATE:-?}; HEAD is ${LAST_TAG:-v$REPO_VER} / $HEAD_DATE; $COMMITS commits, $TAGS tags between, $NEW_TAG_COUNT releases since header date, ${DAYS_BEHIND}d calendar gap."
      # Feed the drift range into Step 2 - widens the diff window beyond `git log -10`
      [[ -n "$RM_VER" ]] && RANGE="${RM_VER}..HEAD"
    fi
  done <<< "$ROADMAPS"
fi
```

**Why tags-and-days, not commit-count:** an agentic session can ship many commits without touching anything the roadmap tracks. A release tag is a deliberate event the roadmap should reflect, and 14 calendar days without an updated header is real staleness regardless of commit volume. Commit count stays only as context in the drift output.

**Side-channel staleness:** the header check is structural - it flags drift in stated metadata, not the *substance* of the roadmap. Roadmaps often contain time-stamped sections like `Scanned 2026-04-10`, `Last refreshed 2026-04-10`, `as of 2026-04-10`, or `Weekly refresh covers ...`. Surface those as **separate observations** when the date is older than HEAD by more than a week:

```bash
echo "$ROADMAPS" | while read -r rm; do
  [[ -f "$rm" ]] || continue
  grep -nE '([Ss]canned|[Ll]ast [Rr]efreshed|[Aa]s of|[Ww]eekly refresh)[^0-9]*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$rm" 2>/dev/null
done
```
