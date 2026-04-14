# Trigger Guide

Per-trigger specifics: cron rules, API fire semantics, GitHub event catalogue, filter fields, and how triggers combine.

All details below reflect the research preview as of April 2026. The beta header is `experimental-cc-routine-2026-04-01`. Shapes, limits, and behavior can change; pin the beta header date so staleness is detectable.

---

## Schedule trigger

### Presets

Four presets are exposed in the web form: hourly, daily, weekdays, weekly. Times are entered in the user's local timezone and converted automatically. The routine runs at that wall-clock time regardless of where the cloud infrastructure is located.

### Custom cron

For intervals like "every two hours" or "first of each month", pick the closest preset in the form, save the routine, then run `/schedule update` in the CLI to set a specific 5-field cron expression.

| Expression | Meaning |
|---|---|
| `0 * * * *` | every hour on the hour |
| `0 */2 * * *` | every two hours |
| `0 9 * * *` | daily at 09:00 local |
| `0 9 * * 1-5` | weekdays at 09:00 local |
| `0 0 * * 0` | weekly, Sunday at midnight |
| `0 0 1 * *` | monthly, first of the month at midnight |

Day-of-week uses `0` or `7` for Sunday through `6` for Saturday. Extended syntax (`L`, `W`, `?`, name aliases like `MON`) is not supported.

### Minimum interval

One hour. Expressions that would fire more frequently are rejected. This is a platform limit, not a quota.

### Stagger

Runs may start a few minutes after the scheduled time. The offset is consistent for each routine (not random per run). An hourly job fires somewhere in the first few minutes of each hour, but the same routine always picks the same offset. Do not assume sub-minute precision.

### Combining schedules

A routine can have multiple schedule triggers, or a schedule plus an API trigger, or a schedule plus a GitHub trigger. Use this when the same work needs more than one firing mode (nightly backlog sweep plus deploy-failure fire, for example).

### Pausing

A schedule can be paused from the routine detail page without deleting the routine. Paused schedules keep their configuration; firing resumes when the toggle is re-enabled.

---

## API trigger

### Endpoint

```
POST https://api.anthropic.com/v1/claude_code/routines/{routine_id}/fire
```

The `routine_id` in the URL is prefixed `trig_`, not `routine_`. The full URL and a sample curl are shown in the modal when you add an API trigger in the web UI.

### Required headers

| Header | Value |
|---|---|
| `Authorization` | `Bearer sk-ant-oat01-...` (per-routine token) |
| `anthropic-beta` | `experimental-cc-routine-2026-04-01` (April 2026) |
| `anthropic-version` | `2023-06-01` |
| `Content-Type` | `application/json` (when body is present) |

Missing the beta header returns `400 invalid_request_error`. The two most recent previous beta header versions keep working so callers have time to migrate when a new dated variant ships.

### Request body

```json
{
  "text": "Free-form context, up to 65,536 characters."
}
```

The body is optional. The `text` field is appended to the routine's saved prompt as a one-shot user turn. It is passed as a literal string - JSON payloads are *not* parsed. Unknown fields are ignored.

### Response

A successful fire returns `200 OK`:

```json
{
  "type": "routine_fire",
  "claude_code_session_id": "session_01HJKLMNOPQRSTUVWXYZ",
  "claude_code_session_url": "https://claude.ai/code/session_01HJKLMNOPQRSTUVWXYZ"
}
```

The call does not stream session output or wait for completion. It returns once the session is created. Open the session URL to watch the run.

### Errors

| HTTP | Error type | Cause |
|---|---|---|
| 400 | `invalid_request_error` | Missing beta header, `text` over 65,536 chars, or routine paused |
| 401 | `authentication_error` | Missing bearer or token does not match this routine |
| 403 | `permission_error` | Account or org lacks access to this endpoint |
| 404 | `not_found_error` | Routine does not exist |
| 429 | `rate_limit_error` | Daily routine cap or subscription usage limit hit. Response includes `Retry-After` |
| 500 | `api_error` | Unexpected server error |
| 503 | `overloaded_error` | Service overloaded. Retry after delay. (Claude Platform returns 529; this endpoint returns 503.) |

### Tokens

Each routine has one bearer token. The token is shown once when generated and cannot be retrieved. Store it in a secret manager. Regenerating a token immediately revokes the previous one.

Token scope: triggers that routine only. No read access, no access to other routines, no account-level data. A compromised token can only fire that specific routine.

Token management (generate, regenerate, revoke) is web-UI only. The CLI cannot create or revoke tokens.

### Idempotency

There is no idempotency key. Every successful POST creates a new session. If a webhook caller retries, the endpoint creates multiple sessions, each drawing down the daily routine cap. Alerting integrations should deduplicate on their side (most do by default).

### Rate limits

Two limits apply to API fires:

1. The per-account daily routine run cap (5 / 15 / 25 depending on plan).
2. The account's Claude Code subscription usage.

When either hits, the endpoint returns `429` with a `Retry-After` header. Organizations with extra usage enabled continue past the daily cap on metered overage.

---

## GitHub trigger

### Setup requirement

GitHub triggers require the **Claude GitHub App** installed on the target repository. Granting repo access via `/web-setup` in the CLI is not sufficient - that grants clone access for the cloud session but does not enable webhook delivery. The trigger setup in the web UI prompts the user to install the app if it is not installed.

### Supported events

