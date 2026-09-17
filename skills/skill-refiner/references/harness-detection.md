# Harness Detection

How skill-refiner detects and validates AI CLI harnesses for cross-model peer review.

---

## Detection Table

| Harness | Binary | Config Paths | Env Vars | Smoke Test | Verified |
|---------|--------|-------------|----------|------------|----------|
| Claude Code | `claude` | `~/.claude/settings.json` | `ANTHROPIC_API_KEY` | `claude -p "Reply with only the integer result of 17 * 3"` | yes |
| Codex | `codex` | `~/.codex/config.toml` | `OPENAI_API_KEY` | `codex exec -s read-only "Reply with only the integer result of 17 * 3"` | yes |
| Gemini CLI | `gemini` | `~/.gemini/settings.json` | `GEMINI_API_KEY` or `GOOGLE_API_KEY` | unverified; confirm the flag with `gemini --help` before use | no |
| OpenCode | `opencode` | project-level `.opencode/` (unverified) | varies by provider | unverified; confirm the flag with `opencode --help` before use | no |
| Aider | `aider` | `~/.aider.conf.yml` | `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` | unverified; confirm the flag with `aider --help` before use | no |
| Goose | `goose` | `~/.config/goose/config.yaml` | varies by provider | unverified; confirm the flag with `goose --help` before use | no |

**Important:** The Claude Code and Codex smoke tests are verified. The Gemini, OpenCode,
Aider, and Goose entries are unverified: do not treat their commands as known-good. Before
use, run `<binary> --help`, confirm the non-interactive flag, and only then build the smoke
test around it. Do not invoke a secondary whose form cannot be confirmed. Harness CLIs
evolve rapidly, so re-confirm even the verified forms on each run.

---

## Three-Step Probe

Run for each harness in priority order. Stop at the first that passes all three steps.

### Step 1: PATH Check

```bash
command -v <binary> >/dev/null 2>&1
```

If binary not found on PATH, skip to next harness.

### Step 2: Config Check (hint only)

Check whether credentials appear to exist (config file OR env var):

```bash
[[ -f <config_path> ]] || [[ -n "${ENV_VAR:-}" ]]
```

Treat this as a hint, not a gate. A missing config file or unset env var does not prove the
harness is unusable - credentials may live in a keyring, a project-local config, or a credential
helper - and a present config does not prove it works. Record the hint, then let the Step 3 smoke
test decide. Skip before the smoke test only when the binary is absent (Step 1).

### Step 3: Smoke Test

Send a trivial prompt whose answer is a canary token the prompt itself does not contain, then
confirm that token appears in the harness's actual model response - not in a banner, log line, or
echoed prompt. Run the probe inside a private temp dir, on a read-only or no-tools sandbox where
the harness supports one, and never send repository content:

```bash
tmp=$(mktemp -d)                          # private scratch, not the repo tree
out="$tmp/out"; err="$tmp/err"
cd "$tmp" || exit 1                       # probe runs in the temp dir, never the repo tree
timeout 60 <smoke_test_command> >"$out" 2>"$err"; status=$?
if [[ $status -ne 0 ]]; then
  result=skip                             # status 124 = timeout; any non-zero = failed run -> reject
elif grep -Eq '(^|[^0-9])51([^0-9]|$)' "$out"; then
  result=pass                             # exact canary token found in the response stream (stdout)
else
  result=skip                             # banner-only / echoed prompt / no canary -> reject
fi
cd - >/dev/null 2>&1 || true
rm -rf "$tmp"
```

