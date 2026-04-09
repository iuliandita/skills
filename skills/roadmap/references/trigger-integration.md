# Trigger Integration

Optional auto-trigger setups for roadmap updates. The skill's built-in activity detection
(Step 0) works without any of this - these are for users who want push-based reminders.

---

## Claude Code Hook

Add to `.claude/settings.json` in the project:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'CMD=$(cat | jq -r \".tool_input.command // empty\" 2>/dev/null); if echo \"$CMD\" | grep -qE \"(gh pr merge|git push.*--tags|gh release create)\"; then echo \"[roadmap] PR merged or release created - consider running /roadmap update\"; fi'"
          }
        ]
      }
    ]
  }
}
```

Claude Code hooks receive tool input as JSON on stdin. The hook parses the Bash
command via `jq`, checks if it matches merge/release patterns, and prints a reminder.
It does not auto-edit ROADMAP.md - the user still invokes the skill.

Requires `jq` installed. If unavailable, a simpler approach is a `Notification` hook
that fires a generic reminder after any Bash call containing "merge" or "release."

---

## GitHub Actions

Create `.github/workflows/roadmap-reminder.yml`:

```yaml
name: Roadmap Reminder
on:
  pull_request:
    types: [closed]
  release:
    types: [published]

jobs:
  remind:
    if: >
      (github.event_name == 'release') ||
      (github.event_name == 'pull_request' && github.event.pull_request.merged == true)
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - name: Create reminder issue
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          EVENT_NAME: ${{ github.event_name }}
          TAG_NAME: ${{ github.event.release.tag_name }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          if [ "$EVENT_NAME" = "release" ]; then
            TITLE="Update ROADMAP.md for $TAG_NAME"
            BODY="Release **$TAG_NAME** published. Check if any roadmap items should be marked as shipped."
          else
            TITLE="Update ROADMAP.md for PR #$PR_NUMBER"
            BODY="PR **#$PR_NUMBER** ($PR_TITLE) merged. Check if this completes any roadmap items."
          fi
          gh issue create --repo "${{ github.repository }}" \
            --title "$TITLE" \
            --body "$BODY" \
            --label "roadmap"
```

Creates a GitHub issue as a reminder. Requires a `roadmap` label to exist (create it
manually or add a step). The issue is the trigger - close it after updating
ROADMAP.md.

Event data is passed through environment variables (not inline `${{ }}` interpolation)
to prevent script injection via crafted PR titles.

**Note**: This only works if ROADMAP.md is tracked in git. For gitignored roadmaps,
the issue is still useful as a reminder but the actual update happens locally.

---

## Git Hook (local fallback)

Add to `.git/hooks/post-merge` (or use a hooks manager like lefthook):

```bash
#!/usr/bin/env bash
# Remind about roadmap updates after pulling merged changes

# Compare HEAD before and after merge to detect new tags
old_tag=$(git describe --tags --abbrev=0 ORIG_HEAD 2>/dev/null || echo "none")
new_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "none")

if [ "$old_tag" != "$new_tag" ]; then
  echo ""
  echo "[roadmap] New tag reachable after merge: $new_tag (was: $old_tag)"
  echo "[roadmap] Consider running: /roadmap update"
  echo ""
fi
```

Uses `ORIG_HEAD` (set by git during merge) to compare the nearest tag before and after
the merge. Only fires when the merge brings HEAD closer to a different tag.

**Limitations**: Only fires on local merges and pulls. Misses server-side squash/rebase
merges (GitHub's merge buttons). Use as a supplement, not the primary trigger.

---

## Choosing an approach

| Approach | Catches server merges | Catches releases | Zero config | Works offline |
|----------|----------------------|-----------------|-------------|--------------|
| Built-in detection (Step 0) | Yes (on next invocation) | Yes | Yes | Partially |
| Claude Code hook | No (local only) | Yes (local tag push) | No | Yes |
| GitHub Actions | Yes | Yes | No | No |
| Git hook | No (local only) | Partially | No | Yes |

**Recommendation**: Start with the built-in detection alone. Add GitHub Actions if you
want issue-based tracking. Add the Claude Code hook if you want inline reminders during
your session. Skip the git hook unless you have a specific local-merge workflow.
