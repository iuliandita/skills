# Harness Detection

How skill-refiner detects and validates AI CLI harnesses for cross-model peer review.

---

## Detection Table

| Harness | Binary | Config Paths | Env Vars | Smoke Test |
|---------|--------|-------------|----------|------------|
| Claude Code | `claude` | `~/.claude/settings.json` | `ANTHROPIC_API_KEY` | `claude -p "respond with PONG"` |
| Codex | `codex` | `~/.codex/config.toml` | `OPENAI_API_KEY` | `codex exec "respond with PONG"` |
| Gemini CLI | `gemini` | `~/.gemini/settings.json` | `GEMINI_API_KEY` or `GOOGLE_API_KEY` | `gemini -p "respond with PONG"` |
| OpenCode | `opencode` | project-level `.opencode/` (verify) | varies by provider | check `opencode --help` |
| Aider | `aider` | `~/.aider.conf.yml` | `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` | `aider --message "respond with PONG" --no-git --yes-always` |
| Goose | `goose` | `~/.config/goose/config.yaml` | varies by provider | check `goose --help` |

**Important:** Smoke test commands are approximate. Verify against current CLI versions
before relying on them. Check `<harness> --help` for the correct non-interactive flag.
Harness CLIs evolve rapidly - these should be verified on each run.

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

Send a trivial prompt with a distinct canary word and confirm the canary appears in the harness's
actual model response - not in a banner, log line, or echoed prompt. Run it in an isolated,
read-only working directory with a private temp dir, and never send repository content:

```bash
tmp=$(mktemp -d)                          # private scratch, not the repo tree
out="$tmp/out"; err="$tmp/err"
timeout 60 <smoke_test_command> >"$out" 2>"$err"; status=$?
if [[ $status -ne 0 ]]; then
  result=skip                             # status 124 = timeout; any non-zero = failed run -> reject
elif grep -qi "pong" "$out"; then
  result=pass                             # canary found in the response stream (stdout)
else
  result=skip                             # banner-only / no canary in response -> reject
fi
rm -rf "$tmp"
```

Use "respond with PONG" as the prompt (not "OK" - too likely to match banner text). Keep stderr
separate from stdout: harnesses (Codex especially) emit verbose startup banners and MCP metadata
(10+ lines) on stderr or ahead of the response, and merging them with `2>&1` lets banner text
satisfy the grep. Capture the exit status explicitly - a timeout (124), crash, or auth error must
reject the harness, not fall through as a pass. Never truncate with `head` or assume the response
is in the first N lines; scan the full response stream. A PONG that appears only in a banner, a
timed-out run, or an errored run does not count: reject and skip to the next harness.

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
different harness. Classify the actual resolved model identities before assigning weight.

### Detecting the Primary Harness

Check in order (env var names are approximate - verify against current CLI versions):
1. Claude Code env var (e.g., `CLAUDE_CODE` or similar) - primary is claude
2. Parent process name contains `codex` - primary is codex
3. Gemini CLI env var (e.g., `GEMINI_CLI` or session marker) or parent process name contains `gemini` - primary is gemini
4. OpenCode env var (e.g., `OPENCODE_SESSION` or similar) - primary is opencode
5. If ambiguous, record the harness as unknown and inspect available runtime metadata;
   ask only if the missing fact blocks an authorized invocation

### Evaluator Identity and Evidence

For every primary evaluation and peer review, record provider, resolved model ID, effective
reasoning effort, harness name and version, and a redacted evidence reference. Use session or
invocation metadata and the effective config/override source. Record requested settings
separately when they differ from actual settings. Do not copy credentials or private endpoints.

A CLI binary, role name, skill `metadata.effort`, requested flag, default config, or model's
self-description alone does not prove which model or effort executed. If resolution or override
precedence cannot be verified, mark the field unknown with a reason; use `not applicable` only
when evidence establishes that the setting is unsupported. Keep evidence linked to the specific
evaluation so later config changes cannot rewrite its identity.

| Verified identity | Review classification | Weight |
|---|---|---|
| Distinct resolved models, on the same or different harness | verified cross-model | 5% |
| Same resolved model, even through different providers or harnesses | same-model fresh-context | 3% |
| Either model identity unknown, or alias equivalence unresolved | unknown-model fresh-context | 3% |

Provider, harness, or effort differences alone do not establish distinct models. Use a fresh
context for all reviewers. For 3% reviews, redistribute the missing 2% proportionally across
AI Self-Check and Behavioral per `references/evaluation-criteria.md`.

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

CLI flag takes precedence over env var. Both skip auto-detection entirely.
Setting `--secondary none` disables secondary selection; fresh local peer review at 3%
remains mandatory after the baseline.

---

## Review Prompt Template

What gets sent to the secondary harness (non-interactive).

Before sending it, classify the source material as public, private, or sensitive. Private or
sensitive repository content requires explicit user authorization for the named secondary
harness/provider; invoking skill-refiner or selecting automatic review is not enough. Without
that authorization, do not send the payload. Use the fresh local-reviewer fallback, retain its
3% weight, and log the blocked export as the reason.

**Known issue**: Codex in `exec` mode may run tools (lint, validate) instead of producing
text-only review output. If the secondary returns tool output instead of a
NO_FLAGS/MINOR_FLAG/MAJOR_FLAG response, fall back to self-review: spawn a fresh agent
on the primary harness with the review prompt template (see Phase 0, Step 6 in SKILL.md).
Classify the fallback as same-model or unknown-model fresh-context review using its evidence.
Weight it at 3% instead of 5% (composite becomes gate/40/55/3, renormalize the
missing 2% proportionally across AI Self-Check and Behavioral).

**Peer review is mandatory.** Probe the secondary first, then run the privacy/authorization
preflight before transmitting source. If no authorized secondary is available or the secondary
fails to produce a valid response, self-review
on a fresh context of the primary harness is the required fallback. Skipping review entirely
is never acceptable - even same-model fresh-context review catches issues the working context
is blind to.

```
You are reviewing a skill improvement diff. Be specific and cite exact lines.

## Relevant Original Context (before)
<changed sections plus only the surrounding rules/references needed to detect regressions>

## Diff
<git diff output of the change>

## Scoring Breakdown
Structural: <score>/100
AI Self-Check: <score>/100
Behavioral: <score>/100
Overall: <score>/100

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

## Flag Verification Protocol

Flags from the secondary model are verified before action:

### Minor Flag
1. Present the flag + diff to the primary model (fresh context, no leading)
2. Ask: "Do you agree this is a valid concern? Why or why not?"
3. If primary agrees: deduct 20 points from cross-model component, log flag
4. If primary disagrees: discard flag, log disagreement with reasoning

### Major Flag
1. Present the flag + diff + secondary's full reasoning to primary
2. Ask: "Is this change genuinely harmful? Analyze independently."
3. If primary agrees: hard revert the change, log reason
4. If primary disagrees: **escalate to circuit breaker** - pause for human review
5. Human decides: keep, revert, or modify

The contested-major-flag-to-human escalation is non-configurable even in `--mode auto`.