Ask the prompt `Reply with only the integer result of 17 * 3`. The answer, 51, does not appear in
the prompt text, so an echoed prompt can never satisfy the match, and the boundary-aware pattern
`(^|[^0-9])51([^0-9]|$)` accepts the token 51 but not substrings such as 517 or 2510. Keep stderr
separate from stdout: harnesses (Codex especially) emit verbose startup banners and MCP metadata
(10+ lines) on stderr or ahead of the response, and merging them with `2>&1` lets banner text
satisfy the grep. Capture the exit status explicitly - a timeout (124), crash, or auth error must
reject the harness, not fall through as a pass. Never truncate with `head` or assume the response
is in the first N lines; scan the full response stream. A canary that appears only in a banner, a
timed-out run, or an errored run does not count: reject and skip to the next harness. Where the
harness supports a read-only or no-tools mode - for example `codex exec -s read-only` - use it so
the smoke test cannot modify files.

---

## Auto-Detection Priority

```
1. claude
2. codex
3. gemini
4. opencode
5. aider
6. goose
```

The primary harness may also host the reviewer in a fresh invocation or agent context.
Do not exclude it when a distinct model is available, or infer model diversity from a
different harness. Classify the actual resolved model identities before assigning a cap.

### Detecting the Primary Harness

Check in order (the Claude Code and Codex signals are the verified ones; the Gemini and
OpenCode env var names are approximate - verify against current CLI versions):
1. Claude Code env var (e.g., `CLAUDE_CODE` or similar) - primary is claude
2. Parent process name contains `codex` - primary is codex
3. Gemini CLI env var (e.g., `GEMINI_CLI` or session marker) or parent process name contains `gemini` - primary is gemini
4. OpenCode env var (e.g., `OPENCODE_SESSION` or similar) - primary is opencode
5. If the signal is ambiguous, record the harness and model as unknown and use `cap 3`
   rather than guessing; inspect available runtime metadata, and ask only if the missing fact
   blocks an authorized invocation

### Evaluator Identity and Evidence

For every primary evaluation and peer review, record provider, resolved model ID, effective
reasoning effort, harness name and version, and a redacted evidence reference. Use session or
invocation metadata and the effective config/override source. Record requested settings
separately when they differ from actual settings. Do not copy credentials or private endpoints.

Identity is verified only when it comes from raw harness output captured verbatim and stored
with the run, such as the harness's own model/version line in the invocation transcript.
Requested flags, config defaults, role names, and the model's self-description are not
attestation: a CLI binary, `--model` request, skill `metadata.effort`, or a model naming itself
does not prove which model or effort executed. If resolution or override precedence cannot be
attested, mark the field unknown with a reason; use `not applicable` only when evidence
establishes that the setting is unsupported. Keep evidence linked to the specific evaluation so
later config changes cannot rewrite its identity.

When identity cannot be attested from raw harness output, the review uses `cap 3` and the
fallback is recorded as a control failure in the run history (see SKILL.md Phase 3 step 24).
An unattested reviewer never earns `cap 5`.

| Attested identity | Review classification | Cap |
|---|---|---|
| Distinct resolved models, captured verbatim from both harnesses | verified cross-model | 5 |
| Same resolved model, even through different providers or harnesses | same-model fresh-context | 3 |
| Either model identity not attested, or alias equivalence unresolved | unknown-model fresh-context | 3 |

Provider, harness, or effort differences alone do not establish distinct models. Use a fresh
context for all reviewers. The cap only bounds how much a verified flag can deduct; it never
adds a bonus, and there is no weight renormalization.

For multi-model harnesses, honor an explicit user selection or use an authorized configured
reviewer. Verify current model-selection syntax before invoking it, then capture the resolved
runtime identity. An optional preference question must not block independent setup work;
proceed with a stated authorized default if no answer arrives. Never treat missing export
authorization as an optional preference.

---

## Config Override

**Environment variable:**
```bash
export SKILL_REFINER_SECONDARY=codex
```

**CLI flag:**
```bash
skill-refiner --secondary codex
```