| Event | Triggers when |
|---|---|
| Pull request | A PR is opened, closed, assigned, labeled, synchronized, or otherwise updated |
| Pull request review | A PR review is submitted, edited, or dismissed |
| Pull request review comment | A comment on a PR diff is created, edited, or deleted |
| Push | Commits are pushed to a branch |
| Release | A release is created, published, edited, or deleted |
| Issues | An issue is opened, edited, closed, labeled, or otherwise updated |
| Issue comment | A comment on an issue or PR is created, edited, or deleted |
| Sub issues | A sub-issue or parent issue is added or removed |
| Commit comment | A commit or diff is commented on |
| Discussion | A discussion is created, edited, answered, or otherwise updated |
| Discussion comment | A discussion comment is created, edited, or deleted |
| Check run | A check run is created, requested, rerequested, or completed |
| Check suite | A check suite completes or is requested |
| Merge queue entry | A PR enters or leaves the merge queue |
| Workflow run | A GitHub Actions workflow run starts or completes |
| Workflow job | A GitHub Actions job is queued or completes |
| Workflow dispatch | A workflow is manually triggered |
| Repository dispatch | A custom `repository_dispatch` event is sent |

Each category can be filtered to a single action (e.g., `pull_request.opened`) or left to match all actions.

### Pull request filters

Only pull request triggers expose structured filters. Filter conditions are AND-combined; every condition must match for the routine to fire.

| Filter | Matches |
|---|---|
| Author | PR author's GitHub username |
| Title | PR title text |
| Body | PR description text |
| Base branch | Branch the PR targets |
| Head branch | Branch the PR comes from |
| Labels | Labels applied to the PR |
| Is draft | Whether the PR is in draft state |
| Is merged | Whether the PR has been merged |
| From fork | Whether the PR comes from a fork |

Useful combinations:

- **Ready-for-review only**: is draft `false`. Skips drafts.
- **External contributor review**: from fork `true`. Routes fork-based PRs through extra checks.
- **Label-gated action**: labels include `needs-backport`. Fires only when a maintainer tags the PR.
- **Scoped review**: base branch `main`, head branch contains `auth-provider`. Sends auth-touching PRs to a focused reviewer.

For other event types (issues, pushes, workflow runs) without structured filters, the routine prompt itself must check the event metadata and exit early when out of scope.

### Session mapping

Each matching event starts a new session. Session reuse across events is not available for GitHub-triggered routines. Two pushes to the same branch produce two independent sessions. A PR that is opened, labelled, and then synchronized produces three sessions (one per matching event).

Keep this in mind when picking event actions: subscribing to `pull_request` with no filter, with a long-lived PR that keeps getting synced, fires many sessions per day.

### Webhook caps

During the research preview, GitHub webhook events are subject to per-routine and per-account hourly caps. Events beyond the limit are dropped until the window resets. Current limits are shown at `claude.ai/code/routines`.

Drop behavior is silent to the caller (GitHub does not retry). Plan filters tight enough that the routine fires on a manageable number of events.

---

## Combining triggers

A routine can have any mix of schedule, API, and GitHub triggers attached at once. Add or remove them from the **Select a trigger** section of the routine's edit form.

When a routine is multi-trigger, the prompt must branch on fire context. See `references/prompt-anatomy.md` section "Trigger-context branching" for the branching pattern.

Typical useful combinations:

- **Schedule + API**: nightly backlog sweep with a manual fire button (ops can trigger it ad hoc).
- **Schedule + GitHub**: weekly docs drift check that also fires whenever docs-touching PRs merge.
- **API + GitHub**: a PR review routine that fires on open and can be re-fired manually from the deploy pipeline after a rebase.

Avoid combining all three unless the routine genuinely has three firing modes - the branching adds prompt length and cognitive load per run.

---

## Scope settings (common to all triggers)

### Repositories

Each repo is cloned at the start of every run from the default branch. Claude creates `claude/`-prefixed branches for changes. The "Allow unrestricted branch pushes" toggle per-repo lifts this. Leave it off unless the routine legitimately pushes elsewhere.

### Connectors

All currently connected MCP connectors are included by default when a routine is created. Remove any the routine does not use - each is attack surface and each extra connector is context the session loads.

### Environment

Each routine runs in a cloud environment that controls:

- Network access level (none, limited, full)
- Environment variables (for API keys, tokens)
- Setup script (runs before each session, e.g., `npm install`)

A default environment is provided. Custom environments must be created before the routine references them.

### Identity

Routines act as the user who owns them. Commits, PRs, Slack messages, and Linear tickets appear under the user's connected identity. Routines are not shared across a team - each teammate owns their own routines.

---

## Daily caps

| Plan | Daily routine runs |
|---|---|
| Pro | 5 |
| Max | 15 |
| Team | 25 |
| Enterprise | 25 |

Runs also draw down Claude Code subscription usage the same way interactive sessions do. When either limit is hit, new fires are rejected. Organizations with extra usage enabled continue on metered overage.

Remaining daily runs are visible at `claude.ai/code/routines` and `claude.ai/settings/usage`.

---

## What routines cannot do

- Run more frequently than once per hour (schedule).
- Read local files from the user's machine (they run on cloud).
- Ask the user a question mid-run - they are fully autonomous.
- Be created programmatically - no public create API yet. Only the `/fire` endpoint is public.
- Be shared with teammates - routines are per-account.
- Retry missed events automatically - if a webhook is dropped by the hourly cap, there is no catch-up.
