# Automation

How to emit `/schedule` invocations, `/fire` curl templates, and GitHub Actions steps. Includes the detection logic that gates CLI automation behind the `claude` binary being present.

---

## What is automatable, and what is not

The routines API surface, as of April 2026, is asymmetric:

| Action | Automatable? | How |
|---|---|---|
| Create a routine | Not via public API | Web UI, Desktop app, or `/schedule` in the `claude` CLI |
| Fire an existing routine | Yes | `POST /v1/claude_code/routines/{trig_id}/fire` |
| Add API or GitHub triggers to an existing routine | Not via public API | Web UI only |
| Generate or revoke tokens | Not via public API | Web UI only |
| Pause / resume a schedule | Not via public API | Web UI or `/schedule update` in the `claude` CLI |

So "automate routine creation" in practice means: help the user invoke `/schedule` inside a Claude Code session (if they have one), or walk them through the web UI. There is no third option today.

---

## Harness detection

Only `claude` can execute `/schedule`. Codex, OpenCode, Cursor, Aider, Goose, and other CLI harnesses cannot create routines. Detect before emitting CLI instructions.

### Minimum detection

```bash
if command -v claude >/dev/null 2>&1; then
  HAS_CLAUDE=1
else
  HAS_CLAUDE=0
fi
```

If `HAS_CLAUDE=0`, skip the `/schedule` path and emit the web-UI walkthrough.

### Fuller detection (recommended before scripting a headless fire)

```bash
# 1. Binary on PATH
command -v claude >/dev/null 2>&1 || { echo "claude not on PATH"; exit 1; }

# 2. Credentials present (config file or OAuth token env var)
[[ -f "$HOME/.claude/settings.json" ]] || [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] \
  || { echo "claude has no credentials configured"; exit 1; }

# 3. Optional: smoke test - the /schedule command is interactive, so verify by running a
#    trivial non-scheduling prompt. Use a distinct canary so banner text does not match.
if ! timeout 60 claude -p "respond with PONG" 2>&1 | grep -qi "pong"; then
  echo "claude smoke test failed - skipping CLI automation"
  exit 1
fi
```

Notes:

- `claude --version` tests the binary but does not test auth.
- The interactive `/schedule` flow asks follow-up questions. Headless `claude -p "/schedule ..."` works for scheduled routines when all required info is in the prompt, but this is an emerging pattern - verify against the installed `claude` version.
- A Claude Code session running the skill already has `claude` on PATH by definition, so when Claude Code is the active harness the detection mostly guards against misconfigured environments.

### Detecting the running harness

Binary presence is more reliable than trying to detect which harness is running. A user in Codex might still have `claude` installed; a user in Claude Code always does. If you need to know the active harness anyway:

| Harness | Signal |
|---|---|
| Claude Code | The session runs `claude`, so the binary is always present. Environment variables prefixed `CLAUDE_CODE_*` are usually set. |
| Codex | Binary `codex` on PATH; parent process often contains `codex` |
| OpenCode | Binary `opencode` on PATH |
| Aider | Binary `aider` on PATH |
| Goose | Binary `goose` on PATH |

---

## Pattern A: scheduled routine via `/schedule`

When `claude` is available and the trigger is a schedule.

### Conversational form (preferred)

Tell the user to paste this at the Claude Code prompt:

```
/schedule <your saved prompt text here>
```

For a concrete example, using the backlog triage prompt:

```
/schedule Run every weekday at 07:00 local. Read issues opened in the last 24 hours
in myorg/api without the auto-triaged label. Apply area and auto-triaged labels,
assign owners from CODEOWNERS, and post a Slack summary in #eng-backlog. If no
issues match, exit without output.
```

`/schedule` walks the user through the rest (cadence, repos, connectors). When the user already has all the info, the conversational form collapses to one or two confirmations.

### With cadence hint

Pass the cadence as part of the description:

```
/schedule daily PR review at 9am
/schedule weekly docs drift check on Fridays
/schedule hourly deploy verification
```

`/schedule` can only add **scheduled** triggers. To add an API or GitHub trigger to the same routine, the user edits the routine at `claude.ai/code/routines` afterwards.

### Managing existing routines

```
/schedule list           # list all routines for this account
/schedule update         # modify a routine
/schedule run            # fire a routine immediately
```

### Headless variant (emerging pattern)

For scripted invocation outside an interactive Claude Code session, pipe the `/schedule` description through `claude -p`:

```bash
PROMPT='Run every weekday at 07:00 local. Read issues opened in the last 24 hours
in myorg/api without the auto-triaged label. Apply area and auto-triaged labels,
assign owners from CODEOWNERS, and post a Slack summary in #eng-backlog. If no
issues match, exit without output.'

claude -p "/schedule $PROMPT"
```

Caveats:

- The `/schedule` flow expects to prompt for missing fields. In headless mode, missing fields either get sensible defaults or the command errors - behavior depends on the installed `claude` version. Verify on the target system before relying on it.
- Confirm with `/schedule list` (interactively or via `claude -p "/schedule list"`) that the routine was created.
- This is research-preview tooling. Treat headless `/schedule` as experimental; for production use, drive creation from the web UI.

---

## Pattern B: fire an existing routine via `/fire`

Works regardless of which harness is running. Requires an already-created routine with an API trigger and its bearer token.

### Curl template

