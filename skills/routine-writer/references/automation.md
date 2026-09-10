# Automation

How to emit `/schedule` invocations, `/fire` curl templates, and GitHub Actions steps. Includes the detection logic that gates CLI automation behind the `claude` binary being present.

---

## What is automatable, and what is not

The routines API surface, as of September 2026 check (2026-09-10), is asymmetric:

| Action | Automatable? | How |
|---|---|---|
| Create a routine | Not via public API | Web UI, Desktop app, or `/schedule` in the `claude` CLI |
| Fire an existing routine | Yes | `POST /v1/claude_code/routines/{trig_id}/fire` |
| Add API triggers | Not via public API | Web UI |
| Add GitHub triggers | Not via public API | Web UI or CLI 2.1.225+ |
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

### Authentication check before live CLI setup

Binary presence does not prove authentication, and a settings file is not a credential check.
Use the installed CLI's supported status command; do not spend a model call on an echoed canary:

```bash
# Bash; verified against installed `claude auth status --help`.
set -euo pipefail
command -v claude >/dev/null 2>&1 || { echo "claude not on PATH" >&2; exit 1; }
claude auth status --json | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("loggedIn") is not True:
    print("Claude authentication required", file=sys.stderr)
    sys.exit(1)
'
```

The parser does not print account details. Keep the command's nonzero status visible. If an
older CLI lacks this surface, report that limitation and use the web setup path; do not infer
success from a file or from text containing the requested canary. Check `/schedule` support
against the installed CLI before live creation. Drafting instructions needs no auth probe.

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
/schedule Run every weekday at 07:00 local. Read up to 100 oldest open untriaged issues
in myorg/api without the auto-triaged label. Apply area labels,
assign owners from CODEOWNERS, then mark each completed issue auto-triaged and reconcile one Slack summary in #eng-backlog. If no
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

CLI 2.1.225+ can attach GitHub triggers after app installation. API tokens still require web setup. See `references/trigger-guide.md`.

### Managing existing routines

CLI 2.1.227+ supports routine management and run-history inspection.

```
/schedule list           # list all routines for this account
/schedule update         # modify a routine
/schedule run            # fire a routine immediately
```

### Headless variant (emerging pattern)

For scripted invocation outside an interactive Claude Code session, pipe the `/schedule` description through `claude -p`:

```bash
PROMPT='Run every weekday at 07:00 local. Read up to 100 oldest open untriaged issues
in myorg/api without the auto-triaged label. Apply area labels,
assign owners from CODEOWNERS, then mark each completed issue auto-triaged and reconcile one Slack summary in #eng-backlog. If no
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
# Bash; URL and token come from protected environment injection.
set -euo pipefail
umask 077
fire_dir=$(mktemp -d)
trap 'rm -rf -- "$fire_dir"' EXIT
printf 'Authorization: Bearer %s\nanthropic-version: 2023-06-01\nanthropic-beta: experimental-cc-routine-2026-04-01\nContent-Type: application/json\n' \
  "$ROUTINE_FIRE_TOKEN" > "$fire_dir/headers"
jq -n --arg text "Sentry alert SEN-4521 fired; inspect the supplied stack trace." \
  '{text: $text}' > "$fire_dir/payload.json"
curl --fail-with-body --silent --show-error --max-time 60 \
  -X POST "$ROUTINE_FIRE_URL" -H @"$fire_dir/headers" \
  --data-binary @"$fire_dir/payload.json"
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

### Error handling

`--fail-with-body` returns nonzero on HTTP errors; retain the response securely if needed.
Treat 401/403 as access failures, 404 as a target/configuration failure, and 429 as a rate or
run-cap limit. A timeout or lost response may follow a successful dispatch: inspect the
routine's sessions before retrying. Never report a fire as successful just because curl ran.
Do not print bearer headers or raw private response bodies into general CI logs.

### Idempotency reminder

There is no idempotency key. Each call creates a new session and consumes one run of the daily cap. Alerting and deploy integrations should deduplicate on their side before firing.

---

## Pattern C: GitHub Actions step

Firing a routine from a GitHub Actions workflow on CI failure:

```yaml
- name: Fire triage routine on CI failure
  if: failure()
  shell: bash
  env:
    ROUTINE_FIRE_URL: ${{ secrets.ROUTINE_FIRE_URL }}
    ROUTINE_FIRE_TOKEN: ${{ secrets.ROUTINE_FIRE_TOKEN }}
  run: |
    set -euo pipefail
    umask 077
    fire_dir=$(mktemp -d)
    trap 'rm -rf -- "$fire_dir"' EXIT
    printf 'Authorization: Bearer %s\nanthropic-version: 2023-06-01\nanthropic-beta: experimental-cc-routine-2026-04-01\nContent-Type: application/json\n' \
      "$ROUTINE_FIRE_TOKEN" > "$fire_dir/headers"
    jq -n --arg text "CI failed: workflow=$GITHUB_WORKFLOW run=$GITHUB_RUN_ID ref=$GITHUB_REF sha=$GITHUB_SHA" \
      '{text: $text}' > "$fire_dir/payload.json"
    curl --fail-with-body --silent --show-error --max-time 60 \
      -X POST "$ROUTINE_FIRE_URL" -H @"$fire_dir/headers" \
      --data-binary @"$fire_dir/payload.json"
```

For release notes after a successful deploy, use `if: success()` after that deploy and
change the payload/prompt to the release-note task. The failure hook above is only for triage.
Deduplicate dispatch by the upstream run/deployment ID before firing.

Add the two secrets under **Settings > Secrets and variables > Actions** in the repository. A generated `ROUTINE_FIRE_TOKEN` is shown once - store it immediately.

For GitLab CI, Jenkins, CircleCI, etc., the pattern is the same: read URL and token from the secret manager, POST with the four required headers.

---

## Pattern D: web-UI walkthrough (fallback)

When CLI setup is unavailable or API tokens are needed, emit a walkthrough the user follows at `claude.ai/code/routines`.

Template to fill in:

```
1. Open https://claude.ai/code/routines and click **New routine**.
2. Name: <name>
3. Prompt: <paste the drafted prompt>
4. Repositories: <repo list>, branch policy <current restrictions>
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

Read the current allowance from the account UI; do not assume fixed per-plan counts.

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