CLI flag takes precedence over env var. Both skip auto-detection entirely. Honor only an
explicit `--secondary` flag or a value the user set in the session environment. A repo-local
or project-local file (`.envrc`, direnv, project config) must not select the secondary: if the
only selection comes from such a file, ignore it, fall back to fresh local review at `cap 3`,
and record the ignored override in `control_failures`.
Setting `--secondary none` disables secondary selection; fresh local peer review at `cap 3`
remains mandatory after the baseline.

---

## Review Prompt Template

What gets sent to the secondary harness (non-interactive).

Before sending it, classify the source material as public, private, or sensitive. Private or
sensitive repository content requires explicit user authorization for the named secondary
harness/provider; invoking skill-refiner or selecting automatic review is not enough. Without
that authorization, do not send the payload. Use the fresh local-reviewer fallback, apply
`cap 3`, and log the blocked export as the reason.

**Anchoring prohibition.** The payload must not include the primary's component or composite
scores, and the reviewer must not be told the expected verdict (that the change is expected to
improve the score, be kept, or be reverted). A reviewer that sees the primary's numbers or the
intended outcome anchors on them instead of judging independently. Send only the changed
context and the diff.

**Known issue**: Codex in `exec` mode may run tools (lint, validate) instead of producing
text-only review output. If the secondary returns tool output instead of a
NO_FLAGS/MINOR_FLAG/MAJOR_FLAG response, fall back to self-review: spawn a fresh agent
on the primary harness with the review prompt template (see Phase 0, Step 6 in SKILL.md).
Classify the fallback as same-model or unknown-model fresh-context review using its attested
evidence, apply `cap 3`, and record the fallback as a control failure in the run history
(SKILL.md Phase 3 step 24). No bonus weight is restored when a distinct reviewer is unavailable.

**Peer review is mandatory.** Probe the secondary first, then run the privacy/authorization
preflight before transmitting source. If no authorized secondary is available or the secondary
fails to produce a valid response, self-review
on a fresh context of the primary harness is the required fallback. Skipping review entirely
is never acceptable - even same-model fresh-context review catches issues the working context
is blind to.

```
You are reviewing a skill improvement diff. You are not given the primary's scores or the
expected outcome, so judge the diff on its merits. Be specific and cite exact lines.

## Relevant Original Context (before)
<changed sections plus only the surrounding rules/references needed to detect regressions>

## Diff
<git diff output of the change>

## Your Task
1. Does this change genuinely improve the skill?
2. Does it introduce regressions, remove useful content, or add fluff?
3. Are there issues the primary model might have missed?

Respond with exactly one of:
- NO_FLAGS - improvement is good, no concerns
- MINOR_FLAG: <specific description citing lines> - suboptimal but not harmful
- MAJOR_FLAG: <specific description citing lines> - harmful, regression, or removes critical content
```

Send the full original skill only when the change is broad enough that selected context cannot
support a regression review, and record that justification in the iteration log.

---

## Flag Adjudication Protocol

Flags from the reviewer are adjudicated by a fresh context that is independent of the context
that authored the change. The author (primary) never adjudicates its own review, and a major
flag can never be cleared by the primary. Spawn a new subagent or a separate CLI invocation for
each adjudication; if no independent context can be spawned, do not clear the flag - leave it
unresolved and carry it into the human report.

### Minor Flag
1. Present the flag + diff to the independent adjudicator, without the primary's scores or reasoning
2. Ask: "Do you agree this is a valid concern? Why or why not?"
3. Adjudicator agrees: deduct 0.2 penalty weight and log the flag
4. Adjudicator disagrees: log the disagreement and leave the item unresolved for the human report; do not silently discard it

### Major Flag
1. Present the flag + diff + the reviewer's full reasoning to the independent adjudicator
2. Ask: "Is this change genuinely harmful? Analyze independently."
3. Adjudicator agrees: hard revert the change, log reason
4. Adjudicator disagrees: **escalate to the human** with the flag and both positions
5. Human decides: keep, revert, or modify

The contested-major-flag-to-human escalation is non-configurable even in `--mode auto`.