```bash
ROUTINE_FIRE_URL="$ROUTINE_FIRE_URL"      # from the web UI modal
ROUTINE_FIRE_TOKEN="$ROUTINE_FIRE_TOKEN"  # shown once at token generation

curl -X POST "$ROUTINE_FIRE_URL" \
  -H "Authorization: Bearer $ROUTINE_FIRE_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "Content-Type: application/json" \
  -d '{"text": "Sentry alert SEN-4521 fired in prod. Stack trace attached."}'
```

Successful response:

```json
{
  "type": "routine_fire",
  "claude_code_session_id": "session_01HJKLMNOPQRSTUVWXYZ",
  "claude_code_session_url": "https://claude.ai/code/session_01HJKLMNOPQRSTUVWXYZ"
}
```

### Env var placeholders (always)

Emitted artifacts must never contain literal tokens. Tokens are shown once at generation and cannot be retrieved. A token leaked into a conversation is a token the user has to revoke.

Use these names consistently so the user can wire them into their secret manager of choice:

- `ROUTINE_FIRE_URL` - the full `/fire` URL for this routine
- `ROUTINE_FIRE_TOKEN` - the bearer token (`sk-ant-oat01-...`)

### Error handling template

```bash
HTTP=$(curl -sS -o /tmp/routine_fire.json -w "%{http_code}" \
  -X POST "$ROUTINE_FIRE_URL" \
  -H "Authorization: Bearer $ROUTINE_FIRE_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

case "$HTTP" in
  200)
    jq -r .claude_code_session_url /tmp/routine_fire.json
    ;;
  429)
    echo "rate limited - check Retry-After header or claude.ai/code/routines for daily cap"
    exit 1
    ;;
  401|403)
    echo "auth failure - token invalid or routine does not grant this account access"
    exit 1
    ;;
  404)
    echo "routine does not exist - check the URL"
    exit 1
    ;;
  *)
    echo "fire failed with HTTP $HTTP"
    cat /tmp/routine_fire.json
    exit 1
    ;;
esac
```

### Idempotency reminder

There is no idempotency key. Each call creates a new session and consumes one run of the daily cap. Alerting and deploy integrations should deduplicate on their side before firing.

---

## Pattern C: GitHub Actions step

Firing a routine from a GitHub Actions workflow on CI failure:

```yaml
- name: Fire triage routine on CI failure
  if: failure()
  env:
    ROUTINE_FIRE_URL: ${{ secrets.ROUTINE_FIRE_URL }}
    ROUTINE_FIRE_TOKEN: ${{ secrets.ROUTINE_FIRE_TOKEN }}
  run: |
    curl -X POST "$ROUTINE_FIRE_URL" \
      -H "Authorization: Bearer $ROUTINE_FIRE_TOKEN" \
      -H "anthropic-version: 2023-06-01" \
      -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"CI failed: workflow=$GITHUB_WORKFLOW run=$GITHUB_RUN_ID ref=$GITHUB_REF sha=$GITHUB_SHA\"}"
```

Add the two secrets under **Settings > Secrets and variables > Actions** in the repository. A generated `ROUTINE_FIRE_TOKEN` is shown once - store it immediately.

For GitLab CI, Jenkins, CircleCI, etc., the pattern is the same: read URL and token from the secret manager, POST with the four required headers.

---

## Pattern D: web-UI walkthrough (fallback)

When `claude` is not on PATH, or when the trigger is GitHub / API only, emit a walkthrough the user follows at `claude.ai/code/routines`.

Template to fill in:

```
1. Open https://claude.ai/code/routines and click **New routine**.
2. Name: <name>
3. Prompt: <paste the drafted prompt>
4. Repositories: <repo list>, branch policy <default or unrestricted>
5. Environment: <default or custom-name>
6. Connectors: <keep only these: ...>
7. Trigger(s):
   - Schedule: <preset or cron>
   - API: click **Add another trigger**, choose **API**, save, then **Generate token**
     and store it as ROUTINE_FIRE_TOKEN (shown once).
   - GitHub event: <event>, filters: <filters>, install the Claude GitHub App if prompted.
8. Click **Create**.
```

Always print the drafted prompt verbatim so the user can paste it.

---

## Daily cap check before firing

Before a scripted `/fire` call, the user may want to know if there is capacity left. There is no endpoint for this - the daily cap is only shown in the web UI at `claude.ai/code/routines` and `claude.ai/settings/usage`. Plan fire frequency against the known plan cap:

| Plan | Daily routine runs |
|---|---|
| Pro | 5 |
| Max | 15 |
| Team | 25 |
| Enterprise | 25 |

A webhook integration that fires more than this will get 429s for the rest of the day. Organizations with extra usage enabled continue on metered overage.

---

## What to emit, by trigger

Given the chosen triggers, emit this combination:

| Chosen trigger(s) | Artifacts to emit |
|---|---|
| Schedule only | The routine prompt, plus `/schedule` CLI command if `claude` is on PATH; otherwise the web-UI walkthrough |
| API only | The routine prompt, the web-UI walkthrough (to create routine and generate token), the curl template |
| GitHub only | The routine prompt, the web-UI walkthrough (to create routine, install GitHub App, and configure filters) |
| Schedule + API | `/schedule` command (if `claude` present) to create the routine with schedule, then web-UI walkthrough for adding the API trigger, plus the curl template |
| Schedule + GitHub | `/schedule` command (if `claude` present) to create the routine with schedule, then web-UI walkthrough for adding the GitHub trigger |
| API + GitHub | Web-UI walkthrough for both, plus the curl template for the API side |
| Schedule + API + GitHub | `/schedule` first (if `claude` present), web-UI walkthrough for the other two, plus the curl template |

Always print the final routine prompt on its own so it can be copy-pasted, regardless of which other artifacts are included.
